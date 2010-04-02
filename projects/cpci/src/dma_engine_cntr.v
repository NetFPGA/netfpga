///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: dma_engine_cntr.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: dma_engine_cntr.v
// Project: CPCI (PCI Control FPGA)
// Description: Counters for the DMA engine
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 12/9/07 - Split from the DMA engine
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine_cntr (
            // PCI Signals
            input          dma_data_vld,  // Indicates data should be captured
                                          // from pci_data during a read or
                                          // that a data transaction has
                                          // occured during a write.
            input          dma_src_en,    // The next piece of data should
                                          // be provided on dma_data

            // CPCI register interface signals
            input [31:0]   dma_rd_addr,   // Address when performing reads
            input [31:0]   dma_wr_addr,   // Address when performing writes

            output reg [31:0] dma_rd_size,// Packet size when performing reads
            input [31:0]   dma_wr_size,   // Packet size when performing writes

            // CNET DMA interface signals
            input [31:0]   dma_data_frm_cnet, // DMA data to be transfered

            // DMA engine signals
            output         tx_wait_done,  // TX wait counter expired
            output         to_cnet_done,  // Finished transfering data to CNET

            input          retry,         // Retry the transaction
            input          rd_undo,       // Undo a read operation
            input          xfer_is_rd,    // Transfer direction

            input          read_get_len,  // Get the length for a read operation
            input          write_start,   // Start a write operation

            input          read_from_cnet, // Just read a word from the cnet

            input          wr_data_rdy,   // Data is ready to write into the write fifo
            input          rd_data_rdy,   // Data is ready to write into the read fifo

            input          tx_wait_cnt_ld,// Load the tx wait conter
            input          ld_dma_addr,   // Load the current DMA address
            input          ld_xfer_cnt,   // Load the xfer cntr

            output         last_word_to_cnet, // Indicates last word going to CNET
            output         last_word_from_cnet, // Indicates last word coming from CNET

            output reg [1:0] non_aligned_bytes, // Number of non-aligned bytes in first word

            output reg [3:0] first_word_be, // Byte-Enable for the first word
            output reg [3:0] last_word_be,  // Byte-Enable for the last word

            output reg [8:0] xfer_cnt_start, // Number of words to transfer
            output reg [8:0] to_cnet_cnt_start,

            output reg [`PCI_ADDR_WIDTH - 1 : 2] dma_addr, // Address to send to host

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Transfer counters
reg [8:0] from_cnet_cnt_start;
reg [8:0] to_cnet_cnt;
reg [8:0] from_cnet_cnt;

// Address pointer
reg [`PCI_ADDR_WIDTH - 1 : 2] start_addr;

// Transfer timer
reg [31:0] xfer_timer;

// Retry counter
reg [15:0] retry_cnt;

// Tx Wait counter
reg [8:0] tx_wait_cnt;

// ==================================================================
// Control state machine
// ==================================================================


wire [1:0] addr_word_offset;
assign addr_word_offset = xfer_is_rd ? dma_rd_addr[1:0] : dma_wr_addr[1:0];

always @(posedge clk)
begin
   // On either reset or the CNET being reprogrammed, go to the idle state
   if (reset || cnet_reprog) begin
      xfer_cnt_start <= 'h0;
      to_cnet_cnt_start <= 'h0;
      from_cnet_cnt_start <= 'h0;
      start_addr <= 'h0;
      non_aligned_bytes <= 'h0;
      first_word_be <= 'h0;
      last_word_be <= 'h0;
      dma_rd_size <= 'h0;
   end
   else begin
      // Work out how many words to send to the CNET
      to_cnet_cnt_start <= dma_wr_size[10:2] + (|(dma_wr_size[1:0]) ? 'h1 : 'h0);

      // Capture the length of the transfer
      if (read_get_len)
         from_cnet_cnt_start <= dma_data_frm_cnet[10:2] + (|(dma_data_frm_cnet[1:0]) ? 'h1 : 'h0);

      // Sample the target address
      if (xfer_is_rd)
         start_addr <= dma_rd_addr[`PCI_ADDR_WIDTH - 1 : 2];
      else
         start_addr <= dma_wr_addr[`PCI_ADDR_WIDTH - 1 : 2];

      // Work out the number of words to transfer
      //
      // This logic may look weird but we have to take into
      // account partial word transfers.
      //
      // The following table summarises the number of additional
      // words to transfer on top of the dma_wr_size[10:2] or
      // dma_data_frm_cnet[10:2]:
      //
      //             |              Len[1:0]              |
      //  Addr[1:0]  |   00   |   01   |   10   |   11    |
      // =================================================|
      //      00     |   +0   |   +1   |   +1   |   +1    |
      //      01     |   +1   |   +1   |   +1   |   +1    |
      //      10     |   +1   |   +1   |   +1   |   +2    |
      //      11     |   +1   |   +1   |   +2   |   +2    |
      if (read_get_len)
         xfer_cnt_start <= dma_data_frm_cnet[10:2] +
                               (|{dma_data_frm_cnet[1:0], dma_rd_addr[1:0]}) +
                               (dma_data_frm_cnet[1] & dma_rd_addr[1] &
                               (dma_data_frm_cnet[0] | dma_rd_addr[0]));
      else if (write_start)
         xfer_cnt_start <= dma_wr_size[10:2] +
                               (|{dma_wr_size[1:0],dma_wr_addr[1:0]}) +
                               (dma_wr_size[1] & dma_wr_addr[1] &
                                (dma_wr_size[0] | dma_wr_addr[0]));


      // Work out the number of non-aligned bytes to read/write in the
      // first word
      case (addr_word_offset)
         2'b00 : begin
            non_aligned_bytes <= 2'b00;
            first_word_be <= 4'b0000;
         end

         2'b01 : begin
            non_aligned_bytes <= 2'b11;
            first_word_be <= 4'b1000;
         end

         2'b10 : begin
            non_aligned_bytes <= 2'b10;
            first_word_be <= 4'b1100;
         end

         default : begin
            non_aligned_bytes <= 2'b01;
            first_word_be <= 4'b1110;
         end
      endcase

      if (read_get_len) begin
         // Capture the length of the transfer
         dma_rd_size <= dma_data_frm_cnet & 'hfff;

         // Work out the byte enable for the final word
         // Note: BE is active low
         case (dma_data_frm_cnet[1:0] + dma_rd_addr[1:0])
            2'b01   : last_word_be <= 4'b0111;
            2'b10   : last_word_be <= 4'b0011;
            2'b11   : last_word_be <= 4'b0001;
            default : last_word_be <= 4'b0000;
         endcase
      end
      else if (write_start) begin
         // Work out the byte enable for the final word
         // Note: BE is active low
         case (dma_wr_size[1:0] + dma_wr_addr[1:0])
            2'b01   : last_word_be <= 4'b0111;
            2'b10   : last_word_be <= 4'b0011;
            2'b11   : last_word_be <= 4'b0001;
            default : last_word_be <= 4'b0000;
         endcase
      end
   end
end


// ==================================================================
// Tx wait counter
// ==================================================================

always @(posedge clk)
  if (reset)
     tx_wait_cnt <= 'h0;
  else if (tx_wait_cnt_ld)
     tx_wait_cnt <= 'd400;
  else if (tx_wait_cnt > 0)
     tx_wait_cnt <= tx_wait_cnt - 'h1;

assign tx_wait_done = tx_wait_cnt == 'h0;


// ==================================================================
// Address counter
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      dma_addr <= 'h0;
   else if (ld_dma_addr)
      dma_addr <= start_addr;
   else if (dma_data_vld)
      dma_addr <= dma_addr + 'h1;
end


// ==================================================================
// CNET tranfser counters
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      to_cnet_cnt <= 'h0;
   else if (ld_xfer_cnt)
      to_cnet_cnt <= to_cnet_cnt_start;
   else if (wr_data_rdy)
      to_cnet_cnt <= to_cnet_cnt - 'h1;
end

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      from_cnet_cnt <= 'h0;
   else if (ld_xfer_cnt && read_from_cnet)
      from_cnet_cnt <= from_cnet_cnt_start - 'h1;
   else if (ld_xfer_cnt && !read_from_cnet)
      from_cnet_cnt <= from_cnet_cnt_start;
   else if (read_from_cnet)
      from_cnet_cnt <= from_cnet_cnt - 'h1;
end

assign to_cnet_done = to_cnet_cnt == 'h0;

// Note: last_word_from_cnet is asserted on 'h2 due to delay in pipeline
assign last_word_to_cnet = to_cnet_cnt == 'h1;
assign last_word_from_cnet = from_cnet_cnt == 'h1;

endmodule // dma_engine_cntr
