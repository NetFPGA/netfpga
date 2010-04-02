///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_sram_sm.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_sram_sm.v
// Project: Selftest
// Description: NetFPGA SRAM controller
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

module nf2_sram_sm  #(parameter SRAM_ADDR_SIZE  = 19,
                      parameter SRAM_DATA_WIDTH = 36 )

   (

   // --- Requesters from two ports
    input req_0,
    input rd_0,
    input [SRAM_ADDR_SIZE-1:0] addr_0,
    input [SRAM_DATA_WIDTH-1:0] wr_data_0,

    output reg ack_0,
    output reg [SRAM_DATA_WIDTH-1:0] rd_data_0,

    input req_1,
    input rd_1,
    input [SRAM_ADDR_SIZE-1:0] addr_1,
    input [SRAM_DATA_WIDTH-1:0] wr_data_1,

    output reg ack_1,
    output reg [SRAM_DATA_WIDTH-1:0] rd_data_1,

   // --- SRAM signals (pins and control)

    output reg [SRAM_ADDR_SIZE-1:0]  sram_addr,
    output reg [SRAM_DATA_WIDTH-1:0] sram_wr_data,
    input      [SRAM_DATA_WIDTH-1:0] sram_rd_data,
    output reg                       sram_tri_en,
    output reg                       sram_we_bw,

    // --- Misc

    input reset,
    input clk

    );

   reg [SRAM_ADDR_SIZE-1:0] sram_addr_nxt;
   reg [SRAM_DATA_WIDTH-1:0] sram_wr_data_nxt;
   reg sram_tri_en_nxt, sram_we_bw_nxt;
   reg [SRAM_DATA_WIDTH-1:0] sram_rd_data_d;

   reg 			     ack_0_nxt;
   reg [SRAM_DATA_WIDTH-1:0] rd_data_0_nxt;

   reg 			     ack_1_nxt;
   reg [SRAM_DATA_WIDTH-1:0] rd_data_1_nxt;

   reg cur_port, cur_port_nxt;
   reg rd, rd_nxt;

   reg [2:0] state, state_nxt;

   parameter
             IDLE_STATE = 3'h 0,
             ADDR_STATE = 3'h 1,
             WAIT_STATE = 3'h 2,
	     WAIT_FLP_STATE = 3'h 3,
             DATA_STATE = 3'h 4,
	     DONE_STATE = 3'h 5;

   always @(*) begin
      sram_addr_nxt = sram_addr;
      sram_wr_data_nxt = sram_wr_data;
      sram_tri_en_nxt = 1'b 0;
      sram_we_bw_nxt = 1'b 1;

      cur_port_nxt = cur_port;
      rd_nxt = rd;

      ack_0_nxt = 1'b 0;
      rd_data_0_nxt = rd_data_0;

      ack_1_nxt = 1'b 0;
      rd_data_1_nxt = rd_data_1;

      state_nxt = state;

      case (state)
        IDLE_STATE:
          case (cur_port)
            1'b 0: begin
               //serve port 0
               if ( req_0 )  begin
                  sram_addr_nxt = addr_0;
                  sram_we_bw_nxt = rd_0;
                  rd_nxt = rd_0;

                  state_nxt = ADDR_STATE;

               end
               else begin

                  cur_port_nxt = ~ cur_port;

               end

            end // case: 1'b 0

            1'b 1: begin
               //serve port 1
               if ( req_1 ) begin
                  sram_addr_nxt = addr_1;
                  sram_we_bw_nxt = rd_1;
                  rd_nxt = rd_1;

                  state_nxt = ADDR_STATE;

               end
               else begin

                  cur_port_nxt = ~ cur_port;

               end

            end // case: 1'b 1

          endcase // case(cur_port)

        ADDR_STATE:
          state_nxt = WAIT_STATE;

        WAIT_STATE: begin
           if (~ rd) begin
              sram_tri_en_nxt = 1'b 1;

              if (cur_port == 1'b 0)
                sram_wr_data_nxt = wr_data_0;
              else
                sram_wr_data_nxt = wr_data_1;

              state_nxt = DATA_STATE;

           end // if (~ rd)
	   else begin

	      state_nxt = WAIT_FLP_STATE;

	   end // else: !if(~ rd)

        end // case: WAIT_STATE

	WAIT_FLP_STATE:
	  state_nxt = DATA_STATE;

        DATA_STATE: begin
           if (cur_port == 1'b 0) begin
              if (rd) rd_data_0_nxt = sram_rd_data_d;

              ack_0_nxt = 1'b 1;
           end
           else begin
              if (rd) rd_data_1_nxt = sram_rd_data_d;

              ack_1_nxt = 1'b 1;

           end

           cur_port_nxt = ~ cur_port;

           state_nxt = DONE_STATE;

        end // case: DATA_STATE

	DONE_STATE:
	  state_nxt = IDLE_STATE;

      endcase // case(state)

   end // always @ (*)


   always @(posedge clk) begin

      sram_rd_data_d <= sram_rd_data;

      if (reset) begin
         sram_addr <= {SRAM_ADDR_SIZE {1'b 0}};
         sram_wr_data <= {SRAM_DATA_WIDTH {1'b 0}};
         sram_tri_en <= 1'b 0;
         sram_we_bw <= 1'b 1;

         cur_port <= 1'b 0;
         rd <= 1'b 1;

	 ack_0 <= 1'b 0;
	 rd_data_0 <= {SRAM_DATA_WIDTH {1'b 0}};

	 ack_1 <= 1'b 0;
	 rd_data_1 <= {SRAM_DATA_WIDTH {1'b 0}};

         state <= IDLE_STATE;

      end

      else begin
         sram_addr <= sram_addr_nxt;
         sram_wr_data <= sram_wr_data_nxt;
         sram_tri_en <= sram_tri_en_nxt;
         sram_we_bw <= sram_we_bw_nxt;

         cur_port <= cur_port_nxt;
         rd <= rd_nxt;

	 ack_0 <= ack_0_nxt;
	 rd_data_0 <= rd_data_0_nxt;

	 ack_1 <= ack_1_nxt;
	 rd_data_1 <= rd_data_1_nxt;

         state <= state_nxt;

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // nf2_sram_sm

