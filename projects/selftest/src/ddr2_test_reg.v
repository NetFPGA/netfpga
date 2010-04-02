///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: ddr2_test_reg.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: ddr2_test_reg.v
// Project: NetFPGA
// Description: Configuration, status and control registers for the DDR2 test
//
// Note: Based heavily upon sram_test_reg.v
//       Clock-domain crossing is performed inside this module
//
///////////////////////////////////////////////////////////////////////////////

module ddr2_test_reg
   #(
      parameter DRAM_ADDR_WIDTH = 24, // 2 - BA  +  22 - Addr
      parameter DRAM_DATA_WIDTH = 64,
      parameter TOTAL_TEST_NUM = 5
    )
    (
      // Register interface
      input reg_req,
      input reg_rd_wr_L,
      input [`DRAM_TEST_REG_ADDR_WIDTH-1:0] reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0] reg_wr_data,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data,
      output reg reg_ack,

      // Self-test interface
      input log_wr,
      output log_rdy,
      input [DRAM_ADDR_WIDTH - 1: 0] log_addr,
      input [DRAM_DATA_WIDTH - 1 : 0] log_exp_data,
      input [DRAM_DATA_WIDTH - 1 : 0] log_rd_data,

      output reg [DRAM_DATA_WIDTH / 2 - 1 : 0] rand_seed,
      output reg test_start,
      output reg [TOTAL_TEST_NUM - 1 : 0] test_en,

      input curr_test_done,
      input curr_test_pass,
      input [2:0] curr_test_idx,
      input done,
      input success,
      input idle,

      // Clock/reset
      input clk_core_125,
      input clk_ddr_200,
      input reset_ddr,
      input reset_core
   );

   localparam
             ERR_LOG_ARRAY_ADDR_BIT_NUM = 4,
             ERR_LOG_ARRAY_DEPTH = 1 << ERR_LOG_ARRAY_ADDR_BIT_NUM;

   localparam START_LEN = 5;

   // ====================================
   // Log storage arrays
   // ====================================

   // Address array
   reg [DRAM_ADDR_WIDTH -1:0] err_log_addr_array [0 : ERR_LOG_ARRAY_DEPTH -1];

   // Expected and read data arrays
   reg [DRAM_DATA_WIDTH -1:0] err_log_exp_data_array [0 : ERR_LOG_ARRAY_DEPTH -1];
   reg [DRAM_DATA_WIDTH -1:0] err_log_rd_data_array [0 : ERR_LOG_ARRAY_DEPTH -1];

   // Error counter (note: should saturate not wrap)
   reg [31:0] err_cnt;

   // Iteration counters
   reg [31:0] iter_num;
   reg [31:0] bad_runs_cnt;
   reg [31:0] good_runs_cnt;

   // Current entry being written
   reg [ERR_LOG_ARRAY_ADDR_BIT_NUM -1 :0] wr_ptr;

   // The current value of the random seed
   reg [DRAM_DATA_WIDTH / 2 - 1 : 0] rand_seed_125;
   reg [DRAM_DATA_WIDTH / 2 - 1 : 0] rand_seed_200;

   reg reg_ack_nxt;
   reg reg_ack_done;
   reg reg_ack_done_nxt;
   reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data_nxt;

   reg rand_seed_sel;
   reg test_en_sel;
   reg test_ctrl_sel;

   reg test_run;
   reg test_repeat;
   reg err_cnt_clear;

   wire test_start_125;
   reg test_start_200;

   // Index to select which of the array elements to view
   wire [ERR_LOG_ARRAY_ADDR_BIT_NUM -1:0] array_idx = reg_addr[6:3];

   reg [DRAM_ADDR_WIDTH - 1 : 0] err_log_addr;
   reg [DRAM_DATA_WIDTH - 1 : 0] tmp_exp_data;
   reg [DRAM_DATA_WIDTH - 1 : 0] tmp_rd_data;


   wire [DRAM_ADDR_WIDTH -1:0] log_addr_125;
   wire [DRAM_DATA_WIDTH -1:0] log_exp_data_125;
   wire [DRAM_DATA_WIDTH -1:0] log_rd_data_125;

   wire log_empty;
   reg log_empty_d1;

   reg curr_test_done_tgl_200;
   reg curr_test_pass_200_d1;
   reg [2:0] curr_test_idx_200_d1;

   reg curr_test_done_tgl_125;
   reg curr_test_done_tgl_125_d1;
   reg curr_test_done_tgl_125_d2;
   reg curr_test_done_125;
   reg curr_test_pass_125;
   reg [2:0] curr_test_idx_125;

   reg done_tgl_200;
   reg done_tgl_125;
   reg done_tgl_125_d1;
   reg done_tgl_125_d2;
   reg done_200_d1;
   reg done_125;
   reg success_200_d1;
   reg success_125;

   reg idle_125_p1;
   reg idle_125;

   reg reset_ddr_125;
   reg reset_ddr_125_d1;

   // ===================================================
   // Clock domain crossing for log data to be written
   // ===================================================

   ddr2_test_fifo ddr2_test_fifo(
	.din ({log_addr, log_exp_data, log_rd_data}),
	.wr_en (log_wr),
	.full (log_full),
	.wr_clk (clk_ddr_200),
        .dout ({log_addr_125, log_exp_data_125, log_rd_data_125}),
	.rd_en (!log_empty),
	.empty (log_empty),
	.rd_clk (clk_core_125),
	.rst (reset_core | err_cnt_clear | test_run & done_125));

   assign log_rdy = !log_full;

   // DDR -> Core
   // Reset sigal
   always @(posedge clk_core_125)
   begin
      reset_ddr_125 <= reset_ddr;
      reset_ddr_125_d1 <= reset_ddr_125;
   end

   // DDR -> Core
   // DDR Clk, log and current test signals
   always @(posedge clk_ddr_200)
   begin
      if (reset_ddr) begin
         curr_test_done_tgl_200 <= 1'b0;
         curr_test_pass_200_d1 <= 1'b0;
         curr_test_idx_200_d1 <= curr_test_idx;

         done_tgl_200 <= 1'b0;
         done_200_d1 <= 1'b0;
         success_200_d1 <= 1'b0;
      end
      else begin
         if (curr_test_done) begin
            curr_test_done_tgl_200 <= !curr_test_done_tgl_200 ;
            curr_test_pass_200_d1 <= curr_test_pass;
            curr_test_idx_200_d1 <= curr_test_idx;
         end

         if (done && !done_200_d1) begin
            done_tgl_200 <= !done_tgl_200;
            success_200_d1 <= success;
         end

         done_200_d1 <= done;
      end
   end

   // DDR -> Core
   // Core Clk, current signals
   always @(posedge clk_core_125)
   begin
      curr_test_done_tgl_125 <= curr_test_done_tgl_200;
      curr_test_done_tgl_125_d1 <= curr_test_done_tgl_125;
      curr_test_done_tgl_125_d2 <= curr_test_done_tgl_125_d1;

      done_tgl_125 <= done_tgl_200;
      done_tgl_125_d1 <= done_tgl_125;
      done_tgl_125_d2 <= done_tgl_125_d1;

      // Bring the 200 MHZ buses across to the 125 MHz domain
      //
      // Note: The bus signals have been stable for at least
      // a 125 MHz clock period
      if (curr_test_done_tgl_125_d2 != curr_test_done_tgl_125_d1) begin
         curr_test_pass_125 <= curr_test_pass_200_d1;
         curr_test_idx_125 <= curr_test_idx_200_d1;

         curr_test_done_125 <= 1'b1;
      end
      else
         curr_test_done_125 <= 1'b0;

      if (done_tgl_125_d2 != done_tgl_125_d1) begin
         done_125 <= 1'b1;
         success_125 <= success_200_d1;
      end
      else
         done_125 <= 1'b0;

      idle_125_p1 <= idle;
      idle_125 <= idle;
   end

   // Core -> DDR
   // DDR clock, test start signal
   always @(posedge clk_ddr_200)
   begin
      test_start_200 <= test_start_125;
      test_start <= test_start_200;

      rand_seed_200 <= rand_seed_125;
      rand_seed <= rand_seed_125;
   end


   // ===================================================
   // Host register access
   // ===================================================

   // Extract the array data being read
   //
   // Note: Could be reading another address but that's okay
   always @(posedge clk_core_125) begin
      err_log_addr <= err_log_addr_array[array_idx];
      tmp_exp_data <= err_log_exp_data_array[array_idx];
      tmp_rd_data <= err_log_rd_data_array[array_idx];
   end

   wire [31:0] err_log_exp_data_hi_word = tmp_exp_data[63:32];
   wire [31:0] err_log_exp_data_lo_word = tmp_exp_data[31: 0];

   wire [31:0] err_log_rd_data_hi_word = tmp_rd_data[63:32];
   wire [31:0] err_log_rd_data_lo_word = tmp_rd_data[31: 0];

   reg [TOTAL_TEST_NUM -1:0] test_done, test_done_nxt;
   reg [TOTAL_TEST_NUM -1:0] test_fail, test_fail_nxt;

   reg [1:0] state, state_nxt;

   parameter
             IDLE_STATE = 2'h 0,
             BRAM_RD_STATE = 2'h 1,
             DONE_STATE = 2'h 2;

   //synthesis attribute SIGNAL_ENCODING of state is user;

   // Register reads
   always @(*) begin
      // Default values
      rand_seed_sel = 1'b 0;
      test_en_sel = 1'b 0;
      test_ctrl_sel = 1'b 0;

      reg_rd_data_nxt = 'h0;
      reg_ack_nxt = 1'b 0;
      state_nxt = state;
      reg_ack_done_nxt = reg_req && reg_ack_done;

      if (reset_core) begin
         reg_ack_done_nxt = 1'b0;
         state_nxt = IDLE_STATE;
      end
      else
         case (state)
            IDLE_STATE: begin
               if (reg_req && !reg_ack_done) begin
                  reg_ack_nxt = 1'b 1;
                  reg_ack_done_nxt = 1'b 1;
                  state_nxt = DONE_STATE;

                  casez (reg_addr[`DRAM_TEST_REG_ADDR_WIDTH-1:0])
                     `DRAM_TEST_ERR_CNT: begin
                        reg_rd_data_nxt = err_cnt;
                     end

                     `DRAM_TEST_ITER_NUM: begin
                        reg_rd_data_nxt = iter_num;
                     end

                     `DRAM_TEST_BAD_RUNS: begin
                        reg_rd_data_nxt = bad_runs_cnt;
                     end

                     `DRAM_TEST_GOOD_RUNS: begin
                        reg_rd_data_nxt = good_runs_cnt;
                     end

                    `DRAM_TEST_STATUS: begin
                        reg_rd_data_nxt[TOTAL_TEST_NUM -1+ 8 :  8] = test_fail;
                        reg_rd_data_nxt[TOTAL_TEST_NUM -1    :  0] = test_done;
                     end

                     `DRAM_TEST_EN: begin
                        reg_rd_data_nxt[TOTAL_TEST_NUM -1 : 0] = test_en;
                        test_en_sel = 1'b 1;
                     end

                     `DRAM_TEST_CTRL: begin
                        reg_rd_data_nxt[TOTAL_TEST_NUM -1 : 0] = {30'b0, test_repeat, test_run};
                        test_ctrl_sel = 1'b 1;
                     end

                     `DRAM_TEST_RAND_SEED: begin
                        reg_rd_data_nxt = rand_seed_125[31:0];
                        rand_seed_sel = 1'b 1;
                     end

                     16'b 1???_????_????_????: begin
                        reg_ack_nxt = 1'b 0;
                        reg_ack_done_nxt = 1'b 0;
                        state_nxt = BRAM_RD_STATE;
                     end

                     default: begin
                        reg_rd_data_nxt = 32'h deadbeaf;
                     end
                  endcase // casez(reg_addr[`DRAM_TEST_REG_ADDR_WIDTH-1:0])
               end // if (reg_req)
            end

            BRAM_RD_STATE: begin
               // Access the log register array
               reg_ack_nxt = 1'b 1;
               reg_ack_done_nxt = 1'b 1;
               state_nxt = DONE_STATE;

               casez (reg_addr[`DRAM_TEST_REG_ADDR_WIDTH-1:0])
                  16'b 1???_????_????_?000: begin
                     reg_rd_data_nxt = err_log_addr;
                  end

                  16'b 1???_????_????_?001: begin
                     reg_rd_data_nxt = err_log_exp_data_hi_word;
                  end

                  16'b 1???_????_????_?010: begin
                     reg_rd_data_nxt = err_log_exp_data_lo_word;
                  end

                  16'b 1???_????_????_?011: begin
                     reg_rd_data_nxt = err_log_rd_data_hi_word;
                  end

                  16'b 1???_????_????_?100: begin
                     reg_rd_data_nxt = err_log_rd_data_lo_word;
                  end

                  default: begin
                     reg_rd_data_nxt = 32'h deadbeef;
                  end
               endcase // case(reg_addr[`DRAM_TEST_REG_ADDR_WIDTH-1:0])
            end // case: BRAM_RD_STATE

            DONE_STATE: begin
              state_nxt = IDLE_STATE;
            end
         endcase // case(state)
   end // always @ (*)

   // Update the test done/test fail registers
   always @(*) begin
      test_done_nxt = test_done;
      test_fail_nxt = test_fail;

      if (curr_test_done_125) begin
         test_done_nxt[curr_test_idx_125] = 1'b1;
         test_fail_nxt[curr_test_idx_125] = !curr_test_pass_125;
      end // if (curr_test_done_125)
   end // always @ (*)

   // Update the done/test fail/pointer registers
   always @(posedge clk_core_125) begin
      if (reset_core || err_cnt_clear || test_run && (done_125 || idle_125)) begin
         err_cnt <= 'h0;
         wr_ptr <= 'h0;
      end
      else begin
         if ( !log_empty_d1 )
            err_cnt <= err_cnt + 'h1;

         if ( !log_empty_d1 && (wr_ptr != (ERR_LOG_ARRAY_DEPTH -1) ) )
            wr_ptr <= wr_ptr + 'h1;
      end // else: !if(reset_core | test_start)
   end // always @ (posedge clk_core_12)

   always @(posedge clk_core_125) begin
      if (reset_core || (test_run || test_repeat) && (done_125 || idle_125)) begin
         test_done <= 'h0;
         test_fail <= 'h0;
      end
      else begin
         test_done <= test_done_nxt;
         test_fail <= test_fail_nxt;
      end // else: !if(reset_core | test_start)
   end // always @ (posedge clk_core_12)

   // Update the iteration counters
   always @(posedge clk_core_125) begin
      if (reset_core || test_run && (done_125 || idle_125)) begin
         iter_num <= 'h1;
         bad_runs_cnt <= 'h0;
         good_runs_cnt <= 'h0;
      end
      else if (done_125) begin
         if (test_repeat)
            iter_num <= iter_num + 'h1;

         if (success_125)
            good_runs_cnt <= good_runs_cnt + 'h1;
         else
            bad_runs_cnt <= bad_runs_cnt + 'h1;
      end
   end

   // Register writes
   always @(posedge clk_core_125) begin
      if (reset_core) begin
         rand_seed_125 <= 'h1;
         test_en <= {TOTAL_TEST_NUM {1'b 1}};

         test_run <= 1'b 1;
         test_repeat <= 1'b 0;
         err_cnt_clear <= 1'b 0;

         reg_ack <= 1'b 0;
         reg_rd_data <= 'h0;

         state <= IDLE_STATE;
         log_empty_d1 <= 1'b0;
      end
      else begin
         if (rand_seed_sel && (! reg_rd_wr_L))
           rand_seed_125[31:0] <= reg_wr_data[31:0];

         if (test_en_sel && (! reg_rd_wr_L)) begin
            test_en <= reg_wr_data[TOTAL_TEST_NUM -1:0];
         end

         if (test_ctrl_sel && (! reg_rd_wr_L)) begin
            // Set test_run if the test_repeat flag is set and the test module
            // is currently sitting idle. This forces counters etc to reset
            test_run <= (reg_wr_data[0] || (reg_wr_data[1] && (done_125 || idle_125))) && |test_en;
            test_repeat <= reg_wr_data[1] && |test_en;
            err_cnt_clear <= reg_wr_data[8];
         end
         else begin
            // Clear the test run flag once the test module has entered the
            // done state. The test module will see the start signal and thus
            // run the test.
            if (done_125 || idle_125)
               test_run <= 1'b0;

            err_cnt_clear <= 1'b0;
         end

         if ( !log_empty_d1 && ( err_cnt[31:ERR_LOG_ARRAY_ADDR_BIT_NUM] == 'h0 ) ) begin
            err_log_addr_array[wr_ptr] <= log_addr_125;
            err_log_exp_data_array[wr_ptr] <= log_exp_data_125;
            err_log_rd_data_array[wr_ptr] <= log_rd_data_125;
         end

         reg_ack <= reg_ack_nxt;
         reg_rd_data <= reg_rd_data_nxt;
         reg_ack_done <= reg_ack_done_nxt;

         state <= state_nxt;

         log_empty_d1 <= log_empty;
      end // else: !if(reset_core)
   end // always @ (posedge clk_core_125)

   assign test_start_125 = test_run | test_repeat;

endmodule // ddr2_test_reg
