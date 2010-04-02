///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_reg_instances.v 5064 2009-02-22 05:20:35Z grg $
//
// Module: oq_reg_instances.v
// Project: NF2.1
// Description: Instances of the oq_regs_generic_reg_grp for each
// of the registers
//
// Note: The control register is implemented separately in the oq_regs_ctrl
// module
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module oq_reg_instances
  #(
      parameter SRAM_ADDR_WIDTH     = 19,
      parameter CTRL_WIDTH          = 8,
      parameter UDP_REG_SRC_WIDTH   = 2,
      parameter NUM_OUTPUT_QUEUES   = 8,
      parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
      parameter PKT_LEN_WIDTH       = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter MAX_PKT             = 2048/CTRL_WIDTH,   // allow for 2K bytes,
      parameter MIN_PKT             = 60/CTRL_WIDTH + 1,
      parameter PKTS_IN_RAM_WIDTH   = log2((2**SRAM_ADDR_WIDTH)/MIN_PKT)
   )

   (
      // --- interface to remove_pkt
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_rd_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_high_addr,
      output     [SRAM_ADDR_WIDTH-1:0]    src_oq_low_addr,
      input      [SRAM_ADDR_WIDTH-1:0]    src_oq_rd_addr_new,
      input                               pkt_removed,
      input      [PKT_LEN_WIDTH-1:0]      removed_pkt_data_length,
      input      [CTRL_WIDTH-1:0]         removed_pkt_overhead_length,
      input      [PKT_WORDS_WIDTH-1:0]    removed_pkt_total_word_length,
      input      [NUM_OQ_WIDTH-1:0]       src_oq,
      input      [NUM_OQ_WIDTH-1:0]       removed_oq,
      input                               rd_src_addr,

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

      // --- Register read/write interfaces (host/ctrl logic) ----
      input [NUM_OQ_WIDTH-1:0]            reg_addr,

      input                               num_pkt_bytes_stored_reg_req,
      output                              num_pkt_bytes_stored_reg_ack,
      input                               num_pkt_bytes_stored_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkt_bytes_stored_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkt_bytes_stored_reg_rd_data,

      input                               num_overhead_bytes_stored_reg_req,
      output                              num_overhead_bytes_stored_reg_ack,
      input                               num_overhead_bytes_stored_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_overhead_bytes_stored_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_overhead_bytes_stored_reg_rd_data,

      input                               num_pkts_stored_reg_req,
      output                              num_pkts_stored_reg_ack,
      input                               num_pkts_stored_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkts_stored_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkts_stored_reg_rd_data,

      input                               num_pkts_dropped_reg_req,
      output                              num_pkts_dropped_reg_ack,
      input                               num_pkts_dropped_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkts_dropped_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkts_dropped_reg_rd_data,

      input                               num_pkt_bytes_removed_reg_req,
      output                              num_pkt_bytes_removed_reg_ack,
      input                               num_pkt_bytes_removed_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkt_bytes_removed_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkt_bytes_removed_reg_rd_data,

      input                               num_overhead_bytes_removed_reg_req,
      output                              num_overhead_bytes_removed_reg_ack,
      input                               num_overhead_bytes_removed_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_overhead_bytes_removed_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_overhead_bytes_removed_reg_rd_data,

      input                               num_pkts_removed_reg_req,
      output                              num_pkts_removed_reg_ack,
      input                               num_pkts_removed_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkts_removed_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkts_removed_reg_rd_data,

      input                               oq_addr_hi_reg_req,
      output                              oq_addr_hi_reg_ack,
      input                               oq_addr_hi_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    oq_addr_hi_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   oq_addr_hi_reg_rd_data,

      input                               oq_addr_lo_reg_req,
      output                              oq_addr_lo_reg_ack,
      input                               oq_addr_lo_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    oq_addr_lo_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   oq_addr_lo_reg_rd_data,

      input                               oq_wr_addr_reg_req,
      output                              oq_wr_addr_reg_ack,
      input                               oq_wr_addr_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    oq_wr_addr_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   oq_wr_addr_reg_rd_data,

      input                               oq_rd_addr_reg_req,
      output                              oq_rd_addr_reg_ack,
      input                               oq_rd_addr_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    oq_rd_addr_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   oq_rd_addr_reg_rd_data,

      input                               max_pkts_in_q_reg_req,
      output                              max_pkts_in_q_reg_ack,
      input                               max_pkts_in_q_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    max_pkts_in_q_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   max_pkts_in_q_reg_rd_data,

      input                               num_pkts_in_q_reg_req,
      output                              num_pkts_in_q_reg_ack,
      input                               num_pkts_in_q_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_pkts_in_q_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_pkts_in_q_reg_rd_data,

      input                               num_words_left_reg_req,
      output                              num_words_left_reg_ack,
      input                               num_words_left_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_words_left_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_words_left_reg_rd_data,

      input                               num_words_in_q_reg_req,
      output                              num_words_in_q_reg_ack,
      input                               num_words_in_q_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    num_words_in_q_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   num_words_in_q_reg_rd_data,

      input                               oq_full_thresh_reg_req,
      output                              oq_full_thresh_reg_ack,
      input                               oq_full_thresh_reg_wr,
      input [`CPCI_NF2_DATA_WIDTH-1:0]    oq_full_thresh_reg_wr_data,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   oq_full_thresh_reg_rd_data,


      // --- Outputs used for calculating full/empty states ---
      output [PKTS_IN_RAM_WIDTH-1:0]      max_pkts_in_q_dst,
      output [PKTS_IN_RAM_WIDTH-1:0]      num_pkts_in_q_dst,
      output                              num_pkts_in_q_dst_wr_done,

      output [PKTS_IN_RAM_WIDTH-1:0]      max_pkts_in_q_src,
      output [PKTS_IN_RAM_WIDTH-1:0]      num_pkts_in_q_src,
      output                              num_pkts_in_q_src_wr_done,

      output [SRAM_ADDR_WIDTH-1:0]        oq_full_thresh_dst,
      output [SRAM_ADDR_WIDTH-1:0]        num_words_left_dst,
      output                              num_words_left_dst_wr_done,

      output [SRAM_ADDR_WIDTH-1:0]        oq_full_thresh_src,
      output [SRAM_ADDR_WIDTH-1:0]        num_words_left_src,
      output                              num_words_left_src_wr_done,

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
   localparam UNUSED_ADDR = {(log2(NUM_OUTPUT_QUEUES)){1'b0}};

   // ------------- Wires/reg ------------------





   // -------------------------------------------
   // Register instances
   //
   // Create one of these for each of the registers
   // -------------------------------------------

   // ==========================================
   //    OQ_QUEUE_NUM_PKT_BYTES_STORED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_LEN_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) num_pkt_bytes_stored_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          (stored_pkt_data_length),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_pkt_bytes_stored_reg_req),
      .reg_ack                            (num_pkt_bytes_stored_reg_ack),
      .reg_wr                             (num_pkt_bytes_stored_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkt_bytes_stored_reg_wr_data),
      .reg_rd_data                        (num_pkt_bytes_stored_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_LEN_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) num_overhead_bytes_stored_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          ({{(PKT_LEN_WIDTH-CTRL_WIDTH){1'b0}}, stored_pkt_overhead_length}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_overhead_bytes_stored_reg_req),
      .reg_ack                            (num_overhead_bytes_stored_reg_ack),
      .reg_wr                             (num_overhead_bytes_stored_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_overhead_bytes_stored_reg_wr_data),
      .reg_rd_data                        (num_overhead_bytes_stored_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_PKTS_STORED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (1),
      .ALLOW_NEGATIVE    (0)
   ) num_pkts_stored_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          (1'd1),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          (1'h0),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_pkts_stored_reg_req),
      .reg_ack                            (num_pkts_stored_reg_ack),
      .reg_wr                             (num_pkts_stored_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkts_stored_reg_wr_data),
      .reg_rd_data                        (num_pkts_stored_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_PKTS_DROPPED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (1),
      .ALLOW_NEGATIVE    (0)
   ) num_pkts_dropped_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_dropped),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          (1'd1),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          (1'h0),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_pkts_dropped_reg_req),
      .reg_ack                            (num_pkts_dropped_reg_ack),
      .reg_wr                             (num_pkts_dropped_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkts_dropped_reg_wr_data),
      .reg_rd_data                        (num_pkts_dropped_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_PKT_BYTES_REMOVED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_LEN_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) num_pkt_bytes_removed_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_removed),
      .wr_addr_a                          (removed_oq),
      .wr_data_a                          (removed_pkt_data_length),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_pkt_bytes_removed_reg_req),
      .reg_ack                            (num_pkt_bytes_removed_reg_ack),
      .reg_wr                             (num_pkt_bytes_removed_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkt_bytes_removed_reg_wr_data),
      .reg_rd_data                        (num_pkt_bytes_removed_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_LEN_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) num_overhead_bytes_removed_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_removed),
      .wr_addr_a                          (removed_oq),
      .wr_data_a                          ({{(PKT_LEN_WIDTH-CTRL_WIDTH){1'b0}}, removed_pkt_overhead_length}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_overhead_bytes_removed_reg_req),
      .reg_ack                            (num_overhead_bytes_removed_reg_ack),
      .reg_wr                             (num_overhead_bytes_removed_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_overhead_bytes_removed_reg_wr_data),
      .reg_rd_data                        (num_overhead_bytes_removed_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_PKTS_REMOVED
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (`CPCI_NF2_DATA_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (1),
      .ALLOW_NEGATIVE    (0)
   ) num_pkts_removed_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_removed),
      .wr_addr_a                          (removed_oq),
      .wr_data_a                          (1'd1),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          (1'h0),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_pkts_removed_reg_req),
      .reg_ack                            (num_pkts_removed_reg_ack),
      .reg_wr                             (num_pkts_removed_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkts_removed_reg_wr_data),
      .reg_rd_data                        (num_pkts_removed_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_ADDR_HI
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (SRAM_ADDR_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) oq_addr_hi_reg (
      // "A" channel input/output signals
      .rd_a                               (rd_dst_addr),
      .rd_addr_a                          (dst_oq),
      .rd_data_a                          (dst_oq_high_addr),

      .wr_a                               (1'b0),
      .wr_addr_a                          (UNUSED_ADDR),
      .wr_data_a                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (rd_src_addr),
      .rd_addr_b                          (src_oq),
      .rd_data_b                          (src_oq_high_addr),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (oq_addr_hi_reg_req),
      .reg_ack                            (oq_addr_hi_reg_ack),
      .reg_wr                             (oq_addr_hi_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (oq_addr_hi_reg_wr_data),
      .reg_rd_data                        (oq_addr_hi_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_ADDRRESS_LO
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (SRAM_ADDR_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) oq_addr_lo_reg (
      // "A" channel input/output signals
      .rd_a                               (rd_dst_addr),
      .rd_addr_a                          (dst_oq),
      .rd_data_a                          (dst_oq_low_addr),

      .wr_a                               (1'b0),
      .wr_addr_a                          (UNUSED_ADDR),
      .wr_data_a                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (rd_src_addr),
      .rd_addr_b                          (src_oq),
      .rd_data_b                          (src_oq_low_addr),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (oq_addr_lo_reg_req),
      .reg_ack                            (oq_addr_lo_reg_ack),
      .reg_wr                             (oq_addr_lo_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (oq_addr_lo_reg_wr_data),
      .reg_rd_data                        (oq_addr_lo_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_WR_ADDR
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (SRAM_ADDR_WIDTH),
      .ALLOW_NEGATIVE    (0),
      .REPLACE_ON_WRITE  (1)
   ) oq_wr_addr_reg (
      // "A" channel input/output signals
      .rd_a                               (rd_dst_addr),
      .rd_addr_a                          (dst_oq),
      .rd_data_a                          (dst_oq_wr_addr),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          (dst_oq_wr_addr_new),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (oq_wr_addr_reg_req),
      .reg_ack                            (oq_wr_addr_reg_ack),
      .reg_wr                             (oq_wr_addr_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (oq_wr_addr_reg_wr_data),
      .reg_rd_data                        (oq_wr_addr_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_RD_ADDR
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (SRAM_ADDR_WIDTH),
      .ALLOW_NEGATIVE    (0),
      .REPLACE_ON_WRITE  (1)
   ) oq_rd_addr_reg (
      // "A" channel input/output signals
      .rd_a                               (rd_src_addr),
      .rd_addr_a                          (src_oq),
      .rd_data_a                          (src_oq_rd_addr),

      .wr_a                               (pkt_removed),
      .wr_addr_a                          (removed_oq),
      .wr_data_a                          (src_oq_rd_addr_new),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({SRAM_ADDR_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (oq_rd_addr_reg_req),
      .reg_ack                            (oq_rd_addr_reg_ack),
      .reg_wr                             (oq_rd_addr_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (oq_rd_addr_reg_wr_data),
      .reg_rd_data                        (oq_rd_addr_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_MAX_PKTS_IN_Q
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (PKTS_IN_RAM_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_LEN_WIDTH),
      .ALLOW_NEGATIVE    (0)
   ) max_pkts_in_q_reg (
      // "A" channel input/output signals
      .rd_a                               (pkt_stored),
      .rd_addr_a                          (dst_oq),
      .rd_data_a                          (max_pkts_in_q_dst),

      .wr_a                               (1'b0),
      .wr_addr_a                          (UNUSED_ADDR),
      .wr_data_a                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (pkt_removed),
      .rd_addr_b                          (removed_oq),
      .rd_data_b                          (max_pkts_in_q_src),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          ({PKT_LEN_WIDTH{1'b0}}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (max_pkts_in_q_reg_req),
      .reg_ack                            (max_pkts_in_q_reg_ack),
      .reg_wr                             (max_pkts_in_q_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (max_pkts_in_q_reg_wr_data),
      .reg_rd_data                        (max_pkts_in_q_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_PKTS_IN_Q
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (PKTS_IN_RAM_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (2),
      .ALLOW_NEGATIVE    (1)
   ) num_pkts_in_q_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          (2'd1),
      .wr_new_value_a                     (num_pkts_in_q_dst),
      .wr_done_a                          (num_pkts_in_q_dst_wr_done),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (pkt_removed),
      .wr_addr_b                          (removed_oq),
      .wr_data_b                          (-2'd1),
      .wr_new_value_b                     (num_pkts_in_q_src),
      .wr_done_b                          (num_pkts_in_q_src_wr_done),

      // Register input/output signals
      .reg_req                            (num_pkts_in_q_reg_req),
      .reg_ack                            (num_pkts_in_q_reg_ack),
      .reg_wr                             (num_pkts_in_q_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_pkts_in_q_reg_wr_data),
      .reg_rd_data                        (num_pkts_in_q_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_WORDS_LEFT
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_WORDS_WIDTH + 1),
      .ALLOW_NEGATIVE    (1)
   ) num_words_left_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          ({1'b1, -stored_pkt_total_word_length}),
      .wr_new_value_a                     (num_words_left_dst),
      .wr_done_a                          (num_words_left_dst_wr_done),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (pkt_removed),
      .wr_addr_b                          (removed_oq),
      .wr_data_b                          ({1'b0, removed_pkt_total_word_length}),
      .wr_new_value_b                     (num_words_left_src),
      .wr_done_b                          (num_words_left_src_wr_done),

      // Register input/output signals
      .reg_req                            (num_words_left_reg_req),
      .reg_ack                            (num_words_left_reg_ack),
      .reg_wr                             (num_words_left_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_words_left_reg_wr_data),
      .reg_rd_data                        (num_words_left_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_NUM_WORDS_IN_Q
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (PKT_WORDS_WIDTH + 1),
      .ALLOW_NEGATIVE    (1)
   ) num_words_in_q_reg (
      // "A" channel input/output signals
      .rd_a                               (1'b0),
      .rd_addr_a                          (UNUSED_ADDR),
      .rd_data_a                          (),

      .wr_a                               (pkt_stored),
      .wr_addr_a                          (dst_oq),
      .wr_data_a                          ({1'b0, stored_pkt_total_word_length}),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (1'b0),
      .rd_addr_b                          (UNUSED_ADDR),
      .rd_data_b                          (),

      .wr_b                               (pkt_removed),
      .wr_addr_b                          (removed_oq),
      .wr_data_b                          ({1'b1, -removed_pkt_total_word_length}),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (num_words_in_q_reg_req),
      .reg_ack                            (num_words_in_q_reg_ack),
      .reg_wr                             (num_words_in_q_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (num_words_in_q_reg_wr_data),
      .reg_rd_data                        (num_words_in_q_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );


   // ==========================================
   //    OQ_QUEUE_FULL_THRESH
   // ==========================================

   oq_regs_generic_reg_grp
   #(
      .REG_WIDTH         (SRAM_ADDR_WIDTH),
      .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES),
      .WRITE_WIDTH       (1),
      .ALLOW_NEGATIVE    (0)
   ) oq_full_thresh_reg (
      // "A" channel input/output signals
      .rd_a                               (pkt_stored),
      .rd_addr_a                          (dst_oq),
      .rd_data_a                          (oq_full_thresh_dst),

      .wr_a                               (1'b0),
      .wr_addr_a                          (UNUSED_ADDR),
      .wr_data_a                          (1'h0),
      .wr_new_value_a                     (),
      .wr_done_a                          (),

      // "B" channel input/output signals
      .rd_b                               (pkt_removed),
      .rd_addr_b                          (removed_oq),
      .rd_data_b                          (oq_full_thresh_src),

      .wr_b                               (1'b0),
      .wr_addr_b                          (UNUSED_ADDR),
      .wr_data_b                          (1'h0),
      .wr_new_value_b                     (),
      .wr_done_b                          (),

      // Register input/output signals
      .reg_req                            (oq_full_thresh_reg_req),
      .reg_ack                            (oq_full_thresh_reg_ack),
      .reg_wr                             (oq_full_thresh_reg_wr),
      .reg_addr                           (reg_addr),
      .reg_wr_data                        (oq_full_thresh_reg_wr_data),
      .reg_rd_data                        (oq_full_thresh_reg_rd_data),


      // --- Misc
      .clk                                (clk),
      .reset                              (reset)
   );

endmodule // oq_reg_instances
