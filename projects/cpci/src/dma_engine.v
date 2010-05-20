///////////////////////////////////////////////////////////////////////////////
// $Id: dma_engine.v 3635 2008-04-21 03:42:17Z grg $
//
// Module: dma_engine.v
// Project: CPCI (PCI Control FPGA)
// Description: DMA engine that controls the DMA process.
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 11/2/04 - Renamed dir to xfer_is_rd to avoid confusion.
//
//                 12/15/04 - Greg fixed read size check to only look at
//                            bits 15:11, since bits 31:16 of first ingress
//                            DMA word contain the source port number.
//
//                 01/08/05 - Reads should automatically select the port to
//                            read in a round-robin manner.
//
//                 01/13/05 - On a read request do not generate an error if
//                            there is no data - simply wait
//                          - separate read and write interrupt flags
//
//                 08/18/05 - Allow reads and writes that commence on
//                            non-word-boundaries
//
//                 08/24/05 - Add logic to deal with endianess...
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine(
            // PCI Signals
            input [`PCI_DATA_WIDTH-1:0] pci_data,      // Data being read from host

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

            output         dma_rd_intr,   // Request an interrupt to indicate read done
            output         dma_wr_intr,   // Request an interrupt to indicate write done

            input          pci_retry,     // Retry signal from CSRs
            input          pci_fatal,     // Fatal error signal from CSRs

            // CPCI register interface signals
            input [31:0]   dma_rd_addr,   // Address when performing reads
            input [31:0]   dma_wr_addr,   // Address when performing writes

            output [3:0]   dma_rd_mac,    // Which MAC was read data from
            input [3:0]    dma_wr_mac,    // Which MAC to write data to

            output [31:0]  dma_rd_size,   // Packet size when performing reads
            input [31:0]   dma_wr_size,   // Packet size when performing writes

            input          dma_rd_owner,  // Who owns read buffer (1 = CPCI)
            input          dma_wr_owner,  // Who owns write buffer (1 = CPCI)

            output         dma_rd_done,   // The current read is done
            output         dma_wr_done,   // The current write is done

            input [31:0]   dma_time,      // Number of clocks before a DMA transfer times out
            output         dma_timeout,   // Indicates a timeout has occured

            input [15:0]   dma_retries,   // Number of retries before a DMA transfer times out
            output         dma_retry_expire, // DMA retry counter has expired

            output         dma_rd_size_err, // Read size is invalid
            output         dma_wr_size_err, // Write size is invalid

            output         dma_rd_addr_err, // Read address is invalid
            output         dma_wr_addr_err, // Write address is invalid

            output         dma_rd_mac_err, // No data is available to read from the requested MAC (not used)
            output         dma_wr_mac_err, // No space is available to write to the requested MAC

            output         dma_fatal_err, // Non-recoverable error

            output         dma_in_progress, // Is a DMA transfer currently taking place?

            input          host_is_le,    // The host is little endian

            // CNET DMA interface signals
            input [15:0]   dma_pkt_avail, // Packets available in which buffers in CNET
            output         dma_rd_request, // Request packet from buffer
            output [3:0]   dma_rd_request_q, // Request packet from buffer X

            input [31:0]   dma_data_frm_cnet, // DMA data to be transfered
            output         dma_rd_en,     // Read a word from the buffer

            output [`CPCI_CNET_DATA_WIDTH-1:0]  dma_data_to_cnet, // DMA data to be transfered
            output         dma_wr_en, // Data on dma_data_to_cnet is valid
            input          dma_wr_rdy,       // We can write data out towards the CNET

            input [15:0]   dma_can_wr_pkt, // Space in Virtex for a full pkt

            input          dma_queue_info_avail, // Is DMA tx full info avail?

            input          dma_nearly_empty, // Three words or less left in the buffer
            input          dma_empty,     // Is the buffer empty?
            input          dma_all_in_buf, // All data for the packet is in the buffer

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Fatal and retry signals
wire fatal, retry;

// Transfer counters
//
// Note: xfer_cnt is how many have actually been transferred and
// acknowledged in the case of a 'read'.
wire [8:0] xfer_cnt;

// Try to start a PCI transaction
wire start;

// Is the transfer done?
wire done;

wire ld_xfer_cnt;

// Address pointer
wire [`PCI_ADDR_WIDTH - 1 : 2] dma_addr;
wire ld_dma_addr;

// DMA request signals
wire [15:0] dma_wr_mac_one_hot;

// Transfer direction
wire xfer_is_rd;

// Discard a word from the read fifo
wire discard;

wire [`PCI_DATA_WIDTH - 1 : 0] rd_dout;

// Transfer timer
wire reset_xfer_timer;
wire enable_xfer_timer;

// Abort the transfer
wire abort_xfer;

// Tx Wait counter
wire 	   tx_wait_cnt_ld;

// The number of non-aligned bytes
wire [1:0] non_aligned_bytes;

// Byte-Enable for the first and last words
wire [3:0] first_word_be;
wire [3:0] last_word_be;

// Are we currently transferring the first or last words on the PCI bus?
wire first_word_pci, last_word_pci;

// Input to the read and write FIFOs
wire [`PCI_DATA_WIDTH - 1 : 0] rdfifo_din;

// CNET register interface signals
//wire [`CPCI_CNET_DATA_WIDTH-1:0] dma_data_buf; // DMA Data going from the CPCI to the CNET
//wire         dma_req;       // DMA Write request signal


wire [`CPCI_CNET_DATA_WIDTH-1:0]  wr_buf_data;
wire wr_data_rdy;
wire last_word_to_cnet;
wire dma_wr_store_size;

// Number of words to transfer
wire [8:0] xfer_cnt_start;
wire [8:0] to_cnet_cnt_start;

assign dma_data_to_cnet = dma_wr_store_size ?
      {12'b0, dma_wr_mac, dma_wr_size[15:0]} : wr_buf_data;
assign dma_wr_en = dma_wr_store_size | wr_data_rdy;
assign dma_wr_store_size = ld_xfer_cnt && !xfer_is_rd;

wire wr_empty = dma_wr_rdy;

// ==================================================================
// FIFO for read data
// ==================================================================

dma_read_fifo_4x32 read_fifo(
            .din (rdfifo_din),
            .wr_en (rd_data_rdy),
            .rd_en (dma_src_en & xfer_is_rd),
            .dout (rd_dout),
            .delete_en (dma_data_vld & xfer_is_rd),
            .undo (rd_undo),
            .full (rd_full),
// synthesis translate_off
            .empty (rd_empty),
// synthesis translate_on
            .reset (reset),
            .clk (clk)
         );
// synthesis attribute keep_hierarchy of read_fifo is false;


// ==================================================================
// Control state machine
// ==================================================================

dma_engine_ctrl dma_engine_ctrl (
            .dma_rd_intr (dma_rd_intr),
            .dma_wr_intr (dma_wr_intr),
            .dma_rd_mac (dma_rd_mac),
            .dma_wr_size (dma_wr_size),
            .dma_rd_owner (dma_rd_owner),
            .dma_wr_owner (dma_wr_owner),
            .dma_rd_done (dma_rd_done),
            .dma_wr_done (dma_wr_done),
            .dma_rd_size_err (dma_rd_size_err),
            .dma_wr_size_err (dma_wr_size_err),
            .dma_rd_addr_err (dma_rd_addr_err),
            .dma_wr_addr_err (dma_wr_addr_err),
            .dma_rd_mac_err (dma_rd_mac_err),
            .dma_wr_mac_err (dma_wr_mac_err),
            .dma_fatal_err (dma_fatal_err),
            .dma_in_progress (dma_in_progress),
            .dma_wr_rdy (dma_wr_rdy),
            .dma_rd_request (dma_rd_request),
            .dma_xfer_size (dma_data_frm_cnet[15:0]),
            .dma_rd_en (dma_rd_en),
            .dma_can_wr_pkt (dma_can_wr_pkt),
            .dma_queue_info_avail (dma_queue_info_avail),
            .dma_nearly_empty (dma_nearly_empty),
            .dma_all_in_buf (dma_all_in_buf),
            .tx_wait_done (tx_wait_done),
            .to_cnet_done (to_cnet_done),
            .wr_empty (wr_empty),
            .fatal (fatal),
            .start (start),
            .done (done),
            .ld_xfer_cnt (ld_xfer_cnt),
            .ld_dma_addr (ld_dma_addr),
            .read_get_len (read_get_len),
            .write_start (write_start),
            .ctrl_done (ctrl_done),
            .dma_rd_request_q_vld (dma_rd_request_q_vld),
            .dma_rd_request_q (dma_rd_request_q),
            .dma_wr_mac_one_hot (dma_wr_mac_one_hot),
            .xfer_is_rd (xfer_is_rd),
            .discard (discard),
            .reset_xfer_timer (reset_xfer_timer),
            .enable_xfer_timer (enable_xfer_timer),
            .abort_xfer (abort_xfer),
            .tx_wait_cnt_ld (tx_wait_cnt_ld),
            .cnet_reprog (cnet_reprog),
            .reset (reset),
            .clk (clk)
         );
// synthesis attribute keep_hierarchy of dma_engine_ctrl is false;


// ==================================================================
// Round robin allocator
// ==================================================================

dma_engine_rr_arb dma_engine_rr_arb (
            .dma_wr_mac (dma_wr_mac),
            .dma_pkt_avail (dma_pkt_avail),
            .dma_rd_request (dma_rd_request),
            .dma_rd_request_q (dma_rd_request_q),
            .dma_wr_mac_one_hot (dma_wr_mac_one_hot),
            .dma_rd_request_q_vld (dma_rd_request_q_vld),
            .ctrl_done (ctrl_done),
            .dma_in_progress (dma_in_progress),
            .xfer_is_rd (xfer_is_rd),
            .cnet_reprog (cnet_reprog),
            .reset (reset),
            .clk (clk)
         );
// synthesis attribute keep_hierarchy of dma_engine_rr_arb is false;



// ==================================================================
// PCI transfer controller
// ==================================================================

dma_engine_pci_xfer dma_engine_pci_xfer(
            .dma_data (dma_data),
            .dma_cbe (dma_cbe),
            .dma_vld (dma_vld),
            .dma_wrdn (dma_wrdn),
            .dma_request (dma_request),
            .dma_complete (dma_complete),
            .dma_data_vld (dma_data_vld),
            .dma_src_en (dma_src_en),
            .dma_lat_timeout (dma_lat_timeout),
            .dma_addr_st (dma_addr_st),
            .dma_data_st (dma_data_st),
            .pci_retry (pci_retry),
            .pci_fatal (pci_fatal),
            .host_is_le (host_is_le),
            .dma_time (dma_time),
            .dma_timeout (dma_timeout),
            .dma_retries (dma_retries),
            .dma_retry_expire (dma_retry_expire),
            .dma_wr_rdy (dma_wr_rdy),
            .dma_nearly_empty (dma_nearly_empty),
            .dma_all_in_buf (dma_all_in_buf),
            .done (done),
            .fatal (fatal),
            .retry (retry),
            .abort_xfer (abort_xfer),
            .rd_undo (rd_undo),
            .start (start),
            .ld_xfer_cnt (ld_xfer_cnt),
            .xfer_is_rd (xfer_is_rd),
            .first_word_pci (first_word_pci),
            .last_word_pci (last_word_pci),
            .wr_fifo_empty (wr_empty),
            .dma_in_progress (dma_in_progress),
            .enable_xfer_timer (enable_xfer_timer),
            .reset_xfer_timer (reset_xfer_timer),
            .first_word_be (first_word_be),
            .last_word_be (last_word_be),
            .xfer_cnt_start (xfer_cnt_start),
            .xfer_cnt (xfer_cnt),
            .dma_addr (dma_addr),
            .rd_dout (rd_dout),
            .cnet_reprog (cnet_reprog),
            .reset (reset),
            .clk (clk)
         );
// synthesis attribute keep_hierarchy of dma_engine_pci_xfer is false;


// ==================================================================
// Alignment of signals to handle non-aligned transfers... (sigh)
// ==================================================================
dma_engine_alignment dma_engine_alignment (
            // PCI Signals
            .pci_data      (pci_data),
            .dma_data_vld  (dma_data_vld),

            // CPCI register interface signals
            .host_is_le    (host_is_le),

            // CNET DMA interface signals
            .dma_data_frm_cnet (dma_data_frm_cnet),
            .dma_rd_en     (dma_rd_en),

            .dma_empty     (dma_empty),

            // DMA engine signals
            .wr_buf_data   (wr_buf_data),
            .rd_buf_data   (rdfifo_din),

            .xfer_is_rd    (xfer_is_rd),

            .last_word_pci (last_word_pci),
            .first_word_pci (first_word_pci),
            .last_word_from_cnet (last_word_from_cnet),

            .rd_full       (rd_full),

            .discard       (discard),

            .wr_data_rdy   (wr_data_rdy),
            .rd_data_rdy   (rd_data_rdy),

            .non_aligned_bytes (non_aligned_bytes),

            .read_from_cnet (read_from_cnet),

            .ld_xfer_cnt (ld_xfer_cnt),

            .xfer_cnt_start (xfer_cnt_start),
            .to_cnet_cnt_start (to_cnet_cnt_start),

            // Miscelaneous signals
            .cnet_reprog   (cnet_reprog),

            .reset         (reset),
            .clk           (clk)
         );
// synthesis attribute keep_hierarchy of dma_engine_alignment is false;

// ==================================================================
// Counters
// ==================================================================
dma_engine_cntr dma_engine_cntr (
            // PCI Signals
            .dma_data_vld (dma_data_vld),
            .dma_src_en (dma_src_en),

            // CPCI register interface signals
            .dma_rd_addr (dma_rd_addr),
            .dma_wr_addr (dma_wr_addr),

            .dma_rd_size (dma_rd_size),
            .dma_wr_size (dma_wr_size),

            // CNET DMA interface signals
            .dma_data_frm_cnet (dma_data_frm_cnet),

            // DMA engine signals
            .tx_wait_done (tx_wait_done),
            .to_cnet_done (to_cnet_done),

            .retry (retry),
            .rd_undo (rd_undo),
            .xfer_is_rd (xfer_is_rd),

            .read_get_len (read_get_len),
            .write_start (write_start),

            .read_from_cnet (read_from_cnet),

            .wr_data_rdy (wr_data_rdy),
            .rd_data_rdy (rd_data_rdy),

            .tx_wait_cnt_ld (tx_wait_cnt_ld),
            .ld_dma_addr (ld_dma_addr),
            .ld_xfer_cnt (ld_xfer_cnt),

            .last_word_to_cnet (last_word_to_cnet),
            .last_word_from_cnet (last_word_from_cnet),

            .non_aligned_bytes (non_aligned_bytes),

            .first_word_be (first_word_be),
            .last_word_be (last_word_be),

            .xfer_cnt_start (xfer_cnt_start),
            .to_cnet_cnt_start (to_cnet_cnt_start),

            .dma_addr (dma_addr),

            // Miscelaneous signals
            .cnet_reprog (cnet_reprog),

            .reset (reset),
            .clk (clk)
         );
// synthesis attribute keep_hierarchy of dma_engine_cntr is false;

// ==================================================================
// Debugging
// ==================================================================

// synthesis translate_off
always @(posedge clk)
begin
//   if (dma_data_vld && xfer_is_rd && !dma_wr_rdy && !dma_req)
//      $display($time, " ERROR: Write FIFO buffer overflow in %m");
   if (dma_src_en & rd_empty & !xfer_is_rd)
      $display($time, " ERROR: Attempt to read from empty read FIFO in %m");
end
// synthesis translate_on

endmodule // dma_engine

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
