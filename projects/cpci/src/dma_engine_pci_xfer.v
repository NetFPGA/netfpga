///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: dma_engine_pci_xfer.v 3635 2008-04-21 03:42:17Z grg $
//
// Module: dma_engine_pci_xfer.v
// Project: CPCI (PCI Control FPGA)
// Description: PCI interface for DMA engine
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 12/10/07 - Split from dma_engine
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine_pci_xfer(
            // PCI Signals
            output [`PCI_DATA_WIDTH-1:0] dma_data, // Data being written to host
            output [3:0]   dma_cbe,       // Command/Byte Enables for DMA data
            output         dma_vld,       // There's currently data on the dma_data_bus

            output         dma_wrdn,      // Transfer direction
                                          // 1 - Write, 0 - read
            output         dma_request,   // Request a new transaction
            output         dma_complete,  // Finish current transaction


            input          dma_data_vld,  // Indicates data should be captured
                                          // from pci_data during a read or
                                          // that a data transaction has
                                          // occured during a write.
            input          dma_src_en,    // The next piece of data should
                                          // be provided on dma_data

            input          dma_lat_timeout,  // Latency timer has expired
            input          dma_addr_st,   // Core is in the address state
            input          dma_data_st,   // Core is in the data state

            input          pci_retry,     // Retry signal from CSRs
            input          pci_fatal,     // Fatal error signal from CSRs

            // CPCI register interface signals
            input          host_is_le,    // The host is little endian

            input [31:0]   dma_time,      // Number of clocks before a DMA transfer times out
            output         dma_timeout,   // Indicates a timeout has occured

            input [15:0]   dma_retries,   // Number of retries before a DMA transfer times out
            output         dma_retry_expire, // DMA retry counter has expired

            // CNET DMA interface signals
            input          dma_wr_rdy,    // There is space in the buffer

            input          dma_nearly_empty, // Three words or less left in the buffer
            input          dma_all_in_buf, // All data for the packet is in the buffer

            // DMA engine signals
            output         done,          // Transfer done?

            output reg     fatal,
            output reg     retry,

            output         abort_xfer,    // Abort the transfer
            output         rd_undo,       // Undo the current read

            input          start,
            input          ld_xfer_cnt,
            input          xfer_is_rd,    // Transfer direction

            output         first_word_pci,// Transferring first word on PCI bus
            output         last_word_pci, // Transferring last word on PCI bus

            input          wr_fifo_empty, // Write fifo is empty

            input          dma_in_progress, // Is the engine idle
            input          enable_xfer_timer,
            input          reset_xfer_timer, // Reset the xfer counter

            input [3:0]    first_word_be,
            input [3:0]    last_word_be,

            input [8:0]    xfer_cnt_start, // Number of words to transfer

            output reg [8:0] xfer_cnt,    // Number of bytes left to transfer
                                          // Note: xfer_cnt is how many have
                                          // actually been transferred and
                                          // acknowledged in the case of a 'read'.

            input [`PCI_ADDR_WIDTH - 1 : 2] dma_addr, // Address pointer
            input [`PCI_DATA_WIDTH - 1 : 0] rd_dout, // Output from FIFO

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Keep track of the data state
reg dma_data_d1;
wire dma_data_fell;

// Transaction termination variables
wire cnt3, cnt2, cnt1;
wire fin3, fin2, fin1;

wire assert_complete;
reg hold_complete;

wire full_buffer_abort;

// Command to send on CBE bus
wire [3:0] command;
wire [3:0] byte_enable;

// Byte-Enable for the first and last words
wire [3:0] first_word_be_swapped;
wire [3:0] last_word_be_swapped;

// Transfer timer
reg [31:0] xfer_timer;

// Retry counter
reg [15:0] retry_cnt;

// PCI transfer counter
//
// Note: xfer_cnt is how many have actually been transferred and
// acknowledged in the case of a 'read'.
// pci_cnt is how many have been transferred but not necessarily
// acknowledged.
reg [8:0] pci_cnt;

// ==================================================================
// Main DMA transfer state machine
// ==================================================================

reg [2:0] xfer_state;

`define DMA_Idle     3'h0
`define DMA_Req      3'h1
`define DMA_Write    3'h2
`define DMA_Read     3'h3
`define DMA_Dead     3'h4
`define DMA_Oops     3'h5

always @(posedge clk)
begin
   // On either reset or the CNET being reprogrammed, go to the idle state
   if (reset || cnet_reprog) begin
      xfer_state <= `DMA_Idle;
   end
   else
      case (xfer_state)
         `DMA_Idle : begin
            if (start)
               xfer_state <= `DMA_Req;
         end

         `DMA_Req : begin
            if (xfer_is_rd)
               xfer_state <= `DMA_Write;
            else
               xfer_state <= `DMA_Read;
         end

         `DMA_Write : begin
            if (dma_data_fell) begin
               if (fatal)
                  xfer_state <= `DMA_Dead;
               else
                  xfer_state <= `DMA_Oops;
            end
         end

         `DMA_Read : begin
            if (dma_data_fell) begin
               if (fatal)
                  xfer_state <= `DMA_Dead;
               else
                  xfer_state <= `DMA_Oops;
            end
         end

         `DMA_Dead : begin
            // Stay here until a reset is issued
         end

         `DMA_Oops : begin
            xfer_state <= `DMA_Idle;
         end

         default : begin
            xfer_state <= `DMA_Idle;
         end
      endcase
end


// ==================================================================
// Transfer timer
// ==================================================================

always @(posedge clk)
begin
   if (reset)
      xfer_timer <= - 'h1;
   else if (reset_xfer_timer)
      xfer_timer <= dma_time;
   else if (enable_xfer_timer && xfer_timer != 'h0)
      xfer_timer <= xfer_timer - 'h1;
end

assign dma_timeout = (xfer_timer == 'h0 && enable_xfer_timer);


// ==================================================================
// Retry counter
// ==================================================================

always @(posedge clk)
begin
   if (reset)
      retry_cnt <= - 'h1;
   // Reset the counter when the control state machine is idle or
   // there is a valid data cycle.
   else if (!dma_in_progress || dma_data_vld)
      retry_cnt <= dma_retries;
   else if (retry && retry_cnt != 'h0)
      retry_cnt <= retry_cnt - 'h1;
end

assign dma_retry_expire = dma_in_progress && retry_cnt == 'h0;


// ==================================================================
// PCI transfer counter
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      pci_cnt <= 'h0;
   else if (ld_xfer_cnt)
      pci_cnt <= xfer_cnt_start;
   else if (rd_undo)
      pci_cnt <= xfer_cnt;
   else if ((dma_data_vld && !xfer_is_rd) || (dma_src_en && xfer_is_rd))
      pci_cnt <= pci_cnt - 'h1;
end

// Is this the first or last word being transfered?
assign first_word_pci = pci_cnt == xfer_cnt_start;
assign last_word_pci = pci_cnt == 'h1;


// ==================================================================
// Acknowledged transfer counter
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      xfer_cnt <= 'h0;
   else if (ld_xfer_cnt)
      xfer_cnt <= xfer_cnt_start;
   else if (dma_data_vld)
      xfer_cnt <= xfer_cnt - 'h1;
end

assign done = xfer_cnt == 'h0;


// ==================================================================
// Transaction termination signals
// ==================================================================

assign cnt3 = xfer_cnt == 'h3 ||
              (dma_nearly_empty && !dma_all_in_buf && xfer_is_rd);
assign cnt2 = xfer_cnt == 'h2;
assign cnt1 = xfer_cnt == 'h1;

assign fin3 = cnt3 & dma_data_vld;
assign fin2 = cnt2 & dma_data_d1;
assign fin1 = cnt1 & dma_request;

// Warning: Check if the dma_lat_timeout setting is correct here
assign assert_complete = fin1 | fin2 | fin3 | dma_lat_timeout;
assign dma_complete = assert_complete | hold_complete | full_buffer_abort;
// Note: The DMA_Read below is meaning reading from the host...
assign full_buffer_abort = !dma_wr_rdy && !xfer_is_rd && xfer_state == `DMA_Read;

always @(posedge clk)
begin
   if (reset || ld_xfer_cnt)
      hold_complete <= 1'b0;
   else if (dma_data_fell)
      hold_complete <= 1'b0;
   else if (assert_complete)
      hold_complete <= 1'b1;
end

// ==================================================================
// Miscelaneous signal generation
// ==================================================================

assign rd_undo = xfer_state == `DMA_Oops;
assign abort_xfer = dma_timeout || dma_retry_expire ||
                    (fatal && (xfer_state == `DMA_Write || xfer_state == `DMA_Read));

// Generate the dma_data_fell signal indicating when the core leaves the
// m_data state
always @(posedge clk)
begin
   if (reset)
      dma_data_d1 <= 1'b0;
   else
      dma_data_d1 <= dma_data_st;
end

assign dma_data_fell = !dma_data_st & dma_data_d1;

// Fatal and Retry signals
always @(posedge clk)
begin
   if (reset) begin
      fatal <= 1'b0;
      retry <= 1'b0;
   end
   else if (dma_addr_st) begin
      fatal <= 1'b0;
      retry <= 1'b0;
   end
   else if (dma_data_st) begin
      fatal <= pci_fatal;
      retry <= pci_retry;
   end
end

// Signals to PCI core
assign dma_request = xfer_state == `DMA_Req;

assign dma_vld = dma_addr_st | dma_src_en;

assign dma_data = dma_addr_st ? {dma_addr, 2'b00} : rd_dout;
assign command = {3'b011, xfer_is_rd};

assign first_word_be_swapped = host_is_le ? {
                        first_word_be[0], first_word_be[1],
                        first_word_be[2], first_word_be[3]} :
                        first_word_be;

assign last_word_be_swapped = host_is_le ? {
                        last_word_be[0], last_word_be[1],
                        last_word_be[2], last_word_be[3]} :
                        last_word_be;

assign byte_enable = /*xfer_is_rd ? 4'b0000 : */
                       (last_word_pci ? last_word_be_swapped : 4'b0000) |
                       (first_word_pci ? first_word_be_swapped : 4'b0000);

assign dma_cbe = dma_addr_st ? command : byte_enable;
assign dma_wrdn = xfer_is_rd;

endmodule // dma_engine_pci_xfer
