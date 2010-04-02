///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: ddr2_blk_rdwr.v
// Project: NetFPGA
// Description:
//   This module provides one write interface and one read interface for
//   a block of data to transfer to/from the DDR2 DRAM.
//   When the output port "ddr2_sm_idle" is asserted, a user of this module may
//   request either write or read to DDR2 DRAM. If both read and write are
//   requested, they are served in round robin. If neither
//   write nor read is requested, this module remains idle.
//
// Note:
// Signal Naming           Clock Domain (launch on positive edge of that clock)
// <signal_0>              clk_0,  ddr2 clock with phase   0 degrees
// <signal_90>             clk_90, ddr2 clock with phase  90 degrees
// <signal_180>            ~clk_0, ddr2 clock with phase 180 degrees
//
//------------------------------------------------------------------------
// NetFPGA 2.x card Specifications Regarding Clock Frequencies:
//
//       1. ddr2 clocks (i.e. clk_0, clk_90) run at 200 MHz;
//       2. system clock (i.e. clk_core) runs at either 62.5 MHz or 125 MHz
//          depending on the configuration register "CPCI_CNET_CLK_SEL_REG"
//          of CPCI chip: 62.5 MHz if Value(CPCI_CNET_CLK_SEL_REG)=0,
//                        125  MHz if Value(CPCI_CNET_CLK_SEL_REG)=1.
//
// ----------------------------------------------------------------------
// Design Assumption:
//
//       This design requires the ddr2 burst access never stall at the ddr2 clock
//       domain logic. So it's required that the system clock domain logic
//       feed faster than the ddr2 burst write, and likewise read faster than
//       the ddr2 burst read bits.
//
//       So the following inequality must hold:
//       PKT_DATA_WIDTH * (system clock freq) > 64-bit * (ddr2 clock freq).
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
///////////////////////////////////////////////////////////////////////////////

