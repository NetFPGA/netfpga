//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: reg_sram_msb.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: reg_sram_msb.v
// Project: NetFPGA
// Description: Implements the sram read/write direct access registers
//
///////////////////////////////////////////////////////////////////////////////


module reg_sram_msb
   (
      //intfc to cpu
      input                                  reg_req,
      input                                  reg_rd_wr_L,
      input [`SRAM_MSB_REG_ADDR_WIDTH - 1:0] reg_addr,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]     reg_wr_data,

      output reg                             reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]reg_rd_data,

      //intfc to SRAM controller 1
      input [`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0]      s1_rd_data_msb,
      output reg [`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0] s1_wr_data_msb,

      //intfc to SRAM controller 2
      input [`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0]      s2_rd_data_msb,
      output reg [`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0] s2_wr_data_msb,

      //intfc to misc
      input clk,
      input reset
   );

   reg reg_ack_nxt;
   reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data_nxt;

   reg s1_wr_data_msb_sel;
   reg s2_wr_data_msb_sel;

   reg state, state_nxt;

   parameter
             IDLE_STATE = 1'h 0,
             DONE_STATE = 1'h 1;

   //synthesis attribute SIGNAL_ENCODING of state is user;

   always @(*) begin

      s1_wr_data_msb_sel = 1'h 0;
      s2_wr_data_msb_sel = 1'h 0;

      reg_rd_data_nxt = {`CPCI_NF2_DATA_WIDTH {1'b 0}};
      reg_ack_nxt = 1'h 0;
      state_nxt = state;

      case (state)

        IDLE_STATE:

          if (reg_req) begin

             reg_ack_nxt = 1'b 1;
             state_nxt = DONE_STATE;

             case (reg_addr)
               `SRAM_MSB_SRAM1_RD : begin
                  reg_rd_data_nxt[3:0] = s1_rd_data_msb;

               end

               `SRAM_MSB_SRAM1_WR : begin
                  reg_rd_data_nxt[3:0] = s1_wr_data_msb;
                  s1_wr_data_msb_sel = 1'b 1;

               end

               `SRAM_MSB_SRAM2_RD : begin
                  reg_rd_data_nxt = s2_rd_data_msb;

               end

               `SRAM_MSB_SRAM2_WR : begin
                  reg_rd_data_nxt[17:16] = s2_wr_data_msb;
                  s2_wr_data_msb_sel = 1'b 1;

               end

               default: begin
                  reg_rd_data_nxt = 32'h deadbeaf;

               end

             endcase // casez(reg_addr)

          end // if (reg_req)

        DONE_STATE:
          if (!reg_req)
             state_nxt = IDLE_STATE;

      endcase // case(state)

   end // always @ (*)


   always @(posedge clk) begin
      if (reset) begin
         state <= IDLE_STATE;
	 reg_ack <= 1'b 0;
	 reg_rd_data <= {`CPCI_NF2_DATA_WIDTH {1'b 0}};

	 s1_wr_data_msb <= {(`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH) {1'b 0}};
	 s2_wr_data_msb <= {(`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH) {1'b 0}};

      end

      else begin
         state <= state_nxt;
	 reg_ack <= reg_ack_nxt;
	 reg_rd_data <= reg_rd_data_nxt;

	 if (s1_wr_data_msb_sel && !reg_rd_wr_L)
	   s1_wr_data_msb <= reg_wr_data[`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0];

	 if (s2_wr_data_msb_sel && !reg_rd_wr_L)
	   s2_wr_data_msb <= reg_wr_data[`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0];

      end

   end // always @ (posedge clk)

endmodule // reg_sram_msb

