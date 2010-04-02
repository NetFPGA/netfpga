///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: ddr2_blk_rdwr_test.v
// Project: NetFPGA
// Description: Test circuit for ddr2_blk_rdwr module
//
//-----------------------------------------------------------------------
//
// NetFPGA 2.x card Specifications Regarding Clock Frequencies:
//
//       1. ddr2 clocks (i.e. clk_0, clk_90) run at 200 MHz;
//       2. system clock (i.e. clk_core) runs at either 62.5 MHz or 125 MHz
//          depending on the configuration register "CPCI_CNET_CLK_SEL_REG"
//          of CPCI chip: 62.5 MHz if Value(CPCI_CNET_CLK_SEL_REG)=0,
//                        125  MHz if Value(CPCI_CNET_CLK_SEL_REG)=1.
//
//-----------------------------------------------------------------------
// Allowed and Disallowed Combination Choices of NetFPGA 2.x System Clock Frequency
// and Parameter PKT_DATA_WIDTH of the ddr2_blk_rdwr Module:
//
//       1. System Clock Frequency = 62.5 MHz, PKT_DATA_WIDTH = 144-bit:
//             Disallowed combination. Design assumption violated.
//
//       2. System Clock Frequency = 62.5 MHz, PKT_DATA_WIDTH = 288-bit:
//             Allowed combination. Design assumption met.
//
//       3. System Clock Frequency =  125 MHz, PKT_DATA_WIDTH = 144-bit:
//             Allowed combination. Design assumption met.
//
//       4. System Clock Frequency =  125 MHz, PKT_DATA_WIDTH = 288-bit:
//             Allowed combination. Design assumption met.
//
////////////////////////////////////////////////////////////////////////////////

