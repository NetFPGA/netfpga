///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: dma_engine_alignment.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: dma_engine_alignment.v
// Project: CPCI (PCI Control FPGA)
// Description: Re-alignment module to handle unaligned transfers
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 12/08/07 - Split the alignment block from the main
//                            processing block to aid in readability
//                            and maintainability
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine_alignment (
            // PCI Signals
            input [`PCI_DATA_WIDTH-1:0] pci_data,      // Data being read from host

            input          dma_data_vld,  // Indicates data should be captured
                                          // from pci_data during a read or
                                          // that a data transaction has
                                          // occured during a write.

            // CPCI register interface signals
            input          host_is_le,    // The host is little endian

            // CNET DMA interface signals
            input [31:0]   dma_data_frm_cnet, // DMA data to be transfered
            output         dma_rd_en,     // Read a word from the buffer

            input          dma_empty,     // Is the buffer empty?

            // DMA engine signals
            output [`PCI_DATA_WIDTH - 1 : 0] wr_buf_data, // Output of the write buffer
            output [`PCI_DATA_WIDTH - 1 : 0] rd_buf_data, // Output of the read buffer

            input          xfer_is_rd,    // Transfer direction

            input          last_word_pci, // Transfering last word on the PCI bus
            input          first_word_pci,// Transfering first word on the PCI bus
            input          last_word_from_cnet, // Transferring last word from CNET

            input          rd_full,       // The read FIFO is full

            input          discard,       // Discard a word from the read fifo
                                          // (ignore it in processint

            output reg     wr_data_rdy,   // Write data is being output in this cycle
            output         rd_data_rdy,   // Read data is being output in this cycle

            input [1:0]    non_aligned_bytes, // Number of non-aligned bytes

            output         read_from_cnet,// Indicates read of word from CNET

            input          ld_xfer_cnt,

            input [8:0]    xfer_cnt_start, // Number of words to transfer
            input [8:0]    to_cnet_cnt_start, // Number of words to transfer

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Is there currently data being OP on dma_data_frm_cnet?
reg data_frm_cnet_ready;

// Byte swaped version of data from PCI bus
wire [`PCI_DATA_WIDTH-1:0] pci_data_swapped;

// Byte swapped version of data from cnet
wire [31:0]   dma_data_frm_cnet_swapped;

// Instruct the read buffer to write a word
wire rdb_wr_en;

// Deal with non-aligned DMA transfers
reg [55:0] wr_realign_buf, rd_realign_buf;

reg wr_pci_done;
reg wr_dma_done;
reg rd_cnet_done;
reg rd_fifo_done;

// Input to the read and write FIFOs
reg [`PCI_DATA_WIDTH - 1 : 0] wr_buf_data_swapped;
reg [`PCI_DATA_WIDTH - 1 : 0] rd_buf_data_swapped;

// Word available in write/read buffers
reg rdb_data_avail;

// Transfer counters
reg [8:0] to_wr_fifo_cnt;
reg [8:0] to_rd_fifo_cnt;

// Last word being written into write or read FIFO
wire last_word_to_wr_fifo;
wire last_word_to_rd_fifo;

// ==================================================================
// Sample the write data for non-aligned transfers
// ==================================================================

assign pci_data_swapped = host_is_le ?
   {pci_data[7:0], pci_data[15:8], pci_data[23:16], pci_data[31:24]} :
   pci_data;

always @(posedge clk)
begin
   if (reset || cnet_reprog)
   begin
      wr_data_rdy <= 1'b0;
      wr_pci_done <= 1'b0;
      wr_dma_done <= 1'b0;
   end
   else
   begin
      // Shift data in the realignment buffer when either:
      //  - we're doing a write over the PCI bus
      //  - the PCI transaction has finished and we've still got data
      //    to transfer over the DMA bus
      if ((dma_data_vld && !xfer_is_rd) ||
          (wr_pci_done && !wr_dma_done ))
         wr_realign_buf <= {wr_realign_buf[31:0], pci_data_swapped};

      // Record that there's data ready to push out of the module when:
      //  - a PCI write has occurred and the transfer is aligned
      //  - a PCI write has occurred and there's already data in the buffer
      //  - PCI transaction is done, DMA transfer is not done and we're not
      //    currently writing
      //  - PCI transaction is done, DMA transfer is not done and we're
      //    transfering something other than the last word
      if (dma_data_vld && !xfer_is_rd)
         wr_data_rdy <= (non_aligned_bytes == 2'b00) || !first_word_pci;
      else if (wr_data_rdy || wr_pci_done)
         wr_data_rdy <= wr_pci_done && !wr_dma_done &&
                        (!wr_data_rdy || !last_word_to_wr_fifo);

      // Record when we've transferred the last word over the PCI and DMA
      // buses
      if (dma_data_vld && !xfer_is_rd)
         wr_pci_done <= last_word_pci;

      if (dma_data_vld && !xfer_is_rd || wr_data_rdy)
         wr_dma_done <= last_word_to_wr_fifo || (wr_dma_done && wr_data_rdy);
   end
end


// ==================================================================
// Sample the read data for non-aligned transfers
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
   begin
      rdb_data_avail <= 1'b0;
      rd_cnet_done <= 1'b0;
   end
   else
   begin
      // Shift data into the buffer when we've got a word from the CNET or
      // when we need to do a shift of the last word to ensure we push all
      // data to the host.
      if (rdb_wr_en || rd_data_rdy)
         case (non_aligned_bytes)
            2'b01 : rd_realign_buf <= {rd_realign_buf[23:0], dma_data_frm_cnet_swapped};
            2'b10 : rd_realign_buf <= {rd_realign_buf[23:8], dma_data_frm_cnet_swapped, 8'b0};
            2'b11 : rd_realign_buf <= {rd_realign_buf[23:16], dma_data_frm_cnet_swapped, 16'b0};
            default : rd_realign_buf <= {dma_data_frm_cnet_swapped, 24'b0};
         endcase

      // Record when there is data available
      if (rdb_wr_en)
         rdb_data_avail <= 1'b1;
      else if (rd_data_rdy)
         rdb_data_avail <= rd_cnet_done && !rd_fifo_done &&
                           (!rdb_data_avail || !last_word_to_rd_fifo);

      // Record when we've transferred the last word from the CNET and to
      // the read FIFO
      if (rdb_wr_en)
         rd_cnet_done <= last_word_from_cnet;

      if (rdb_wr_en || rd_data_rdy)
         rd_fifo_done <= last_word_to_rd_fifo || (rd_data_rdy && rd_fifo_done);
   end
end

// ==================================================================
// Work out the data to input into the Write FIFO
// ==================================================================

always @*
begin
   case (non_aligned_bytes)
      2'b00    : wr_buf_data_swapped <= wr_realign_buf[31:0];
      2'b01    : wr_buf_data_swapped <= wr_realign_buf[39:8];
      2'b10    : wr_buf_data_swapped <= wr_realign_buf[47:16];
      default  : wr_buf_data_swapped <= wr_realign_buf[55:24];
   endcase
end

assign wr_buf_data = {wr_buf_data_swapped[7:0],
                      wr_buf_data_swapped[15:8],
                      wr_buf_data_swapped[23:16],
                      wr_buf_data_swapped[31:24]};


// ==================================================================
// Work out the data to input into the Read FIFO
// ==================================================================

always @*
   rd_buf_data_swapped <= rd_realign_buf[55:24];

assign rd_buf_data = host_is_le ?
                     {rd_buf_data_swapped[7:0],
                      rd_buf_data_swapped[15:8],
                      rd_buf_data_swapped[23:16],
                      rd_buf_data_swapped[31:24]} :
                     rd_buf_data_swapped;

assign dma_data_frm_cnet_swapped = {
               dma_data_frm_cnet[7:0],
               dma_data_frm_cnet[15:8],
               dma_data_frm_cnet[23:16],
               dma_data_frm_cnet[31:24]
               };

// ==================================================================
// Rd/Wr FIFO transfer counters
// ==================================================================

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      to_wr_fifo_cnt <= 'h0;
   else if (ld_xfer_cnt)
      to_wr_fifo_cnt <= to_cnet_cnt_start;
   else if (wr_data_rdy)
      to_wr_fifo_cnt <= to_wr_fifo_cnt - 'h1;
end

always @(posedge clk)
begin
   if (reset || cnet_reprog)
      to_rd_fifo_cnt <= 'h0;
   else if (ld_xfer_cnt)
      to_rd_fifo_cnt <= xfer_cnt_start;
   else if (rd_data_rdy)
      to_rd_fifo_cnt <= to_rd_fifo_cnt - 'h1;
end

assign last_word_to_wr_fifo = to_wr_fifo_cnt == 'h1;
assign last_word_to_rd_fifo = to_rd_fifo_cnt == 'h1;


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

// Record when there is data available from the CNET
always @(posedge clk)
begin
   if (reset || cnet_reprog)
      data_frm_cnet_ready <= 1'b0;
   else if (dma_rd_en)
      data_frm_cnet_ready <= 1'b1;
   else if (rd_data_rdy || discard)
      data_frm_cnet_ready <= 1'b0;
end

// Write a word into the read buffer if data is available and we're not
// discarding and the output fifo isn't backed up
assign rdb_wr_en = data_frm_cnet_ready && !discard && !rd_full;
assign read_from_cnet = rdb_wr_en;

// Generate the read ready signal
assign rd_data_rdy = rdb_data_avail && !rd_full;

// Pull the next word from the CNET if there's data available and either:
//  - we don't currently have any data
//  - we're discarding the current word
//  - we're writing the current word into the realign buffer
assign dma_rd_en = !dma_empty &&
                   (!data_frm_cnet_ready || discard || rdb_wr_en);

endmodule // dma_engine_alignment

