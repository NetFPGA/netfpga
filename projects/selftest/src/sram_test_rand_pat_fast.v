//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: sram_test_rand_pat_fast.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: sram_test_rand_pat.v
// Project: NetFPGA
// Description: the module to perform pseudo-random patterns test
//              for external SRAM test
//
// The parent of this module asserts the initial seed for the pseudo-random
// test patterns and the start signals.
//
// When test is running, if error is detected, the log_vld is asserted
// for error logging.
//
// Upon test completion, the done signal is asserted and the fail signal
// is asserted if at least one error is detected.
//
///////////////////////////////////////////////////////////////////////////////

module sram_test_rand_pat_fast
  #(parameter SRAM_ADDR_WIDTH = 19,
    parameter SRAM_DATA_WIDTH = 36,
    parameter STOP_ADDR = {SRAM_ADDR_WIDTH {1'b 1}}
    )

  (
   //intfc to sram_ctrl
    output reg [SRAM_ADDR_WIDTH -1:0] addr,
   output reg [SRAM_DATA_WIDTH -1:0] wr_data,
   output reg tri_en,
   output reg we_bw,

   input [SRAM_DATA_WIDTH -1:0] rd_data,

   //intfc to test wrapper
   input start,
   input [SRAM_DATA_WIDTH -1:0] seed,

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

   reg tri_en_nxt, we_bw_nxt;
   reg [SRAM_ADDR_WIDTH -1:0] addr_nxt;
   reg [SRAM_DATA_WIDTH -1:0] wr_data_nxt, rand_num, rand_num_nxt;
   reg done_nxt, fail_nxt;

   reg log_vld_nxt;
   reg [SRAM_ADDR_WIDTH -1:0] log_addr_nxt;
   reg [SRAM_DATA_WIDTH -1:0] log_exp_data_nxt, log_rd_data_nxt;

   parameter PIPE_STAGE = 5;

   reg pipe_vld[0:PIPE_STAGE-1],
       pipe_vld_nxt[0:0];
   reg pipe_op[0:PIPE_STAGE-1],
       pipe_op_nxt[0:0];
   reg [SRAM_ADDR_WIDTH -1:0] pipe_addr[0:PIPE_STAGE-1],
			      pipe_addr_nxt[0:0];
   reg [SRAM_DATA_WIDTH -1:0] pipe_data[0:PIPE_STAGE-1],
			      pipe_data_nxt[0:0];

   reg 			      chk_fail;

   reg 			      sm_rd, sm_req;
   reg [SRAM_DATA_WIDTH -1:0] sm_wr_data;
   reg [SRAM_ADDR_WIDTH -1:0] sm_addr, sm_addr_nxt;

   wire [SRAM_ADDR_WIDTH -1:0] pipe_addr_4;
   wire 		       pipe_op_4;
   wire 		       pipe_vld_4;

   reg [1:0] state, state_nxt ;

   parameter
             IDLE_STATE = 2'h 0,
             WRITE_STATE = 2'h 1,
             READ_STATE = 2'h 2;

    always @(*) begin

       fail_nxt = fail;
       sm_req = 'h 0;
       sm_rd = 'h 1;
       sm_addr_nxt = sm_addr;
       sm_wr_data = 'h 0;
       rand_num_nxt = rand_num;
       done_nxt = 1'b 0;

       state_nxt = state;

       case (state)
         IDLE_STATE:
           if (start) begin
              fail_nxt = 1'b 0;

              sm_req = 1'b 1;
              sm_rd = 1'b 0;
              sm_addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
              sm_wr_data = seed;
              rand_num_nxt = rand_gen(seed);

              state_nxt = WRITE_STATE;
           end

         WRITE_STATE: begin

            if (sm_addr == STOP_ADDR) begin
               //finish wr. start read
	       sm_req = 'h 1;
               sm_addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
               rand_num_nxt = seed;

               state_nxt = READ_STATE;
            end
	    else begin
	       // do write
	       sm_req = 'h 1;
               sm_rd = 1'b 0;
               sm_addr_nxt = sm_addr + 1;
               sm_wr_data = rand_num;
               rand_num_nxt = rand_gen(rand_num);

	    end

         end // case: WRITE_STATE

         READ_STATE: begin
	    if (sm_addr != STOP_ADDR) begin
	       // do read
	       sm_req = 'h 1;
               sm_addr_nxt = sm_addr + 1;
               rand_num_nxt = rand_gen(rand_num);
	    end

	    fail_nxt = fail | chk_fail;

            if ((sm_addr == STOP_ADDR) &&
		pipe_vld_4 &&
		pipe_op_4 &&
		(pipe_addr_4 == STOP_ADDR)) begin
                 //finish rd
                 done_nxt = 1'b 1;

                 state_nxt = IDLE_STATE;
              end

           end // if (ack)

       endcase // case(state)

    end // always @ (*)

   //pipeline stages

   //stage 0: prepare addr, we_bw (active low for write)
   always @(*) begin
      addr_nxt = sm_addr_nxt;
      we_bw_nxt = sm_rd;

      pipe_vld_nxt[0] = sm_req;
      pipe_op_nxt[0] = sm_rd; //0: wr; 1: rd
      pipe_addr_nxt[0] = sm_addr_nxt;
      if (sm_rd)
	pipe_data_nxt[0] = rand_num_nxt;
      else
	pipe_data_nxt[0] = sm_wr_data;

   end

   //stage 1: wait a cycle


   //stage 2: prepare tri_en and wr_data

   wire pipe_op_1 = pipe_op[1];
   wire [SRAM_DATA_WIDTH -1:0] pipe_data_1 = pipe_data[1];

   always @(*) begin
      if (~pipe_op_1) begin
	 tri_en_nxt = 1'b 1;
	 wr_data_nxt = pipe_data_1;
      end
      else begin
	 tri_en_nxt = 1'b 0;
	 wr_data_nxt = {SRAM_DATA_WIDTH {1'h 0}};

      end

   end // always @ (*)


   //stage 3: wait

   //stage 4: wait


   //stage 5: sampling rd_data and comparing with expected value
   assign pipe_addr_4 = pipe_addr[4];
   assign pipe_op_4 = pipe_op[4];
   assign pipe_vld_4 = pipe_vld[4];
   wire [SRAM_DATA_WIDTH -1:0] pipe_data_4 = pipe_data[4];

   always @(*) begin
      chk_fail = 1'b 0;

      log_vld_nxt = 1'b 0;
      log_addr_nxt = {SRAM_ADDR_WIDTH {1'b 0}};
      log_exp_data_nxt = {SRAM_DATA_WIDTH {1'b 0}};
      log_rd_data_nxt = {SRAM_DATA_WIDTH {1'b 0}};

      if (pipe_op_4 & pipe_vld_4) begin
	 //rd
	 if (rd_data != pipe_data_4) begin
            chk_fail = 1'b 1;

            log_vld_nxt = 1'b 1;
            log_addr_nxt = pipe_addr_4;
            log_exp_data_nxt = pipe_data_4;
            log_rd_data_nxt = rd_data;
	 end

      end // if (pipe_op_4 & pipe_vld_4)


   end // always @ (*)

   always @(posedge clk) begin
      pipe_vld[0] <= pipe_vld_nxt[0];
      pipe_op[0] <= pipe_op_nxt[0];
      pipe_addr[0] <= pipe_addr_nxt[0];
      pipe_data[0] <= pipe_data_nxt[0];

      pipe_vld[1] <= pipe_vld[0];
      pipe_op[1] <= pipe_op[0];
      pipe_addr[1] <= pipe_addr[0];
      pipe_data[1] <= pipe_data[0];

      pipe_vld[2] <= pipe_vld[1];
      pipe_op[2] <= pipe_op[1];
      pipe_addr[2] <= pipe_addr[1];
      pipe_data[2] <= pipe_data[1];

      pipe_vld[3] <= pipe_vld[2];
      pipe_op[3] <= pipe_op[2];
      pipe_addr[3] <= pipe_addr[2];
      pipe_data[3] <= pipe_data[2];

      pipe_vld[4] <= pipe_vld[3];
      pipe_op[4] <= pipe_op[3];
      pipe_addr[4] <= pipe_addr[3];
      pipe_data[4] <= pipe_data[3];
   end


   always @(posedge clk) begin
        if (reset) begin
           sm_addr <= 'h 0;
	   addr <= {SRAM_ADDR_WIDTH {1'b 0}};
           wr_data <= {SRAM_DATA_WIDTH {1'b 0}};
	   tri_en <= 'h 0;
	   we_bw <= 'h 1;

           fail <= 1'b 0;
           rand_num <= {SRAM_DATA_WIDTH {1'b 0}};
           done <= 1'b 0;
           log_vld <= 1'b 0;
           log_addr <= {SRAM_ADDR_WIDTH {1'b 0}};
           log_exp_data <= {SRAM_DATA_WIDTH {1'b 0}};
           log_rd_data <= {SRAM_DATA_WIDTH {1'b 0}};

           state <= IDLE_STATE;

        end // if (reset)

        else begin
	   sm_addr <= sm_addr_nxt;
           addr <= addr_nxt;
           wr_data <= wr_data_nxt;
	   tri_en <= tri_en_nxt;
	   we_bw <= we_bw_nxt;

           fail <= fail_nxt;
           rand_num <= rand_num_nxt;
           done <= done_nxt;
           log_vld <= log_vld_nxt;
           log_addr <= log_addr_nxt;
           log_exp_data <= log_exp_data_nxt;
           log_rd_data <= log_rd_data_nxt;

           state <= state_nxt;

        end // else: !if(reset)

   end // always @ (posedge clk)

   // 36-bit psuedo-random pattern generatior
   function [36 -1: 0] rand_gen ;
      input [36 -1: 0] rand_prev;

      reg feed_in;

      begin
         feed_in = (rand_prev[35] ^ rand_prev[24]) ^ ( ~ (|rand_prev[34:0]) );

         rand_gen = {rand_prev[34:0], feed_in};

      end

   endfunction // rand_gen

endmodule // sram_test_rand_pat_fast

