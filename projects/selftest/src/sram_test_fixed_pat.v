//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: sram_test_fixed_pat.v 1348 2007-02-21 19:58:35Z jyluo $
//
// Module: sram_test_fixed_pat.v
// Project: NetFPGA
// Description: the module to perform a fixed pattern test
//              for external SRAM test
//
// The parent of this module asserts the test pattern and the start
// signals.
//
// When test is running, if error is detected, the log_vld is asserted
// for error logging.
//
// Upon test completion, the done signal is asserted and the fail signal
// is asserted if at least one error is detected.
//
///////////////////////////////////////////////////////////////////////////////


module sram_test_fixed_pat
  #(parameter SRAM_ADDR_WIDTH = 19,
    parameter SRAM_DATA_WIDTH = 36,
    parameter STOP_ADDR = {SRAM_ADDR_WIDTH {1'b 0}}
    )

  (
   //intfc to sram_ctrl
   output reg req,
   output reg rd,
   output reg [SRAM_ADDR_WIDTH -1:0] addr,
   output reg [SRAM_DATA_WIDTH -1:0] wr_data,

   input ack,
   input [SRAM_DATA_WIDTH -1:0] rd_data,

   //intfc to test wrapper
   input start,
   input [SRAM_DATA_WIDTH -1:0] pattern,

   output reg done,
   output reg fail,

   //to log registers
   output reg log_vld,
   output reg [SRAM_ADDR_WIDTH -1:0] log_addr,
   output reg [SRAM_DATA_WIDTH -1:0] log_exp_data, log_rd_data,

   //intfc to misc
   input clk,
   input reset
   );

   reg req_nxt, rd_nxt;
   reg [SRAM_ADDR_WIDTH -1:0] addr_nxt;
   reg [SRAM_DATA_WIDTH -1:0] wr_data_nxt;
   reg done_nxt, fail_nxt;

   reg log_vld_nxt;
   reg [SRAM_ADDR_WIDTH -1:0] log_addr_nxt;
   reg [SRAM_DATA_WIDTH -1:0] log_exp_data_nxt, log_rd_data_nxt;

   reg [1:0] state, state_nxt ;

   parameter
             IDLE_STATE = 2'h 0,
             WRITE_STATE = 2'h 1,
             READ_STATE = 2'h 2;

    always @(*) begin

       fail_nxt = fail;
       req_nxt = req;
       rd_nxt = rd;
       addr_nxt = addr;
       wr_data_nxt = wr_data;
       done_nxt = 1'b 0;
       state_nxt = state;

       log_vld_nxt = 1'b 0;
       log_addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
       log_exp_data_nxt = {SRAM_DATA_WIDTH {1'b 0}};
       log_rd_data_nxt = {SRAM_DATA_WIDTH {1'b 0}};

       case (state)
         IDLE_STATE:
           if (start) begin
              fail_nxt = 1'b 0;

              req_nxt = 1'b 1;
              rd_nxt = 1'b 0;
              addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
              wr_data_nxt = pattern;

              state_nxt = WRITE_STATE;
           end

         WRITE_STATE:
            if (ack) begin
               addr_nxt = addr + 1;

               if (addr_nxt == STOP_ADDR) begin
                  //finish wr
                  rd_nxt = 1'b 1;
                  addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
                  wr_data_nxt = {SRAM_DATA_WIDTH {1'b 0}};

                  state_nxt = READ_STATE;
               end

            end // if (ack)

         READ_STATE:
           if (ack) begin
              if (rd_data != pattern) begin
                 fail_nxt = 1'b 1;

                 log_vld_nxt = 1'b 1;
                 log_addr_nxt = addr;
                 log_exp_data_nxt = pattern;
                 log_rd_data_nxt = rd_data;
              end

              addr_nxt = addr + 1;

              if (addr_nxt == STOP_ADDR) begin
                 //finish rd
                 req_nxt = 1'b 0;
                 done_nxt = 1'b 1;

                 state_nxt = IDLE_STATE;
              end

           end // if (ack)

       endcase // case(state)

    end // always @ (*)


   always @(posedge clk) begin
        if (reset) begin
           fail <= 1'b 0;
           req <= 1'b 0;
           rd <= 1'b 1;
           addr <= {SRAM_ADDR_WIDTH {1'b 0}};
           wr_data <= {SRAM_DATA_WIDTH {1'b 0}};
           done <= 1'b 0;
           log_vld <= 1'b 0;
           log_addr <= {SRAM_ADDR_WIDTH {1'b 0}};
           log_exp_data <= {SRAM_DATA_WIDTH {1'b 0}};
           log_rd_data <= {SRAM_DATA_WIDTH {1'b 0}};

           state <= IDLE_STATE;

        end

        else begin
           fail <= fail_nxt;
           req <= req_nxt;
           rd <= rd_nxt;
           addr <= addr_nxt;
           wr_data <= wr_data_nxt;
           done <= done_nxt;
           log_vld <= log_vld_nxt;
           log_addr <= log_addr_nxt;
           log_exp_data <= log_exp_data_nxt;
           log_rd_data <= log_rd_data_nxt;

           state <= state_nxt;

        end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // sram_test_fixed_pat