module ddr2_blk_rdwr_test
#(
  parameter PKT_MEM_PTR_WIDTH = 22,  //in unit of 16-byte. for 64 MB DRAM

  //select the right PKT_DATA_WIDTH for your design.
  parameter PKT_DATA_WIDTH = 144, //144-bit can work for 125 MHz
  //parameter PKT_DATA_WIDTH = 288, //288-bit can work for 62.5 MHz and 125 MHz

  //when to stop block transfer.
  //this parameter is overriden with a small number to speed up simulation.
  //11-bit: width of TRANSF_BLOCK_BRAM_SZ
  //4-bit:  width of 16-byte granularity in DDR2.
   parameter STOP_BLK_NUM = {(PKT_MEM_PTR_WIDTH-(11-4)) {1'b 1}}
  )

  (
   //output:
   output reg test_done,
   output reg test_success,

   // --- misc
   input clk,
   input reset,

   // --- ddr2 intfc
   input init_val_180,            // Initialization done
   input cmd_ack_180,             // Command acknowledged
   input auto_ref_req_180,        // Auto-refresh request
   input ar_done_180,             // Auto-refresh done
   input [63:0] rd_data_90,       //[63:0], Data returned from mem
   input rd_data_valid_90,       // Data is valid

   //output:
   output [3:0] cmd_180,          //[3:0] Command

   output [1:0] bank_addr_0, //[1:0], Bank address
   output [21:0] addr_0,        //[21:0] Rd/Wr address
   output burst_done_0,         // Burst complete

   output [14:0] config1,     //[14:0] Config register 1
   output [12:0] config2,     //[12:0] Config register 2

   output [63:0] wr_data_90,     //[63:0] Data written to mem
   output [7:0] wr_data_mask_90,  //[7:0] Write data mask

   //-------------------------------------
   //misc:
   input reset_0,
   input clk_0,
   input clk_90
   );

   function integer log2;
      input integer number;
      begin
         log2 = 0;
         while (2**log2 < number) begin
            log2 = log2 + 1;
         end
      end
   endfunction // log2

   //note that the DRAM block size is 2048-byte.
   //BRAM block size is no more than DRAM block size, and is multiple of the PKT_DATA_WIDTH.
   //2034-byte if PKT_DATA_WIDTH = 144-bit.
   //2016-byte if PKT_DATA_WIDTH = 288-bit.
   parameter TRANSF_BLOCK_BRAM_SZ = (PKT_DATA_WIDTH == 144) ? 2034 : 2016;

   parameter INTRA_BLK_WIDTH = log2(TRANSF_BLOCK_BRAM_SZ)-4;

   parameter BLK_NUM_WIDTH = PKT_MEM_PTR_WIDTH - INTRA_BLK_WIDTH;

   localparam NUM_WD_PER_BLK = TRANSF_BLOCK_BRAM_SZ/(PKT_DATA_WIDTH/8);// 8-bit/1-byte

   // --- wires from ddr2_blk_rdwr
   wire ddr2_sm_idle;
   wire p_wr_ack, p_wr_full, p_wr_done;
   wire p_rd_ack, p_rd_rdy, p_rd_done;
   wire [PKT_DATA_WIDTH-1:0] p_rd_data;

   //---------------------------------------------------
   //  wires from test bench

   // master
   reg [BLK_NUM_WIDTH-1:0]     blk_num,
			       blk_num_nxt;
   reg [1:0] 		       mst_state, mst_state_nxt, mst_state_d1;
   reg 			       slv_wr_start, slv_wr_start_nxt;
   reg 			       slv_rd_start, slv_rd_start_nxt;
   reg 			       test_done_nxt;
   reg                         clear_fail_flg;

   // wr
   reg 			       p_wr_req, p_wr_req_nxt;
   reg p_wr_data_vld, p_wr_data_vld_nxt;
   reg [PKT_MEM_PTR_WIDTH-1:0] p_wr_ptr, p_wr_ptr_nxt;
   reg [PKT_DATA_WIDTH-1:0] p_wr_data, p_wr_data_nxt;
   reg [1:0] 		       slv_wr_state, slv_wr_state_nxt;
   reg 			       slv_wr_done, slv_wr_done_nxt;

   reg [log2(NUM_WD_PER_BLK)-1:0] wr_word_cnt, wr_word_cnt_nxt;
   reg [7:0] 			  wr_char, wr_char_nxt;

   // rd
   reg 			    p_rd_req, p_rd_req_nxt;
   reg [PKT_MEM_PTR_WIDTH-1:0] p_rd_ptr, p_rd_ptr_nxt;
   reg [1:0] 		       slv_rd_state, slv_rd_state_nxt;
   reg 			       slv_rd_done, slv_rd_done_nxt;

   reg 			       fail_flg, fail_flg_nxt, fail_evt;
   reg [7:0] 		       rd_char, rd_char_nxt;
   reg [log2(NUM_WD_PER_BLK)-1:0] rd_word_cnt, rd_word_cnt_nxt;
   reg [PKT_DATA_WIDTH-1:0] 	  p_rd_data_exp, p_rd_data_exp_nxt;

   localparam MST_IDLE_STATE = 'h 0,
	      MST_WR_STATE   = 'h 1,
	      MST_RD_STATE   = 'h 2,
	      MST_DONE_STATE = 'h 3;

   localparam SLV_WR_IDLE_STATE = 'h 0,
	      SLV_WR_WAIT_ACK_STATE = 'h 1,
	      SLV_WR_DATA_STATE = 'h 2;

   localparam SLV_RD_IDLE_STATE = 'h 0,
	      SLV_RD_WAIT_ACK_STATE = 'h 1,
	      SLV_RD_DATA_STATE = 'h 2;

   // --- Instantiations
   ddr2_blk_rdwr
     #(
       .PKT_MEM_PTR_WIDTH    (PKT_MEM_PTR_WIDTH), //in unit of 16-byte
       .PKT_DATA_WIDTH       (PKT_DATA_WIDTH)
       ) ddr2_blk_rdwr_u
       (
	//---------------------------------------
	//intfc to ddr2 mem_intfc
	//input:
	.init_val_180     ( init_val_180 ),            // Initialization done
	.cmd_ack_180      ( cmd_ack_180 ),             // Command acknowledged
	.auto_ref_req_180 ( auto_ref_req_180 ),        // Auto-refresh request
	.ar_done_180      ( ar_done_180 ),             // Auto-refresh done
	.rd_data_90       ( rd_data_90 ),       //[63:0], Data returned from mem
	.rd_data_valid_90 ( rd_data_valid_90 ),       // Data is valid

	//output:
	.cmd_180      ( cmd_180 ),          //[3:0] Command
	.bank_addr_0  ( bank_addr_0 ), //[1:0], Bank address
	.addr_0       ( addr_0 ),        //[21:0] Rd/Wr address
	.burst_done_0 ( burst_done_0 ),         // Burst complete

	.config1 ( config1 ),     //[14:0] Config register 1
	.config2 ( config2 ),     //[12:0] Config register 2

	.wr_data_90      ( wr_data_90 ),     //[63:0] Data written to mem
	.wr_data_mask_90 ( wr_data_mask_90 ),  //[7:0] Write data mask

	//-------------------------------------
	//misc:
	//input:
	.reset_0 ( reset_0 ),
	.clk_0   ( clk_0 ),
	.clk_90  ( clk_90 ),

	//------------------------------------------------------------
	.ddr2_sm_idle ( ddr2_sm_idle ),

        //---------------------------------------
        // intfc to pkt data wr
        //input:
        .p_wr_req         ( p_wr_req ),
        .p_wr_ptr         ( p_wr_ptr ), //[PKT_MEM_PTR_WIDTH-1 : 0] in unit of 16-byte
        .p_wr_data_vld    ( p_wr_data_vld ),
        .p_wr_data        ( p_wr_data ), //[PKT_DATA_WIDTH-1 : 0]

        //output:
	.p_wr_ack         ( p_wr_ack ),
        .p_wr_full        ( p_wr_full ),
        .p_wr_done        ( p_wr_done ),

        //---------------------------------------
        // intfc to pkt data rd
        //input:
        .p_rd_req         ( p_rd_req ),
        .p_rd_ptr         ( p_rd_ptr ),//[PKT_MEM_PTR_WIDTH-1 : 0], in unit of 16-byte
        .p_rd_en          ( p_rd_rdy ),

        //output:
	.p_rd_ack         ( p_rd_ack ),
        .p_rd_rdy         ( p_rd_rdy ),
        .p_rd_data        ( p_rd_data ), //[PKT_DATA_WIDTH-1 : 0]
        .p_rd_done        ( p_rd_done ),

        //misc:
        //input:
        .clk_core         ( clk ),
        .reset_core       ( reset )
	);

   // --- logic

   //-------------------------------------------------------------
   // One way to design the master controller:
   // batch writes followed by batch reads
   always @(*) begin

      mst_state_nxt = mst_state;
      blk_num_nxt = blk_num;
      slv_wr_start_nxt = 1'h 0;
      slv_rd_start_nxt = 1'h 0;
      test_done_nxt = 1'b 0;
      test_success = 1'b 0;
      clear_fail_flg = 1'b 0;

      case (mst_state)
	MST_IDLE_STATE: begin

	   blk_num_nxt = 'h 0;
	   slv_wr_start_nxt = 1'b 1;

	   mst_state_nxt = MST_WR_STATE;

	end

	MST_WR_STATE: begin
	   if (slv_wr_done) begin

	      if (blk_num == STOP_BLK_NUM) begin

		 blk_num_nxt = 'h 0;
		 slv_rd_start_nxt = 1'b 1;

		 mst_state_nxt = MST_RD_STATE;

	      end
	      else begin

		 blk_num_nxt = blk_num + 'h 1;
		 slv_wr_start_nxt = 1'b 1;

	      end

	   end // if (slv_wr_done)

	end // case: MST_WR_STATE

	MST_RD_STATE: begin

	   if (slv_rd_done) begin

	      if (blk_num == STOP_BLK_NUM) begin

		 test_done_nxt = 1'b 1;
		 mst_state_nxt = MST_DONE_STATE;

	      end
	      else begin

		 blk_num_nxt = blk_num + 1;
		 slv_rd_start_nxt = 1'b 1;

	      end

	   end // if (slv_rd_done)

	end // case: MST_RD_STATE

	MST_DONE_STATE: begin

	   test_success = ~ fail_flg;
	   clear_fail_flg = 1'b 1;

	   mst_state_nxt = MST_IDLE_STATE;

	end

      endcase // case(mst_state)

   end // always @ *



