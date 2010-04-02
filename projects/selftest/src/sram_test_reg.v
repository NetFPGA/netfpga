//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: sram_test_reg.v 5983 2010-03-07 03:30:11Z grg $
//
// Module: sram_test_reg.v
// Project: NetFPGA
// Description: the module implements the configuration, status and log
//              registers for external SRAM test.
//
// CPU can read/write these SRAM test configuration, status and log registers.
//
///////////////////////////////////////////////////////////////////////////////


module sram_test_reg
  #(
     parameter SRAM_ADDR_WIDTH = 19,
     parameter SRAM_DATA_WIDTH = 36,
     parameter TOTAL_TEST_NUM = 5
     )
    (
     //intfc to cpu
     input reg_req,
     input reg_rd_wr_L,
     input [`SRAM_TEST_REG_ADDR_WIDTH-1:0] reg_addr,
     input [`CPCI_NF2_DATA_WIDTH -1:0] reg_wr_data,

     output reg reg_ack,
     output reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data,

     //intfc to tests
     input log_vld,
     input [SRAM_ADDR_WIDTH :0] log_addr,
     input [SRAM_DATA_WIDTH -1:0] log_exp_data, log_rd_data,

     output reg [SRAM_DATA_WIDTH -1:0] rand_seed,
     output test_start,
     output reg [TOTAL_TEST_NUM -1:0] test_en,
     output reg [1:0] sram_en,

     //intfc to tester
     input one_test_done,
     input one_test_fail,
     input [2:0] test_idx,
     input sram_idx,

     input done,
     input success,

     //intfc to misc
     input clk,
     input reset
   );

   parameter
             ERR_LOG_ARRAY_ADDR_BIT_NUM = 4,
             ERR_LOG_ARRAY_DEPTH = 1 << ERR_LOG_ARRAY_ADDR_BIT_NUM;

   reg reg_ack_nxt;
   reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data_nxt;

   // there are 16 log registers. err_cnt is up to 5'h 10.
   reg [31 :0] err_cnt;

   // Iteration counters
   reg [31:0] iter_num;
   reg [31:0] bad_runs_cnt;
   reg [31:0] good_runs_cnt;

   // wrt_ptr is up to 4'h F.
   reg [ERR_LOG_ARRAY_ADDR_BIT_NUM -1 :0] wrt_ptr;

   // 20-bit addr = 1-bit for chip idx + 19-bit sram addr
   reg [SRAM_ADDR_WIDTH :0] err_log_addr_array [0 : ERR_LOG_ARRAY_DEPTH -1];

   // 36-bit expected data, 36-bit actual read data
   reg [SRAM_DATA_WIDTH -1:0] err_log_exp_data_array [0 : ERR_LOG_ARRAY_DEPTH -1];
   reg [SRAM_DATA_WIDTH -1:0] err_log_rd_data_array [0 : ERR_LOG_ARRAY_DEPTH -1];

   reg rand_seed_hi_sel, rand_seed_lo_sel, test_en_sel;
   reg test_ctrl_sel;
   reg reset_d;

   reg test_run;
   reg test_repeat;
   reg err_cnt_clear;

   reg done_d1;

   // select one out of 16 log registers
   wire [ERR_LOG_ARRAY_ADDR_BIT_NUM -1:0] array_idx = reg_addr[6:3];

   reg [SRAM_ADDR_WIDTH :0] err_log_addr;
   reg [SRAM_DATA_WIDTH -1:0] tmp_exp_data;
   reg [SRAM_DATA_WIDTH -1:0] tmp_rd_data;

   always @(posedge clk) begin
      err_log_addr <= err_log_addr_array[array_idx];
      tmp_exp_data <= err_log_exp_data_array[array_idx];
      tmp_rd_data <= err_log_rd_data_array[array_idx];
   end

   wire [3:0] err_log_exp_data_hi_3_bit =   tmp_exp_data[35:32];
   wire [31:0] err_log_exp_data_lo_32_bit = tmp_exp_data[31: 0];

   wire [3:0] err_log_rd_data_hi_3_bit =   tmp_rd_data[35:32];
   wire [31:0] err_log_rd_data_lo_32_bit = tmp_rd_data[31: 0];

   reg [TOTAL_TEST_NUM -1:0] test_done_0, test_done_0_nxt;
   reg [TOTAL_TEST_NUM -1:0] test_fail_0, test_fail_0_nxt;
   reg [TOTAL_TEST_NUM -1:0] test_done_1, test_done_1_nxt;
   reg [TOTAL_TEST_NUM -1:0] test_fail_1, test_fail_1_nxt;

   reg [1:0] state, state_nxt;

   parameter
             IDLE_STATE = 2'h 0,
             BRAM_RD_STATE = 2'h 1,
             DONE_STATE = 2'h 2;

   //synthesis attribute SIGNAL_ENCODING of state is user;

   always @(*) begin

      rand_seed_hi_sel = 1'h 0;
      rand_seed_lo_sel = 1'h 0;
      test_en_sel = 1'b 0;
      test_ctrl_sel = 1'b 0;

      reg_rd_data_nxt = {`CPCI_NF2_DATA_WIDTH {1'b 0}};
      reg_ack_nxt = 1'h 0;
      state_nxt = state;

      case (state)

        IDLE_STATE:

          if (reg_req) begin

             reg_ack_nxt = 1'b 1;
             state_nxt = DONE_STATE;

             casez (reg_addr[`SRAM_TEST_REG_ADDR_WIDTH-1:0])
               `SRAM_TEST_ERR_CNT: begin
                  reg_rd_data_nxt[4:0] = err_cnt;
               end

               `SRAM_TEST_ITER_NUM: begin
                  reg_rd_data_nxt = iter_num;
               end

               `SRAM_TEST_BAD_RUNS: begin
                  reg_rd_data_nxt = bad_runs_cnt;
               end

               `SRAM_TEST_GOOD_RUNS: begin
                  reg_rd_data_nxt = good_runs_cnt;
               end

               `SRAM_TEST_STATUS: begin
                  //sram_1:
                  reg_rd_data_nxt[`SRAM_TEST_STATUS_FAIL_2_POS_LO +: TOTAL_TEST_NUM] = test_fail_1;
                  reg_rd_data_nxt[`SRAM_TEST_STATUS_DONE_2_POS_LO +: TOTAL_TEST_NUM] = test_done_1;

                  //sram_0:
                  reg_rd_data_nxt[`SRAM_TEST_STATUS_FAIL_1_POS_LO +: TOTAL_TEST_NUM] = test_fail_0;
                  reg_rd_data_nxt[`SRAM_TEST_STATUS_DONE_1_POS_LO +: TOTAL_TEST_NUM] = test_done_0;
               end

               `SRAM_TEST_EN: begin
                  reg_rd_data_nxt[`SRAM_TEST_ENABLE_SRAM_EN_POS_HI : `SRAM_TEST_ENABLE_SRAM_EN_POS_LO] = sram_en;
                  reg_rd_data_nxt[`SRAM_TEST_ENABLE_TEST_EN_POS_LO +: TOTAL_TEST_NUM] = test_en;
                  test_en_sel = 1'b 1;
               end

               `SRAM_TEST_CTRL: begin
                  test_ctrl_sel = 1'b 1;
               end

               `SRAM_TEST_RAND_SEED_HI: begin
                  reg_rd_data_nxt[3:0] = rand_seed[35:32];
                  rand_seed_hi_sel = 1'b 1;
               end

               `SRAM_TEST_RAND_SEED_LO: begin
                  reg_rd_data_nxt = rand_seed[31:0];
                  rand_seed_lo_sel = 1'b 1;
               end

               `SRAM_TEST_REG_ADDR_WIDTH'b 1???_????_????_????: begin
                  reg_ack_nxt = 1'b 0;
                  state_nxt = BRAM_RD_STATE;

               end

               default: begin
                  reg_rd_data_nxt = 32'h deadbeaf;

               end

             endcase // casez(reg_addr[`SRAM_TEST_REG_ADDR_WIDTH-1:0])

          end // if (reg_req)


        BRAM_RD_STATE: begin


           //-------------------------------------------------
           // log register array

           reg_ack_nxt = 1'b 1;

           casez (reg_addr[`SRAM_TEST_REG_ADDR_WIDTH-1:0])

             16'b 1???_????_????_?000: begin
                reg_rd_data_nxt[19:0] = err_log_addr;
             end

             16'b 1???_????_????_?001: begin
                reg_rd_data_nxt[3:0] = err_log_exp_data_hi_3_bit;
             end

             16'b 1???_????_????_?010: begin
                reg_rd_data_nxt[31:0] = err_log_exp_data_lo_32_bit;
             end

             16'b 1???_????_????_?011: begin
                reg_rd_data_nxt[3:0] = err_log_rd_data_hi_3_bit;
             end

             16'b 1???_????_????_?100: begin
                reg_rd_data_nxt = err_log_rd_data_lo_32_bit;
             end

             default: begin
                reg_rd_data_nxt = 32'h deadbeef;
             end

           endcase // case(reg_addr[`SRAM_TEST_REG_ADDR_WIDTH-1:0])

           state_nxt = DONE_STATE;

        end // case: BRAM_RD_STATE


        DONE_STATE:
            if (!reg_req)
               state_nxt = IDLE_STATE;

      endcase // case(state)

   end // always @ (*)


   always @(*) begin

      test_done_0_nxt = test_done_0;
      test_fail_0_nxt = test_fail_0;

      test_done_1_nxt = test_done_1;
      test_fail_1_nxt = test_fail_1;

      if (one_test_done) begin
         case ( {sram_idx, test_idx} )
           //sram_0
           4'b 0_000: begin
              test_done_0_nxt[0] = 1'b 1;
              test_fail_0_nxt[0] = one_test_fail;
           end

           4'b 0_001: begin
              test_done_0_nxt[1] = 1'b 1;
              test_fail_0_nxt[1] = one_test_fail;
           end

           4'b 0_010: begin
              test_done_0_nxt[2] = 1'b 1;
              test_fail_0_nxt[2] = one_test_fail;
           end

           4'b 0_011: begin
              test_done_0_nxt[3] = 1'b 1;
              test_fail_0_nxt[3] = one_test_fail;
           end

           4'b 0_100: begin
              test_done_0_nxt[4] = 1'b 1;
              test_fail_0_nxt[4] = one_test_fail;
           end

           //sram_1
           4'b 1_000: begin
              test_done_1_nxt[0] = 1'b 1;
              test_fail_1_nxt[0] = one_test_fail;
           end

           4'b 1_001: begin
              test_done_1_nxt[1] = 1'b 1;
              test_fail_1_nxt[1] = one_test_fail;
           end

           4'b 1_010: begin
              test_done_1_nxt[2] = 1'b 1;
              test_fail_1_nxt[2] = one_test_fail;
           end

           4'b 1_011: begin
              test_done_1_nxt[3] = 1'b 1;
              test_fail_1_nxt[3] = one_test_fail;
           end

           4'b 1_100: begin
              test_done_1_nxt[4] = 1'b 1;
              test_fail_1_nxt[4] = one_test_fail;
           end

         endcase // case(sram_idx, test_idx)

      end // if (oen_test_done)

   end // always @ (*)


   always @(posedge clk) begin
      if (reset | test_start) begin
         err_cnt <= { (ERR_LOG_ARRAY_ADDR_BIT_NUM +1) {1'h 0}};
         wrt_ptr <= { ERR_LOG_ARRAY_ADDR_BIT_NUM {1'h 0}};
      end
      else begin
         if ( log_vld )
           err_cnt <= err_cnt + 'h1;

         if ( log_vld && (wrt_ptr < (ERR_LOG_ARRAY_DEPTH -1) ) )
           wrt_ptr <= wrt_ptr + 'h1;
      end // else: !if(reset | test_start)
   end // always @ (posedge clk)

   always @(posedge clk) begin
      if (reset || (test_run || test_repeat) && done) begin
         test_done_0 <= {TOTAL_TEST_NUM {1'b 0}};
         test_fail_0 <= {TOTAL_TEST_NUM {1'b 0}};

         test_done_1 <= {TOTAL_TEST_NUM {1'b 0}};
         test_fail_1 <= {TOTAL_TEST_NUM {1'b 0}};
      end
      else begin
         test_done_0 <= test_done_0_nxt;
         test_fail_0 <= test_fail_0_nxt;

         test_done_1 <= test_done_1_nxt;
         test_fail_1 <= test_fail_1_nxt;
      end // else: !if(reset_core | test_start)
   end // always @ (posedge clk_core_12)

   // Update the iteration counters
   always @(posedge clk) begin
      if (reset || test_run && done) begin
         iter_num <= 'h1;
         bad_runs_cnt <= 'h0;
         good_runs_cnt <= 'h0;
      end
      else if (done && !done_d1) begin
         if (test_repeat)
            iter_num <= iter_num + 'h1;

         if (success)
            good_runs_cnt <= good_runs_cnt + 'h1;
         else
            bad_runs_cnt <= bad_runs_cnt + 'h1;
      end
   end

   always @(posedge clk) begin
      if (reset) begin
         reset_d <= 1'b 1;

         rand_seed <= {SRAM_DATA_WIDTH {1'h 0}};
         sram_en <= 2'b 11;
         test_en <= {TOTAL_TEST_NUM {1'b 1}};
         test_run <= 1'b 1;
         test_repeat <= 1'b 0;
         err_cnt_clear <= 1'b 0;

         reg_ack <= 1'b 0;
         reg_rd_data <= {SRAM_DATA_WIDTH {1'b 0}};

         state <= IDLE_STATE;

         done_d1 <= 1'b 0;

      end

      else begin
         reset_d <= reset;

         if (rand_seed_hi_sel && (! reg_rd_wr_L))
           rand_seed[SRAM_DATA_WIDTH -1:32] <= reg_wr_data[SRAM_DATA_WIDTH -33:0];

         if (rand_seed_lo_sel && (! reg_rd_wr_L))
           rand_seed[31:0] <= reg_wr_data[31:0];

         if (test_en_sel && (! reg_rd_wr_L)) begin
            sram_en <= reg_wr_data[`SRAM_TEST_ENABLE_TEST_EN_POS_HI : `SRAM_TEST_ENABLE_TEST_EN_POS_LO];
            test_en <= reg_wr_data[`SRAM_TEST_ENABLE_SRAM_EN_POS_LO +: TOTAL_TEST_NUM];
         end

         if (test_ctrl_sel && (! reg_rd_wr_L)) begin
            // Set test_run if the test_repeat flag is set and the test module
            // is currently sitting idle. This forces counters etc to reset
            test_run <= (reg_wr_data[`SRAM_TEST_CTRL_RUN_POS] ||
               (reg_wr_data[`SRAM_TEST_CTRL_REPEAT_POS] && done)) && |test_en;
            test_repeat <= reg_wr_data[`SRAM_TEST_CTRL_REPEAT_POS] && |test_en;
            err_cnt_clear <= reg_wr_data[`SRAM_TEST_CTRL_RESET_ERR_CNT_POS];
         end
         else begin
            // Clear the test run flag once the test module has entered the
            // done state. The test module will see the start signal and thus
            // run the test.
            if (done_d1)
               test_run <= 1'b0;

            err_cnt_clear <= 1'b0;
         end

         if ( log_vld && ( err_cnt < ERR_LOG_ARRAY_DEPTH ) ) begin
            err_log_addr_array[wrt_ptr] <= log_addr;
            err_log_exp_data_array[wrt_ptr] <= log_exp_data;
            err_log_rd_data_array[wrt_ptr] <= log_rd_data;
         end

         reg_ack <= reg_ack_nxt;
         reg_rd_data <= reg_rd_data_nxt;

         state <= state_nxt;

         done_d1 <= done;

      end // else: !if(reset)

   end // always @ (posedge clk)

   assign test_start = test_run | test_repeat;

endmodule // sram_test_reg
