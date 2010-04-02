///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reg_iface.v 3679 2008-05-04 22:23:46Z grg $
//
// Module: cnet_reg_iface.v
// Project: CPCI (PCI Control FPGA)
// Description: Register interface module to the CNET.
//              Manages the crossing of data between the PCI clock domain
//              and the *NET core clock domain.
//              Performs chip to chip communication
//
// Note: cnet_rd_time should not change a few clocks before issuing a read.
//       This is for synchronization reasons.
//
// Care should be taken not to have more than two reads in the buffer at
// the same time otherwise the result of one may overwrite the result
// of the other.
//
// Change history:
//    9/16/04 - Removed intermediate level of flops between FIFO and output
//            - Replaced tri-mode with rd, wr and tri-en signals for cpci_data
//    9/24/04 - Added timeout logic (this needs to be moved from
//              cnet_reg_access)
//    11/03/04 - Changed synchronization logic for buses.
//               Can't pass a bus through a set of flops :(
//               For cnet_rd_result_1, generate a n2p_rd_complete signal when
//               the signal should be ready.
//    2/21/05 - Reinstated intermediate level of flops between FIFO and output
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

//`include "defines.v"

module cnet_reg_iface (
            // CPCI internal signals
            // CPCI->CNET
            input [`CPCI_CNET_DATA_WIDTH-1:0]  p2n_data,  // Data going from the CPCI to the CNET
            input [`CPCI_CNET_ADDR_WIDTH-1:0]  p2n_addr,  // Data going from the CPCI to the CNET
            input          p2n_we,        // Write enable signal
            input          p2n_req,       // Read/Write request signal

            output         p2n_full,      // Full signal for FIFO from CPCI to CNET
            output         p2n_almost_full,  // Almost full signal

            // CNET->CPCI
            output reg [`CPCI_CNET_DATA_WIDTH-1:0]   n2p_data,  // Data going from the CPCI to the CNET
            output reg          n2p_rd_rdy,    // Read enable signal

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed
            input          cnet_hit,      // CNET hit signal

            input [31:0]   cnet_rd_time,  // Number of clocks before a CNET read timeout occurs
            output         cnet_rd_timeout, // Indicated a timeout has occured

            // CNET interface signals
            output reg     cpci_rd_wr_L,  // Read or write request (read high, write low)
            output reg     cpci_req,      // Transaction Request
            output reg [`CPCI_CNET_ADDR_WIDTH-1:0] cpci_addr,     // Address
            output reg [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data_wr,  // Data
            input      [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data_rd,  // Data
            output reg     cpci_data_tri_en, // Tri-state enable

            input          cpci_wr_rdy,   // Was the write accepted?
            input          cpci_rd_rdy,   // Is the read result ready?

            input          reset,
            input          pclk,          // PCI clock
            input          nclk           // *NET clock
         );


// ==================================================================
// Local
// ==================================================================

// Local version of external signals
// Allows flops in external signals to be pushed into the IOBs!
// Note: Don't need internal flops for cpci_req or cpci_data_tri_en
// as the next value doesn't depend upon the current value

wire [`CPCI_CNET_DATA_WIDTH-1:0] fifo_data;
wire [`CPCI_CNET_ADDR_WIDTH-1:0] fifo_addr;
wire fifo_wr;

reg [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data_wr_nxt;
reg [`CPCI_CNET_ADDR_WIDTH-1:0] cpci_addr_nxt;
reg cpci_rd_wr_L_nxt;
reg want_cpci_req_nxt;
reg cpci_req_nxt;
reg cpci_data_tri_en_nxt;

// Is the output from FIFO "good" - meaning is it new unprocessed data?
reg fifo_data_good, fifo_data_good_nxt;
reg fifo_data_good_d1;

// Read or write transaction has completed successfully
wire rd_done, wr_done;

// Track data coming back from the CNET
reg cnet_rd_tgl_1, cnet_rd_tgl_1_nxt;
reg cnet_rd_tgl_2, cnet_rd_tgl_2_nxt;
reg [`CPCI_CNET_DATA_WIDTH-1:0]   cnet_rd_result_1;
reg [`CPCI_CNET_DATA_WIDTH-1:0]   cnet_rd_result_1_nxt;
reg [`CPCI_CNET_DATA_WIDTH-1:0]   cnet_rd_result_2;
reg [`CPCI_CNET_DATA_WIDTH-1:0]   cnet_rd_result_2_nxt;

reg cnet_rd_tgl_1_pclk1, cnet_rd_tgl_1_pclk2, cnet_rd_tgl_1_pclk2_d1;
reg cnet_rd_tgl_2_pclk1, cnet_rd_tgl_2_pclk2, cnet_rd_tgl_2_pclk2_d1;

reg curr_result_buf, curr_result_buf_nxt;

// N-Clk reset signal
reg nreset_1, nreset;

// N-Clk cnet_reprog signal
reg ncnet_reprog_1, ncnet_reprog;

// Force a FIFO read
reg force_fifo_rd;
wire force_fifo_rd_nxt;

// Read timer
reg [31:0] rd_timer, rd_timer_nxt;
reg [31:0] max_rd_time, max_rd_time_1;
reg nrd_timeout, nrd_timeout_nxt;
reg prd_timeout, prd_timeout_1, prd_timeout_d1, prd_timeout_d2;

// Signal to force data capture
wire n2p_data_capture_1;
wire n2p_data_capture_2;

// Delayed version of cpci_wr_rdy, cpci_rd_rdy and cpci_data_rd
reg cpci_wr_rdy_d1;
reg cpci_rd_rdy_d1;
reg [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data_rd_d1;

// Want cpci req signal
reg want_cpci_req;

// ==================================================================
// Asynchronous FIFO
// ==================================================================

cpci_pci2net_16x60 cpci_pci2net_fifo (
         .din ({p2n_we, p2n_addr, p2n_data}),
	 .rd_clk (nclk),
	 .rd_en (fifo_rd_en),
	 .rst (reset || cnet_reprog),
	 .wr_clk (pclk),
	 .wr_en (p2n_req),
	 .almost_full (p2n_almost_full),
	 .dout ({fifo_wr, fifo_addr, fifo_data}),
	 .empty (fifo_empty),
	 .full (p2n_full)
      );



// ==================================================================
// Main state machine
// ==================================================================

reg [1:0] curr_state, curr_state_nxt;

`define Bus_Idle     2'h0
`define Bus_Read     2'h1
`define Bus_Write    2'h2

always @(posedge nclk)
begin
   curr_state <= curr_state_nxt;
   cpci_req <= cpci_req_nxt;
   cpci_data_wr <= cpci_data_wr_nxt;
   cpci_data_tri_en <= cpci_data_tri_en_nxt;
   cpci_addr <= cpci_addr_nxt;
   cpci_rd_wr_L <= cpci_rd_wr_L_nxt;
   want_cpci_req <= want_cpci_req_nxt;
   nrd_timeout <= nrd_timeout_nxt;
   fifo_data_good <= fifo_data_good_nxt;
   fifo_data_good_d1 <= fifo_data_good;
end

// Calculate the next state
always @*
begin
   // Default to the previous state
   curr_state_nxt = curr_state;
   nrd_timeout_nxt = nrd_timeout;

   // On either reset or the CNET being reprogrammed, go to the idle state
   if (nreset || ncnet_reprog) begin
      curr_state_nxt = `Bus_Idle;
      nrd_timeout_nxt = 1'b0;
   end
   else
      case (curr_state)
         `Bus_Idle : begin
            if (fifo_data_good)
               if (fifo_wr)
                  curr_state_nxt = `Bus_Write;
               else
                  curr_state_nxt = `Bus_Read;
         end

         `Bus_Read : begin
            // Force a turn-around cycle after a read
            if (rd_done) begin
               curr_state_nxt = `Bus_Idle;
               if (!cpci_rd_rdy_d1)
                  nrd_timeout_nxt = ~nrd_timeout;
            end
         end

         `Bus_Write : begin
            if (wr_done)
               if (fifo_data_good) begin
                  if (fifo_wr)
                     curr_state_nxt = `Bus_Write;
                  else
                     curr_state_nxt = `Bus_Read;
               end
               else begin
                  curr_state_nxt = `Bus_Idle;
               end
         end
      endcase
end

// Calculate the next value of the cpci* signals
always @*
begin
   // Set defaults
   cpci_data_wr_nxt = cpci_data_wr;
   cpci_addr_nxt = cpci_addr;
   cpci_rd_wr_L_nxt = cpci_rd_wr_L;
   want_cpci_req_nxt = want_cpci_req && !rd_done && !(wr_done && cpci_wr_rdy_d1);
   cpci_req_nxt = want_cpci_req && !rd_done && !(wr_done && cpci_wr_rdy_d1) && (cpci_rd_wr_L|| cpci_wr_rdy_d1);
   cpci_data_tri_en_nxt = want_cpci_req && !rd_done && !(wr_done && cpci_wr_rdy_d1) && !cpci_rd_wr_L;

   // On either reset or the CNET being reprogrammed, go to the idle state
   if (nreset || ncnet_reprog) begin
      cpci_data_wr_nxt = 'h0;
      cpci_addr_nxt = 'h0;
      cpci_rd_wr_L_nxt = 1'b0;
      want_cpci_req_nxt = 1'b0;
      cpci_req_nxt = 1'b0;
      cpci_data_tri_en_nxt = 1'b0;
   end
   else if (fifo_data_good && (!want_cpci_req || wr_done)) begin
      // Latch through the next values
      cpci_data_wr_nxt = fifo_data;
      cpci_addr_nxt = fifo_addr;
      cpci_rd_wr_L_nxt = !fifo_wr;
      want_cpci_req_nxt = 1'b1;
      cpci_req_nxt = !fifo_wr || cpci_wr_rdy_d1;
      cpci_data_tri_en_nxt = fifo_wr;
   end
end

// fifo_data_good
always @*
begin
   fifo_data_good_nxt = fifo_data_good;

   if (reset || cnet_reprog)
      fifo_data_good_nxt = 1'b0;
   else if (fifo_rd_en && !fifo_empty)
      fifo_data_good_nxt = 1'b1;
   else if (fifo_data_good && (!want_cpci_req || wr_done) && cpci_wr_rdy_d1)
      fifo_data_good_nxt = 1'b0;
end


// ==================================================================
// Latch the data returning from the CNET
// ==================================================================

always @(posedge nclk)
begin
   curr_result_buf <= curr_result_buf_nxt;

   cnet_rd_result_1 <= cnet_rd_result_1_nxt;
   cnet_rd_tgl_1 <= cnet_rd_tgl_1_nxt;

   cnet_rd_result_2 <= cnet_rd_result_2_nxt;
   cnet_rd_tgl_2 <= cnet_rd_tgl_2_nxt;
end

always @*
begin
   // Restore prev value
   curr_result_buf_nxt = curr_result_buf;

   cnet_rd_tgl_1_nxt = cnet_rd_tgl_1;
   cnet_rd_result_1_nxt = cnet_rd_result_1;

   cnet_rd_tgl_2_nxt = cnet_rd_tgl_2;
   cnet_rd_result_2_nxt = cnet_rd_result_2;

   if (nreset) begin
      curr_result_buf_nxt = 1'b0;
      cnet_rd_tgl_1_nxt = 1'b0;
      cnet_rd_result_1_nxt = 'h0;
      cnet_rd_tgl_2_nxt = 1'b0;
      cnet_rd_result_2_nxt = 'h0;
   end
   else if (want_cpci_req && rd_done) begin
      if (!curr_result_buf) begin
         cnet_rd_tgl_1_nxt = !cnet_rd_tgl_1;
         cnet_rd_result_1_nxt = cpci_rd_rdy_d1 ? cpci_data_rd_d1 : 'h dead_beef;
      end
      else begin
         cnet_rd_tgl_2_nxt = !cnet_rd_tgl_2;
         cnet_rd_result_2_nxt = cpci_rd_rdy_d1 ? cpci_data_rd_d1 : 'h dead_beef;
      end

      curr_result_buf_nxt = ~curr_result_buf_nxt;
   end
end

// Synchronize
//
// Note: No series of flops for the bus to do with sync issues
//
// Wait for the capture signal to propagate through and then latch when
// capture is asserted. (The output on cnet_rd_result_1 HAS to be stable then
// provided that we haven't changed the value on it's output.)
always @(posedge pclk)
begin
   if (n2p_data_capture_1) begin
      n2p_data <= cnet_rd_result_1;
   end
   else if (n2p_data_capture_2) begin
      n2p_data <= cnet_rd_result_2;
   end
   n2p_rd_rdy <= n2p_data_capture_1 | n2p_data_capture_2;
end

always @(posedge pclk)
begin
   if (reset) begin
      cnet_rd_tgl_1_pclk1 <= 1'b0;
      cnet_rd_tgl_1_pclk2 <= 1'b0;
      cnet_rd_tgl_1_pclk2_d1 <= 1'b0;
      cnet_rd_tgl_2_pclk1 <= 1'b0;
      cnet_rd_tgl_2_pclk2 <= 1'b0;
      cnet_rd_tgl_2_pclk2_d1 <= 1'b0;
   end
   else begin
      cnet_rd_tgl_1_pclk1 <= cnet_rd_tgl_1;
      cnet_rd_tgl_1_pclk2 <= cnet_rd_tgl_1_pclk1;
      cnet_rd_tgl_1_pclk2_d1 <= cnet_rd_tgl_1_pclk2;
      cnet_rd_tgl_2_pclk1 <= cnet_rd_tgl_2;
      cnet_rd_tgl_2_pclk2 <= cnet_rd_tgl_2_pclk1;
      cnet_rd_tgl_2_pclk2_d1 <= cnet_rd_tgl_2_pclk2;
   end
end

assign n2p_data_capture_1 = cnet_rd_tgl_1_pclk2 != cnet_rd_tgl_1_pclk2_d1;
assign n2p_data_capture_2 = cnet_rd_tgl_2_pclk2 != cnet_rd_tgl_2_pclk2_d1;


// ==================================================================
// Read timeout logic
// ==================================================================

always @(posedge nclk)
begin
   rd_timer <= rd_timer_nxt;
end

always @*
begin
   rd_timer_nxt = rd_timer;

   if (fifo_rd_en && !fifo_empty)
      rd_timer_nxt = max_rd_time;
   else if (cpci_rd_wr_L && rd_timer != 0)
      rd_timer_nxt = rd_timer - 'h1;
end

always @(posedge nclk)
begin
   max_rd_time <= max_rd_time_1;
   max_rd_time_1 <= cnet_rd_time;
end

always @(posedge pclk)
begin
   if (reset) begin
      prd_timeout_1 <= 1'b0;
      prd_timeout <= 1'b0;
      prd_timeout_d1 <= 1'b0;
      prd_timeout_d2 <= 1'b0;
   end
   else begin
      prd_timeout_1 <= nrd_timeout;
      prd_timeout <= prd_timeout_1;
      prd_timeout_d1 <= prd_timeout;
      prd_timeout_d2 <= prd_timeout_d1;
   end
end

// Note: Use d1 and d2 as output takes one extra clocked since it has to
// be registered before it is output.
assign cnet_rd_timeout = prd_timeout_d1 != prd_timeout_d2;

// ==================================================================
// N-Reset generation
// ==================================================================

always @(posedge nclk)
begin
   nreset_1 <= reset;
   nreset <= nreset_1;
end

always @(posedge nclk)
begin
   ncnet_reprog_1 <= cnet_reprog;
   ncnet_reprog <= ncnet_reprog_1;
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

// Delay cpci_wr_rdy, cpci_rd_rdy and cpci_rd_data
// Allows FFs to be pushed into IOBs making timing *much* easier :)
always @(posedge nclk) begin
   cpci_wr_rdy_d1 <= cpci_wr_rdy;
   cpci_rd_rdy_d1 <= cpci_rd_rdy;
   cpci_data_rd_d1 <= cpci_data_rd;
end

// Generate the read and write done signals
assign rd_done = cpci_rd_wr_L && (cpci_rd_rdy_d1 || rd_timer == 'h0);
assign wr_done = !cpci_rd_wr_L && cpci_wr_rdy_d1;

// When should data be read from the fifo?
assign fifo_rd_en = !fifo_data_good || force_fifo_rd || wr_done;

// Force a FIFO read on the next clock if the bus is currently idle and
// there isn't currently a read in progress
always @(posedge nclk) begin
   force_fifo_rd <= force_fifo_rd_nxt;
end
assign force_fifo_rd_nxt = !want_cpci_req && !fifo_data_good && !fifo_rd_en;

// ==================================================================
// Debug logic
// ==================================================================

// synthesis translate_off

// Attempt to detect if the cnet_rd_time changes when starting a read
reg [31:0] cnet_rd_time_d1;

always @(posedge pclk)
begin
   if (reset)
      cnet_rd_time_d1 <= 'h0;
   else
      cnet_rd_time_d1 <= cnet_rd_time;

   if (cnet_rd_time != cnet_rd_time_d1 && fifo_rd_en && !fifo_empty)
      $display($time, " ERROR: cnet_rd_time changed while initiating a read in %m");
end

// Try to detect when a read result is missed (should never happen as there
// shouldn't be overlapping reads)
reg [1:0] wait_for_capture;

always @(posedge nclk)
begin
   if (nreset)
      wait_for_capture <= 2'b00;
   else if (cpci_req && rd_done) begin
      // Check to see if there is an outstanding capture request
      if (wait_for_capture == 2'b11)
         $display($time, " ERROR: Read data returned while waiting for previous read to be captured in %m");
      wait_for_capture <= {wait_for_capture[0], 1'b1};
   end
end

always @(posedge pclk)
begin
   if (n2p_data_capture_1 || n2p_data_capture_2)
      wait_for_capture <= {wait_for_capture[0], 1'b0};
end

// synthesis translate_on

endmodule // cnet_reg_iface

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