/* -----\/----- EXCLUDED -----\/-----
   //-------------------------------------------------------------
   // Alternative way to design the master controller:
   // one write followed by one read, then repeat write and read

   always @(*) begin

      mst_state_nxt = mst_state;
      blk_num_nxt = blk_num;
      slv_wr_start_nxt = 1'b 0;
      slv_rd_start_nxt = 1'b 0;
      test_done_nxt = 1'b 0;

      test_success = 1'b 0;
      clear_fail_flg = 1'b 0;

      case (mst_state)
	MST_IDLE_STATE: begin

	      blk_num_nxt = 'h 0;
	      slv_wr_start_nxt = 1'b 1;

	      mst_state_nxt = MST_WR_STATE;

	end

	MST_WR_STATE: begin
	   if (slv_wr_done) begin
	      slv_rd_start_nxt = 1'b 1;

	      mst_state_nxt = MST_RD_STATE;

	   end // if (slv_wr_done)

	end // case: MST_WR_STATE

	MST_RD_STATE: begin

	   if (slv_rd_done) begin

	      if (blk_num == STOP_BLK_NUM) begin

		 test_done_nxt = 1'b 1;
		 mst_state_nxt = MST_DONE_STATE;

	      end
	      else begin

		 blk_num_nxt = blk_num + 'h 1;
		 slv_wr_start_nxt = 1'b 1;

		 mst_state_nxt = MST_WR_STATE;

	      end

	   end // if (slv_rd_done)

	end // case: MST_RD_STATE

	MST_DONE_STATE: begin

           test_success = ~ fail_flg;
           clear_fail_flg = 1'b 1;

   	   mst_state_nxt = MST_IDLE_STATE;

	end

      endcase // case(mst_state)

   end // always @ *

 -----/\----- EXCLUDED -----/\----- */


   //slv_wr
   always @(*) begin

      slv_wr_state_nxt = slv_wr_state;
      p_wr_req_nxt = p_wr_req;
      p_wr_ptr_nxt = p_wr_ptr;
      wr_word_cnt_nxt = wr_word_cnt;
      p_wr_data_vld_nxt = 'h 0;
      p_wr_data_nxt = p_wr_data;
      wr_char_nxt = wr_char;

      slv_wr_done_nxt = 1'b 0;

      case (slv_wr_state)
	SLV_WR_IDLE_STATE:
	  if (slv_wr_start) begin
	     p_wr_req_nxt = 'h 1;
	     p_wr_ptr_nxt = {blk_num_nxt, {INTRA_BLK_WIDTH {1'b 0}}};
	     wr_word_cnt_nxt = 'h 0;

	     slv_wr_state_nxt = SLV_WR_WAIT_ACK_STATE;

	  end

	SLV_WR_WAIT_ACK_STATE:

	  if (p_wr_ack) begin
	     p_wr_req_nxt = 'h 0;

	     slv_wr_state_nxt = SLV_WR_DATA_STATE;

	  end // if (p_wr_ack)

	SLV_WR_DATA_STATE: begin

	   if (p_wr_done) begin
	      slv_wr_state_nxt = SLV_WR_IDLE_STATE;
	      slv_wr_done_nxt = 1'b 1;

	   end
	   else
	     if (~ p_wr_full) begin

		wr_word_cnt_nxt = wr_word_cnt + 'h 1;

		p_wr_data_vld_nxt = 'h 1;
		p_wr_data_nxt = make_one_word(wr_char);
		wr_char_nxt = wr_char + PKT_DATA_WIDTH/8; //divided by 8-bit/1-byte
	     end


	end // case: SLV_WR_DATA_STATE

      endcase // case(slv_wr_state)

   end // always @ *


   //slv_rd
   always @(*) begin

      slv_rd_state_nxt = slv_rd_state;
      p_rd_req_nxt = p_rd_req;
      p_rd_ptr_nxt = p_rd_ptr;
      rd_word_cnt_nxt = rd_word_cnt;
      rd_char_nxt = rd_char;
      fail_flg_nxt = fail_flg;
      fail_evt = 1'b 0;
      p_rd_data_exp_nxt = p_rd_data_exp;

      slv_rd_done_nxt = 1'h 0;

      case (slv_rd_state)
	SLV_RD_IDLE_STATE:
	  if (slv_rd_start) begin
	     p_rd_req_nxt = 'h 1;
	     p_rd_ptr_nxt = {blk_num_nxt, {INTRA_BLK_WIDTH {1'b 0}}};
	     rd_word_cnt_nxt = 'h 0;

	     slv_rd_state_nxt = SLV_RD_WAIT_ACK_STATE;

	  end

	SLV_RD_WAIT_ACK_STATE:

	  if (p_rd_ack) begin
	     p_rd_req_nxt = 'h 0;

	     p_rd_data_exp_nxt = make_one_word(rd_char);
	     rd_char_nxt = rd_char + PKT_DATA_WIDTH/8; //divided by 8-bit/1-byte

	     slv_rd_state_nxt = SLV_RD_DATA_STATE;

	  end // if (p_rd_ack)

	SLV_RD_DATA_STATE: begin

	   if (p_rd_rdy) begin

	      if (p_rd_data_exp != p_rd_data) begin
		 fail_flg_nxt = 1'h 1;
		 fail_evt = 1'b 1;
	      end

	      rd_word_cnt_nxt = rd_word_cnt + 'h 1;

	      if (rd_word_cnt_nxt != NUM_WD_PER_BLK) begin
		 p_rd_data_exp_nxt = make_one_word(rd_char);
		 rd_char_nxt = rd_char + PKT_DATA_WIDTH/8; //divided by 8-bit/1-byte
	      end

	   end // if (p_rd_rdy)

	   if (p_rd_done) begin
	      slv_rd_state_nxt = SLV_RD_IDLE_STATE;
	      slv_rd_done_nxt = 1'h 1;

	   end

	end // case: SLV_RD_DATA_STATE

      endcase // case(slv_rd_state)

   end // always @ *


   function [PKT_DATA_WIDTH-1:0] make_one_word;
      input [7:0] char;
      integer i;
      reg [7:0] c;

      begin
	 c = char;

	 for (i=0; i<PKT_DATA_WIDTH/8; i=i+1) begin
	    make_one_word = { make_one_word[PKT_DATA_WIDTH-9:0], c};
	    c = c + 8'h 1;
	 end
      end

   endfunction // make_one_word


   always @(posedge clk) begin
      if (reset) begin

	 mst_state <= MST_IDLE_STATE;
	 blk_num   <= 'h 0;
	 slv_wr_start <= 'h 0;
	 slv_rd_start <= 'h 0;
	 test_done    <= 'h 0;

	 slv_wr_state <= SLV_WR_IDLE_STATE;
	 p_wr_req     <= 'h 0;
	 p_wr_ptr     <= 'h 0;
	 wr_word_cnt  <= 'h 0;
	 p_wr_data_vld <= 'h 0;
	 p_wr_data     <= {PKT_DATA_WIDTH {1'h 0}};
	 wr_char       <= 'h 0;

	 slv_rd_state <= SLV_RD_IDLE_STATE;
	 p_rd_req     <= 'h 0;
	 p_rd_ptr     <= 'h 0;
	 rd_word_cnt  <= 'h 0;
	 rd_char      <= 'h 0;
	 fail_flg     <= 'h 0;
	 p_rd_data_exp <= 'h 0;

	 slv_wr_done <= 1'h 0;
	 slv_rd_done <= 1'h 0;

      end
      else begin

	 mst_state <= mst_state_nxt;
	 blk_num   <= blk_num_nxt;
	 slv_wr_start <= slv_wr_start_nxt;
	 slv_rd_start <= slv_rd_start_nxt;
	 test_done    <= test_done_nxt;

	 slv_wr_state <= slv_wr_state_nxt;
	 p_wr_req     <= p_wr_req_nxt;
	 p_wr_ptr     <= p_wr_ptr_nxt;
	 wr_word_cnt  <= wr_word_cnt_nxt;
	 p_wr_data_vld <= p_wr_data_vld_nxt;
	 p_wr_data     <= p_wr_data_nxt;
	 wr_char       <= wr_char_nxt;

	 slv_rd_state <= slv_rd_state_nxt;
	 p_rd_req     <= p_rd_req_nxt;
	 p_rd_ptr     <= p_rd_ptr_nxt;
	 rd_word_cnt  <= rd_word_cnt_nxt;
	 rd_char      <= rd_char_nxt;
	 fail_flg     <= clear_fail_flg ? 1'b 0 : fail_flg_nxt;
	 p_rd_data_exp <= p_rd_data_exp_nxt;

	 slv_wr_done <= slv_wr_done_nxt;
	 slv_rd_done <= slv_rd_done_nxt;

      end // else: !if(reset)

   end // always @ (posedge clk)

   //-----------------------------------------------------------------
   // synthesis translate_off
   // simulation debug mesg

   localparam DBG_STUCK_TIMEOUT_VAL = 800;
   reg [9:0]  dbg_stuck_timer_cnt;

   always @(posedge clk) begin

      if (reset) begin
	 dbg_stuck_timer_cnt <= DBG_STUCK_TIMEOUT_VAL;
      end
      else begin
	  if (p_wr_done | p_rd_done)
	    dbg_stuck_timer_cnt <= DBG_STUCK_TIMEOUT_VAL;
	  else
	     dbg_stuck_timer_cnt <= (| dbg_stuck_timer_cnt) ?
				    (dbg_stuck_timer_cnt - 1) : 'h 0;

      end // else: !if(reset)

   end // always @ (posedge clk)

   always @(posedge clk) begin

      if ( ~fail_flg & fail_flg_nxt) begin
	 $display ($time,"ERROR: fail_flg set to 1. p_rd_data_exp:%h. p_rd_data: %h: %m",
		   p_rd_data_exp, p_rd_data);

	 //$vcdplusflush;
	 $finish;

      end

      if (~ (|dbg_stuck_timer_cnt)) begin
	 $display ($time,"ERROR: dbg_stuck_timer_cnt is 0. Logic is stuck. %m");

	 //$vcdplusflush;
	 $finish;

      end

   end // always @ (posedge clk)

   //synthesis translate_on
   //---------------------------------------------------------------------

endmodule // ddr2_blk_rdwr_test



