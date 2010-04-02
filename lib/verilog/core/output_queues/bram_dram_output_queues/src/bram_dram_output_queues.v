
module bram_dram_output_queues
  #(
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH=DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2,
    parameter OP_LUT_STAGE_NUM = 4,
    parameter NUM_OUTPUT_QUEUES = 8,
    parameter STAGE_NUM = 6
    )

  (

   // --- Interface to the subsequent module
   output [DATA_WIDTH-1:0]        out_data_0,
   output [CTRL_WIDTH-1:0]        out_ctrl_0,
   output                         out_wr_0,
   input                          out_rdy_0,

   output [DATA_WIDTH-1:0]        out_data_1,
   output [CTRL_WIDTH-1:0]        out_ctrl_1,
   output                         out_wr_1,
   input                          out_rdy_1,

   output [DATA_WIDTH-1:0]        out_data_2,
   output [CTRL_WIDTH-1:0]        out_ctrl_2,
   output                         out_wr_2,
   input                          out_rdy_2,

   output [DATA_WIDTH-1:0]        out_data_3,
   output [CTRL_WIDTH-1:0]        out_ctrl_3,
   output                         out_wr_3,
   input                          out_rdy_3,

   output [DATA_WIDTH-1:0]        out_data_4,
   output [CTRL_WIDTH-1:0]        out_ctrl_4,
   output                         out_wr_4,
   input                          out_rdy_4,

   output [DATA_WIDTH-1:0]        out_data_5,
   output [CTRL_WIDTH-1:0]        out_ctrl_5,
   output                         out_wr_5,
   input                          out_rdy_5,

   output [DATA_WIDTH-1:0]        out_data_6,
   output [CTRL_WIDTH-1:0]        out_ctrl_6,
   output                         out_wr_6,
   input                          out_rdy_6,

   output [DATA_WIDTH-1:0]        out_data_7,
   output [CTRL_WIDTH-1:0]        out_ctrl_7,
   output                         out_wr_7,
   input                          out_rdy_7,

   // --- Interface to the preceding module
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

   // --- Misc
   input clk_core,
   input reset_core,

   //---------------------------------------
   //intfc to ddr2 mem_intfc
   input init_val_180,            // Initialization done
   input cmd_ack_180,             // Command acknowledged
   input auto_ref_req_180,        // Auto-refresh request
   input ar_done_180,             // Auto-refresh done
   input [63:0] rd_data_90,       //[63:0], Data returned from mem
   input rd_data_valid_90,       // Data is valid

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

   //BRAM pkt cache intfc param. BRAM datawidth is 9-byte or multiple.
   parameter PKT_MEM_PTR_WIDTH    = 22; //in unit of 16-byte
   parameter  TRANSF_BLOCK_DATA_SZ = 2034; //in unit of byte

   //DRAM pkt memory intfc param. DRAM datawidth is 8-byte or multiple.
   parameter  TRANSF_BLOCK_SZ      = 2048; //in unit of byte
   parameter  BLOCK_BYTE_CNT_WIDTH = 12;

   //width of counter for the number of blocks in per queue
   parameter  OCCUP_BLK_CNT_WIDTH = 16; //in unit of blocks

   //---------------------------------------------------------
   // reg, wire from tail cache
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_dram_data_ctrl;
   wire 				tc_dram_wr;

   wire [9:0] tc_q_occup_word_cnt_0, tc_q_occup_word_cnt_1;
   wire [9:0] tc_q_occup_word_cnt_2, tc_q_occup_word_cnt_3;
   wire [9:0] tc_q_occup_word_cnt_4, tc_q_occup_word_cnt_5;
   wire [9:0] tc_q_occup_word_cnt_6, tc_q_occup_word_cnt_7;

   wire [NUM_OUTPUT_QUEUES-1:0] tc_hc_wr, tc_q_occup_one_blk;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_0, tc_hc_data_ctrl_1;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_2, tc_hc_data_ctrl_3;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_4, tc_hc_data_ctrl_5;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_6, tc_hc_data_ctrl_7;

   //---------------------------------------------------------
   // reg, wire from tail cache arbiter
   wire [2:0] tca_queue_num;
   wire       tca_queue_rd;
   wire [NUM_OUTPUT_QUEUES-1:0] hc_tc_rdy;

   //---------------------------------------------------------
   // reg, wire from head cache
   wire [10:0] hc_q_occup_word_cnt_0, hc_q_occup_word_cnt_1;
   wire [10:0] hc_q_occup_word_cnt_2, hc_q_occup_word_cnt_3;
   wire [10:0] hc_q_occup_word_cnt_4, hc_q_occup_word_cnt_5;
   wire [10:0] hc_q_occup_word_cnt_6, hc_q_occup_word_cnt_7;
   wire [NUM_OUTPUT_QUEUES-1:0] hc_q_space_one_blk, hc_q_rdy;

   //---------------------------------------------------------
   // reg, wire from head cache arbiter
   wire [2:0] hca_queue_num;
   wire       hca_queue_vld;

   //---------------------------------------------------------
   // reg, wire from dram_ctrl
   wire [1:0] dram_phase;
   wire       dram_tc_wr_rdy;
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] dram_data_ctrl;
   wire 				dram_wr;
   wire [NUM_OUTPUT_QUEUES-1:0] 	dram_q_not_empty, dram_q_space_one_blk;


   //-------------------------------------------------------
   // Instantiations

   tail_cache tail_cache_u
     (
      // intfc to preceding module
      //input:
      .in_data ( in_data ),//[DATA_WIDTH-1:0]
      .in_ctrl ( in_ctrl ),//[CTRL_WIDTH-1:0]
      .in_wr   ( in_wr ),

      //output:
      .tc_rdy  ( in_rdy ),

      // intfc to tail cache arbiter
      //input:
      .tca_queue_num ( tca_queue_num ),//[2:0]
      .tca_queue_rd  ( tca_queue_rd ),
      .hc_tc_rdy     ( hc_tc_rdy ),//[NUM_OUTPUT_QUEUES-1:0]

      // intfc to DRAM ctrl
      //output:
      .tc_dram_data_ctrl ( tc_dram_data_ctrl ),//[2*(DATA_WIDTH+CTRL_WIDTH)-1:0]
      .tc_dram_wr        ( tc_dram_wr ),

      //input:
      .dram_tc_wr_rdy    ( dram_tc_wr_rdy ),

      // status signals to tail cache arbiter
      //output:
      .tc_q_occup_word_cnt_0 ( tc_q_occup_word_cnt_0 ), //[10:0], unit is 18-byte. count up to 1024.
      .tc_q_occup_word_cnt_1 ( tc_q_occup_word_cnt_1 ),
      .tc_q_occup_word_cnt_2 ( tc_q_occup_word_cnt_2 ),
      .tc_q_occup_word_cnt_3 ( tc_q_occup_word_cnt_3 ),
      .tc_q_occup_word_cnt_4 ( tc_q_occup_word_cnt_4 ),
      .tc_q_occup_word_cnt_5 ( tc_q_occup_word_cnt_5 ),
      .tc_q_occup_word_cnt_6 ( tc_q_occup_word_cnt_6 ),
      .tc_q_occup_word_cnt_7 ( tc_q_occup_word_cnt_7 ),
      .tc_q_occup_one_blk    ( tc_q_occup_one_blk ),//[NUM_OUTPUT_QUEUES-1:0]

      // intfc to head cache (cut-thru path)
      //output:
      .tc_hc_wr          ( tc_hc_wr ),//[NUM_OUTPUT_QUEUES-1:0]
      .tc_hc_data_ctrl_0 ( tc_hc_data_ctrl_0 ),//[2*(DATA_WIDTH+CTRL_WIDTH)-1:0]
      .tc_hc_data_ctrl_1 ( tc_hc_data_ctrl_1 ),
      .tc_hc_data_ctrl_2 ( tc_hc_data_ctrl_2 ),
      .tc_hc_data_ctrl_3 ( tc_hc_data_ctrl_3 ),
      .tc_hc_data_ctrl_4 ( tc_hc_data_ctrl_4 ),
      .tc_hc_data_ctrl_5 ( tc_hc_data_ctrl_5 ),
      .tc_hc_data_ctrl_6 ( tc_hc_data_ctrl_6 ),
      .tc_hc_data_ctrl_7 ( tc_hc_data_ctrl_7 ),

      // --- Misc
      //input:
      .clk   ( clk_core ),
      .reset ( reset_core )
      );

   tail_cache_arb tail_cache_arb_u
     (
      // --- intfc to tail cache
      //input:
      .tc_q_occup_word_cnt_0 ( tc_q_occup_word_cnt_0 ), //[10:0] unit is 18-byte. count up to 1024.
      .tc_q_occup_word_cnt_1 ( tc_q_occup_word_cnt_1 ),
      .tc_q_occup_word_cnt_2 ( tc_q_occup_word_cnt_2 ),
      .tc_q_occup_word_cnt_3 ( tc_q_occup_word_cnt_3 ),
      .tc_q_occup_word_cnt_4 ( tc_q_occup_word_cnt_4 ),
      .tc_q_occup_word_cnt_5 ( tc_q_occup_word_cnt_5 ),
      .tc_q_occup_word_cnt_6 ( tc_q_occup_word_cnt_6 ),
      .tc_q_occup_word_cnt_7 ( tc_q_occup_word_cnt_7 ),
      .tc_q_occup_one_blk    ( tc_q_occup_one_blk ),

      //output:
      .tca_queue_num ( tca_queue_num ), //[2:0]
      .tca_queue_rd  ( tca_queue_rd ),
      .hc_tc_rdy     ( hc_tc_rdy ), //[NUM_OUTPUT_QUEUES-1:0]

      // -- intfc to dram
      //input:
      .dram_q_not_empty     ( dram_q_not_empty ),//[NUM_OUTPUT_QUEUES-1:0]
      .dram_q_space_one_blk ( dram_q_space_one_blk ), //[NUM_OUTPUT_QUEUES-1:0]

      // -- intfc to head cache
      //input:
      .hc_q_rdy ( hc_q_rdy ),//[NUM_OUTPUT_QUEUES-1:0]

      // -- phase info
      //input:
      .dram_phase ( dram_phase ), //[1:0]

      // --- misc
      //input:
      .clk   ( clk_core ),
      .reset ( reset_core )
      );


   dram_queue_blk_rdwr dram_queue_blk_rdwr_u
     (
      //output:
      .dram_sm_idle ( dram_sm_idle ),

      // intfc to tail cache arbiter and tail cache
      //input:
      .tca_dram_wr_req    ( tca_dram_wr_req ),
      .tca_dram_queue_num     ( tca_queue_num ), // [2:0]
      .tc_dram_data_ctrl ( tc_dram_data_ctrl ), // [PKT_DATA_WIDTH-1:0]
      .tc_dram_data_ctrl_vld ( tc_dram_wr ),

      //output:
      .dram_tc_wr_full   ( dram_tc_wr_full ),
      .dram_tca_wr_done ( dram_tca_wr_done ),

      // intfc to head cache arbiter and head cache
      //input:
      .hca_dram_rd_req  ( hca_queue_vld ),
      .hca_dram_queue_num ( hca_queue_num ), // [2:0]

      //output:
      .dram_data_ctrl ( dram_data_ctrl ), //[PKT_DATA_WIDTH-1:0]
      .dram_data_ctrl_vld   ( dram_wr ),
      .dram_hca_rd_done ( dram_hca_rd_done ),

      // status signals to head cache arbiter and tail cache arbiter
      //output:
      .dram_q_not_empty     ( dram_q_not_empty ),
      .dram_q_space_one_blk ( dram_q_space_one_blk ),

      //misc:
      //input:
      .clk_core_125 ( clk_core ),
      .reset_core   ( reset_core ),

      //intfc to ddr2 mem_intfc
      //input:
      .init_val_180 ( init_val_180 ),            // Initialization done
      .cmd_ack_180  ( cmd_ack_180 ),             // Command acknowledged
      .auto_ref_req_180 ( auto_ref_req_180 ),        // Auto-refresh request
      .ar_done_180  ( ar_done_180 ),             // Auto-refresh done
      .rd_data_90   ( rd_data_90 ),       //[63:0], Data returned from mem
      .rd_data_valid_90 ( rd_data_valid_90 ),       // Data is valid

      //output:
      .cmd_180      ( cmd_180 ),          //[3:0] Command
      .bank_addr_0  ( bank_addr_0 ), //[1:0], Bank address
      .addr_0       ( addr_0 ),        //[21:0] Rd/Wr address
      .burst_done_0 ( burst_done_0 ),         // Burst complete
      .config1      ( config1 ),     //[14:0] Config register 1
      .config2      ( config2 ),     //[12:0] Config register 2
      .wr_data_90   ( wr_data_90 ),     //[63:0] Data written to mem
      .wr_data_mask_90 ( wr_data_mask_90 ),  //[7:0] Write data mask

      //misc:
      //input:
      .reset_0 ( reset_0 ),
      .clk_0   ( clk_0 ),
      .clk_90  ( clk_90 )
      );

   head_cache_arb head_cache_arb_u
       (
	// --- intfc to head cache
	//input:
	.hc_q_occup_word_cnt_0 ( hc_q_occup_word_cnt_0 ), //[10:0] unit is 18-byte. count up to 1024.
	.hc_q_occup_word_cnt_1 ( hc_q_occup_word_cnt_1 ),
	.hc_q_occup_word_cnt_2 ( hc_q_occup_word_cnt_2 ),
	.hc_q_occup_word_cnt_3 ( hc_q_occup_word_cnt_3 ),
	.hc_q_occup_word_cnt_4 ( hc_q_occup_word_cnt_4 ),
	.hc_q_occup_word_cnt_5 ( hc_q_occup_word_cnt_5 ),
	.hc_q_occup_word_cnt_6 ( hc_q_occup_word_cnt_6 ),
	.hc_q_occup_word_cnt_7 ( hc_q_occup_word_cnt_7 ),
	.hc_q_space_one_blk    ( hc_q_space_one_blk ),//[NUM_OUTPUT_QUEUES-1:0]

	//output:
	.hca_queue_num ( hca_queue_num ),//[2:0]
	.hca_queue_vld ( hca_queue_vld ),

	// ---- intfc to DRAM
	//input:
	.dram_q_not_empty ( dram_q_not_empty ),//[NUM_OUTPUT_QUEUES-1:0]

	// --- phase info
	//input:
	.dram_phase ( dram_phase ),//[1:0]

	// ---- misc
	//input:
	.clk   ( clk_core ),
	.reset ( reset_core )
	);

   head_cache head_cache_u
     (
      // intfc to head cache arbiter
      //input:
      .hca_queue_num ( hca_queue_num ),//[2:0]
      .hca_queue_wr  ( hca_queue_vld ),

      // intfc to DRAM ctrler
      //input:
      .dram_data_ctrl ( dram_data_ctrl ),//[2*(DATA_WIDTH+CTRL_WIDTH)-1:0]
      .dram_wr        ( dram_wr ),

      // status signals to head cache arbiter
      //output:
      .hc_q_occup_word_cnt_0 ( hc_q_occup_word_cnt_0 ), //[10:0] unit is 18-byte. count up to 1024.
      .hc_q_occup_word_cnt_1 ( hc_q_occup_word_cnt_1 ),
      .hc_q_occup_word_cnt_2 ( hc_q_occup_word_cnt_2 ),
      .hc_q_occup_word_cnt_3 ( hc_q_occup_word_cnt_3 ),
      .hc_q_occup_word_cnt_4 ( hc_q_occup_word_cnt_4 ),
      .hc_q_occup_word_cnt_5 ( hc_q_occup_word_cnt_5 ),
      .hc_q_occup_word_cnt_6 ( hc_q_occup_word_cnt_6 ),
      .hc_q_occup_word_cnt_7 ( hc_q_occup_word_cnt_7 ),
      .hc_q_space_one_blk    ( hc_q_space_one_blk ),//[NUM_OUTPUT_QUEUES-1:0]

      // intfc to tail cache (cut-thru path)
      //output:
      .hc_q_rdy ( hc_q_rdy ), //[NUM_OUTPUT_QUEUES-1:0]

      //input:
      .tc_hc_wr          ( tc_hc_wr ), //[NUM_OUTPUT_QUEUES-1:0]
      .tc_hc_data_ctrl_0 ( tc_hc_data_ctrl_0 ), //[2*(DATA_WIDTH+CTRL_WIDTH)-1:0]
      .tc_hc_data_ctrl_1 ( tc_hc_data_ctrl_1 ),
      .tc_hc_data_ctrl_2 ( tc_hc_data_ctrl_2 ),
      .tc_hc_data_ctrl_3 ( tc_hc_data_ctrl_3 ),
      .tc_hc_data_ctrl_4 ( tc_hc_data_ctrl_4 ),
      .tc_hc_data_ctrl_5 ( tc_hc_data_ctrl_5 ),
      .tc_hc_data_ctrl_6 ( tc_hc_data_ctrl_6 ),
      .tc_hc_data_ctrl_7 ( tc_hc_data_ctrl_7 ),

      // intfc to MAC TX fifo
      //output:
      .hc_data_0 ( out_data_0 ),//[DATA_WIDTH-1:0]
      .hc_ctrl_0 ( out_ctrl_0 ),//[CTRL_WIDTH-1:0]
      .hc_wr_0   ( out_wr_0 ),
      //input:
      .mac_tx_rdy_0 ( out_rdy_0 ),

      //output:
      .hc_data_1 ( out_data_1 ),
      .hc_ctrl_1 ( out_ctrl_1 ),
      .hc_wr_1   ( out_wr_1 ),
      //input:
      .mac_tx_rdy_1 ( out_rdy_1 ),

      //output:
      .hc_data_2 ( out_data_2 ),
      .hc_ctrl_2 ( out_ctrl_2 ),
      .hc_wr_2   ( out_wr_2 ),
      //input:
      .mac_tx_rdy_2 ( out_rdy_2 ),

      //output:
      .hc_data_3 ( out_data_3 ),
      .hc_ctrl_3 ( out_ctrl_3 ),
      .hc_wr_3   ( out_wr_3 ),
      //input:
      .mac_tx_rdy_3 ( out_rdy_3 ),

      //output:
      .hc_data_4 ( out_data_4 ),
      .hc_ctrl_4 ( out_ctrl_4 ),
      .hc_wr_4   ( out_wr_4 ),
      //input:
      .mac_tx_rdy_4 ( out_rdy_4 ),

      //output:
      .hc_data_5 ( out_data_5 ),
      .hc_ctrl_5 ( out_ctrl_5 ),
      .hc_wr_5   ( out_wr_5 ),
      //input:
      .mac_tx_rdy_5 ( out_rdy_5 ),

      //output:
      .hc_data_6 ( out_data_6 ),
      .hc_ctrl_6 ( out_ctrl_6 ),
      .hc_wr_6   ( out_wr_6 ),
      //input:
      .mac_tx_rdy_6 ( out_rdy_6 ),

      //output:
      .hc_data_7 ( out_data_7 ),
      .hc_ctrl_7 ( out_ctrl_7 ),
      .hc_wr_7   ( out_wr_7 ),
      //input:
      .mac_tx_rdy_7 ( out_rdy_7 ),

      // --- Misc
      //input:
      .clk   ( clk_core ),
      .reset ( reset_core )
      );

endmodule // bram_dram_output_queues


