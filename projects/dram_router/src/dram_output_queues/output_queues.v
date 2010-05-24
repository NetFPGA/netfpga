///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_queues.v 4880 2009-02-12 09:32:37Z hyzeng $
//
// Module: output_queues.v
// Project: NF2.1
// Description: stores incoming packets into the DRAM and implements a round
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
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2*(DATA_WIDTH + CTRL_WIDTH)
)

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

     // --- Interface to DRAM
     output				dram_wr_req,
     output	[DRAM_ADDR_WIDTH-1:0]	dram_wr_ptr,
     output				dram_wr_data_vld,
     output	[DRAM_DATA_WIDTH-1:0]	dram_wr_data,
     input				dram_wr_ack,
     input				dram_wr_full,
     input				dram_wr_done,

     // --- Interface to DRAM
     output				dram_rd_req,
     output [DRAM_ADDR_WIDTH-1:0]	dram_rd_ptr,
     output				dram_rd_en,
     input [DRAM_DATA_WIDTH-1:0]	dram_rd_data,
     input				dram_rd_ack,
     input				dram_rd_rdy,
     input				dram_rd_done,

     input				dram_sm_idle,

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

   wire                       dst_oq_avail;
   wire [NUM_OUTPUT_QUEUES-1:0]    parsed_dst_oq;
   wire [PKT_BYTE_CNT_WIDTH-1:0] parsed_pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0] parsed_pkt_word_len;
   wire                       rd_dst_oq;
   wire                       header_parser_rdy;

   wire                       input_fifo_rd_en;
   wire                       input_fifo_empty;
   wire [DATA_WIDTH-1:0]      input_fifo_data_out;
   wire [CTRL_WIDTH-1:0]      input_fifo_ctrl_out;
   wire                       input_fifo_nearly_full;

   wire [DATA_WIDTH-1:0] out_data[NUM_OUTPUT_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0] out_ctrl[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0] out_wr;
   wire [NUM_OUTPUT_QUEUES-1:0] out_rdy;

   wire [DATA_WIDTH-1:0] local_in_data[NUM_OUTPUT_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0] local_in_ctrl[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0] local_in_wr;
   wire [NUM_OUTPUT_QUEUES-1:0] local_in_rdy;
   wire [NUM_OUTPUT_QUEUES-1:0] local_odd_word;

   wire [NUM_OUTPUT_QUEUES * 9-1:0] local_fifo_wr_data_count;

   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_wr_req;
   wire [DRAM_ADDR_WIDTH * NUM_OUTPUT_QUEUES-1:0] local_dram_wr_ptr;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_wr_data_vld;
   wire [DRAM_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0] local_dram_wr_data;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_wr_ack;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_wr_full;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_wr_done;

   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_rd_req;
   wire [DRAM_ADDR_WIDTH * NUM_OUTPUT_QUEUES-1:0] local_dram_rd_ptr;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_rd_en;
   wire [DRAM_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0] local_dram_rd_data;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_rd_ack;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_rd_rdy;
   wire [NUM_OUTPUT_QUEUES-1:0] local_dram_rd_done;

      // Counters
   wire [NUM_OUTPUT_QUEUES-1:0]	     pkts_stored;
   wire [NUM_OUTPUT_QUEUES-1:0]	     pkts_dropped;
   wire [NUM_OUTPUT_QUEUES-1:0]	     pkts_removed;
   wire [NUM_OUTPUT_QUEUES-1:0]	     shortcut_words;
   wire [NUM_OUTPUT_QUEUES-1:0]	     input_words;
   wire [NUM_OUTPUT_QUEUES-1:0]	     output_words;
   wire [NUM_OUTPUT_QUEUES-1:0]	     dram_wr_words;
   wire [NUM_OUTPUT_QUEUES-1:0]	     dram_rd_words;

      // SW
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     block_addr_lo;
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     block_addr_hi;
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]	   shortcut_disable;
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]	   ctrl;

      // HW
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     rd_addr;
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     wr_addr;

   assign out_data_0 = out_data[0];
   assign out_data_1 = out_data[1];
   assign out_data_2 = out_data[2];
   assign out_data_3 = out_data[3];
   assign out_data_4 = out_data[4];
   assign out_data_5 = out_data[5];
   assign out_data_6 = out_data[6];
   assign out_data_7 = out_data[7];

   assign out_ctrl_0 = out_ctrl[0];
   assign out_ctrl_1 = out_ctrl[1];
   assign out_ctrl_2 = out_ctrl[2];
   assign out_ctrl_3 = out_ctrl[3];
   assign out_ctrl_4 = out_ctrl[4];
   assign out_ctrl_5 = out_ctrl[5];
   assign out_ctrl_6 = out_ctrl[6];
   assign out_ctrl_7 = out_ctrl[7];

   assign out_wr_0 = out_wr[0];
   assign out_wr_1 = out_wr[1];
   assign out_wr_2 = out_wr[2];
   assign out_wr_3 = out_wr[3];
   assign out_wr_4 = out_wr[4];
   assign out_wr_5 = out_wr[5];
   assign out_wr_6 = out_wr[6];
   assign out_wr_7 = out_wr[7];

   assign out_rdy[0] = out_rdy_0;
   assign out_rdy[1] = out_rdy_1;
   assign out_rdy[2] = out_rdy_2;
   assign out_rdy[3] = out_rdy_3;
   assign out_rdy[4] = out_rdy_4;
   assign out_rdy[5] = out_rdy_5;
   assign out_rdy[6] = out_rdy_6;
   assign out_rdy[7] = out_rdy_7;

   dram_interface_arbiter
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .DRAM_ADDR_WIDTH(DRAM_ADDR_WIDTH),
       .DRAM_DATA_WIDTH(DRAM_DATA_WIDTH))
    dram_interface_arbiter
    (
     .dram_wr_req(dram_wr_req),
     .dram_wr_ptr(dram_wr_ptr),
     .dram_wr_data_vld(dram_wr_data_vld),
     .dram_wr_data(dram_wr_data),
     .dram_wr_ack(dram_wr_ack),
     .dram_wr_full(dram_wr_full),
     .dram_wr_done(dram_wr_done),

     // --- Interface to DRAM
     .dram_rd_req(dram_rd_req),
     .dram_rd_ptr(dram_rd_ptr),
     .dram_rd_en(dram_rd_en),
     .dram_rd_data(dram_rd_data),
     .dram_rd_ack(dram_rd_ack),
     .dram_rd_rdy(dram_rd_rdy),
     .dram_rd_done(dram_rd_done),

     // --- Interface to dram_queue
     .dram_wr_req_in(local_dram_wr_req),
     .dram_wr_ptr_in(local_dram_wr_ptr),
     .dram_wr_data_vld_in(local_dram_wr_data_vld),
     .dram_wr_data_in(local_dram_wr_data),
     .dram_wr_ack_in(local_dram_wr_ack),
     .dram_wr_full_in(local_dram_wr_full),
     .dram_wr_done_in(local_dram_wr_done),

     // --- Interface to dram_queue
     .dram_rd_req_in(local_dram_rd_req),
     .dram_rd_ptr_in(local_dram_rd_ptr),
     .dram_rd_en_in(local_dram_rd_en),
     .dram_rd_data_in(local_dram_rd_data),
     .dram_rd_ack_in(local_dram_rd_ack),
     .dram_rd_rdy_in(local_dram_rd_rdy),
     .dram_rd_done_in(local_dram_rd_done),

     // --- misc
     .clk(clk),
     .reset(reset)
    );

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

   fallthrough_small_fifo input_fifo
     (.dout({input_fifo_ctrl_out, input_fifo_data_out}),
      .full(),
      .nearly_full(input_fifo_nearly_full),
      .empty(input_fifo_empty),
      .din({in_ctrl, in_data}),
      .wr_en(in_wr),
      .rd_en(input_fifo_rd_en),
      .reset(reset),
      .clk(clk));

   dram_queue_arbiter
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES))
   dram_queue_arbiter
   (
       .parsed_dst_oq        (parsed_dst_oq),
       .parsed_pkt_byte_len  (parsed_pkt_byte_len),
       .parsed_pkt_word_len  (parsed_pkt_word_len),
       .header_parser_rdy    (header_parser_rdy),
       .dst_oq_avail         (dst_oq_avail),
       .rd_dst_oq            (rd_dst_oq),

        .input_fifo_rd_en                (input_fifo_rd_en),
        .input_fifo_empty                (input_fifo_empty),
        .input_fifo_data_out            (input_fifo_data_out),
        .input_fifo_ctrl_out            (input_fifo_ctrl_out),

        .fifo_wr_data_count             (local_fifo_wr_data_count),
	.odd_word			(local_odd_word),
        .pkts_dropped			(pkts_dropped),

        .out_data_0(local_in_data[0]), .out_ctrl_0(local_in_ctrl[0]), .out_rdy_0(local_in_rdy[0]),.out_wr_0(local_in_wr[0]),
        .out_data_1(local_in_data[1]), .out_ctrl_1(local_in_ctrl[1]), .out_rdy_1(local_in_rdy[1]),.out_wr_1(local_in_wr[1]),
        .out_data_2(local_in_data[2]), .out_ctrl_2(local_in_ctrl[2]), .out_rdy_2(local_in_rdy[2]),.out_wr_2(local_in_wr[2]),
        .out_data_3(local_in_data[3]), .out_ctrl_3(local_in_ctrl[3]), .out_rdy_3(local_in_rdy[3]),.out_wr_3(local_in_wr[3]),
        .out_data_4(local_in_data[4]), .out_ctrl_4(local_in_ctrl[4]), .out_rdy_4(local_in_rdy[4]),.out_wr_4(local_in_wr[4]),
        .out_data_5(local_in_data[5]), .out_ctrl_5(local_in_ctrl[5]), .out_rdy_5(local_in_rdy[5]),.out_wr_5(local_in_wr[5]),
        .out_data_6(local_in_data[6]), .out_ctrl_6(local_in_ctrl[6]), .out_rdy_6(local_in_rdy[6]),.out_wr_6(local_in_wr[6]),
        .out_data_7(local_in_data[7]), .out_ctrl_7(local_in_ctrl[7]), .out_rdy_7(local_in_rdy[7]),.out_wr_7(local_in_wr[7]),

        .clk(clk),
        .reset(reset)
   );

   generate
   genvar i;
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: dram_queue
         dram_queue
        #(.DATA_WIDTH			(DATA_WIDTH),
	  .CTRL_WIDTH			(CTRL_WIDTH),
	  .DRAM_ADDR_WIDTH		(22),
	  .DRAM_BLOCK_RDWR_ADDR_WIDTH	(`DRAM_BLOCK_RDWR_ADDR_WIDTH),
	  .DRAM_BLOCK_SIZE		(128),
      .DEFAULT_ADDR(i*1024)
	)
	dram_queue
           (
               .out_data(out_data[i]),
               .out_ctrl(out_ctrl[i]),
               .out_rdy(out_rdy[i]),
               .out_wr(out_wr[i]),

               .in_data(local_in_data[i]),
               .in_ctrl(local_in_ctrl[i]),
               .in_rdy(local_in_rdy[i]),
               .in_wr(local_in_wr[i]),
	       .odd_word(local_odd_word[i]),

               .fifo_wr_data_count(local_fifo_wr_data_count[(i+1)*9-1:i*9]),

               .pkts_dropped(pkts_dropped[i]),

    		// --- DRAM sm interface
                .dram_wr_req(local_dram_wr_req[i]),
                .dram_wr_ptr(local_dram_wr_ptr[(i+1)*DRAM_ADDR_WIDTH -1:i*DRAM_ADDR_WIDTH]),
                .dram_wr_data_vld(local_dram_wr_data_vld[i]),
                .dram_wr_data(local_dram_wr_data[(i+1)*DRAM_DATA_WIDTH -1:i*DRAM_DATA_WIDTH]),
                .dram_wr_ack(local_dram_wr_ack[i]),
                .dram_wr_full(local_dram_wr_full[i]),
                .dram_wr_done(local_dram_wr_done[i]),

                .dram_rd_req(local_dram_rd_req[i]),
                .dram_rd_ptr(local_dram_rd_ptr[(i+1)*DRAM_ADDR_WIDTH -1:i*DRAM_ADDR_WIDTH]),
                .dram_rd_en(local_dram_rd_en[i]),
                .dram_rd_data(local_dram_rd_data[(i+1)*DRAM_DATA_WIDTH -1:i*DRAM_DATA_WIDTH]),
                .dram_rd_ack(local_dram_rd_ack[i]),
                .dram_rd_done(local_dram_rd_done[i]),
                .dram_rd_rdy(local_dram_rd_rdy[i]),

                .dram_sm_idle(dram_sm_idle),

		//Registers
		//--- Counters
        	.input_words		(input_words[i]),
      		.dram_wr_words		(dram_wr_words[i]),
      		.dram_rd_words		(dram_rd_words[i]),
      		.shortcut_words		(shortcut_words[i]),
        	.output_words		(output_words[i]),
		.pkts_stored		(pkts_stored[i]),
		.pkts_removed		(pkts_removed[i]),

		//--- SW
                .shortcut_disable	(shortcut_disable[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),
        	.block_addr_lo		(block_addr_lo[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),
        	.block_addr_hi		(block_addr_hi[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),
        	.ctrl			(ctrl[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),

		//--- HW
        	.wr_addr		(wr_addr[i*`CPCI_NF2_DATA_WIDTH + `DRAM_BLOCK_RDWR_ADDR_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),
        	.rd_addr		(rd_addr[i*`CPCI_NF2_DATA_WIDTH + `DRAM_BLOCK_RDWR_ADDR_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH]),

    		// --- Misc
                .clk(clk),
                .reset(reset)
            );

	    // Unused HW register bits
	    assign wr_addr[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH + `DRAM_BLOCK_RDWR_ADDR_WIDTH] = 0;
	    assign rd_addr[(i+1)*`CPCI_NF2_DATA_WIDTH -1:i*`CPCI_NF2_DATA_WIDTH + `DRAM_BLOCK_RDWR_ADDR_WIDTH] = 0;

      end // block: dram_queue
   endgenerate

  dram_queue_regs
   #(
       .UDP_REG_SRC_WIDTH	(UDP_REG_SRC_WIDTH),
       .OQ_BLOCK_ADDR		(`OQ_BLOCK_ADDR),//Don't be confused! This is "block addr" of registers!
       .OQ_REG_ADDR_WIDTH	(`OQ_REG_ADDR_WIDTH),
       .NUM_OUTPUT_QUEUES	(NUM_OUTPUT_QUEUES)
   )dram_queue_regs
   (
      .reg_req_in       	(reg_req_in),
      .reg_ack_in       	(reg_ack_in),
      .reg_rd_wr_L_in   	(reg_rd_wr_L_in),
      .reg_addr_in      	(reg_addr_in),
      .reg_data_in      	(reg_data_in),
      .reg_src_in       	(reg_src_in),

      .reg_req_out      	(reg_req_out),
      .reg_ack_out      	(reg_ack_out),
      .reg_rd_wr_L_out  	(reg_rd_wr_L_out),
      .reg_addr_out     	(reg_addr_out),
      .reg_data_out     	(reg_data_out),
      .reg_src_out      	(reg_src_out),

      //--- Counters
      .input_words		(input_words),
      .output_words		(output_words),
      .dram_wr_words		(dram_wr_words),
      .dram_rd_words		(dram_rd_words),
      .shortcut_words		(shortcut_words),
      .pkts_stored		(pkts_stored),
      .pkts_removed		(pkts_removed),
      .pkts_dropped		(pkts_dropped),

      //--- SW
      .shortcut_disable		(shortcut_disable),
      .block_addr_lo		(block_addr_lo),
      .block_addr_hi		(block_addr_hi),
      .ctrl			(ctrl),

      //--- HW
      .wr_addr			(wr_addr),
      .rd_addr			(rd_addr),

      //Miscs
      .clk			(clk),
      .reset			(reset)
    );


   //------------------ Logic ------------------------
   assign in_rdy = header_parser_rdy && !input_fifo_nearly_full;

endmodule // output_queues




