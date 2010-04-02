
module dram_queue_blk_rdwr
  #(
    //BRAM pkt cache intfc param. BRAM datawidth is 18-byte (144-bit)
    parameter PKT_DATA_WIDTH       = 144,
    parameter TRANSF_BLOCK_BRAM_SZ = 2034, //in unit of byte
    parameter NUM_OUTPUT_QUEUES    = 8
    )
  (
   //------------------------------------------------------------
   output dram_sm_idle,

   //-------------------------------------------------------------
   // intfc to tail cache arbiter and tail cache
   input tca_dram_wr_req,
   input [2:0] tca_dram_queue_num,
   input tc_dram_data_ctrl_vld,
   input [PKT_DATA_WIDTH-1:0] tc_dram_data_ctrl,

   output reg dram_tca_wr_ack,
   output dram_tc_wr_full,
   output dram_tca_wr_done,

   //---------------------------------------------------------------
   // intfc to head cache arbiter and head cache
   input hca_dram_rd_req,
   input [2:0] hca_dram_queue_num,

   output reg dram_hca_rd_ack,
   output [PKT_DATA_WIDTH-1:0] dram_data_ctrl,
   output dram_data_ctrl_vld,
   output dram_hca_rd_done,

   //----------------------------------------------------------------
   // status signals to head cache arbiter and tail cache arbiter
   output [NUM_OUTPUT_QUEUES-1:0] dram_q_not_empty,
   output [NUM_OUTPUT_QUEUES-1:0] dram_q_space_one_blk,

   //-------------------------------------
   //misc:
   input clk_core_125,
   input reset_core,

   //---------------------------------------
   //intfc to ddr2 mem_intfc
   //input:
   input init_val_180,           // Initialization done
   input cmd_ack_180,            // Command acknowledged
   input auto_ref_req_180,       // Auto-refresh request
   input ar_done_180,            // Auto-refresh done
   input [63:0] rd_data_90,      //[63:0], data returned from DRAM
   input rd_data_valid_90,       // Data is valid

   //output:
   output [3:0] cmd_180,         //[3:0], Command

   output [1:0] bank_addr_0,     //[1:0], Bank address
   output [21:0] addr_0,         //[21:0], Rd/Wr address
   output burst_done_0,          // Burst complete

   output [14:0] config1,        //[14:0], Config register 1
   output [12:0] config2,        //[12:0], Config register 2

   output [63:0] wr_data_90,     //[63:0], Data written to mem
   output [7:0] wr_data_mask_90, //[7:0], Write data mask. value 0 allows overwriting

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

   // DRAM capacity = 64MB
   localparam DRAM_CAPACITY = 64 * 1024 * 1024; //in byte unit

   // DRAM transfer block size is rounded up to 2's exponent
   localparam TRANSF_BLOCK_DRAM_SZ = 2**log2(TRANSF_BLOCK_BRAM_SZ);

   // width of memory pointer to blocks in DRAM
   localparam BLK_PTR_WIDTH = log2( DRAM_CAPACITY / TRANSF_BLOCK_DRAM_SZ ); //in unit of blocks

   // width of counter for the number of blocks in a queue
   localparam OCCUP_BLK_CNT_WIDTH = BLK_PTR_WIDTH + 1;

   // DDR2 interface is configured to do rd/wr burst of burst length 4.
   // Each burst transfers 4-byte * 4 / burst = 16-byte / burst
   localparam PKT_MEM_PTR_WIDTH = log2(DRAM_CAPACITY / 16);

   //--------------------------------------------------------
   // queue low and high addresses: in unit of blocks
   wire [BLK_PTR_WIDTH-1:0] q_low_addr[NUM_OUTPUT_QUEUES-1:0];
   wire [BLK_PTR_WIDTH-1:0] q_high_addr[NUM_OUTPUT_QUEUES-1:0];

   assign q_low_addr[0]  = 15'h    0;
   assign q_high_addr[0] = 15'h 0fff;

   assign q_low_addr[1]  = 15'h 1000;
   assign q_high_addr[1] = 15'h 1fff;

   assign q_low_addr[2]  = 15'h 2000;
   assign q_high_addr[2] = 15'h 2fff;

   assign q_low_addr[3]  = 15'h 3000;
   assign q_high_addr[3] = 15'h 3fff;

   assign q_low_addr[4]  = 15'h 4000;
   assign q_high_addr[4] = 15'h 4fff;

   assign q_low_addr[5]  = 15'h 5000;
   assign q_high_addr[5] = 15'h 5fff;

   assign q_low_addr[6]  = 15'h 6000;
   assign q_high_addr[6] = 15'h 6fff;

   assign q_low_addr[7]  = 15'h 7000;
   assign q_high_addr[7] = 15'h 7fff;

   //-----------------------------------------------------
   // queue read/write pointers
   reg [BLK_PTR_WIDTH:0] q_rd_ptr[NUM_OUTPUT_QUEUES-1:0];
   reg [BLK_PTR_WIDTH:0] q_rd_ptr_nxt[NUM_OUTPUT_QUEUES-1:0];

   reg [BLK_PTR_WIDTH:0] q_wr_ptr[NUM_OUTPUT_QUEUES-1:0];
   reg [BLK_PTR_WIDTH:0] q_wr_ptr_nxt[NUM_OUTPUT_QUEUES-1:0];

   //in unit of blocks
   reg [OCCUP_BLK_CNT_WIDTH-1:0] dram_que_occup_blk_cnt[NUM_OUTPUT_QUEUES-1:0];
   reg [OCCUP_BLK_CNT_WIDTH-1:0] dram_que_occup_blk_cnt_nxt[NUM_OUTPUT_QUEUES-1:0];

   generate
      genvar i;

      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: dram_q_not_empty_space_one_blk
	 assign dram_q_not_empty[i] = | dram_que_occup_blk_cnt[i];

	 assign dram_q_space_one_blk[i] =
		dram_que_occup_blk_cnt[i] <= ({1'b 0, q_high_addr[i]}-{1'b 0, q_low_addr[i]});
      end

   endgenerate

   //-------------------------------------------------
   // reg, wire from the ddr2_blk_rdwr
   wire	p_wr_full;
   wire p_rd_rdy;
   wire p_wr_done;
   wire p_rd_done;
   wire [PKT_DATA_WIDTH-1 : 0] p_rd_data;
   wire 		       ddr2_sm_idle;

   //-----------------------------------------------
   // reg, wire from the state machine
   localparam PRE_INIT_STATE = 2'd 0,
	      IDLE_STATE     = 2'd 1,
	      WR_STATE       = 2'd 2,
	      RD_STATE       = 2'd 3;
   reg [1:0] state, state_nxt;

   reg 	     prev_op, prev_op_nxt;
   reg 	     tca_dram_wr_req_d, hca_dram_rd_req_d;
   reg p_wr_data_vld, p_wr_req;
   reg p_rd_en, p_rd_req;
   reg [PKT_DATA_WIDTH-1 : 0] p_wr_data;
   reg [PKT_MEM_PTR_WIDTH-1:0] p_wr_ptr, p_rd_ptr;

   integer j;

   assign  dram_sm_idle = (state == IDLE_STATE);

   assign  dram_data_ctrl_vld = p_rd_rdy;

//   always @(*) begin
   always @(state,
	    q_wr_ptr[0], q_rd_ptr[0], dram_que_occup_blk_cnt[0],
	    q_wr_ptr[1], q_rd_ptr[1], dram_que_occup_blk_cnt[1],
	    q_wr_ptr[2], q_rd_ptr[2], dram_que_occup_blk_cnt[2],
	    q_wr_ptr[3], q_rd_ptr[3], dram_que_occup_blk_cnt[3],
	    q_wr_ptr[4], q_rd_ptr[4], dram_que_occup_blk_cnt[4],
	    q_wr_ptr[5], q_rd_ptr[5], dram_que_occup_blk_cnt[5],
	    q_wr_ptr[6], q_rd_ptr[6], dram_que_occup_blk_cnt[6],
	    q_wr_ptr[7], q_rd_ptr[7], dram_que_occup_blk_cnt[7],
	    ddr2_sm_idle, tca_dram_wr_req, tca_dram_queue_num,
	    q_high_addr[0], q_high_addr[1], q_high_addr[2], q_high_addr[3],
	    q_high_addr[4], q_high_addr[5], q_high_addr[6], q_high_addr[7],
	    q_low_addr[0], q_low_addr[1], q_low_addr[2], q_low_addr[3],
	    q_low_addr[4], q_low_addr[5], q_low_addr[6], q_low_addr[7],
	    hca_dram_rd_req, hca_dram_queue_num,
	    dram_tca_wr_done, dram_hca_rd_done
	    ) begin

      state_nxt = state;

      for (j=0; j<8; j=j+1) begin
	 q_wr_ptr_nxt[j] = q_wr_ptr[j];
	 q_rd_ptr_nxt[j] = q_rd_ptr[j];
	 dram_que_occup_blk_cnt_nxt[j] = dram_que_occup_blk_cnt[j];
      end

      prev_op_nxt = prev_op;

      p_wr_ptr = {PKT_MEM_PTR_WIDTH {1'b 0}};
      p_rd_ptr = {PKT_MEM_PTR_WIDTH {1'b 0}};

      dram_hca_rd_ack = 0;
      dram_tca_wr_ack = 0;

      case (state)
	PRE_INIT_STATE:
	  if (ddr2_sm_idle) begin
	     //dram has got out of initilization
	     state_nxt = IDLE_STATE;
	  end

	IDLE_STATE: begin

	   case ({tca_dram_wr_req, hca_dram_rd_req})
	     2'b 01: begin

	        dram_hca_rd_ack = 1;
		prev_op_nxt = 1;

	     end

	     2'b 10: begin

	        dram_tca_wr_ack = 1;
		prev_op_nxt = 0;

	     end

	     2'b 11: begin

		if (prev_op)
		  dram_tca_wr_ack = 1;
		else
		  dram_hca_rd_ack = 1;

		prev_op_nxt = ~prev_op;

	     end

	   endcase // case({tca_dram_wr_req, hca_dram_rd_req})

	  if (dram_tca_wr_ack) begin

	     p_wr_ptr = {q_wr_ptr[tca_dram_queue_num], {(PKT_MEM_PTR_WIDTH - BLK_PTR_WIDTH) {1'b 0}}};
	     q_wr_ptr_nxt[tca_dram_queue_num] =
						(q_wr_ptr[tca_dram_queue_num] == q_high_addr[tca_dram_queue_num]) ?
						q_low_addr[tca_dram_queue_num] : (q_wr_ptr[tca_dram_queue_num] + 1);

	     dram_que_occup_blk_cnt_nxt[tca_dram_queue_num] = dram_que_occup_blk_cnt[tca_dram_queue_num] + 1;

	     state_nxt = WR_STATE;

	  end
	  else if (dram_hca_rd_ack) begin

	     p_rd_ptr = {q_rd_ptr[hca_dram_queue_num], {(PKT_MEM_PTR_WIDTH - BLK_PTR_WIDTH) {1'b 0}}};
	     q_rd_ptr_nxt[hca_dram_queue_num] = (q_rd_ptr[hca_dram_queue_num] == q_high_addr[hca_dram_queue_num]) ?
						 q_low_addr[hca_dram_queue_num] : (q_rd_ptr[hca_dram_queue_num] + 1);

	     dram_que_occup_blk_cnt_nxt[hca_dram_queue_num] = dram_que_occup_blk_cnt[hca_dram_queue_num] - 1;

	     state_nxt = RD_STATE;

	  end

	end // case: IDLE_STATE

	WR_STATE:
	  if (dram_tca_wr_done)
	    state_nxt = IDLE_STATE;

	RD_STATE:
	  if (dram_hca_rd_done)
	    state_nxt = IDLE_STATE;

      endcase // case(state)

   end // always @ (*)


   always @(posedge clk_core_125) begin
      if (reset_core) begin
	 state <= PRE_INIT_STATE;
	 prev_op <= 1'b 0;

/* -----\/----- EXCLUDED -----\/-----
	 for (j=0; j<8; j=j+1) begin
	    q_rd_ptr[j]               <= q_low_addr[j];
	    q_wr_ptr[j]               <= q_low_addr[j];
	    dram_que_occup_blk_cnt[j] <= 0;
	 end
 -----/\----- EXCLUDED -----/\----- */
	 q_rd_ptr[0]               <= q_low_addr[0];
	 q_wr_ptr[0]               <= q_low_addr[0];
	 dram_que_occup_blk_cnt[0] <= 0;

	 q_rd_ptr[1]               <= q_low_addr[1];
	 q_wr_ptr[1]               <= q_low_addr[1];
	 dram_que_occup_blk_cnt[1] <= 0;

	 q_rd_ptr[2]               <= q_low_addr[2];
	 q_wr_ptr[2]               <= q_low_addr[2];
	 dram_que_occup_blk_cnt[2] <= 0;

	 q_rd_ptr[3]               <= q_low_addr[3];
	 q_wr_ptr[3]               <= q_low_addr[3];
	 dram_que_occup_blk_cnt[3] <= 0;

	 q_rd_ptr[4]               <= q_low_addr[4];
	 q_wr_ptr[4]               <= q_low_addr[4];
	 dram_que_occup_blk_cnt[4] <= 0;

	 q_rd_ptr[5]               <= q_low_addr[5];
	 q_wr_ptr[5]               <= q_low_addr[5];
	 dram_que_occup_blk_cnt[5] <= 0;

	 q_rd_ptr[6]               <= q_low_addr[6];
	 q_wr_ptr[6]               <= q_low_addr[6];
	 dram_que_occup_blk_cnt[6] <= 0;

	 q_rd_ptr[7]               <= q_low_addr[7];
	 q_wr_ptr[7]               <= q_low_addr[7];
	 dram_que_occup_blk_cnt[7] <= 0;

      end // if (reset_core)

      else begin
	 state <= state_nxt;
	 prev_op <= prev_op_nxt;

/* -----\/----- EXCLUDED -----\/-----
	 for (j=0; j<8; j=j+1) begin
	    q_rd_ptr[j]               <= q_rd_ptr_nxt[j];
	    q_wr_ptr[j]               <= q_wr_ptr_nxt[j];
	    dram_que_occup_blk_cnt[j] <= dram_que_occup_blk_cnt_nxt[j];
	 end
 -----/\----- EXCLUDED -----/\----- */
	 q_rd_ptr[0]               <= q_rd_ptr_nxt[0];
	 q_wr_ptr[0]               <= q_wr_ptr_nxt[0];
	 dram_que_occup_blk_cnt[0] <= dram_que_occup_blk_cnt_nxt[0];

	 q_rd_ptr[1]               <= q_rd_ptr_nxt[1];
	 q_wr_ptr[1]               <= q_wr_ptr_nxt[1];
	 dram_que_occup_blk_cnt[1] <= dram_que_occup_blk_cnt_nxt[1];

	 q_rd_ptr[2]               <= q_rd_ptr_nxt[2];
	 q_wr_ptr[2]               <= q_wr_ptr_nxt[2];
	 dram_que_occup_blk_cnt[2] <= dram_que_occup_blk_cnt_nxt[2];

	 q_rd_ptr[3]               <= q_rd_ptr_nxt[3];
	 q_wr_ptr[3]               <= q_wr_ptr_nxt[3];
	 dram_que_occup_blk_cnt[3] <= dram_que_occup_blk_cnt_nxt[3];

	 q_rd_ptr[4]               <= q_rd_ptr_nxt[4];
	 q_wr_ptr[4]               <= q_wr_ptr_nxt[4];
	 dram_que_occup_blk_cnt[4] <= dram_que_occup_blk_cnt_nxt[4];

	 q_rd_ptr[5]               <= q_rd_ptr_nxt[5];
	 q_wr_ptr[5]               <= q_wr_ptr_nxt[5];
	 dram_que_occup_blk_cnt[5] <= dram_que_occup_blk_cnt_nxt[5];

	 q_rd_ptr[6]               <= q_rd_ptr_nxt[6];
	 q_wr_ptr[6]               <= q_wr_ptr_nxt[6];
	 dram_que_occup_blk_cnt[6] <= dram_que_occup_blk_cnt_nxt[6];

	 q_rd_ptr[7]               <= q_rd_ptr_nxt[7];
	 q_wr_ptr[7]               <= q_wr_ptr_nxt[7];
	 dram_que_occup_blk_cnt[7] <= dram_que_occup_blk_cnt_nxt[7];

      end // else: !if(reset_core)

   end // always @ (posedge clk_core_125)


   //------------------------------------------------------
   // Instantiations

   ddr2_blk_rdwr
            #(
              //BRAM pkt cache intfc param
              .PKT_MEM_PTR_WIDTH    (PKT_MEM_PTR_WIDTH), //in unit of 16-byte
              .PKT_DATA_WIDTH       (PKT_DATA_WIDTH),
              .TRANSF_BLOCK_BRAM_SZ (TRANSF_BLOCK_BRAM_SZ) //in unit of byte
              ) ddr2_blk_rdwr_u
              (
               //---------------------------------------
               //intfc to mem_intfc
               //input:
               .init_val_180     ( init_val_180 ),            // Initialization done
               .cmd_ack_180      ( cmd_ack_180 ),             // Command acknowledged
               .auto_ref_req_180 ( auto_ref_req_180 ),        // Auto-refresh request
               .ar_done_180      ( ar_done_180 ),             // Auto-refresh done
               .rd_data_90       ( rd_data_90 ),       //[63:0], Data returned from mem
               .rd_data_valid_90 ( rd_data_valid_90 ),       // Data is valid

               //output:
               .cmd_180          ( cmd_180 ),          //[3:0] Command

               .bank_addr_0      ( bank_addr_0 ), //[1:0], Bank address
               .addr_0           ( addr_0 ),        //[21:0] Rd/Wr address
               .burst_done_d2_0  ( burst_done_0 ),         // Burst complete

               .config1          ( config1 ),     //[14:0] Config register 1
               .config2          ( config2 ),     //[12:0] Config register 2

               .wr_data_90       ( wr_data_90 ),     //[63:0] Data written to mem
               .wr_data_mask_90  ( wr_data_mask_90 ),  //[7:0] Write data mask

               //-------------------------------------
               //misc:
               //input:
	       .reset_0          ( reset_0 ),
               .clk_0            ( clk_0 ),
               .clk_90           ( clk_90 ),

	       //-------------------------------------
	       .ddr2_sm_idle     ( ddr2_sm_idle ),

               //---------------------------------------
               // intfc to pkt data wr
               //input:
               .p_wr_req         ( tca_dram_wr_req ),
               .p_wr_ptr         ( p_wr_ptr ), //[PKT_MEM_PTR_WIDTH-1 : 0] in unit of 16-byte
               .p_wr_data_vld    ( tc_dram_data_ctrl_vld ),
               .p_wr_data        ( tc_dram_data_ctrl ), //[PKT_DATA_WIDTH-1 : 0]

               //output:
               .p_wr_full        ( dram_tc_wr_full ),
	       .p_wr_done        ( dram_tca_wr_done ),

               //---------------------------------------
               // intfc to pkt data rd
               //input:
               .p_rd_req         ( hca_dram_rd_req ),
               .p_rd_ptr         ( p_rd_ptr ),//[PKT_MEM_PTR_WIDTH-1 : 0], in unit of 16-byte
               .p_rd_en          ( p_rd_rdy ),

               //output:
               .p_rd_rdy         ( p_rd_rdy ),
               .p_rd_data        ( dram_data_ctrl ), //[PKT_DATA_WIDTH-1 : 0]
	       .p_rd_done        ( dram_hca_rd_done ),

               //misc:
               //input:
	       .clk_core_125     ( clk_core_125 ),
               .reset_core       ( reset_core )
	       );

endmodule // dram_queue_blk_rdwr
