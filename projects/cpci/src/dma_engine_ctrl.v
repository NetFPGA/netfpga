///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: dma_engine_ctrl.v 3635 2008-04-21 03:42:17Z grg $
//
// Module: dma_engine_ctrl.v
// Project: CPCI (PCI Control FPGA)
// Description: Main state machine for the DMA engine
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 12/9/07 - Split from DMA engine
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine_ctrl (
            // PCI Signals
            output reg     dma_rd_intr,   // Request an interrupt to indicate read done
            output reg     dma_wr_intr,   // Request an interrupt to indicate write done

            // CPCI register interface signals
            output reg [3:0] dma_rd_mac,    // Which MAC was read data from

            input [31:0]   dma_wr_size,   // Packet size when performing writes

            input          dma_rd_owner,  // Who owns read buffer (1 = CPCI)
            input          dma_wr_owner,  // Who owns write buffer (1 = CPCI)

            output reg     dma_rd_done,   // The current read is done
            output reg     dma_wr_done,   // The current write is done

            output reg     dma_rd_size_err, // Read size is invalid
            output reg     dma_wr_size_err, // Write size is invalid

            output reg     dma_rd_addr_err, // Read address is invalid
            output reg     dma_wr_addr_err, // Write address is invalid

            output reg     dma_rd_mac_err, // No data is available to read from the requested MAC (not used)
            output reg     dma_wr_mac_err, // No space is available to write to the requested MAC

            output         dma_fatal_err, // Non-recoverable error

            output         dma_in_progress, // Is a DMA transfer currently taking place?

            // CNET DMA interface signals
            output reg     dma_rd_request, // Request packet from buffer

            input [15:0]   dma_xfer_size, // Transfer size of DMA read
            input          dma_rd_en,     // Read a word from the buffer

            input [15:0]   dma_can_wr_pkt, // Space in Virtex for full pkt

            input          dma_queue_info_avail,// Is DMA tx full info avail?

            input          dma_nearly_empty, // Three words or less left in the buffer
            input          dma_all_in_buf, // All data for the packet is in the buffer

            input          dma_wr_rdy,    // There's space in the buffer

            input          tx_wait_done,
            input          to_cnet_done,
            input          wr_empty,
            input          fatal,         // Fatal error
            output reg     start,         // Start (or continue) transferring
            input          done,          // Is the transfer done?

            output reg     ld_xfer_cnt,   // Load the xfer counter
            output reg     ld_dma_addr,   // Load the DMA address

            output reg     read_get_len,  // Record the length of the packet during a write
            output reg     write_start,   // In the write start state

            output         ctrl_done,     // In the done state

            input          dma_rd_request_q_vld,
            input [3:0]    dma_rd_request_q,
            input [15:0]   dma_wr_mac_one_hot,

            output reg     xfer_is_rd,    // Xfer is a read
            output reg     discard,       // Discard the current word

            output reg     reset_xfer_timer, // Reset the xfer timer
            output         enable_xfer_timer, // Enable the xfer timer
            input          abort_xfer,    // Abort the transfer

            output reg     tx_wait_cnt_ld,// Tx Wait counter

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Try to start a PCI transaction
reg start_nxt;

reg ld_xfer_cnt_nxt;

// Address pointer
reg ld_dma_addr_nxt;

// DMA request signals
reg dma_rd_request_nxt;

// Delayed version of dma_rd_en
reg dma_rd_en_d1;

// Read and write done
reg dma_rd_done_nxt, dma_wr_done_nxt;

reg next_dma_rd_done_nxt;
reg next_dma_rd_done;

reg next_dma_wr_done_nxt;
reg next_dma_wr_done;

// Transfer direction
reg xfer_is_rd_nxt;

// Discard a word from the read fifo
reg discard_nxt;

// Error signals
reg dma_rd_size_err_nxt;
reg dma_wr_size_err_nxt;
reg dma_rd_addr_err_nxt;
reg dma_wr_addr_err_nxt;
reg dma_rd_mac_err_nxt;
reg dma_wr_mac_err_nxt;

reg next_dma_rd_size_err;
reg next_dma_rd_size_err_nxt;
reg next_dma_wr_size_err;
reg next_dma_wr_size_err_nxt;
reg next_dma_wr_mac_err;
reg next_dma_wr_mac_err_nxt;

// Transfer timer
reg reset_xfer_timer_nxt;

// DMA interrupt signal
reg dma_rd_intr_nxt, dma_wr_intr_nxt;

reg next_dma_rd_intr;
reg next_dma_rd_intr_nxt;
reg next_dma_wr_intr;
reg next_dma_wr_intr_nxt;

// State variables
reg read_start_nxt;
reg read_get_len_nxt;
reg write_start_nxt;

// Which MAC did we read?
reg [3:0] dma_rd_mac_nxt;

// ==================================================================
// Control state machine
// ==================================================================

/* The state machine has the following states:
 *   DMAC_Idle        - Waiting for a transaction
 *   DMAC_Read        - Read transaction
 *   DMAC_Write       - Write transaction
 */

reg [3:0] curr_state, curr_state_nxt;

`define DMAC_Idle          4'h0
`define DMAC_Read_Start    4'h1
`define DMAC_Read_Get_Len  4'h2
`define DMAC_Read          4'h3
`define DMAC_Write_Start   4'h4
`define DMAC_Write         4'h5
`define DMAC_Wait          4'h8
`define DMAC_Done          4'h9
`define DMAC_Pre_Idle      4'ha
`define DMAC_Wait_Tx       4'hb
`define DMAC_Error         4'hf

always @(posedge clk)
begin
   curr_state <= curr_state_nxt;

   start <= start_nxt;
   ld_xfer_cnt <= ld_xfer_cnt_nxt;
   ld_dma_addr <= ld_dma_addr_nxt;
   discard <= discard_nxt;
   reset_xfer_timer <= reset_xfer_timer_nxt;

   // External signals
   xfer_is_rd <= xfer_is_rd_nxt;
   dma_rd_request <= dma_rd_request_nxt;
   dma_rd_mac <= dma_rd_mac_nxt;
   dma_rd_done <= dma_rd_done_nxt;
   dma_wr_done <= dma_wr_done_nxt;
   next_dma_rd_done <= next_dma_rd_done_nxt;
   next_dma_wr_done <= next_dma_wr_done_nxt;
   dma_rd_size_err <= dma_rd_size_err_nxt;
   dma_wr_size_err <= dma_wr_size_err_nxt;
   dma_rd_addr_err <= dma_rd_addr_err_nxt;
   dma_wr_addr_err <= dma_wr_addr_err_nxt;
   dma_rd_mac_err <= dma_rd_mac_err_nxt;
   dma_wr_mac_err <= dma_wr_mac_err_nxt;
   next_dma_rd_size_err <= next_dma_rd_size_err_nxt;
   next_dma_wr_size_err <= next_dma_wr_size_err_nxt;
   next_dma_wr_mac_err <= next_dma_wr_mac_err_nxt;
   dma_rd_intr <= dma_rd_intr_nxt;
   dma_wr_intr <= dma_wr_intr_nxt;
   next_dma_rd_intr <= next_dma_rd_intr_nxt;
   next_dma_wr_intr <= next_dma_wr_intr_nxt;
   read_get_len <= read_get_len_nxt;
   write_start <= write_start_nxt;
end

always @*
begin
   // Set defaults
   curr_state_nxt = curr_state;

   start_nxt = start;
   ld_xfer_cnt_nxt = 1'b0;
   ld_dma_addr_nxt = 1'b0;
   discard_nxt = 1'b0;
   reset_xfer_timer_nxt = 1'b0;

   xfer_is_rd_nxt = xfer_is_rd;
   dma_rd_request_nxt = 1'b0;
   dma_rd_mac_nxt = dma_rd_mac;
   dma_rd_done_nxt = 1'b0;
   dma_wr_done_nxt = 1'b0;
   next_dma_rd_done_nxt = next_dma_rd_done;
   next_dma_wr_done_nxt = next_dma_wr_done;
   dma_rd_size_err_nxt = 1'b0;
   dma_wr_size_err_nxt = 1'b0;
   dma_rd_addr_err_nxt = 1'b0;
   dma_wr_addr_err_nxt = 1'b0;
   dma_rd_mac_err_nxt = 1'b0;
   dma_wr_mac_err_nxt = 1'b0;
   next_dma_rd_size_err_nxt = next_dma_rd_size_err;
   next_dma_wr_size_err_nxt = next_dma_wr_size_err;
   next_dma_wr_mac_err_nxt = next_dma_wr_mac_err;
   dma_rd_intr_nxt = 1'b0;
   dma_wr_intr_nxt = 1'b0;
   next_dma_rd_intr_nxt = next_dma_rd_intr;
   next_dma_wr_intr_nxt = next_dma_wr_intr;
   read_get_len_nxt = read_get_len;
   write_start_nxt = write_start;

   tx_wait_cnt_ld = 0;


   // On either reset or the CNET being reprogrammed, go to the idle state
   if (reset || cnet_reprog) begin
      curr_state_nxt = `DMAC_Idle;
      start_nxt = 1'b0;
      xfer_is_rd_nxt = 1'b0;
      dma_rd_mac_nxt = 4'h0;
      next_dma_rd_done_nxt = 1'b0;
      next_dma_wr_done_nxt = 1'b0;
      next_dma_rd_intr_nxt = 1'b0;
      next_dma_wr_intr_nxt = 1'b0;
      next_dma_rd_size_err_nxt = 1'b0;
      next_dma_wr_size_err_nxt = 1'b0;
      next_dma_wr_mac_err_nxt = 1'b0;
   end
   else
      case (curr_state)
         `DMAC_Idle : begin
            // Check if there is a read request and there is data available
            if (dma_rd_owner && dma_rd_request_q_vld) begin
               curr_state_nxt = `DMAC_Read_Start;
               reset_xfer_timer_nxt = 1'b1;
               xfer_is_rd_nxt = 1'b1;
               read_start_nxt = 1'b1;
            end
            // Check if there is a write request
            else if (dma_wr_owner) begin
               curr_state_nxt = `DMAC_Write_Start;
               reset_xfer_timer_nxt = 1'b1;
               xfer_is_rd_nxt = 1'b0;
               write_start_nxt = 1'b1;
            end
         end

         `DMAC_Read_Start : begin
            curr_state_nxt = `DMAC_Read_Get_Len;

            // Sample the target address
            ld_dma_addr_nxt = 1'b1;

            // Instruct the CNET to start transferring a packet
            dma_rd_request_nxt = 1'b1;
            dma_rd_mac_nxt = dma_rd_request_q;

            read_start_nxt = 1'b0;
            read_get_len_nxt = 1'b1;
         end

         `DMAC_Read_Get_Len : begin
            if (dma_rd_en && !dma_rd_en_d1) begin
               // Discard the word from the FIFO
               discard_nxt = 1'b1;
            end

            if (abort_xfer) begin
               curr_state_nxt = fatal ? `DMAC_Error : `DMAC_Done;
               next_dma_rd_done_nxt = !fatal;
            end
            // Capture the first word that is transferred as the length
            else if (dma_rd_en_d1) begin
               // Make sure the size is < 2048
               if (dma_xfer_size[15:11] != 'h0) begin
                  curr_state_nxt = `DMAC_Done;
                  next_dma_rd_done_nxt = 1'b1;
                  next_dma_rd_size_err_nxt = 1'b1;
               end
               else begin
                  curr_state_nxt = `DMAC_Wait;

                  // Capture the length of the transfer
                  ld_xfer_cnt_nxt = 1'b1;
               end

               // Record that we're no longer in the get len state
               read_get_len_nxt = 1'b0;
            end
         end

         `DMAC_Read : begin
            // Generate a start signal if the buffer is not empty or if all
            // of the data has been transferred
            if (!dma_nearly_empty || (dma_all_in_buf && !done))
               start_nxt = 1'b1;
            else if (dma_nearly_empty || done || abort_xfer)
               start_nxt = 1'b0;

            // Return to the idle state when done
            if (done || abort_xfer) begin
               curr_state_nxt = fatal ? `DMAC_Error : `DMAC_Done;
               next_dma_rd_done_nxt = !fatal;
               next_dma_rd_intr_nxt = !abort_xfer;
            end
         end

         `DMAC_Write_Start : begin
            if ((dma_wr_mac_one_hot & dma_can_wr_pkt) == 'h0) begin
	       // wait a while to see if current pkt gets transmitted
	       // before we indicate an error.
               curr_state_nxt = `DMAC_Wait_Tx;
	       tx_wait_cnt_ld = 1;
            end
            // Make sure the size is < 2048
            else if (dma_wr_size[31:11] != 'h0) begin
               curr_state_nxt = `DMAC_Done;
               next_dma_wr_done_nxt = 1'b1;
               next_dma_wr_size_err_nxt = 1'b1;
            end
            else begin
               curr_state_nxt = `DMAC_Wait;

               // Sample the target address
               ld_dma_addr_nxt = 1'b1;
               ld_xfer_cnt_nxt = 1'b1;

               // Start the transfer
               start_nxt = 1'b1;
            end

            // Record that we're leaving the write start state
            write_start_nxt = 1'b0;
         end

         `DMAC_Write : begin
            // Halt the transfer if the register buffer to the CNET becomes full
            // or we've transferred everything or a timeout occurs
            if (done || !dma_wr_rdy || abort_xfer)
               start_nxt = 1'b0;
            else if (wr_empty)
               start_nxt = 1'b1;

            // Return to the idle state when we're done sending all data to
            // the CNET
            if (to_cnet_done || abort_xfer) begin
               curr_state_nxt = fatal ? `DMAC_Error : `DMAC_Done;
               next_dma_wr_done_nxt = !fatal;
               next_dma_wr_intr_nxt = !abort_xfer;
            end
         end

         `DMAC_Wait : begin
            // Wait a clock cycle for counts to settle
            curr_state_nxt = xfer_is_rd ? `DMAC_Read : `DMAC_Write ;
         end

         `DMAC_Done : begin
            if (dma_queue_info_avail) begin
               curr_state_nxt = `DMAC_Pre_Idle;

               // Copy the appropriate *next* signals into the outputs
               dma_rd_done_nxt = next_dma_rd_done;
               dma_rd_intr_nxt = next_dma_rd_intr;

               dma_wr_done_nxt = next_dma_wr_done;
               dma_wr_intr_nxt = next_dma_wr_intr;

               dma_rd_size_err_nxt = next_dma_rd_size_err;
               dma_wr_size_err_nxt = next_dma_wr_size_err;
               dma_wr_mac_err_nxt = next_dma_wr_mac_err;

               // Clear the *next* signals
               next_dma_rd_done_nxt = 1'b0;
               next_dma_wr_done_nxt = 1'b0;
               next_dma_rd_intr_nxt = 1'b0;
               next_dma_wr_intr_nxt = 1'b0;
               next_dma_rd_size_err_nxt = 1'b0;
               next_dma_wr_size_err_nxt = 1'b0;
               next_dma_wr_mac_err_nxt = 1'b0;
            end
         end

         `DMAC_Pre_Idle : begin
            // Wait here for one cycle for the read/write flags to be reset
            curr_state_nxt = `DMAC_Idle;
         end

         `DMAC_Error : begin
            // Stay here until reset
         end

         `DMAC_Wait_Tx : begin
	    if (tx_wait_done) begin
	       if ((dma_wr_mac_one_hot & dma_can_wr_pkt) == 'h0) begin
		  curr_state_nxt = `DMAC_Done;
		  next_dma_wr_done_nxt = 1'b1;
		  next_dma_wr_mac_err_nxt = 1'b1;
	       end
	       else // go back and try again
		 curr_state_nxt = `DMAC_Write_Start;
	    end
         end

         default : begin
            curr_state_nxt = `DMAC_Idle;
         end
      endcase
end

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      dma_rd_en_d1 <= 1'b0;
   else
      dma_rd_en_d1 <= dma_rd_en;
end

// ==================================================================
// Miscelaneous signal generation
// ==================================================================

assign dma_fatal_err = curr_state == `DMAC_Error;
assign dma_in_progress = curr_state != `DMAC_Idle;
assign enable_xfer_timer = curr_state != `DMAC_Idle;

assign ctrl_done = curr_state == `DMAC_Done;

endmodule // dma_engine_ctrl
