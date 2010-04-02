
module head_cache_arb
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8
      )
  (
   // --- intfc to head cache
   input [10:0] hc_q_occup_word_cnt_0, //unit is 18-byte. count up to 1024.
   input [10:0] hc_q_occup_word_cnt_1,
   input [10:0] hc_q_occup_word_cnt_2,
   input [10:0] hc_q_occup_word_cnt_3,
   input [10:0] hc_q_occup_word_cnt_4,
   input [10:0] hc_q_occup_word_cnt_5,
   input [10:0] hc_q_occup_word_cnt_6,
   input [10:0] hc_q_occup_word_cnt_7,

   input [NUM_OUTPUT_QUEUES-1:0] hc_q_space_one_blk,

   output reg [2:0] hca_queue_num,
   output reg hca_queue_vld,

   // ---- intfc to DRAM
   input [NUM_OUTPUT_QUEUES-1:0] dram_q_not_empty,

   // --- phase info
   input [1:0] dram_phase,

   // ---- misc
   input clk,
   input reset

   );

   localparam IDLE_STATE = 0,
	      DRAM_RD_STATE = 1;

   reg 	      state, state_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] hca_que_one_hot, hca_que_one_hot_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] elig_vec;
   reg 			       hca_queue_vld_nxt;
   reg [2:0] 		       hca_queue_num_nxt;


   //--------------------------------------------------
   //dram_phase      Meaning
   //    2'b 00       time slot for DRAM initialization
   //    2'b 01       time slot for DRAM refresh
   //    2'b 10       time slot for DRAM write. Time for data transfer from BRAM to DRAM
   //    2'b 11       time slot for DRAM read.  Time for data transfer from DRAM to BRAM
   //
   // dram time slot will cycle through 3 phases: DRAM refresh, DRAM write, DRAM read,
   // and repeat that sequence.

   always @(*) begin

      state_nxt = state;
      hca_que_one_hot_nxt = hca_que_one_hot;
      hca_queue_vld_nxt = 1'b 0;
      hca_queue_num_nxt = hca_queue_num;

      elig_vec = 'h 0;

      case (state)
	IDLE_STATE:
	  if (dram_phase == 2'b 11) begin
	     //DRAM read phase
	     elig_vec = dram_q_not_empty & hc_q_space_one_blk;

	     hca_que_one_hot_nxt = func_sel_least(elig_vec,
						  hc_q_occup_word_cnt_0,
						  hc_q_occup_word_cnt_1,
						  hc_q_occup_word_cnt_2,
						  hc_q_occup_word_cnt_3,
						  hc_q_occup_word_cnt_4,
						  hc_q_occup_word_cnt_5,
						  hc_q_occup_word_cnt_6,
						  hc_q_occup_word_cnt_7
						  );

	     hca_queue_vld_nxt = | hca_que_one_hot_nxt;
	     hca_queue_num_nxt = func_encode(hca_que_one_hot_nxt);

	     state_nxt = DRAM_RD_STATE;
	  end // if (dram_phase == 2'b 11)

	DRAM_RD_STATE:
	   if (dram_phase == 2'b 01) begin
	      // refresh phase
	      hca_que_one_hot_nxt = 'h 0;
	      state_nxt = IDLE_STATE;
	   end

      endcase // case(state)

   end // always @ (*)

   always @(posedge clk) begin
      if (reset) begin
	 state           <= IDLE_STATE;
	 hca_que_one_hot <= 'h 0;
	 hca_queue_vld   <= 1'h 0;
	 hca_queue_num   <= 'h 0;

      end
      else begin
	 state           <= state_nxt;
	 hca_que_one_hot <= hca_que_one_hot_nxt;
	 hca_queue_vld   <= hca_queue_vld_nxt;
	 hca_queue_num   <= hca_queue_num_nxt;

      end
   end

   // select the less from two numbers
   function [NUM_OUTPUT_QUEUES+1:0] func_sel_less;
      input [1:0] elig_pair;
      input [10:0] cnt1, cnt0;

      reg vld, winner;
      reg [10:0] cnt;

      begin
      	 vld = elig_pair[0] | elig_pair[1];

	 case (elig_pair[1:0])
	   2'b 00: begin
	      winner = 0;
	      cnt = 11'h 0;
	   end

	   2'b 01: begin
	      winner = 0;
	      cnt = cnt0;
	   end

	   2'b 10: begin
	      winner = 1;
	      cnt = cnt1;
	   end

	   2'b 11: begin
	      if (cnt0 >= cnt1) begin
		 winner = 1;
		 cnt = cnt1;

	      end
	      else begin
		 winner = 0;
		 cnt = cnt0;

	      end

	   end // case: 2'b 11

	 endcase // case(elig_pair[1:0])

	 func_sel_less = {vld, winner, cnt};

      end

   endfunction // func_sel_less



   // select the least from all queue counts
   function [NUM_OUTPUT_QUEUES-1:0] func_sel_least;
      input [NUM_OUTPUT_QUEUES-1:0] elig_vec;
      input [10:0] tc_q_occup_word_cnt_0; //unit is 18-byte. count up to 1024.
      input [10:0] tc_q_occup_word_cnt_1;
      input [10:0] tc_q_occup_word_cnt_2;
      input [10:0] tc_q_occup_word_cnt_3;
      input [10:0] tc_q_occup_word_cnt_4;
      input [10:0] tc_q_occup_word_cnt_5;
      input [10:0] tc_q_occup_word_cnt_6;
      input [10:0] tc_q_occup_word_cnt_7;

      reg [12:0] res00, res01, res02, res03;
      reg vld00, vld01, vld02, vld03;
      reg winner00, winner01, winner02, winner03;
      reg [10:0] cnt00, cnt01, cnt02, cnt03;

      reg [12:0] res10, res11;
      reg vld10, vld11;
      reg winner10, winner11;
      reg [10:0] cnt10, cnt11;

      reg [12:0] res20;
      reg vld20, winner20;

      reg [2:0] winner;

      begin

	 // ---- layer 0
	 res00 = func_sel_less(elig_vec[1:0],
			       tc_q_occup_word_cnt_1,
			       tc_q_occup_word_cnt_0
			       );
	 vld00    = res00[12];
	 winner00 = res00[11];
	 cnt00    = res00[10:0];


	 res01 = func_sel_less(elig_vec[3:2],
			       tc_q_occup_word_cnt_3,
			       tc_q_occup_word_cnt_2
			       );
	 vld01    = res01[12];
	 winner01 = res01[11];
	 cnt01    = res01[10:0];


	 res02 = func_sel_less(elig_vec[5:4],
			       tc_q_occup_word_cnt_5,
			       tc_q_occup_word_cnt_4
			       );
	 vld02    = res02[12];
	 winner02 = res02[11];
	 cnt02    = res02[10:0];


	 res03 = func_sel_less(elig_vec[7:6],
			       tc_q_occup_word_cnt_7,
			       tc_q_occup_word_cnt_6
			       );
	 vld03    = res03[12];
	 winner03 = res03[11];
	 cnt03    = res03[10:0];


	 // ---- layer 1
	 res10 = func_sel_less({vld01, vld00},
			       cnt01,
			       cnt00
			       );
	 vld10    = res10[12];
	 winner10 = res10[11];
	 cnt10    = res10[10:0];

	 res11 = func_sel_less({vld03, vld02},
			       cnt03,
			       cnt02
			       );
	 vld11    = res11[12];
	 winner11 = res11[11];
	 cnt11    = res11[10:0];

	 // ---- layer 2
	 res20 = func_sel_less({vld11, vld10},
			       cnt11,
			       cnt10
			       );
	 vld20    = res20[12];
	 winner20 = res20[11];

	 // --- gen func return value
	 if (~ vld20)
	   func_sel_least = 'h 0;

	 else begin
	    winner[2] = winner20;

	    if (~ winner[2])
	      winner[1] = winner10;
	    else
	      winner[1] = winner11;

	    case (winner[2:1])
	      2'b 00: winner[0] = winner00;
	      2'b 01: winner[0] = winner01;
	      2'b 10: winner[0] = winner02;
	      2'b 11: winner[0] = winner03;
	    endcase // case(winner[2:1])

	    case (winner[2:0])
	      3'h 7: func_sel_least = 8'h 80;
	      3'h 6: func_sel_least = 8'h 40;
	      3'h 5: func_sel_least = 8'h 20;
	      3'h 4: func_sel_least = 8'h 10;
	      3'h 3: func_sel_least = 8'h 08;
	      3'h 2: func_sel_least = 8'h 04;
	      3'h 1: func_sel_least = 8'h 02;
	      3'h 0: func_sel_least = 8'h 01;
	    endcase // case(winner[2:0])

	 end // else: !if(~ vld20)

      end

   endfunction // func_sel_least


   function [2:0] func_encode;
      input [NUM_OUTPUT_QUEUES-1:0] one_hot;

      begin
	 casez (one_hot)
	   8'b 1???_????: func_encode = 3'h 7;
	   8'b 01??_????: func_encode = 3'h 6;
	   8'b 001?_????: func_encode = 3'h 5;
	   8'b 0001_????: func_encode = 3'h 4;
	   8'b 0000_1???: func_encode = 3'h 3;
	   8'b 0000_01??: func_encode = 3'h 2;
	   8'b 0000_001?: func_encode = 3'h 1;
	   8'b 0000_0001: func_encode = 3'h 0;
	   8'b 0000_0000: func_encode = 3'h 0;
	 endcase // casez(one_hot)

      end
   endfunction // func_encode

endmodule // head_cache_arb