module ddr2_blk_rdwr
  #(
    parameter PKT_MEM_PTR_WIDTH    = 22,  //in unit of 16-byte. for 64 MB DRAM

    //in unit of bit
    parameter PKT_DATA_WIDTH       = 144 //144-bit can work for 125 MHz
    //parameter PKT_DATA_WIDTH       = 288 //288-bit can work for 62.5 MHz and 125 MHz
    )
    (
     //---------------------------------------
     //intfc to mem_intfc
     //input:
     input init_val_180,           // Initialization done
     input cmd_ack_180,            // Command acknowledged
     input auto_ref_req_180,       // Auto-refresh request
     input ar_done_180,            // Auto-refresh done
     input [63:0] rd_data_90,      // Data returned from mem
     input rd_data_valid_90,       // Data is valid

     //output:
     output reg [3:0] cmd_180,     // Command

     output [1:0] bank_addr_0,     // Bank address
     output [21:0] addr_0,         // Rd/Wr address
     output reg burst_done_0,      // Burst complete

     output [14:0] config1,        // Config register 1
     output [12:0] config2,        // Config register 2

     output reg [63:0] wr_data_90, // Data written to mem
     output [7:0] wr_data_mask_90, // Write data mask

     //-------------------------------------
     //misc:
     input reset_0,                // reset sync to clk_0
     input clk_0,                  // ddr2 clk phase  0
     input clk_90,                 // ddr2 clk phase 90

     //--------------------------------------
     output ddr2_sm_idle,          // DDR2 block transfer state machine idle

     //---------------------------------------
     // intfc to pkt data wr
     //input:
     input p_wr_req,               // request for write transfer to DDR2
     input [PKT_MEM_PTR_WIDTH-1 : 0] p_wr_ptr, //in unit of 16-byte chunk

     input p_wr_data_vld,          // write data valid
     input [PKT_DATA_WIDTH-1 : 0] p_wr_data, // write data

     //output:
     output reg p_wr_ack,
     output p_wr_full,             // write datapath is full
     output reg p_wr_done,         // write transfer is done

     //---------------------------------------
     // intfc to pkt data rd
     //input:
     input p_rd_req,               // request for read transfer from DDR2
     input [PKT_MEM_PTR_WIDTH-1 : 0] p_rd_ptr, //in unit of 16-byte chunk
     input p_rd_en,

     //output:
     output reg p_rd_ack,
     output p_rd_rdy,              // data ready for read
     output [PKT_DATA_WIDTH-1 : 0] p_rd_data, // data read out
     output reg p_rd_done,         // read transfer is done

     //misc:
     input clk_core,               // system clock
     input reset_core              // reset sync to system clock
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
   //BRAM block size is no more than DRAM block size, and is multiple of
   //the PKT_DATA_WIDTH.
   //2034-byte if PKT_DATA_WIDTH = 144-bit.
   //2016-byte if PKT_DATA_WIDTH = 288-bit.
   parameter TRANSF_BLOCK_BRAM_SZ = (PKT_DATA_WIDTH == 144) ? 2034 : 2016;

   //allocate one more bit in case of counter overflow
   localparam BLOCK_BYTE_CNT_WIDTH = log2(TRANSF_BLOCK_BRAM_SZ) + 1;

   //DRAM pkt memory intfc param
   //in unit of byte
   localparam TRANSF_BLOCK_DRAM_SZ = 2**log2(TRANSF_BLOCK_BRAM_SZ);

   // 1. point to 16-byte chunks. +4
   // 2. top 2-bit addr is Bank Addr. -2
   localparam DDR2_COL_ADDR_WIDTH = PKT_MEM_PTR_WIDTH + 4 - 2;

   //----------------------------------------------
   // wires from async_fifo_cmdaddr_sysclk_2_ddr2clk0
   wire fifo_cmdaddr_wfull;
   wire [(PKT_MEM_PTR_WIDTH + 1):0] fifo_cmdaddr_rdata;
   wire fifo_cmdaddr_rempty;

   //----------------------------------------------
   // wires from async_fifo_ack_ddr2clk0_2_sysclk
   wire fifo_ack_wfull;
   wire fifo_ack_rdata;
   wire fifo_ack_rempty;

   //----------------------------------------------
   // wires from async_fifo_p_wr_data_sysclk_2_clk0
   wire fifo_p_wr_data_almost_full, fifo_p_wr_data_full, fifo_p_wr_data_empty;
   wire [71:0] fifo_p_wr_data_dout;

   //----------------------------------------------
   // wires from async_fifo_p_rd_data_clk0_2_sysclk
   wire fifo_p_rd_data_full, fifo_p_rd_data_empty;

   //----------------------------------------------
   /// wires from ddr2_blk_rdwr_fifo_72b_2_64b
   wire fifo_72b_2_64b_full, fifo_72b_2_64b_empty;
   wire [63:0] fifo_72b_2_64b_rd_data;

   //----------------------------------------------
   /// wires from ddr2_blk_rdwr_fifo_64b_2_72b
   wire        fifo_64b_2_72b_full, fifo_64b_2_72b_empty;
   wire [71:0] fifo_64b_2_72b_rd_data;

   //---------------------------------------------
   // wires from arbiter
   reg prev_op, prev_op_nxt;
   reg do_wr, do_rd;
   reg rd_done_seen, rd_done_seen_nxt;
   reg fifo_cmdaddr_winc;
   reg [(PKT_MEM_PTR_WIDTH + 1) : 0] fifo_cmdaddr_wdata;
   reg fifo_ack_rinc;
   reg [(BLOCK_BYTE_CNT_WIDTH-1) : 0] arb_wr_byte_cnt, arb_wr_byte_cnt_nxt;
   reg [(BLOCK_BYTE_CNT_WIDTH-1) : 0] arb_rd_byte_cnt, arb_rd_byte_cnt_nxt;
   reg 				      fifo_p_wr_data_wr_en;
   reg [(PKT_DATA_WIDTH-1) : 0]       fifo_p_wr_data_din;
   reg async_fifo_p_rd_data_clk0_2_sysclk_clear;
   reg [5:0] in_arb_fsm_cnt_dn, in_arb_fsm_cnt_dn_nxt;
   wire [(log2(PKT_DATA_WIDTH)-4):0] arb_byte_cnt_inc = PKT_DATA_WIDTH >> 3;

   localparam IN_ARB_RESET_STATE    = 3'h 0,
	      IN_ARB_WAIT_0_STATE   = 3'h 6,
	      IN_ARB_PRE_INIT_STATE = 3'h 1,
	      IN_ARB_IDLE_STATE     = 3'h 2,
	      IN_ARB_WR_STATE       = 3'h 3,
	      IN_ARB_RD_STATE       = 3'h 4,
	      IN_ARB_RD_DONE_STATE  = 3'h 5;

   reg [2:0] in_arb_state, in_arb_state_nxt;

   localparam ARB_OP_WR   = 2'b 00,
	      ARB_OP_RD   = 2'b 01;

   // The ddr2 reset "reset_0" won't be asserted until after reset_core
   // is deasserted. So the system clock domain state machine has to
   // wait for assertion of ddr2 reset "reset_0" before checking
   // the signal "fifo_ack_rempty" which involves the ddr2 clock domain logic.
   // The parameter IN_ARB_FSM_CNT_DN_MAX specifies the number of cycles
   // to wait so that "reset_0" will be asserted by then.
   localparam IN_ARB_FSM_CNT_DN_MAX = 6'h 20;

   //---------------------------------------------
   // ddr2 state machine
   reg [1:0] ddr2_op, ddr2_op_nxt;
   reg 	     ddr2_op_unfinished, ddr2_op_unfinished_nxt;
   reg [(DDR2_COL_ADDR_WIDTH-1) : 0] ddr2_addr, ddr2_addr_nxt;
   reg [2:0] 			     ddr2_addr_lat_cnt, ddr2_addr_lat_cnt_nxt;

   reg [(BLOCK_BYTE_CNT_WIDTH-1-3) : 0] wr_8byte_cnt, wr_8byte_cnt_nxt;
   reg [(BLOCK_BYTE_CNT_WIDTH-1-3) : 0] rd_8byte_cnt, rd_8byte_cnt_nxt;
   reg [(BLOCK_BYTE_CNT_WIDTH-1-3) : 0] rd_vld_8byte_cnt, rd_vld_8byte_cnt_nxt;
   reg [3:0] 				cmd_0, cmd_0_nxt;
   reg [63:0] wr_data_0, wr_data_0_nxt, wr_data_rep_0;
   reg 	      burst_done_a2_0, burst_done_a2_0_nxt;
   reg 	      burst_done_a1_0;
   reg 	      refr_flg, refr_flg_dup, refr_flg_nxt;
   reg 	      refr_in_prog, refr_in_prog_nxt;

   reg [63:0] fifo_64b_2_72b_wr_data;
   reg 	      fifo_64b_2_72b_wr_en, fifo_64b_2_72b_clear;
   reg 	      fifo_72b_2_64b_rd_en, fifo_72b_2_64b_clear;
   reg 	      fifo_ack_winc;
   reg 	      fifo_ack_wdata;
   reg 	      fifo_cmdaddr_rinc;
   reg [4:0]  ddr2_fsm_cnt_dn, ddr2_fsm_cnt_dn_nxt;

   //---------------------------------------------
   // sync for ddr2 clk_180, clk_90, clk_0
   reg init_val_0, auto_ref_req_0, auto_ref_req_dup_0;
   reg ar_done_0, cmd_ack_0, rd_data_valid_0;
   reg [63:0] rd_data_0;
   reg [63:0] wr_data_180;

   //---------------------------------------------
   // input flop
   reg 	      auto_ref_req_d1_180;

   //---------------------------------------------
   // wire connection between fifos
   reg 	      fifo_p_wr_data_rd_en;
   reg 	      fifo_72b_2_64b_wr_en;
   reg 	      fifo_64b_2_72b_rd_en;
   reg 	      fifo_p_rd_data_wr_en, fifo_p_rd_data_wr_en_nxt;

   //---------------------------------------------

   assign p_rd_rdy
	  = (~ fifo_p_rd_data_empty) & (in_arb_state == IN_ARB_RD_STATE);

   assign wr_data_mask_90 = 8'h 0;

   // clock alias
   wire   clk_180 = ~clk_0;

   //-------------------------------------------------
   // Logic in 125 MHz system clock domain

   //--------------------------------------------------
   // input arbiter

   assign ddr2_sm_idle = (in_arb_state == IN_ARB_IDLE_STATE);

   assign p_wr_full = fifo_p_wr_data_almost_full;

   always @(*) begin
      in_arb_state_nxt = in_arb_state;
      arb_wr_byte_cnt_nxt = arb_wr_byte_cnt;
      arb_rd_byte_cnt_nxt = arb_rd_byte_cnt;
      rd_done_seen_nxt = rd_done_seen;
      prev_op_nxt = prev_op;
      in_arb_fsm_cnt_dn_nxt = in_arb_fsm_cnt_dn;

      fifo_cmdaddr_wdata = { (PKT_MEM_PTR_WIDTH + 2) {1'h 0}};
      fifo_cmdaddr_winc  = 1'h 0;
      fifo_ack_rinc = 1'b 0;
      fifo_p_wr_data_wr_en = 1'b 0;
      fifo_p_wr_data_din   = {PKT_DATA_WIDTH {1'b 0}};
      p_wr_done = 1'b 0;
      p_rd_done = 1'b 0;
      async_fifo_p_rd_data_clk0_2_sysclk_clear = 1'b 0;
      do_wr = 1'b 0;
      do_rd = 1'b 0;
      p_rd_ack = 1'b 0;
      p_wr_ack = 1'b 0;

      case (in_arb_state)
	IN_ARB_RESET_STATE: begin
	   in_arb_fsm_cnt_dn_nxt = IN_ARB_FSM_CNT_DN_MAX;

	   in_arb_state_nxt = IN_ARB_WAIT_0_STATE;
	end

	IN_ARB_WAIT_0_STATE: begin
	   //wait for ddr2 logic to come out of reset

	   if (~ (| in_arb_fsm_cnt_dn))
	     in_arb_state_nxt = IN_ARB_PRE_INIT_STATE;
	   else
	     in_arb_fsm_cnt_dn_nxt = in_arb_fsm_cnt_dn - 1;
	end

	IN_ARB_PRE_INIT_STATE:
	  if (~fifo_ack_rempty) begin
	     //it's ack for ddr2 initialization done
	     fifo_ack_rinc    = 1'b 1;

	     in_arb_state_nxt = IN_ARB_IDLE_STATE;
	  end

	IN_ARB_IDLE_STATE: begin

	   case ({p_rd_req, p_wr_req})
	     2'b 01: begin
		do_wr = 1'b 1;
		p_wr_ack = 1'b 1;

		prev_op_nxt = 0; //wr op

	     end

	     2'b 10: begin
		do_rd = 1'b 1;
		p_rd_ack = 1'b 1;

		prev_op_nxt = 1; //rd op

	     end

	     2'b 11: begin
		do_wr = prev_op;
		p_wr_ack = do_wr;

		do_rd = ~prev_op;
		p_rd_ack = do_rd;

		prev_op_nxt = ~prev_op; //alternate
	     end

	   endcase // case({p_rd_req, p_wr_req})

	   if (do_wr) begin
	      fifo_cmdaddr_wdata  = {ARB_OP_WR, p_wr_ptr};
	      fifo_cmdaddr_winc   = 1'b 1;
	      arb_wr_byte_cnt_nxt = {BLOCK_BYTE_CNT_WIDTH {1'b 0}};

	     if (p_wr_data_vld & (~ p_wr_full)) begin
		fifo_p_wr_data_wr_en = 1'b 1;
		fifo_p_wr_data_din   = p_wr_data;

		arb_wr_byte_cnt_nxt = arb_byte_cnt_inc;

	     end

	      in_arb_state_nxt = IN_ARB_WR_STATE;

	   end
	   else
	     if (do_rd) begin
		rd_done_seen_nxt = 1'b 0;

		fifo_cmdaddr_wdata = {ARB_OP_RD, p_rd_ptr};
		fifo_cmdaddr_winc = 1'b 1;
		arb_rd_byte_cnt_nxt = {BLOCK_BYTE_CNT_WIDTH {1'b 0}};

		in_arb_state_nxt = IN_ARB_RD_STATE;

	     end

	end // case: IN_ARB_IDLE_STATE

	IN_ARB_WR_STATE: begin

	   if ( (arb_wr_byte_cnt == TRANSF_BLOCK_BRAM_SZ) &&
		(arb_wr_byte_cnt < TRANSF_BLOCK_DRAM_SZ) && (~ fifo_p_wr_data_full) ) begin
	      // pad only one word per block
	      fifo_p_wr_data_wr_en = 1'b 1;
	      fifo_p_wr_data_din = {PKT_DATA_WIDTH {1'b 0}};

	      arb_wr_byte_cnt_nxt = arb_wr_byte_cnt + arb_byte_cnt_inc;

	   end
	   else
	     if ( (arb_wr_byte_cnt < TRANSF_BLOCK_BRAM_SZ) & p_wr_data_vld & (~ fifo_p_wr_data_full)) begin
		fifo_p_wr_data_wr_en = 1'b 1;
		fifo_p_wr_data_din   = p_wr_data;

		arb_wr_byte_cnt_nxt = arb_wr_byte_cnt + arb_byte_cnt_inc;

		// assert p_wr_done to signal this is the last write data
		if (arb_wr_byte_cnt_nxt == TRANSF_BLOCK_BRAM_SZ)
		  p_wr_done = 1'b 1;

	     end

	   if (~fifo_ack_rempty) begin
	      fifo_ack_rinc = 1'b 1;

	      in_arb_state_nxt = IN_ARB_IDLE_STATE;
	   end
	end

	IN_ARB_RD_STATE: begin

	   if (~fifo_ack_rempty) begin
	      fifo_ack_rinc = 1'b 1;

	      rd_done_seen_nxt = 1'b 1;
	   end

	   if (p_rd_en) begin
	      arb_rd_byte_cnt_nxt = arb_rd_byte_cnt + arb_byte_cnt_inc;

	   end

	   if (rd_done_seen_nxt && (arb_rd_byte_cnt_nxt == TRANSF_BLOCK_BRAM_SZ) ) begin

	      p_rd_done = 1'b 1;

	      in_arb_state_nxt = IN_ARB_RD_DONE_STATE;

	   end

	end // case: IN_ARB_RD_STATE


	IN_ARB_RD_DONE_STATE: begin

	   // clear the residual bytes in async_fifo_p_rd_data_clk0_2_sysclk
	   async_fifo_p_rd_data_clk0_2_sysclk_clear = 1'b 1;

	   in_arb_state_nxt = IN_ARB_IDLE_STATE;

	end

      endcase // case(in_arb_state)

   end // always @ (*)

   always @(posedge clk_core) begin
      if (reset_core) begin
	 in_arb_state    <= IN_ARB_RESET_STATE;
	 arb_wr_byte_cnt <= {BLOCK_BYTE_CNT_WIDTH {1'b 0}};
	 arb_rd_byte_cnt <= {BLOCK_BYTE_CNT_WIDTH {1'b 0}};
	 rd_done_seen    <= 1'b 0;
	 prev_op         <= 1'b 0;
	 in_arb_fsm_cnt_dn <= 'h 0;

      end
      else begin
	 in_arb_state    <= in_arb_state_nxt;
	 arb_wr_byte_cnt <= arb_wr_byte_cnt_nxt;
	 arb_rd_byte_cnt <= arb_rd_byte_cnt_nxt;
	 rd_done_seen    <= rd_done_seen_nxt;
	 prev_op         <= prev_op_nxt;
	 in_arb_fsm_cnt_dn <= in_arb_fsm_cnt_dn_nxt;

      end
   end


   //-------------------------------------------------
   // Logic in ddr2_clk_0 domain

   // convert from 72-bit to 64-bit, and from 64-bit to 72-bit
   always @(*) begin
      //--------------------------------
      // pkt wr: from 72-bit bram to 64-bit dram
      fifo_p_wr_data_rd_en = 1'b 0;
      fifo_72b_2_64b_wr_en = 1'b 0;

      if(  (~ fifo_p_wr_data_empty) & (~ fifo_72b_2_64b_full)) begin
	 fifo_p_wr_data_rd_en = 1'b 1;
	 fifo_72b_2_64b_wr_en = 1'b 1;
      end

      //---------------------------------
      // pkt rd: from 64-bit dram to 72-bit bram
      fifo_64b_2_72b_rd_en = 1'b 0;

      if ( (~ fifo_64b_2_72b_empty) &
	   (~ fifo_p_rd_data_full) ) begin

	 fifo_64b_2_72b_rd_en = 1'b 1;


      end // if ( (~ fifo_64b_2_72b_empty) &...

   end // always @ (*)



   // ==============================================
   // Configuration registers
   // ==============================================
   // Input : CONFIG REGISTER FORMAT
   // config_register1 = {  Power Down Mode,
   // 			 Write Recovery (3),
   //                       TM,
   //                       Reserved (3),
   //                       CAS_latency (3),
   //                       Burst type ,
   //                       Burst_length (3) }
   //
   // config_register2 = {  Outputs enabled,
   //                       RDQS enable,
   //                       DQSn enable,
   //                       OCD Operation (3),
   //                       Posted CAS Latency (3),
   //                       RTT (2),
   //                       ODS,
   //                       Reserved }
   //
   // Input : Address format
   //   row address = input address(19 downto 8)
   //   column addrs = input address( 7 downto 0)
   //
   assign    config1 = {1'b0, 3'b010, 1'b0, 3'b000, 3'b011, 1'b0,  3'b010};
   assign    config2 = {1'b0, 1'b0,   1'b0, 3'b000, 3'b000, 2'b11, 1'b1,  1'b0};

   localparam CMD_NOP      = 4'b 0000,
	      CMD_MEM_INIT = 4'b 0010,
	      CMD_REFR     = 4'b 0011,
	      CMD_WRITE    = 4'b 0100,
	      CMD_READ     = 4'b 0110;

   //------------------------------------------------
   // ddr2 state machine in ddr2 clk_0 domain

   localparam DDR2_RESET_STATE            = 5'd  0,
	      DDR2_WAIT_0_STATE           = 5'd  1,
	      DDR2_WAIT_1_STATE           = 5'd  2,
	      DDR2_PRE_INIT_STATE         = 5'd  3,
	      DDR2_INIT_WAIT_STATE        = 5'd  4,
	      DDR2_IDLE_STATE             = 5'd  5,
	      DDR2_REFR_STATE             = 5'd  6,
	      DDR2_WR_WAIT_DATA_STATE     = 5'd  7,
	      DDR2_WR_WAIT_ACK_STATE      = 5'd  8,
              DDR2_WR_WAIT_ACK_LAT_STATE  = 5'd  9,
	      DDR2_WR_BURST_STATE         = 5'd 10,
	      DDR2_WR_DATA_LATENCY_STATE  = 5'd 11,
	      DDR2_BURST_DONE_0_STATE     = 5'd 12,
	      DDR2_BURST_DONE_1_STATE     = 5'd 13,
	      DDR2_CMD_DONE_0_STATE       = 5'd 14,
	      DDR2_CMD_DONE_1_STATE       = 5'd 15,
	      DDR2_CMD_WAIT_ACK_DONE_STATE= 5'd 16,
	      DDR2_RD_WAIT_ACK_STATE      = 5'd 17,
	      DDR2_RD_BURST_STATE         = 5'd 18;
   reg [4:0] ddr2_state, ddr2_state_nxt, ddr2_state_d1;

   assign bank_addr_0 = ddr2_addr [DDR2_COL_ADDR_WIDTH-1 : DDR2_COL_ADDR_WIDTH-2];
   assign addr_0      = ddr2_addr [DDR2_COL_ADDR_WIDTH-3 : 0];

   always @(*) begin
      ddr2_state_nxt = ddr2_state;
      cmd_0_nxt = cmd_0;
      wr_8byte_cnt_nxt = wr_8byte_cnt;
      rd_8byte_cnt_nxt = rd_8byte_cnt;
      rd_vld_8byte_cnt_nxt = rd_vld_8byte_cnt;
      wr_data_0_nxt = wr_data_0;
      ddr2_op_nxt = ddr2_op;
      ddr2_addr_nxt = ddr2_addr;
      burst_done_a2_0_nxt = burst_done_a2_0;
      ddr2_op_unfinished_nxt = ddr2_op_unfinished;
      refr_flg_nxt = refr_flg;
      refr_in_prog_nxt = refr_in_prog;
      ddr2_addr_lat_cnt_nxt = ddr2_addr_lat_cnt;
      ddr2_fsm_cnt_dn_nxt = ddr2_fsm_cnt_dn;

      fifo_ack_winc = 1'b 0;
      fifo_ack_wdata = 1'b 0;
      fifo_cmdaddr_rinc = 1'b 0;
      fifo_72b_2_64b_rd_en = 1'b 0;
      fifo_72b_2_64b_clear = 1'b 0;
      fifo_64b_2_72b_clear = 1'b 0;
      fifo_64b_2_72b_wr_en = 1'b 0;
      fifo_64b_2_72b_wr_data = 64'h 0;

      case (ddr2_state)
	DDR2_RESET_STATE: begin
	   ddr2_fsm_cnt_dn_nxt = 5'h 6;
	   ddr2_state_nxt = DDR2_WAIT_0_STATE;
	end

	DDR2_WAIT_0_STATE:
	  if (~ (|ddr2_fsm_cnt_dn))
	    ddr2_state_nxt = DDR2_PRE_INIT_STATE;
	  else
	    ddr2_fsm_cnt_dn_nxt = ddr2_fsm_cnt_dn - 1;

	DDR2_PRE_INIT_STATE: begin
	   //issue command to initialize DDR2 DRAM
	   cmd_0_nxt = CMD_MEM_INIT;
	   ddr2_state_nxt = DDR2_INIT_WAIT_STATE;
	end

	DDR2_INIT_WAIT_STATE: begin
	   cmd_0_nxt = CMD_NOP;

	   if (init_val_0)  begin
	      fifo_ack_winc  = 1'b 1;
	      fifo_ack_wdata = 1'b 0;

	      ddr2_state_nxt = DDR2_IDLE_STATE;
	   end
	end // case: DDR2_INIT_WAIT_STATE

	DDR2_IDLE_STATE: begin

	   if (auto_ref_req_0) begin

	      cmd_0_nxt      = CMD_REFR;
	      ddr2_state_nxt = DDR2_REFR_STATE;

	   end
	   else begin

	      if (ddr2_op_unfinished | (~ fifo_cmdaddr_rempty)) begin

		 if (ddr2_op_unfinished)
		   ddr2_op_unfinished_nxt = 1'b 0;

		 else begin
		    fifo_cmdaddr_rinc = 1'b 1;

		    ddr2_op_nxt   = fifo_cmdaddr_rdata[(PKT_MEM_PTR_WIDTH + 1) : PKT_MEM_PTR_WIDTH];
		    ddr2_addr_nxt = {fifo_cmdaddr_rdata[(PKT_MEM_PTR_WIDTH -1) : 0], 2'b 00};
		    wr_8byte_cnt_nxt = 'h 0;
		    rd_8byte_cnt_nxt = 'h 0;
		    rd_vld_8byte_cnt_nxt = 'h 0;

		    // this clears the residual bytes in fifo_ddr2_blk_rdwr_64b_2_72b and
		    // assembly registers in async_fifo_in_72b_out_144b
		    // or async_fifo_in_72b_out_288b.
		    fifo_64b_2_72b_clear = 1'b 1;

		 end

		 case (ddr2_op_nxt)

		   ARB_OP_WR: begin

		      ddr2_state_nxt = DDR2_WR_WAIT_DATA_STATE;

		   end

		   ARB_OP_RD: begin

		      cmd_0_nxt      = CMD_READ;
		      ddr2_state_nxt = DDR2_RD_WAIT_ACK_STATE;
		   end

		 endcase // case(ddr2_op_nxt)

	      end // if (ddr2_op_unfinished | (~ fifo_cmdaddr_rempty))

	   end // else: !if(auto_ref_req_0)

	end // case: DDR2_IDLE_STATE

	//-----------------------------------------
	// DRAM refresh states

	DDR2_REFR_STATE: begin
	   cmd_0_nxt = CMD_NOP;

	   if (ar_done_0)
	     ddr2_state_nxt = DDR2_IDLE_STATE;

	end

	//-----------------------------------------
	// DRAM write states

	DDR2_WR_WAIT_DATA_STATE:
	  if (~ fifo_72b_2_64b_empty) begin

	     fifo_72b_2_64b_rd_en = 1'b 1;
	     cmd_0_nxt       = CMD_WRITE;
	     wr_data_0_nxt   = fifo_72b_2_64b_rd_data;

	     ddr2_state_nxt  = DDR2_WR_WAIT_ACK_STATE;

	  end


	DDR2_WR_WAIT_ACK_STATE: begin

	     if (cmd_ack_0) begin

		wr_8byte_cnt_nxt = wr_8byte_cnt + 1;

		ddr2_state_nxt = DDR2_WR_WAIT_ACK_LAT_STATE;

             end

	end


	DDR2_WR_WAIT_ACK_LAT_STATE: begin

	      fifo_72b_2_64b_rd_en = 1'b 1;
	      wr_data_0_nxt        = fifo_72b_2_64b_rd_data;
	      wr_8byte_cnt_nxt      = wr_8byte_cnt + 1;
	      ddr2_addr_lat_cnt_nxt = 'h 5;

	      ddr2_state_nxt       = DDR2_WR_BURST_STATE;

	   end

	DDR2_WR_BURST_STATE: begin
	   ddr2_addr_lat_cnt_nxt = (| ddr2_addr_lat_cnt) ? (ddr2_addr_lat_cnt-1):'h 0;

	   if ( ~(| ddr2_addr_lat_cnt) &  (wr_8byte_cnt[0]) ) begin
	      // if wr_8byte_cnt in the previous cycle is multiple of 2,
	      // the address is incremented by 4
	      ddr2_addr_nxt = ddr2_addr + 4; //1 unit is 4-byte
	   end

	   if ( (wr_8byte_cnt == (TRANSF_BLOCK_DRAM_SZ/8)) |
		(auto_ref_req_0 & (~ wr_8byte_cnt[0]) & (ddr2_addr_lat_cnt<=1) ) ) begin

	      ddr2_op_unfinished_nxt = (wr_8byte_cnt != (TRANSF_BLOCK_DRAM_SZ/8));
	      refr_flg_nxt = auto_ref_req_dup_0 & (~ wr_8byte_cnt[0]) & (ddr2_addr_lat_cnt<=1);
	      // clear the residual bytes in fifo_ddr2_blk_rdwr_72b_2_64b
	      fifo_72b_2_64b_clear = (wr_8byte_cnt == (TRANSF_BLOCK_DRAM_SZ/8));

	      ddr2_state_nxt = DDR2_WR_DATA_LATENCY_STATE;

	   end
	   else begin

	      fifo_72b_2_64b_rd_en = 1'b 1;
	      wr_data_0_nxt        = fifo_72b_2_64b_rd_data;
	      wr_8byte_cnt_nxt     = wr_8byte_cnt + 1;

	   end

	end // case: DDR2_WR_BURST_STATE

	DDR2_WR_DATA_LATENCY_STATE: begin

	   ddr2_addr_lat_cnt_nxt = (| ddr2_addr_lat_cnt) ? (ddr2_addr_lat_cnt-1):'h 0;

	   if (~ (| ddr2_addr_lat_cnt))
	     ddr2_addr_nxt = ddr2_addr + 4; //unit is 4-byte

	   refr_flg_nxt   = refr_flg | auto_ref_req_dup_0;
	   burst_done_a2_0_nxt       = 1'b 1;
	   ddr2_state_nxt         = DDR2_BURST_DONE_0_STATE;

	end


	DDR2_BURST_DONE_0_STATE: begin

	   ddr2_addr_lat_cnt_nxt = (| ddr2_addr_lat_cnt) ? (ddr2_addr_lat_cnt-1):'h 0;

	   if (ddr2_op == ARB_OP_RD)
	     rd_8byte_cnt_nxt = rd_8byte_cnt + 1;

	   refr_flg_nxt   = refr_flg | auto_ref_req_dup_0;
	   ddr2_state_nxt = DDR2_BURST_DONE_1_STATE;

	end

	DDR2_BURST_DONE_1_STATE: begin

	   if (~ (| ddr2_addr_lat_cnt))
	     ddr2_addr_nxt = ddr2_addr + 4; //unit is 4-byte

	   refr_flg_nxt     = refr_flg_dup | auto_ref_req_dup_0;
	   burst_done_a2_0_nxt = 1'b 0;
	   ddr2_state_nxt   = DDR2_CMD_DONE_0_STATE;

	end

	DDR2_CMD_DONE_0_STATE: begin

	   refr_flg_nxt   = refr_flg_dup | auto_ref_req_dup_0;
	   ddr2_state_nxt = DDR2_CMD_DONE_1_STATE;

	end

	DDR2_CMD_DONE_1_STATE: begin

	   if ( ddr2_op == ARB_OP_WR)
	     ddr2_addr_nxt = ddr2_addr + 4; //unit is 4-byte

	   refr_flg_nxt = refr_flg_dup | auto_ref_req_dup_0;

	   if (refr_flg_nxt) begin

	      refr_flg_nxt     = 1'b 0;
	      refr_in_prog_nxt = 1'b 1;
	      cmd_0_nxt        = CMD_REFR;

	   end
	   else
	      cmd_0_nxt = CMD_NOP;

	   ddr2_state_nxt = DDR2_CMD_WAIT_ACK_DONE_STATE;

	end // case: DDR2_CMD_DONE_1_STATE

	DDR2_CMD_WAIT_ACK_DONE_STATE: begin
	   if (refr_in_prog)
	     cmd_0_nxt = CMD_NOP;

	   if (refr_in_prog & ar_done_0)
	     refr_in_prog_nxt = 1'b 0;

	  if ( (~ cmd_ack_0) & (~ refr_in_prog_nxt) &
	       ( (ddr2_op == ARB_OP_WR) |
		 ( (ddr2_op == ARB_OP_RD) &
		   (ddr2_op_unfinished | (rd_vld_8byte_cnt_nxt == TRANSF_BLOCK_DRAM_SZ/8) )
		   )
		 )
	       ) begin

	     if (~ ddr2_op_unfinished) begin

		fifo_ack_winc  = 1'b 1;
		fifo_ack_wdata = 1'b 1;

	     end

	     ddr2_state_nxt = DDR2_IDLE_STATE;

	  end // if ( (~ cmd_ack_0) & (~ refr_in_prog_nxt) &...

	end // case: DDR2_CMD_WAIT_ACK_DONE_STATE

	//-----------------------------------------
	// read states

	DDR2_RD_WAIT_ACK_STATE:
	  if (cmd_ack_0) begin

	     ddr2_addr_lat_cnt_nxt = 'h 2;

	     ddr2_state_nxt = DDR2_RD_BURST_STATE;

	  end

	DDR2_RD_BURST_STATE: begin

	   ddr2_addr_lat_cnt_nxt = (| ddr2_addr_lat_cnt) ? (ddr2_addr_lat_cnt-1) : 'h 0;

	   if (~(| ddr2_addr_lat_cnt)) begin

	      //rd_8byte_cnt is multiple of 2, address is incremented by 4
	      if (~ rd_8byte_cnt[0])
		ddr2_addr_nxt = ddr2_addr + 4; //1 unit is 4-byte
	   end

	   if (ddr2_addr_lat_cnt <= 1) begin

	      rd_8byte_cnt_nxt = rd_8byte_cnt + 1;

	      if ( ( (rd_8byte_cnt+2) == (TRANSF_BLOCK_DRAM_SZ/8) ) |
		(auto_ref_req_dup_0 & (~ rd_8byte_cnt[0]) ) ) begin

		 ddr2_op_unfinished_nxt = ((rd_8byte_cnt+2)!=(TRANSF_BLOCK_DRAM_SZ/8) );
		 refr_flg_nxt           = auto_ref_req_dup_0 & (~ rd_8byte_cnt[0]);
		 burst_done_a2_0_nxt    = 1'b 1;
		 ddr2_state_nxt         = DDR2_BURST_DONE_0_STATE;

	      end

	   end // if (ddr2_addr_lat_cnt <= 1)

	end // case: DDR2_RD_BURST_STATE

      endcase // case(ddr2_state)

      if ( (ddr2_state == DDR2_RD_BURST_STATE) ||
	   (ddr2_state == DDR2_BURST_DONE_0_STATE) ||
	   (ddr2_state == DDR2_BURST_DONE_1_STATE) ||
	   (ddr2_state == DDR2_CMD_DONE_0_STATE) ||
	   (ddr2_state == DDR2_CMD_DONE_1_STATE) ||
	   (ddr2_state == DDR2_CMD_WAIT_ACK_DONE_STATE) ) begin

	 if (rd_data_valid_0) begin
	    rd_vld_8byte_cnt_nxt = rd_vld_8byte_cnt + 'h 1;

	    fifo_64b_2_72b_wr_en   = 1'b 1;
	    fifo_64b_2_72b_wr_data = rd_data_0;
	 end

      end // if ( (ddr2_state == DDR2_RD_BURST_STATE) ||...

   end // always @ (*)

   //-------------------------------------------
   // synchronization
   always @(posedge clk_0) begin
      // 180 -> 0
      init_val_0         <= init_val_180;
      auto_ref_req_0     <= auto_ref_req_d1_180;
      auto_ref_req_dup_0 <= auto_ref_req_d1_180;

      ar_done_0          <= ar_done_180;
      cmd_ack_0          <= cmd_ack_180;

      // 90 -> 0
      rd_data_valid_0 <= rd_data_valid_90;
      rd_data_0       <= rd_data_90;

   end

   always @(posedge clk_90) begin
      // 180 -> 90
      wr_data_90 <= wr_data_180;

   end

   always @(posedge clk_180) begin
      // 0 -> 180
      cmd_180 <= cmd_0;
      wr_data_180 <= wr_data_0;

      // input flop
      auto_ref_req_d1_180 <= auto_ref_req_180;

   end

   always @(posedge clk_0) begin
      if (reset_0) begin
	 ddr2_op            <= ARB_OP_RD;
	 ddr2_op_unfinished <= 1'b 0;
	 ddr2_addr          <= {DDR2_COL_ADDR_WIDTH {1'b 0}};
	 ddr2_addr_lat_cnt  <= 'h 0;
	 wr_8byte_cnt       <= 'h 0;
	 rd_8byte_cnt       <= 'h 0;
	 rd_vld_8byte_cnt   <= 'h 0;
	 cmd_0              <= CMD_NOP;
	 wr_data_0          <= 64'h 0;
	 burst_done_a2_0    <= 1'b 0;
	 burst_done_a1_0    <= 1'b 0;
	 burst_done_0       <= 1'b 0;
	 refr_flg           <= 1'b 0;
	 refr_flg_dup       <= 1'b 0;
	 refr_in_prog       <= 1'b 0;
	 ddr2_state         <= DDR2_RESET_STATE;
	 ddr2_fsm_cnt_dn    <= 'h 0;

      end
      else begin
	 ddr2_op            <= ddr2_op_nxt;
	 ddr2_op_unfinished <= ddr2_op_unfinished_nxt;
	 ddr2_addr          <= ddr2_addr_nxt;
	 ddr2_addr_lat_cnt  <= ddr2_addr_lat_cnt_nxt;
	 wr_8byte_cnt       <= wr_8byte_cnt_nxt;
	 rd_8byte_cnt       <= rd_8byte_cnt_nxt;
	 rd_vld_8byte_cnt   <= rd_vld_8byte_cnt_nxt;
	 cmd_0              <= cmd_0_nxt;
	 wr_data_0          <= wr_data_0_nxt;
	 burst_done_a2_0    <= burst_done_a2_0_nxt;
	 burst_done_a1_0    <= burst_done_a2_0;
	 burst_done_0       <= burst_done_a1_0;
	 refr_flg           <= refr_flg_nxt;
	 refr_flg_dup       <= refr_flg_nxt;
	 refr_in_prog       <= refr_in_prog_nxt;
	 ddr2_state         <= ddr2_state_nxt;
	 ddr2_fsm_cnt_dn    <= ddr2_fsm_cnt_dn_nxt;

      end
   end


   //---------------------------------------------------
   // instantiations

   // async fifo to pass command and pkt memory address
   // from sys clk domain to ddr2 clk_0 domain
   small_async_fifo #(.DSIZE(PKT_MEM_PTR_WIDTH + 2),
		      .ASIZE(4),
		      .ALMOST_FULL_SIZE(3),
		      .ALMOST_EMPTY_SIZE(1)
		      )
     async_fifo_cmdaddr_sysclk_2_ddr2clk0
       (
	//wr interface
	//output:
	.wfull         ( fifo_cmdaddr_wfull ),
	.w_almost_full (  ),

	//input:
	.wdata         ( fifo_cmdaddr_wdata ), // [DSIZE-1:0]
	.winc          ( fifo_cmdaddr_winc ),

	//misc:
	.wclk          ( clk_core ),
	.wrst_n        ( ~ reset_core ),

	//rd interface
	//output:
	.rdata         ( fifo_cmdaddr_rdata ), //[DSIZE-1:0]
	.rempty        ( fifo_cmdaddr_rempty ),
	.r_almost_empty(  ),

	//input
	.rinc          ( fifo_cmdaddr_rinc ),

	//misc:
	.rclk          ( clk_0 ),
	.rrst_n        ( ~ reset_0 )
	);

	 /*async_fifo_16bit
     async_fifo_cmdaddr_sysclk_2_ddr2clk0
       (
	//wr interface
	//output:
	.full         ( fifo_cmdaddr_wfull ),

	//input:
	.din         ( fifo_cmdaddr_wdata ), // [DSIZE-1:0]
	.wr_en          ( fifo_cmdaddr_winc ),

	//misc:
	.wr_clk          ( clk_core ),

	//rd interface
	//output:
	.dout         ( fifo_cmdaddr_rdata ), //[DSIZE-1:0]
	.empty        ( fifo_cmdaddr_rempty ),

	//input
	.rd_en          ( fifo_cmdaddr_rinc ),

	//misc:
	.rd_clk          ( clk_0 ),
	.rst        ( reset_core )
	);*/


   // async fifo to indicate a task in ddr2 clk_0 domain is done
   // from ddr2 clk_0 domain to sys clk domain
    small_async_fifo #(.DSIZE(1),
		      .ASIZE(4),
		      .ALMOST_FULL_SIZE(3),
		      .ALMOST_EMPTY_SIZE(1)
		      )
     async_fifo_ack_ddr2clk0_2_sysclk
       (
	//--------------------
	//wr interface
	//output:
	.wfull         ( fifo_ack_wfull ),
	.w_almost_full (  ),

	//input:
	.wdata         ( fifo_ack_wdata  ),
	.winc          ( fifo_ack_winc ),

	//misc:
	.wclk          ( clk_0 ),
	.wrst_n        ( ~ reset_0 ),

	//--------------------
	//rd interface
	//output:
	.rdata         ( fifo_ack_rdata ),
	.rempty        ( fifo_ack_rempty ),
	.r_almost_empty(  ),

	//input
	.rinc          ( fifo_ack_rinc ),

	//misc:
	.rclk          ( clk_core ),
	.rrst_n        ( ~ reset_core )
	);


   generate
      if (PKT_DATA_WIDTH==144) begin:data_fifo_144

	 //--------------------------------------------------------
	 // async fifo from sys clk domain to ddr2 clk_0 domain
	 // feeder on the sys clk    side: 144-bit wide. 125 MHZ
	 // reader on the ddr2 clk_0 side: 72-bit  wide. 200 MHz
	 // feed will occasionally see fifo full, need to wait for fifo to become not full

	 async_fifo_in_144b_out_72b
	   async_fifo_p_wr_data_sysclk_2_clk0
	     (
	      //-----------------------------------
	      //wr intfc
	      //input:
              .din         ( fifo_p_wr_data_din ),
              .wr_en       ( fifo_p_wr_data_wr_en ),

	      //output:
              .almost_full ( fifo_p_wr_data_almost_full ),
              .full        ( fifo_p_wr_data_full ),

	      //clk:
              .wr_clk      ( clk_core ),

	      //-----------------------------------
	      //rd intfc
	      //input:
              .rd_en        ( fifo_p_wr_data_rd_en ),

	      //output:
              .almost_empty (  ),
              .empty        ( fifo_p_wr_data_empty ),
              .dout         ( fifo_p_wr_data_dout ),

	      //clk:
              .rd_clk       ( clk_0 ),

	      //-----------------------------------
	      // async rst
              .rst          ( reset_core )
	      );

	 //--------------------------------------------------------
	 // async fifo from ddr2 clk_0 domain to sys clk domain
	 // reader on sys clk    side: 144-bit wide. 125 MHz
	 // feeder on ddr2 clk_0 side: 144-bit wide. 200 MHz.
	 // reader will occasionally see fifo empty, need to wait for data to be available


	 async_fifo_in_72b_out_144b
	   async_fifo_p_rd_data_clk0_2_sysclk
	     (
	      //-----------------------------
	      //wr intfc
	      //input:
	      .din         ( fifo_64b_2_72b_rd_data ),
	      .wr_en       ( fifo_64b_2_72b_rd_en ),

	      //output:
	      .full        ( fifo_p_rd_data_full ),

	      //wr clk
	      .wr_clk      ( clk_0 ),
	      .wr_reset    ( reset_0 ),
	      .wr_clear_residue ( fifo_64b_2_72b_clear ),

	      //-----------------------------
	      //rd intfc
	      //input:
	      .rd_en       ( p_rd_en ),

	      //output:
	      .dout        ( p_rd_data ),
	      .empty       ( fifo_p_rd_data_empty ),

	      //rd clk
	      .rd_clk      ( clk_core ),

	      //--------------------------
	      // async reset
	      .arst         ( reset_core )
 	      );


	 end //block:data_fifo_144

      else if (PKT_DATA_WIDTH==288) begin:data_fifo_288

	 //--------------------------------------------------------
	 // async fifo from sys clk domain to ddr2 clk_0 domain
	 // feeder on the sys clk    side: 288-bit wide. 62.5 MHZ
	 // reader on the ddr2 clk_0 side: 72-bit  wide. 200 MHz
	 // feed will occasionally see fifo full, need to wait for fifo to become not full

	 async_fifo_in_288b_out_72b
	   async_fifo_p_wr_data_sysclk_2_clk0
	     (
	      //-----------------------------------
	      //wr intfc
	      //input:
              .din         ( fifo_p_wr_data_din ),
              .wr_en       ( fifo_p_wr_data_wr_en ),

	      //output:
              .almost_full ( fifo_p_wr_data_almost_full ),
              .full        ( fifo_p_wr_data_full ),

	      //clk:
              .wr_clk      ( clk_core ),

	      //-----------------------------------
	      //rd intfc
	      //input:
              .rd_en        ( fifo_p_wr_data_rd_en ),

	      //output:
              .almost_empty (  ),
              .empty        ( fifo_p_wr_data_empty ),
              .dout         ( fifo_p_wr_data_dout ),

	      //clk:
              .rd_clk       ( clk_0 ),

	      //-----------------------------------
	      // async rst
              .rst          ( reset_core )
	      );


	 async_fifo_in_72b_out_288b
	   async_fifo_p_rd_data_clk0_2_sysclk
	     (
	      //-----------------------------
	      //wr intfc
	      //input:
	      .din         ( fifo_64b_2_72b_rd_data ),
	      .wr_en       ( fifo_64b_2_72b_rd_en ),

	      //output:
	      .full        ( fifo_p_rd_data_full ),

	      //wr clk
	      .wr_clk      ( clk_0 ),
	      .wr_reset    ( reset_0 ),
	      .wr_clear_residue ( fifo_64b_2_72b_clear ),

	      //-----------------------------
	      //rd intfc
	      //input:
	      .rd_en       ( p_rd_en ),

	      //output:
	      .dout        ( p_rd_data ),
	      .empty       ( fifo_p_rd_data_empty ),

	      //rd clk
	      .rd_clk      ( clk_core ),

	      //--------------------------
	      // async reset
	      .arst         ( reset_core )
 	      );

      end //block:data_fifo_288

   endgenerate


   //-----------------------------------
   // wr fifo for data width conversion
   // input: 72-bit
   // output: 64-bit
   ddr2_blk_rdwr_fifo_72b_2_64b
     ddr2_blk_rdwr_fifo_72b_2_64b_u
     (
      //----------------------
      // wr intfc
      //input:
      .wr_data ( fifo_p_wr_data_dout ),
      .wr_en   ( fifo_72b_2_64b_wr_en ),

      //output:
      .full    ( fifo_72b_2_64b_full ),

      //----------------------
      // rd intfc
      //input:
      .rd_en   ( fifo_72b_2_64b_rd_en ),

      //output:
      .rd_data ( fifo_72b_2_64b_rd_data ),
      .empty   ( fifo_72b_2_64b_empty ),

      //misc:
      .clk     ( clk_0 ),
      .rst     ( reset_0 | fifo_72b_2_64b_clear )
      );

   //-----------------------------------
   // rd fifo for data width conversion
   // input: 64-bit
   // output: 72-bit
   ddr2_blk_rdwr_fifo_64b_2_72b
     ddr2_blk_rdwr_fifo_64b_2_72b_u
       (
	//----------------------
	// wr intfc
	//input:
	.wr_data ( fifo_64b_2_72b_wr_data ),
	.wr_en   ( fifo_64b_2_72b_wr_en ),

	//output:
	.full    ( fifo_64b_2_72b_full ),

	//----------------------
	// rd intfc
	//input:
	.rd_en   ( fifo_64b_2_72b_rd_en ),

	//output:
	.rd_data_d1 ( fifo_64b_2_72b_rd_data ),
	.rd_data    (  ),
	.empty   ( fifo_64b_2_72b_empty ),

	//misc:
	.clk     ( clk_0 ),
	.rst     ( reset_0 | fifo_64b_2_72b_clear )
	);

endmodule // ddr2_blk_rdwr


