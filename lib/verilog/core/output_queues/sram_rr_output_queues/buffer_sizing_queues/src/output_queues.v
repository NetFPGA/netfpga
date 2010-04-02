///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_queues.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: output_queues.v
// Project: NF2.1
// Description: stores incoming packets into the SRAM and implements a round
// robin arbiter to service the output queues
//
///////////////////////////////////////////////////////////////////////////////

  module output_queues
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter STAGE_NUM = 6,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter SIG_VALUE_SIZE = 8,
      parameter ALL_SIG_VALUES_SIZE = 3*SIG_VALUE_SIZE,
      parameter SIGNAL_ID_SIZE = log2(NUM_OUTPUT_QUEUES),
      parameter ALL_SIGNAL_IDS_SIZE = 3*SIGNAL_ID_SIZE)

   (// --- data path interface
    output     [DATA_WIDTH-1:0]        out_data_0,
    output     [CTRL_WIDTH-1:0]        out_ctrl_0,
    input                              out_rdy_0,
    output                             out_wr_0,

    output     [DATA_WIDTH-1:0]        out_data_1,
    output     [CTRL_WIDTH-1:0]        out_ctrl_1,
    input                              out_rdy_1,
    output                             out_wr_1,

    output     [DATA_WIDTH-1:0]        out_data_2,
    output     [CTRL_WIDTH-1:0]        out_ctrl_2,
    input                              out_rdy_2,
    output                             out_wr_2,

    output     [DATA_WIDTH-1:0]        out_data_3,
    output     [CTRL_WIDTH-1:0]        out_ctrl_3,
    input                              out_rdy_3,
    output                             out_wr_3,

    output     [DATA_WIDTH-1:0]        out_data_4,
    output     [CTRL_WIDTH-1:0]        out_ctrl_4,
    input                              out_rdy_4,
    output                             out_wr_4,

    output  [DATA_WIDTH-1:0]           out_data_5,
    output  [CTRL_WIDTH-1:0]           out_ctrl_5,
    output                             out_wr_5,
    input                              out_rdy_5,

    output  [DATA_WIDTH-1:0]           out_data_6,
    output  [CTRL_WIDTH-1:0]           out_ctrl_6,
    output                             out_wr_6,
    input                              out_rdy_6,

    output  [DATA_WIDTH-1:0]           out_data_7,
    output  [CTRL_WIDTH-1:0]           out_ctrl_7,
    output                             out_wr_7,
    input                              out_rdy_7,

    // --- Interface to the previous module
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    output                             in_rdy,
    input                              in_wr,

    // --- Register interface
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- SRAM sm interface
    output [SRAM_ADDR_WIDTH-1:0]       wr_0_addr,
    output                             wr_0_req,
    input                              wr_0_ack,
    output [DATA_WIDTH+CTRL_WIDTH-1:0] wr_0_data,

    input                              rd_0_ack,
    input  [DATA_WIDTH+CTRL_WIDTH-1:0] rd_0_data,
    input                              rd_0_vld,
    output [SRAM_ADDR_WIDTH-1:0]       rd_0_addr,
    output                             rd_0_req,

    // --- Event capture interface
    output [2:0]                       oq_signals,
    output [ALL_SIGNAL_IDS_SIZE-1:0]   oq_signal_ids,
    output [`CPCI_NF2_DATA_WIDTH*2*NUM_OUTPUT_QUEUES-1:0] oq_abs_regs,
    output [ALL_SIG_VALUES_SIZE-1:0]   oq_signal_values,

    // --- Misc
    input                              clk,
    input                              reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //------------- Internal Parameters ---------------
   parameter NUM_OQ_WIDTH       = log2(NUM_OUTPUT_QUEUES);
   parameter PKT_LEN_WIDTH      = 11;
   parameter PKT_WORDS_WIDTH    = PKT_LEN_WIDTH-log2(CTRL_WIDTH);
   parameter MAX_PKT            = 2048;   // allow for 2K bytes
   parameter PKT_BYTE_CNT_WIDTH = log2(MAX_PKT);
   parameter PKT_WORD_CNT_WIDTH = log2(MAX_PKT/CTRL_WIDTH);

   //--------------- Regs/Wires ----------------------

   wire [SRAM_ADDR_WIDTH-1:0] src_oq_rd_addr;
   wire [SRAM_ADDR_WIDTH-1:0] src_oq_high_addr;
   wire [SRAM_ADDR_WIDTH-1:0] src_oq_low_addr;
   wire [NUM_OUTPUT_QUEUES-1:0]src_oq_empty;
   wire [SRAM_ADDR_WIDTH-1:0] src_oq_rd_addr_new;
   wire                       pkt_removed;
   wire [PKT_LEN_WIDTH-1:0]   removed_pkt_data_length;
   wire [CTRL_WIDTH-1:0]      removed_pkt_overhead_length;
   wire [PKT_WORDS_WIDTH-1:0] removed_pkt_total_word_length;
   wire [NUM_OQ_WIDTH-1:0]    src_oq;
   wire [NUM_OQ_WIDTH-1:0]    removed_oq;
   wire                       rd_src_addr;
   wire [NUM_OUTPUT_QUEUES-1:0] enable_send_pkt;

   wire                       dst_oq_avail;
   wire [NUM_OQ_WIDTH-1:0]    parsed_dst_oq;
   wire [PKT_BYTE_CNT_WIDTH-1:0] parsed_pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0] parsed_pkt_word_len;
   wire                       rd_dst_oq;

   wire [SRAM_ADDR_WIDTH-1:0] dst_oq_wr_addr_new;
   wire                       pkt_stored;
   wire                       pkt_dropped;
   wire [PKT_LEN_WIDTH-1:0]   stored_pkt_data_length;
   wire [CTRL_WIDTH-1:0]      stored_pkt_overhead_length;
   wire [PKT_WORDS_WIDTH-1:0] stored_pkt_total_word_length;
   wire [NUM_OQ_WIDTH-1:0]    dst_oq;
   wire                       rd_dst_addr;
   wire [SRAM_ADDR_WIDTH-1:0] dst_oq_high_addr;
   wire [SRAM_ADDR_WIDTH-1:0] dst_oq_low_addr;
   wire [SRAM_ADDR_WIDTH-1:0] dst_oq_wr_addr;
   wire [NUM_OUTPUT_QUEUES-1:0]dst_oq_full;

   wire                       input_fifo_rd_en;
   wire                       input_fifo_empty;
   wire [DATA_WIDTH-1:0]      input_fifo_data_out;
   wire [CTRL_WIDTH-1:0]      input_fifo_ctrl_out;
   wire                       input_fifo_nearly_full;

   //---------------- Modules ------------------------
   oq_header_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .OP_LUT_STAGE_NUM(OP_LUT_STAGE_NUM),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES))
   oq_header_parser
     (
       .parsed_dst_oq        (parsed_dst_oq),
       .parsed_pkt_byte_len  (parsed_pkt_byte_len),
       .parsed_pkt_word_len  (parsed_pkt_word_len),
       .header_parser_rdy    (header_parser_rdy),
       .dst_oq_avail         (dst_oq_avail),
       .rd_dst_oq            (rd_dst_oq),
       .in_wr                (in_wr),
       .in_ctrl              (in_ctrl),
       .in_data              (in_data),
       .clk                  (clk),
       .reset                (reset));

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(3))
   input_fifo
     (.dout({input_fifo_ctrl_out, input_fifo_data_out}),
      .full(),
      .prog_full(),
      .nearly_full(input_fifo_nearly_full),
      .empty(input_fifo_empty),
      .din({in_ctrl, in_data}),
      .wr_en(in_wr),
      .rd_en(input_fifo_rd_en),
      .reset(reset),
      .clk(clk));

   store_pkt
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES),
       .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .OQ_STAGE_NUM (STAGE_NUM),
       .PKT_LEN_WIDTH(PKT_LEN_WIDTH))
   store_pkt
     (     // --- Interface to header_parser
           .dst_oq_avail (dst_oq_avail),
           .parsed_dst_oq (parsed_dst_oq),
           .parsed_pkt_byte_len (parsed_pkt_byte_len),
           .parsed_pkt_word_len (parsed_pkt_word_len),
           .rd_dst_oq (rd_dst_oq),

           // --- Interface to registers
           .dst_oq_wr_addr_new (dst_oq_wr_addr_new),
           .pkt_stored (pkt_stored),
           .pkt_dropped (pkt_dropped),
           .stored_pkt_data_length (stored_pkt_data_length),
           .stored_pkt_overhead_length (stored_pkt_overhead_length),
           .stored_pkt_total_word_length (stored_pkt_total_word_length),
           .dst_oq (dst_oq),
           .rd_dst_addr (rd_dst_addr),
           .dst_oq_high_addr (dst_oq_high_addr),
           .dst_oq_low_addr (dst_oq_low_addr),
           .dst_oq_wr_addr (dst_oq_wr_addr),
           .dst_oq_full (dst_oq_full),

           // --- Interface to SRAM
           .wr_0_addr (wr_0_addr),
           .wr_0_req (wr_0_req),
           .wr_0_ack (wr_0_ack),
           .wr_0_data (wr_0_data),

           // --- Interface to input fifo
           .input_fifo_rd_en (input_fifo_rd_en),
           .input_fifo_empty (input_fifo_empty),
           .input_fifo_data_out (input_fifo_data_out),
           .input_fifo_ctrl_out (input_fifo_ctrl_out),

           // --- misc
           .clk (clk),
           .reset (reset));

   remove_pkt
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES),
       .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .OQ_STAGE_NUM (STAGE_NUM),
       .OP_LUT_STAGE_NUM(OP_LUT_STAGE_NUM),
       .PKT_LEN_WIDTH(PKT_LEN_WIDTH))
   remove_pkt
     (// --- Interface to SRAM
      .rd_0_ack (rd_0_ack),
      .rd_0_data (rd_0_data),
      .rd_0_vld (rd_0_vld),
      .rd_0_addr (rd_0_addr),
      .rd_0_req (rd_0_req),

      // --- Interface to regs
      .src_oq_rd_addr (src_oq_rd_addr),
      .src_oq_high_addr (src_oq_high_addr),
      .src_oq_low_addr (src_oq_low_addr),
      .src_oq_empty (src_oq_empty),
      .src_oq_rd_addr_new (src_oq_rd_addr_new),
      .pkt_removed (pkt_removed),
      .removed_pkt_data_length (removed_pkt_data_length),
      .removed_pkt_overhead_length (removed_pkt_overhead_length),
      .removed_pkt_total_word_length (removed_pkt_total_word_length),
      .src_oq (src_oq),
      .removed_oq (removed_oq),
      .rd_src_addr (rd_src_addr),
      .enable_send_pkt (enable_send_pkt),

      // --- Interface to datapath
      .out_data_0 (out_data_0),
      .out_ctrl_0 (out_ctrl_0),
      .out_wr_0 (out_wr_0),
      .out_rdy_0 (out_rdy_0),

      .out_data_1 (out_data_1),
      .out_ctrl_1 (out_ctrl_1),
      .out_wr_1 (out_wr_1),
      .out_rdy_1 (out_rdy_1),

      .out_data_2 (out_data_2),
      .out_ctrl_2 (out_ctrl_2),
      .out_wr_2 (out_wr_2),
      .out_rdy_2 (out_rdy_2),

      .out_data_3 (out_data_3),
      .out_ctrl_3 (out_ctrl_3),
      .out_wr_3 (out_wr_3),
      .out_rdy_3 (out_rdy_3),

      .out_data_4 (out_data_4),
      .out_ctrl_4 (out_ctrl_4),
      .out_wr_4 (out_wr_4),
      .out_rdy_4 (out_rdy_4),

      .out_data_5 (out_data_5),
      .out_ctrl_5 (out_ctrl_5),
      .out_wr_5 (out_wr_5),
      .out_rdy_5 (out_rdy_5),

      .out_data_6 (out_data_6),
      .out_ctrl_6 (out_ctrl_6),
      .out_wr_6 (out_wr_6),
      .out_rdy_6 (out_rdy_6),

      .out_data_7 (out_data_7),
      .out_ctrl_7 (out_ctrl_7),
      .out_wr_7 (out_wr_7),
      .out_rdy_7 (out_rdy_7),

      // --- Misc
      .clk (clk),
      .reset (reset));

   oq_regs
     #(
       .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES),
       .PKT_LEN_WIDTH(PKT_LEN_WIDTH))
   oq_regs
     (// --- interface to udp_reg_grp
      .reg_req_in                      (reg_req_in),
      .reg_ack_in                      (reg_ack_in),
      .reg_rd_wr_L_in                  (reg_rd_wr_L_in),
      .reg_addr_in                     (reg_addr_in),
      .reg_data_in                     (reg_data_in),
      .reg_src_in                      (reg_src_in),

      .reg_req_out                     (reg_req_out),
      .reg_ack_out                     (reg_ack_out),
      .reg_rd_wr_L_out                 (reg_rd_wr_L_out),
      .reg_addr_out                    (reg_addr_out),
      .reg_data_out                    (reg_data_out),
      .reg_src_out                     (reg_src_out),

      // --- interface to remove_pkt
      .src_oq_rd_addr                  (src_oq_rd_addr),
      .src_oq_high_addr                (src_oq_high_addr),
      .src_oq_low_addr                 (src_oq_low_addr),
      .src_oq_empty                    (src_oq_empty),
      .src_oq_rd_addr_new              (src_oq_rd_addr_new),
      .pkt_removed                     (pkt_removed),
      .removed_pkt_data_length         (removed_pkt_data_length),
      .removed_pkt_overhead_length     (removed_pkt_overhead_length),
      .removed_pkt_total_word_length   (removed_pkt_total_word_length),
      .src_oq                          (src_oq),
      .removed_oq                      (removed_oq),
      .rd_src_addr                     (rd_src_addr),
      .enable_send_pkt                 (enable_send_pkt),

      // --- interface to store_pkt
      .dst_oq_wr_addr_new              (dst_oq_wr_addr_new),
      .pkt_stored                      (pkt_stored),
      .stored_pkt_data_length          (stored_pkt_data_length),
      .stored_pkt_overhead_length      (stored_pkt_overhead_length),
      .stored_pkt_total_word_length    (stored_pkt_total_word_length),
      .pkt_dropped                     (pkt_dropped),
      .dst_oq                          (dst_oq),
      .rd_dst_addr                     (rd_dst_addr),
      .dst_oq_high_addr                (dst_oq_high_addr),
      .dst_oq_low_addr                 (dst_oq_low_addr),
      .dst_oq_wr_addr                  (dst_oq_wr_addr),
      .dst_oq_full                     (dst_oq_full),

      // --- Misc
      .clk                             (clk),
      .reset                           (reset));


   evt_capture_oq_plugin
     #(.PKT_WORDS_WIDTH (PKT_WORDS_WIDTH),
       .SRAM_ADDR_WIDTH (SRAM_ADDR_WIDTH),
       .NUM_OUTPUT_QUEUES (NUM_OUTPUT_QUEUES))
     oq_plugin
     (
      .pkt_stored                      (pkt_stored),
      .pkt_dropped                     (pkt_dropped),
      .stored_pkt_total_word_length    (stored_pkt_total_word_length),
      .dst_oq                          (dst_oq),

      .pkt_removed                     (pkt_removed),
      .removed_pkt_total_word_length   (removed_pkt_total_word_length),
      .removed_oq                      (removed_oq),

      .oq_abs_regs                     (oq_abs_regs),
      .oq_signals                      (oq_signals),
      .oq_signal_ids                   (oq_signal_ids),
      .oq_signal_values                (oq_signal_values),

      .clk                             (clk),
      .reset                           (reset));

   //------------------ Logic ------------------------

   assign in_rdy = header_parser_rdy && !input_fifo_nearly_full;


endmodule // output_queues




