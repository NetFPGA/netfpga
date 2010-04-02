///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module:
// Project: NF2.1
// Description:
//
///////////////////////////////////////////////////////////////////////////////

  module head_cache
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter STAGE_NUM = 6,
      parameter TRANSF_BLOCK_SZ = 2034 //in unit of byte
      )
   (
    // intfc to head cache arbiter and DRAM ctrler
    input [2:0] hca_queue_num,
    input hca_queue_wr,

    input [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] dram_data_ctrl,
    input dram_wr,

    // status signals to head cache arbiter
    output [10:0] hc_q_occup_word_cnt_0, //unit is 18-byte. count up to 1024.
    output [10:0] hc_q_occup_word_cnt_1,
    output [10:0] hc_q_occup_word_cnt_2,
    output [10:0] hc_q_occup_word_cnt_3,
    output [10:0] hc_q_occup_word_cnt_4,
    output [10:0] hc_q_occup_word_cnt_5,
    output [10:0] hc_q_occup_word_cnt_6,
    output [10:0] hc_q_occup_word_cnt_7,

    output [NUM_OUTPUT_QUEUES-1:0] hc_q_space_one_blk,

    // intfc to tail cache (cut-thru path)
    output [NUM_OUTPUT_QUEUES-1:0] hc_q_rdy,
    input [NUM_OUTPUT_QUEUES-1:0]  tc_hc_wr,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_0,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_1,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_2,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_3,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_4,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_5,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_6,
    input     [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_7,

    // intfc to MAC TX fifo
    output     [DATA_WIDTH-1:0] hc_data_0,
    output     [CTRL_WIDTH-1:0] hc_ctrl_0,
    output                      hc_wr_0,
    input                       mac_tx_rdy_0,

    output     [DATA_WIDTH-1:0] hc_data_1,
    output     [CTRL_WIDTH-1:0] hc_ctrl_1,
    output                      hc_wr_1,
    input                       mac_tx_rdy_1,

    output     [DATA_WIDTH-1:0] hc_data_2,
    output     [CTRL_WIDTH-1:0] hc_ctrl_2,
    output                      hc_wr_2,
    input                       mac_tx_rdy_2,

    output     [DATA_WIDTH-1:0] hc_data_3,
    output     [CTRL_WIDTH-1:0] hc_ctrl_3,
    output                      hc_wr_3,
    input                       mac_tx_rdy_3,

    output     [DATA_WIDTH-1:0] hc_data_4,
    output     [CTRL_WIDTH-1:0] hc_ctrl_4,
    output                      hc_wr_4,
    input                       mac_tx_rdy_4,

    output     [DATA_WIDTH-1:0] hc_data_5,
    output     [CTRL_WIDTH-1:0] hc_ctrl_5,
    output                      hc_wr_5,
    input                       mac_tx_rdy_5,

    output     [DATA_WIDTH-1:0] hc_data_6,
    output     [CTRL_WIDTH-1:0] hc_ctrl_6,
    output                      hc_wr_6,
    input                       mac_tx_rdy_6,

    output     [DATA_WIDTH-1:0] hc_data_7,
    output     [CTRL_WIDTH-1:0] hc_ctrl_7,
    output                      hc_wr_7,
    input                       mac_tx_rdy_7,

    // --- Misc
    input clk,
    input reset
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

   localparam BUFFER_DEPTH = 1024;//at the input side, width: 144
   localparam NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES);
   localparam TRANSF_BYTE_CNT_WIDTH = log2(TRANSF_BLOCK_SZ);

   //----------------------------------------
   // destination queue parser
   wire [NUM_OQ_WIDTH-1:0]     parsed_dst_oq;
   wire 		       parsed_pkt_byte_len;
   wire 		       parsed_pkt_word_len;
   wire 		       header_parser_rdy;
   wire 		       dst_oq_avail;

   //----------------------------------------
   // small fifo
   wire 		       input_fifo_ctrl_out;
   wire 		       input_fifo_data_out;
   wire 		       input_fifo_empty;
   wire 		       input_fifo_nearly_full;

   //----------------------------------------
   // tail cache queues
   wire [NUM_OUTPUT_QUEUES-1:0]  almost_full_oq;
   wire [10:0] 			 data_count_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [DATA_WIDTH+CTRL_WIDTH-1:0] dout_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0]         empty_oq;
   wire [NUM_OUTPUT_QUEUES-1:0] 	hc_ctrl_bit;
   reg [NUM_OUTPUT_QUEUES-1:0] 		hc_ctrl_bit_d1, hc_ctrl_bit_d2;

   //----------------------------------------
   // input state machine
   localparam INP_WAIT_FOR_PACKET_STATE = 0,
	      INP_STORE_PACKET_STATE    = 1,
	      INP_PAD_ONE_WORD_STATE    = 2;

   reg [1:0] inp_state, inp_state_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] selected_outputs, selected_outputs_next;
   wire [NUM_OUTPUT_QUEUES-1:0] wr_oq, rd_oq;
   reg 			       input_fifo_rd_en;
   reg 			       rd_dst_oq, in_pkt_stored;
   reg 			       inp_cnt_odd, inp_cnt_odd_nxt;

   //-----------------------------------------
   // output state machine
   localparam OUTP_IDLE_STATE = 0,
	      OUTP_TX_STATE   = 1;

   reg 	      outp_state, outp_state_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] tca_queue_one_hot, tca_queue_one_hot_nxt;
   reg [TRANSF_BYTE_CNT_WIDTH-1:0] dram_tx_byte_cnt, dram_tx_byte_cnt_nxt;

   //----------------------------------------
   // other wire, reg
   wire [NUM_OUTPUT_QUEUES-1:0] hc_tc_rdy, hc_wr, mac_tx_rdy;
   reg [NUM_OUTPUT_QUEUES-1:0] hca_queue_one_hot, hca_queue_one_hot_nxt;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl[NUM_OUTPUT_QUEUES-1:0];

   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] oq_din[NUM_OUTPUT_QUEUES-1:0];

   genvar i;


   //-----------------------------------------
   // Instantiations

   generate

      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: head_cache_queue
         asyncfifo_1024x144 oq  //actual required = 578 x 144
           (
	    // -- wr intfc
	    //input:
            .wr_en        ( wr_oq[i] ),
	    .din          ( oq_din[i] ), //[143:0]
	    //output:
            .wr_data_count( data_count_oq[i] ), // Bus [10 : 0]
            .full         (  ),
            .almost_full  ( almost_full_oq[i] ),

	    .wr_clk       ( clk ),

	    // -- rd intfc
	    //input:
            .rd_en        ( rd_oq[i] ),
	    //output:
            .dout         ( dout_oq[i] ), // Bus [71 : 0]
            .empty        ( empty_oq[i] ),

            .rd_clk       ( clk ),

	    // -- async rst:
            .rst          ( reset )
	    );
      end // block: head_cache
   endgenerate

   //--------------------------------------------------------
   // Logic

   generate
   for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: space_one_blk
      assign hc_q_space_one_blk[i] = ((BUFFER_DEPTH - data_count_oq[i]) > (TRANSF_BLOCK_SZ / (2*(DATA_WIDTH+CTRL_WIDTH)/8 )));
   end
   endgenerate

   generate
   for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: oq_wr_data
      assign oq_din[i] = hca_queue_one_hot[i] & dram_wr ? dram_data_ctrl :
			 (tc_hc_wr[i] ? tc_hc_data_ctrl[i]:{2*(DATA_WIDTH+CTRL_WIDTH) {1'b0}});
   end
   endgenerate

   assign hc_q_occup_word_cnt_0 = data_count_oq[0];
   assign hc_q_occup_word_cnt_1 = data_count_oq[1];
   assign hc_q_occup_word_cnt_2 = data_count_oq[2];
   assign hc_q_occup_word_cnt_3 = data_count_oq[3];
   assign hc_q_occup_word_cnt_4 = data_count_oq[4];
   assign hc_q_occup_word_cnt_5 = data_count_oq[5];
   assign hc_q_occup_word_cnt_6 = data_count_oq[6];
   assign hc_q_occup_word_cnt_7 = data_count_oq[7];

   assign tc_hc_data_ctrl[0] = tc_hc_data_ctrl_0;
   assign tc_hc_data_ctrl[1] = tc_hc_data_ctrl_1;
   assign tc_hc_data_ctrl[2] = tc_hc_data_ctrl_2;
   assign tc_hc_data_ctrl[3] = tc_hc_data_ctrl_3;
   assign tc_hc_data_ctrl[4] = tc_hc_data_ctrl_4;
   assign tc_hc_data_ctrl[5] = tc_hc_data_ctrl_5;
   assign tc_hc_data_ctrl[6] = tc_hc_data_ctrl_6;
   assign tc_hc_data_ctrl[7] = tc_hc_data_ctrl_7;

   assign {hc_ctrl_0, hc_data_0} = dout_oq[0];
   assign {hc_ctrl_1, hc_data_1} = dout_oq[1];
   assign {hc_ctrl_2, hc_data_2} = dout_oq[2];
   assign {hc_ctrl_3, hc_data_3} = dout_oq[3];
   assign {hc_ctrl_4, hc_data_4} = dout_oq[4];
   assign {hc_ctrl_5, hc_data_5} = dout_oq[5];
   assign {hc_ctrl_6, hc_data_6} = dout_oq[6];
   assign {hc_ctrl_7, hc_data_7} = dout_oq[7];

   assign hc_ctrl_bit[0] = | hc_ctrl_0;
   assign hc_ctrl_bit[1] = | hc_ctrl_1;
   assign hc_ctrl_bit[2] = | hc_ctrl_2;
   assign hc_ctrl_bit[3] = | hc_ctrl_3;
   assign hc_ctrl_bit[4] = | hc_ctrl_4;
   assign hc_ctrl_bit[5] = | hc_ctrl_5;
   assign hc_ctrl_bit[6] = | hc_ctrl_6;
   assign hc_ctrl_bit[7] = | hc_ctrl_7;

   assign hc_wr_0 = hc_wr[0];
   assign hc_wr_1 = hc_wr[1];
   assign hc_wr_2 = hc_wr[2];
   assign hc_wr_3 = hc_wr[3];
   assign hc_wr_4 = hc_wr[4];
   assign hc_wr_5 = hc_wr[5];
   assign hc_wr_6 = hc_wr[6];
   assign hc_wr_7 = hc_wr[7];

   assign mac_tx_rdy[0] = mac_tx_rdy_0;
   assign mac_tx_rdy[1] = mac_tx_rdy_1;
   assign mac_tx_rdy[2] = mac_tx_rdy_2;
   assign mac_tx_rdy[3] = mac_tx_rdy_3;
   assign mac_tx_rdy[4] = mac_tx_rdy_4;
   assign mac_tx_rdy[5] = mac_tx_rdy_5;
   assign mac_tx_rdy[6] = mac_tx_rdy_6;
   assign mac_tx_rdy[7] = mac_tx_rdy_7;

   //----------------------------------------------------
   // input state machine
   localparam INP_IDLE_STATE = 0,
	      INP_TX_STATE   = 1;

   always @(*) begin

      inp_state_nxt = inp_state;
      hca_queue_one_hot_nxt = hca_queue_one_hot;
      dram_tx_byte_cnt_nxt = dram_tx_byte_cnt;

      case (inp_state)
	INP_IDLE_STATE:
	  if (hca_queue_wr) begin
	     case (hca_queue_num)
	       3'h 0: hca_queue_one_hot_nxt = 8'h  1;
	       3'h 1: hca_queue_one_hot_nxt = 8'h  2;
	       3'h 2: hca_queue_one_hot_nxt = 8'h  4;
	       3'h 3: hca_queue_one_hot_nxt = 8'h  8;
	       3'h 4: hca_queue_one_hot_nxt = 8'h 10;
	       3'h 5: hca_queue_one_hot_nxt = 8'h 20;
	       3'h 6: hca_queue_one_hot_nxt = 8'h 40;
	       3'h 7: hca_queue_one_hot_nxt = 8'h 80;
	     endcase // case(hca_queue_num)

	     dram_tx_byte_cnt_nxt = {TRANSF_BYTE_CNT_WIDTH {1'h 0}};

	     inp_state_nxt = INP_TX_STATE;

	  end // if (tca_queue_rd)

	INP_TX_STATE: begin
	  if (dram_wr)
	    dram_tx_byte_cnt_nxt = dram_tx_byte_cnt + (DATA_WIDTH+CTRL_WIDTH)*2/8;

	   if (dram_tx_byte_cnt_nxt == TRANSF_BLOCK_SZ) begin
	      hca_queue_one_hot_nxt = 8'h 0;
	      inp_state_nxt = INP_IDLE_STATE;

	   end

	end // case: INP_TX_STATE

      endcase // case(inp_state)

   end // always @ (*)


   assign wr_oq = (~ almost_full_oq) &
		  (hca_queue_one_hot & {NUM_OUTPUT_QUEUES {dram_wr}} |
		   ~hca_queue_one_hot & tc_hc_wr);

   assign hc_q_rdy = (~ almost_full_oq) & ~tca_queue_one_hot;

   assign rd_oq = (~ empty_oq) & mac_tx_rdy;

   //remove the padding at the end of packet
   assign hc_wr = rd_oq & ~( (~hc_ctrl_bit_d2) & hc_ctrl_bit_d1 & (~hc_ctrl_bit));


   always @(posedge clk) begin
      if (reset) begin
	 inp_state         <= INP_IDLE_STATE;
	 tca_queue_one_hot <= 8'h 0;
	 dram_tx_byte_cnt  <= { TRANSF_BYTE_CNT_WIDTH {1'h 0} };

	 hc_ctrl_bit_d1    <= {NUM_OUTPUT_QUEUES {1'b 0}};
	 hc_ctrl_bit_d2    <= {NUM_OUTPUT_QUEUES {1'b 0}};

      end
      else begin
	 inp_state         <= inp_state_nxt;
	 tca_queue_one_hot <= tca_queue_one_hot_nxt;
	 dram_tx_byte_cnt  <= dram_tx_byte_cnt_nxt;

	 hc_ctrl_bit_d1    <= hc_ctrl_bit;
	 hc_ctrl_bit_d2    <= hc_ctrl_bit_d1;

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // head_cache

