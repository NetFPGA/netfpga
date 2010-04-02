///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_regs.v 4020 2008-06-10 21:58:23Z grg $
//
// Module: oq_regs.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module oq_regs
  #(
      parameter SRAM_ADDR_WIDTH     = 19,
      parameter CTRL_WIDTH          = 8,
      parameter UDP_REG_SRC_WIDTH   = 2,
      parameter NUM_OUTPUT_QUEUES   = 8,
      parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
      parameter PKT_LEN_WIDTH       = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH)
   )

   (
      // --- interface to udp_reg_grp
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

      // --- interface to remove_pkt
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_rd_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_high_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_low_addr,
      output     [NUM_OUTPUT_QUEUES-1:0]  src_oq_empty,
      input      [SRAM_ADDR_WIDTH-1:0]    src_oq_rd_addr_new,
      input                               pkt_removed,
      input      [PKT_LEN_WIDTH-1:0]      removed_pkt_data_length,
      input      [CTRL_WIDTH-1:0]         removed_pkt_overhead_length,
      input      [PKT_WORDS_WIDTH-1:0]    removed_pkt_total_word_length,
      input      [NUM_OQ_WIDTH-1:0]       src_oq,
      input      [NUM_OQ_WIDTH-1:0]       removed_oq,
      input                               rd_src_addr,
      output     [NUM_OUTPUT_QUEUES-1:0]  enable_send_pkt,

      // --- interface to store_pkt
      input      [SRAM_ADDR_WIDTH-1:0]    dst_oq_wr_addr_new,
      input                               pkt_stored,
      input      [PKT_LEN_WIDTH-1:0]      stored_pkt_data_length,
      input      [CTRL_WIDTH-1:0]         stored_pkt_overhead_length,
      input      [PKT_WORDS_WIDTH-1:0]    stored_pkt_total_word_length,
      input                               pkt_dropped,
      input      [NUM_OQ_WIDTH-1:0]       dst_oq,
      input                               rd_dst_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    dst_oq_high_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    dst_oq_low_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    dst_oq_wr_addr,
      output     [NUM_OUTPUT_QUEUES-1:0]  dst_oq_full,

      // --- Misc
      input                               clk,
      input                               reset
   );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2


   // ------------- Internal parameters --------------

   localparam NUM_REGS_USED      = 17;

   localparam MAX_PKT            = 2048/CTRL_WIDTH;   // allow for 2K bytes
   localparam MIN_PKT            = 60/CTRL_WIDTH + 1;   // allow for 2K bytes
   localparam PKTS_IN_RAM_WIDTH  = log2((2**SRAM_ADDR_WIDTH)/MIN_PKT);

   localparam ADDR_WIDTH         = log2(NUM_REGS_USED);



   // ------------- Wires/reg ------------------

   // Register interfaces
   wire [NUM_OQ_WIDTH-1:0]             reg_addr;

   wire                                num_pkt_bytes_stored_reg_req;
   wire                                num_pkt_bytes_stored_reg_ack;
   wire                                num_pkt_bytes_stored_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkt_bytes_stored_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkt_bytes_stored_reg_rd_data;

   wire                                num_overhead_bytes_stored_reg_req;
   wire                                num_overhead_bytes_stored_reg_ack;
   wire                                num_overhead_bytes_stored_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_overhead_bytes_stored_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_overhead_bytes_stored_reg_rd_data;

   wire                                num_pkts_stored_reg_req;
   wire                                num_pkts_stored_reg_ack;
   wire                                num_pkts_stored_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_stored_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_stored_reg_rd_data;

   wire                                num_pkts_dropped_reg_req;
   wire                                num_pkts_dropped_reg_ack;
   wire                                num_pkts_dropped_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_dropped_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_dropped_reg_rd_data;

   wire                                num_pkt_bytes_removed_reg_req;
   wire                                num_pkt_bytes_removed_reg_ack;
   wire                                num_pkt_bytes_removed_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkt_bytes_removed_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkt_bytes_removed_reg_rd_data;

   wire                                num_overhead_bytes_removed_reg_req;
   wire                                num_overhead_bytes_removed_reg_ack;
   wire                                num_overhead_bytes_removed_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_overhead_bytes_removed_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_overhead_bytes_removed_reg_rd_data;

   wire                                num_pkts_removed_reg_req;
   wire                                num_pkts_removed_reg_ack;
   wire                                num_pkts_removed_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_removed_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_removed_reg_rd_data;

   wire                                oq_addr_hi_reg_req;
   wire                                oq_addr_hi_reg_ack;
   wire                                oq_addr_hi_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_addr_hi_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_addr_hi_reg_rd_data;

   wire                                oq_addr_lo_reg_req;
   wire                                oq_addr_lo_reg_ack;
   wire                                oq_addr_lo_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_addr_lo_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_addr_lo_reg_rd_data;

   wire                                oq_wr_addr_reg_req;
   wire                                oq_wr_addr_reg_ack;
   wire                                oq_wr_addr_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_wr_addr_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_wr_addr_reg_rd_data;

   wire                                oq_rd_addr_reg_req;
   wire                                oq_rd_addr_reg_ack;
   wire                                oq_rd_addr_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_rd_addr_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_rd_addr_reg_rd_data;

   wire                                max_pkts_in_q_reg_req;
   wire                                max_pkts_in_q_reg_ack;
   wire                                max_pkts_in_q_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     max_pkts_in_q_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     max_pkts_in_q_reg_rd_data;

   wire                                num_pkts_in_q_reg_req;
   wire                                num_pkts_in_q_reg_ack;
   wire                                num_pkts_in_q_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_in_q_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_pkts_in_q_reg_rd_data;

   wire                                num_words_left_reg_req;
   wire                                num_words_left_reg_ack;
   wire                                num_words_left_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_words_left_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_words_left_reg_rd_data;

   wire                                num_words_in_q_reg_req;
   wire                                num_words_in_q_reg_ack;
   wire                                num_words_in_q_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_words_in_q_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     num_words_in_q_reg_rd_data;

   wire                                oq_full_thresh_reg_req;
   wire                                oq_full_thresh_reg_ack;
   wire                                oq_full_thresh_reg_wr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_full_thresh_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     oq_full_thresh_reg_rd_data;

   // Values used to calculate full/emtpy state
   wire [PKTS_IN_RAM_WIDTH-1:0]        max_pkts_in_q_dst;
   wire [PKTS_IN_RAM_WIDTH-1:0]        num_pkts_in_q_dst;
   wire                                num_pkts_in_q_dst_wr_done;

   wire [PKTS_IN_RAM_WIDTH-1:0]        max_pkts_in_q_src;
   wire [PKTS_IN_RAM_WIDTH-1:0]        num_pkts_in_q_src;
   wire                                num_pkts_in_q_src_wr_done;

   wire [SRAM_ADDR_WIDTH-1:0]          oq_full_thresh_dst;
   wire [SRAM_ADDR_WIDTH-1:0]          num_words_left_dst;
   wire                                num_words_left_dst_wr_done;

   wire [SRAM_ADDR_WIDTH-1:0]          oq_full_thresh_src;
   wire [SRAM_ADDR_WIDTH-1:0]          num_words_left_src;
   wire                                num_words_left_src_wr_done;

   // --- interface to oq_regs_host_iface
   wire                                reg_req;
   wire                                reg_rd_wr_L_held;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     reg_data_held;

   wire [ADDR_WIDTH-1:0]               addr;
   wire [NUM_OQ_WIDTH-1:0]             q_addr;

   wire                                result_ready;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     reg_result;

   wire [NUM_OUTPUT_QUEUES-1:0]        empty;
   wire [NUM_OUTPUT_QUEUES-1:0]        full;

   wire                                initialize;
   wire [NUM_OQ_WIDTH-1:0]             initialize_oq;



   // --------- logic ---------------------------

   assign src_oq_empty = empty;
   assign dst_oq_full = full;



   // -------------------------------------------
   // Control module
   //   -- Contains logic for resetting the queues, initalizing the queues on
   //      writes to the control register and logic to process register requests
   //      from the host
   // -------------------------------------------

   oq_regs_ctrl
   #(
      .SRAM_ADDR_WIDTH      (SRAM_ADDR_WIDTH),
      .CTRL_WIDTH           (CTRL_WIDTH),
      .NUM_OUTPUT_QUEUES    (NUM_OUTPUT_QUEUES),
      .NUM_REGS_USED        (NUM_REGS_USED),
      .MAX_PKT              (MAX_PKT),   // allow for 2K bytes
      .PKT_LEN_WIDTH        (PKT_LEN_WIDTH)
   ) oq_regs_ctrl  (
      // --- interface to store/remove pkt
      .enable                                (enable_send_pkt),

      // --- interface to oq_regs_host_iface
      .reg_req                               (req_in_progress),
      .reg_rd_wr_L_held                      (reg_rd_wr_L_held),
      .reg_data_held                         (reg_data_held),

      .addr                                  (addr),
      .q_addr                                (q_addr),

      .result_ready                          (result_ready),
      .reg_result                            (reg_result),

      // --- Interface to full/empty generation logic
      .initialize                            (initialize),
      .initialize_oq                         (initialize_oq),

      // Register interfaces
      .reg_addr                              (reg_addr),

      .num_pkt_bytes_stored_reg_req          (num_pkt_bytes_stored_reg_req),
      .num_pkt_bytes_stored_reg_ack          (num_pkt_bytes_stored_reg_ack),
      .num_pkt_bytes_stored_reg_wr           (num_pkt_bytes_stored_reg_wr),
      .num_pkt_bytes_stored_reg_wr_data      (num_pkt_bytes_stored_reg_wr_data),
      .num_pkt_bytes_stored_reg_rd_data      (num_pkt_bytes_stored_reg_rd_data),

      .num_overhead_bytes_stored_reg_req     (num_overhead_bytes_stored_reg_req),
      .num_overhead_bytes_stored_reg_ack     (num_overhead_bytes_stored_reg_ack),
      .num_overhead_bytes_stored_reg_wr      (num_overhead_bytes_stored_reg_wr),
      .num_overhead_bytes_stored_reg_wr_data (num_overhead_bytes_stored_reg_wr_data),
      .num_overhead_bytes_stored_reg_rd_data (num_overhead_bytes_stored_reg_rd_data),

      .num_pkts_stored_reg_req               (num_pkts_stored_reg_req),
      .num_pkts_stored_reg_ack               (num_pkts_stored_reg_ack),
      .num_pkts_stored_reg_wr                (num_pkts_stored_reg_wr),
      .num_pkts_stored_reg_wr_data           (num_pkts_stored_reg_wr_data),
      .num_pkts_stored_reg_rd_data           (num_pkts_stored_reg_rd_data),

      .num_pkts_dropped_reg_req              (num_pkts_dropped_reg_req),
      .num_pkts_dropped_reg_ack              (num_pkts_dropped_reg_ack),
      .num_pkts_dropped_reg_wr               (num_pkts_dropped_reg_wr),
      .num_pkts_dropped_reg_wr_data          (num_pkts_dropped_reg_wr_data),
      .num_pkts_dropped_reg_rd_data          (num_pkts_dropped_reg_rd_data),

      .num_pkt_bytes_removed_reg_req         (num_pkt_bytes_removed_reg_req),
      .num_pkt_bytes_removed_reg_ack         (num_pkt_bytes_removed_reg_ack),
      .num_pkt_bytes_removed_reg_wr          (num_pkt_bytes_removed_reg_wr),
      .num_pkt_bytes_removed_reg_wr_data     (num_pkt_bytes_removed_reg_wr_data),
      .num_pkt_bytes_removed_reg_rd_data     (num_pkt_bytes_removed_reg_rd_data),

      .num_overhead_bytes_removed_reg_req    (num_overhead_bytes_removed_reg_req),
      .num_overhead_bytes_removed_reg_ack    (num_overhead_bytes_removed_reg_ack),
      .num_overhead_bytes_removed_reg_wr     (num_overhead_bytes_removed_reg_wr),
      .num_overhead_bytes_removed_reg_wr_data(num_overhead_bytes_removed_reg_wr_data),
      .num_overhead_bytes_removed_reg_rd_data(num_overhead_bytes_removed_reg_rd_data),

      .num_pkts_removed_reg_req              (num_pkts_removed_reg_req),
      .num_pkts_removed_reg_ack              (num_pkts_removed_reg_ack),
      .num_pkts_removed_reg_wr               (num_pkts_removed_reg_wr),
      .num_pkts_removed_reg_wr_data          (num_pkts_removed_reg_wr_data),
      .num_pkts_removed_reg_rd_data          (num_pkts_removed_reg_rd_data),

      .oq_addr_hi_reg_req                    (oq_addr_hi_reg_req),
      .oq_addr_hi_reg_ack                    (oq_addr_hi_reg_ack),
      .oq_addr_hi_reg_wr                     (oq_addr_hi_reg_wr),
      .oq_addr_hi_reg_wr_data                (oq_addr_hi_reg_wr_data),
      .oq_addr_hi_reg_rd_data                (oq_addr_hi_reg_rd_data),

      .oq_addr_lo_reg_req                    (oq_addr_lo_reg_req),
      .oq_addr_lo_reg_ack                    (oq_addr_lo_reg_ack),
      .oq_addr_lo_reg_wr                     (oq_addr_lo_reg_wr),
      .oq_addr_lo_reg_wr_data                (oq_addr_lo_reg_wr_data),
      .oq_addr_lo_reg_rd_data                (oq_addr_lo_reg_rd_data),

      .oq_wr_addr_reg_req                    (oq_wr_addr_reg_req),
      .oq_wr_addr_reg_ack                    (oq_wr_addr_reg_ack),
      .oq_wr_addr_reg_wr                     (oq_wr_addr_reg_wr),
      .oq_wr_addr_reg_wr_data                (oq_wr_addr_reg_wr_data),
      .oq_wr_addr_reg_rd_data                (oq_wr_addr_reg_rd_data),

      .oq_rd_addr_reg_req                    (oq_rd_addr_reg_req),
      .oq_rd_addr_reg_ack                    (oq_rd_addr_reg_ack),
      .oq_rd_addr_reg_wr                     (oq_rd_addr_reg_wr),
      .oq_rd_addr_reg_wr_data                (oq_rd_addr_reg_wr_data),
      .oq_rd_addr_reg_rd_data                (oq_rd_addr_reg_rd_data),

      .max_pkts_in_q_reg_req                 (max_pkts_in_q_reg_req),
      .max_pkts_in_q_reg_ack                 (max_pkts_in_q_reg_ack),
      .max_pkts_in_q_reg_wr                  (max_pkts_in_q_reg_wr),
      .max_pkts_in_q_reg_wr_data             (max_pkts_in_q_reg_wr_data),
      .max_pkts_in_q_reg_rd_data             (max_pkts_in_q_reg_rd_data),

      .num_pkts_in_q_reg_req                 (num_pkts_in_q_reg_req),
      .num_pkts_in_q_reg_ack                 (num_pkts_in_q_reg_ack),
      .num_pkts_in_q_reg_wr                  (num_pkts_in_q_reg_wr),
      .num_pkts_in_q_reg_wr_data             (num_pkts_in_q_reg_wr_data),
      .num_pkts_in_q_reg_rd_data             (num_pkts_in_q_reg_rd_data),

      .num_words_left_reg_req                (num_words_left_reg_req),
      .num_words_left_reg_ack                (num_words_left_reg_ack),
      .num_words_left_reg_wr                 (num_words_left_reg_wr),
      .num_words_left_reg_wr_data            (num_words_left_reg_wr_data),
      .num_words_left_reg_rd_data            (num_words_left_reg_rd_data),

      .num_words_in_q_reg_req                (num_words_in_q_reg_req),
      .num_words_in_q_reg_ack                (num_words_in_q_reg_ack),
      .num_words_in_q_reg_wr                 (num_words_in_q_reg_wr),
      .num_words_in_q_reg_wr_data            (num_words_in_q_reg_wr_data),
      .num_words_in_q_reg_rd_data            (num_words_in_q_reg_rd_data),

      .oq_full_thresh_reg_req                (oq_full_thresh_reg_req),
      .oq_full_thresh_reg_ack                (oq_full_thresh_reg_ack),
      .oq_full_thresh_reg_wr                 (oq_full_thresh_reg_wr),
      .oq_full_thresh_reg_wr_data            (oq_full_thresh_reg_wr_data),
      .oq_full_thresh_reg_rd_data            (oq_full_thresh_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // -------------------------------------------
   // Empty/full signal generation logic
   //    -- Analyzes the number of packets/number of words in each queue on
   //       updates
   // -------------------------------------------
   oq_regs_eval_empty
   #(
      .SRAM_ADDR_WIDTH      (SRAM_ADDR_WIDTH),
      .CTRL_WIDTH           (CTRL_WIDTH),
      .UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
      .NUM_OUTPUT_QUEUES    (NUM_OUTPUT_QUEUES),
      .PKT_LEN_WIDTH        (PKT_LEN_WIDTH),
      .MAX_PKT              (MAX_PKT)
   ) oq_regs_eval_empty (
      // --- Inputs from dst update ---
      .dst_update                         (pkt_stored),
      .dst_oq                             (dst_oq),
      .dst_num_pkts_in_q                  (num_pkts_in_q_dst),
      .dst_num_pkts_in_q_done             (num_pkts_in_q_dst_wr_done),

      // --- Inputs from src update ---
      .src_update                         (pkt_removed),
      .src_oq                             (removed_oq),
      .src_num_pkts_in_q                  (num_pkts_in_q_src),
      .src_num_pkts_in_q_done             (num_pkts_in_q_src_wr_done),

      // --- Clear the flag ---
      .initialize                         (initialize),
      .initialize_oq                      (initialize_oq),

      .empty                              (empty),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   oq_regs_eval_full
   #(
      .SRAM_ADDR_WIDTH      (SRAM_ADDR_WIDTH),
      .CTRL_WIDTH           (CTRL_WIDTH),
      .UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
      .NUM_OUTPUT_QUEUES    (NUM_OUTPUT_QUEUES),
      .PKT_LEN_WIDTH        (PKT_LEN_WIDTH),
      .MAX_PKT              (MAX_PKT)
   ) oq_regs_eval_full (
      // --- Inputs from dst update ---
      .dst_update                         (pkt_stored),
      .dst_oq                             (dst_oq),
      .dst_max_pkts_in_q                  (max_pkts_in_q_dst),
      .dst_num_pkts_in_q                  (num_pkts_in_q_dst),
      .dst_num_pkts_in_q_done             (num_pkts_in_q_dst_wr_done),

      .dst_oq_full_thresh                 (oq_full_thresh_dst),
      .dst_num_words_left                 (num_words_left_dst),
      .dst_num_words_left_done            (num_words_left_dst_wr_done),

      // --- Inputs from src update ---
      .src_update                         (pkt_removed),
      .src_oq                             (removed_oq),
      .src_max_pkts_in_q                  (max_pkts_in_q_src),
      .src_num_pkts_in_q                  (num_pkts_in_q_src),
      .src_num_pkts_in_q_done             (num_pkts_in_q_src_wr_done),

      .src_oq_full_thresh                 (oq_full_thresh_src),
      .src_num_words_left                 (num_words_left_src),
      .src_num_words_left_done            (num_words_left_src_wr_done),

      // --- Clear the flag ---
      .initialize                         (initialize),
      .initialize_oq                      (initialize_oq),

      .full                               (full),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );



   // -------------------------------------------
   // Host interface module
   //  -- initial processing of incoming register
   //     requests
   //  -- most of the register processing is handed
   //     off to oq_regs_host_ctrl
   // -------------------------------------------

   oq_regs_host_iface
   #(
      .SRAM_ADDR_WIDTH     (SRAM_ADDR_WIDTH),
      .CTRL_WIDTH          (CTRL_WIDTH),
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .NUM_OUTPUT_QUEUES   (NUM_OUTPUT_QUEUES),
      .NUM_REGS_USED       (NUM_REGS_USED)
   ) oq_regs_host_iface (
      // --- interface to udp_reg_grp
      .reg_req_in                            (reg_req_in),
      .reg_ack_in                            (reg_ack_in),
      .reg_rd_wr_L_in                        (reg_rd_wr_L_in),
      .reg_addr_in                           (reg_addr_in),
      .reg_data_in                           (reg_data_in),
      .reg_src_in                            (reg_src_in),

      .reg_req_out                           (reg_req_out),
      .reg_ack_out                           (reg_ack_out),
      .reg_rd_wr_L_out                       (reg_rd_wr_L_out),
      .reg_addr_out                          (reg_addr_out),
      .reg_data_out                          (reg_data_out),
      .reg_src_out                           (reg_src_out),

      // --- interface to oq_regs_process_sm
      .req_in_progress                       (req_in_progress),
      .reg_rd_wr_L_held                      (reg_rd_wr_L_held),
      .reg_data_held                         (reg_data_held),
      .addr                                  (addr),
      .q_addr                                (q_addr),

      .result_ready                          (result_ready),
      .reg_result                            (reg_result),

      // --- Misc
      .clk                                   (clk),
      .reset                                 (reset)
   );



   // -------------------------------------------
   // Register instances module
   //   -- Holds the memory instances for all registers except the control
   //      register
   // -------------------------------------------

   oq_reg_instances
   #(
      .SRAM_ADDR_WIDTH      (SRAM_ADDR_WIDTH),
      .CTRL_WIDTH           (CTRL_WIDTH),
      .UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
      .NUM_OUTPUT_QUEUES    (NUM_OUTPUT_QUEUES),
      .PKT_LEN_WIDTH        (PKT_LEN_WIDTH),
      .MAX_PKT              (MAX_PKT)
   ) oq_reg_instances  (
      // --- interface to remove_pkt
      .src_oq_rd_addr                     (src_oq_rd_addr),
      .src_oq_high_addr                   (src_oq_high_addr),
      .src_oq_low_addr                    (src_oq_low_addr),
      .src_oq_rd_addr_new                 (src_oq_rd_addr_new),
      .pkt_removed                        (pkt_removed),
      .removed_pkt_data_length            (removed_pkt_data_length),
      .removed_pkt_overhead_length        (removed_pkt_overhead_length),
      .removed_pkt_total_word_length      (removed_pkt_total_word_length),
      .src_oq                             (src_oq),
      .removed_oq                         (removed_oq),
      .rd_src_addr                        (rd_src_addr),

      // --- interface to store_pkt
      .dst_oq_wr_addr_new                 (dst_oq_wr_addr_new),
      .pkt_stored                         (pkt_stored),
      .stored_pkt_data_length             (stored_pkt_data_length),
      .stored_pkt_overhead_length         (stored_pkt_overhead_length),
      .stored_pkt_total_word_length       (stored_pkt_total_word_length),
      .pkt_dropped                        (pkt_dropped),
      .dst_oq                             (dst_oq),
      .rd_dst_addr                        (rd_dst_addr),
      .dst_oq_high_addr                   (dst_oq_high_addr),
      .dst_oq_low_addr                    (dst_oq_low_addr),
      .dst_oq_wr_addr                     (dst_oq_wr_addr),

      // Register interfaces
      .reg_addr                           (reg_addr),

      .num_pkt_bytes_stored_reg_req       (num_pkt_bytes_stored_reg_req),
      .num_pkt_bytes_stored_reg_ack       (num_pkt_bytes_stored_reg_ack),
      .num_pkt_bytes_stored_reg_wr        (num_pkt_bytes_stored_reg_wr),
      .num_pkt_bytes_stored_reg_wr_data   (num_pkt_bytes_stored_reg_wr_data),
      .num_pkt_bytes_stored_reg_rd_data   (num_pkt_bytes_stored_reg_rd_data),

      .num_overhead_bytes_stored_reg_req  (num_overhead_bytes_stored_reg_req),
      .num_overhead_bytes_stored_reg_ack  (num_overhead_bytes_stored_reg_ack),
      .num_overhead_bytes_stored_reg_wr   (num_overhead_bytes_stored_reg_wr),
      .num_overhead_bytes_stored_reg_wr_data(num_overhead_bytes_stored_reg_wr_data),
      .num_overhead_bytes_stored_reg_rd_data(num_overhead_bytes_stored_reg_rd_data),

      .num_pkts_stored_reg_req            (num_pkts_stored_reg_req),
      .num_pkts_stored_reg_ack            (num_pkts_stored_reg_ack),
      .num_pkts_stored_reg_wr             (num_pkts_stored_reg_wr),
      .num_pkts_stored_reg_wr_data        (num_pkts_stored_reg_wr_data),
      .num_pkts_stored_reg_rd_data        (num_pkts_stored_reg_rd_data),

      .num_pkts_dropped_reg_req           (num_pkts_dropped_reg_req),
      .num_pkts_dropped_reg_ack           (num_pkts_dropped_reg_ack),
      .num_pkts_dropped_reg_wr            (num_pkts_dropped_reg_wr),
      .num_pkts_dropped_reg_wr_data       (num_pkts_dropped_reg_wr_data),
      .num_pkts_dropped_reg_rd_data       (num_pkts_dropped_reg_rd_data),

      .num_pkt_bytes_removed_reg_req      (num_pkt_bytes_removed_reg_req),
      .num_pkt_bytes_removed_reg_ack      (num_pkt_bytes_removed_reg_ack),
      .num_pkt_bytes_removed_reg_wr       (num_pkt_bytes_removed_reg_wr),
      .num_pkt_bytes_removed_reg_wr_data  (num_pkt_bytes_removed_reg_wr_data),
      .num_pkt_bytes_removed_reg_rd_data  (num_pkt_bytes_removed_reg_rd_data),

      .num_overhead_bytes_removed_reg_req (num_overhead_bytes_removed_reg_req),
      .num_overhead_bytes_removed_reg_ack (num_overhead_bytes_removed_reg_ack),
      .num_overhead_bytes_removed_reg_wr  (num_overhead_bytes_removed_reg_wr),
      .num_overhead_bytes_removed_reg_wr_data(num_overhead_bytes_removed_reg_wr_data),
      .num_overhead_bytes_removed_reg_rd_data(num_overhead_bytes_removed_reg_rd_data),

      .num_pkts_removed_reg_req           (num_pkts_removed_reg_req),
      .num_pkts_removed_reg_ack           (num_pkts_removed_reg_ack),
      .num_pkts_removed_reg_wr            (num_pkts_removed_reg_wr),
      .num_pkts_removed_reg_wr_data       (num_pkts_removed_reg_wr_data),
      .num_pkts_removed_reg_rd_data       (num_pkts_removed_reg_rd_data),

      .oq_addr_hi_reg_req                 (oq_addr_hi_reg_req),
      .oq_addr_hi_reg_ack                 (oq_addr_hi_reg_ack),
      .oq_addr_hi_reg_wr                  (oq_addr_hi_reg_wr),
      .oq_addr_hi_reg_wr_data             (oq_addr_hi_reg_wr_data),
      .oq_addr_hi_reg_rd_data             (oq_addr_hi_reg_rd_data),

      .oq_addr_lo_reg_req                 (oq_addr_lo_reg_req),
      .oq_addr_lo_reg_ack                 (oq_addr_lo_reg_ack),
      .oq_addr_lo_reg_wr                  (oq_addr_lo_reg_wr),
      .oq_addr_lo_reg_wr_data             (oq_addr_lo_reg_wr_data),
      .oq_addr_lo_reg_rd_data             (oq_addr_lo_reg_rd_data),

      .oq_wr_addr_reg_req                 (oq_wr_addr_reg_req),
      .oq_wr_addr_reg_ack                 (oq_wr_addr_reg_ack),
      .oq_wr_addr_reg_wr                  (oq_wr_addr_reg_wr),
      .oq_wr_addr_reg_wr_data             (oq_wr_addr_reg_wr_data),
      .oq_wr_addr_reg_rd_data             (oq_wr_addr_reg_rd_data),

      .oq_rd_addr_reg_req                 (oq_rd_addr_reg_req),
      .oq_rd_addr_reg_ack                 (oq_rd_addr_reg_ack),
      .oq_rd_addr_reg_wr                  (oq_rd_addr_reg_wr),
      .oq_rd_addr_reg_wr_data             (oq_rd_addr_reg_wr_data),
      .oq_rd_addr_reg_rd_data             (oq_rd_addr_reg_rd_data),

      .max_pkts_in_q_reg_req              (max_pkts_in_q_reg_req),
      .max_pkts_in_q_reg_ack              (max_pkts_in_q_reg_ack),
      .max_pkts_in_q_reg_wr               (max_pkts_in_q_reg_wr),
      .max_pkts_in_q_reg_wr_data          (max_pkts_in_q_reg_wr_data),
      .max_pkts_in_q_reg_rd_data          (max_pkts_in_q_reg_rd_data),

      .num_pkts_in_q_reg_req              (num_pkts_in_q_reg_req),
      .num_pkts_in_q_reg_ack              (num_pkts_in_q_reg_ack),
      .num_pkts_in_q_reg_wr               (num_pkts_in_q_reg_wr),
      .num_pkts_in_q_reg_wr_data          (num_pkts_in_q_reg_wr_data),
      .num_pkts_in_q_reg_rd_data          (num_pkts_in_q_reg_rd_data),

      .num_words_left_reg_req             (num_words_left_reg_req),
      .num_words_left_reg_ack             (num_words_left_reg_ack),
      .num_words_left_reg_wr              (num_words_left_reg_wr),
      .num_words_left_reg_wr_data         (num_words_left_reg_wr_data),
      .num_words_left_reg_rd_data         (num_words_left_reg_rd_data),

      .num_words_in_q_reg_req             (num_words_in_q_reg_req),
      .num_words_in_q_reg_ack             (num_words_in_q_reg_ack),
      .num_words_in_q_reg_wr              (num_words_in_q_reg_wr),
      .num_words_in_q_reg_wr_data         (num_words_in_q_reg_wr_data),
      .num_words_in_q_reg_rd_data         (num_words_in_q_reg_rd_data),

      .oq_full_thresh_reg_req             (oq_full_thresh_reg_req),
      .oq_full_thresh_reg_ack             (oq_full_thresh_reg_ack),
      .oq_full_thresh_reg_wr              (oq_full_thresh_reg_wr),
      .oq_full_thresh_reg_wr_data         (oq_full_thresh_reg_wr_data),
      .oq_full_thresh_reg_rd_data         (oq_full_thresh_reg_rd_data),

      // Values used to calculate full/emtpy state
      .max_pkts_in_q_dst                  (max_pkts_in_q_dst),
      .num_pkts_in_q_dst                  (num_pkts_in_q_dst),
      .num_pkts_in_q_dst_wr_done          (num_pkts_in_q_dst_wr_done),

      .max_pkts_in_q_src                  (max_pkts_in_q_src),
      .num_pkts_in_q_src                  (num_pkts_in_q_src),
      .num_pkts_in_q_src_wr_done          (num_pkts_in_q_src_wr_done),

      .oq_full_thresh_dst                 (oq_full_thresh_dst),
      .num_words_left_dst                 (num_words_left_dst),
      .num_words_left_dst_wr_done         (num_words_left_dst_wr_done),

      .oq_full_thresh_src                 (oq_full_thresh_src),
      .num_words_left_src                 (num_words_left_src),
      .num_words_left_src_wr_done         (num_words_left_src_wr_done),

      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );

endmodule // oq_regs
