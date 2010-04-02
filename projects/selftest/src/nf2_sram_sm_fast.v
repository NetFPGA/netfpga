///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_sram_sm_fast.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_sram_sm.v
// Project: Selftest
// Description: Selftest SRAM controller
//
// Accepts requests for reading or writing and then services them in some
// sort of round-robin order.
//
// Set up to drive a Cypress cy7c1370 NOBL part (512Kx36), but anything with
// two clock delay from addr to data should be OK.
//
// We do not exploit the NOBL feature but instead we provide a bus turn around
// cycle because we can afford to do it.
//
///////////////////////////////////////////////////////////////////////////////

module nf2_sram_sm_fast  #(parameter SRAM_ADDR_WIDTH = 19,
			   parameter SRAM_DATA_WIDTH = 36 )

   (
   //--- Requests from sram_test

    input sram_test_req,
    input [SRAM_ADDR_WIDTH-1:0] sram_test_addr,
    input [SRAM_DATA_WIDTH-1:0] sram_test_wr_data,
    input sram_test_tri_en,
    input sram_test_we_bw,

    output reg [SRAM_DATA_WIDTH-1:0] sram_test_rd_data,

    //--- Requests from cpu
    input reg_req,
    input reg_rd_wr_L,
    input [`SRAM_REG_ADDR_WIDTH-1:0] reg_addr,
    input [SRAM_DATA_WIDTH-1:0] reg_wr_data,

    output reg reg_ack,
    output reg [SRAM_DATA_WIDTH-1:0] reg_rd_data,

   // --- SRAM signals (pins and control)

    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,
    output reg [SRAM_DATA_WIDTH-1:0] sram_wr_data,
    input      [SRAM_DATA_WIDTH-1:0] sram_rd_data,
    output reg                       sram_tri_en,
    output reg                       sram_we_bw,

    // --- Misc

    input reset,
    input clk

    );

   reg [SRAM_ADDR_WIDTH-1:0] sram_addr_nxt;
   reg [SRAM_DATA_WIDTH-1:0] sram_wr_data_nxt, sram_wr_data_int;
   reg sram_tri_en_nxt, sram_we_bw_nxt;
   reg [SRAM_DATA_WIDTH-1:0] sram_rd_data_d;

   reg 			     reg_ack_nxt;
   reg [SRAM_DATA_WIDTH-1:0] reg_rd_data_nxt;

   reg rd, rd_nxt;

   reg [2:0] state, state_nxt;

   parameter
             IDLE_STATE = 3'h 0,
             ADDR_STATE = 3'h 1,
             WAIT_STATE = 3'h 2,
	     WAIT_FLP_STATE = 3'h 3,
             DATA_STATE = 3'h 4,
	     DONE_STATE = 3'h 5,
	     HW_TEST_STATE = 3'h 6;

   always @(*) begin
      sram_addr_nxt = sram_addr;
      sram_wr_data_nxt = sram_wr_data_int;
      sram_tri_en_nxt = 1'b 0;
      sram_we_bw_nxt = 1'b 1;

      rd_nxt = rd;

      sram_test_rd_data = 'h 0;

      reg_ack_nxt = 1'b 0;
      reg_rd_data_nxt = reg_rd_data;

      state_nxt = state;

      //preempt to HW_TEST_STATE
      if (sram_test_req) begin
	 sram_addr_nxt = sram_test_addr;
	 sram_wr_data_nxt = sram_test_wr_data;
	 sram_tri_en_nxt = sram_test_tri_en;
	 sram_we_bw_nxt = sram_test_we_bw;

	 sram_test_rd_data = sram_rd_data_d;

	 state_nxt = HW_TEST_STATE;
      end //if (sram_test_req)

      else begin

	 case (state)
	   HW_TEST_STATE:
	     state_nxt = IDLE_STATE;

           IDLE_STATE:
	     if ( reg_req )  begin
                sram_addr_nxt = reg_addr;
                sram_we_bw_nxt = reg_rd_wr_L;
                rd_nxt = reg_rd_wr_L;

                state_nxt = ADDR_STATE;

	     end

           ADDR_STATE:
             state_nxt = WAIT_STATE;

           WAIT_STATE: begin
              if (~ rd) begin
		 sram_tri_en_nxt = 1'b 1;

                 sram_wr_data_nxt = reg_wr_data;

		 state_nxt = DATA_STATE;

              end // if (~ rd)
	      else begin

		 state_nxt = WAIT_FLP_STATE;

	      end // else: !if(~ rd)

           end // case: WAIT_STATE

	   WAIT_FLP_STATE:
	     state_nxt = DATA_STATE;

           DATA_STATE: begin
	      if (rd) reg_rd_data_nxt = sram_rd_data_d;

	      reg_ack_nxt = 1'b 1;

              state_nxt = DONE_STATE;

           end // case: DATA_STATE

	   DONE_STATE:
             if (!reg_req)
	        state_nxt = IDLE_STATE;

	 endcase // case(state)

      end // else: !if(sram_test_req)

   end // always @ (*)


   always @(posedge clk) begin

      sram_rd_data_d <= sram_rd_data;

      if (reset) begin
         sram_addr <= {SRAM_ADDR_WIDTH {1'b 0}};
         sram_wr_data <= {SRAM_DATA_WIDTH {1'b 0}};
         sram_wr_data_int <= {SRAM_DATA_WIDTH {1'b 0}};
         sram_tri_en <= 1'b 0;
         sram_we_bw <= 1'b 1;

         rd <= 1'b 1;

	 reg_ack <= 1'b 0;
	 reg_rd_data <= {SRAM_DATA_WIDTH {1'b 0}};

         state <= IDLE_STATE;

      end

      else begin
         sram_addr <= sram_addr_nxt;
         sram_wr_data <= sram_wr_data_nxt;
         sram_wr_data_int <= sram_wr_data_nxt;
         sram_tri_en <= sram_tri_en_nxt;
         sram_we_bw <= sram_we_bw_nxt;

         rd <= rd_nxt;

	 reg_ack <= reg_ack_nxt;
	 reg_rd_data <= reg_rd_data_nxt;

         state <= state_nxt;

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // nf2_sram_sm_fast

