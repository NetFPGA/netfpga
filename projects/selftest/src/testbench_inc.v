///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: testbench_inc.v 3003 2007-11-21 19:24:12Z jnaous $
//
// Module: testbench_inc.v
// Project: NetFPGA
// Description: Testbench overrides
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns

module testbench_inc;

   // Control which tests will be run
   parameter NF21_SELFTEST_NO_SRAM_TEST = 0;
   parameter NF21_SELFTEST_NO_DRAM_TEST = 0;
   parameter NF21_SELFTEST_DRAM_RANDOM_ACCESS = 0;
   parameter NF21_SELFTEST_NO_PHY_TEST = 0;
   parameter NF21_SELFTEST_NO_SATA_TEST = 0;

   // Control faulty connections
   parameter NF21_SELFTEST_SRAM_FAULT = 0;
   parameter NF21_SELFTEST_DRAM_FAULT = 0;
   parameter NF21_SELFTEST_PHY_FAULT = 0;
   parameter NF21_SELFTEST_SATA_FAULT = 0;
   parameter NF21_SELFTEST_NO_SATA_CABLE = 0;

   //limit the word depth of every SRAM instance to the first 4 words
   defparam  testbench.u_board.nf2_top.nf2_core.sram_test_u.sram_test_fixed_pat_u.STOP_ADDR=19'h 3;
   defparam  testbench.u_board.nf2_top.nf2_core.sram_test_u.sram_test_rand_pat_u.STOP_ADDR=19'h 3;

   // Restrict the DRAM test to 4096 words
   defparam  testbench.u_board.nf2_top.nf2_core.ddr2_test.TOTAL_XFER_SIZE = 32'd 4096;

   // set the test length to 512 cycles for the SATA
   defparam  testbench.u_board.nf2_top.nf2_core.serial_test.COUNT_WIDTH = 9;

   // ==============================================
   // Actual test code
   //
   initial begin
      $display("NF2.1 testbench_inc.v is included.");
   end

   // Force test signals as necessary
   //
   // Note: can't force reset in the modules because the force "leaks" out to
   // higher level modules, resetting everything! :-(
   initial
   begin
      if (NF21_SELFTEST_NO_SRAM_TEST) begin
         force testbench.u_board.nf2_top.nf2_core.sram_done = 1'b1;
         force testbench.u_board.nf2_top.nf2_core.sram_fail = 1'b0;
         force testbench.u_board.nf2_top.nf2_core.sram_test_u.test_start = 1'b0;
      end

      if (NF21_SELFTEST_NO_DRAM_TEST || NF21_SELFTEST_DRAM_RANDOM_ACCESS) begin
         force testbench.u_board.nf2_top.nf2_core.dram_done = 1'b1;
         force testbench.u_board.nf2_top.nf2_core.dram_success = 1'b0;
         force testbench.u_board.nf2_top.nf2_core.ddr2_test.test_state_180 = testbench.u_board.nf2_top.nf2_core.ddr2_test.T_DONE;
         force testbench.u_board.nf2_top.nf2_core.ddr2_test.state_180 = testbench.u_board.nf2_top.nf2_core.ddr2_test.HOLD;
      end

      if (NF21_SELFTEST_NO_PHY_TEST) begin
         force testbench.u_board.nf2_top.nf2_core.eth_done = 1'b1;
         force testbench.u_board.nf2_top.nf2_core.eth_success = 1'b0;
         force testbench.u_board.nf2_top.nf2_core.phy_test.phy_test_reg.start = 1'b0;
      end

      if (NF21_SELFTEST_NO_SATA_TEST) begin
         force testbench.u_board.nf2_top.nf2_core.serial_test_done = 1'b1;
         force testbench.u_board.nf2_top.nf2_core.serial_test_successful = 1'b1;
         force testbench.u_board.nf2_top.nf2_core.serial_test.restart_test = 1'b1;
      end

      if (NF21_SELFTEST_NO_SATA_CABLE) begin
         force testbench.u_board.serial_RXP_0 = 1'bz;
         force testbench.u_board.serial_RXN_0 = 1'bz;
         force testbench.u_board.serial_RXP_1 = 1'bz;
         force testbench.u_board.serial_RXN_1 = 1'bz;
      end
   end

   initial
   begin
      // Release the DRAM selftest signals after 5000ns to allow other tests to
      // use the DRAM interface
      if (NF21_SELFTEST_DRAM_RANDOM_ACCESS) begin
         #4000
         force testbench.u_board.nf2_top.nf2_core.ddr2_test.state_180 = testbench.u_board.nf2_top.nf2_core.ddr2_test.INIT;
         force testbench.u_board.nf2_top.nf2_core.ddr2_test.ddr2_test_reg.test_run = 1'b0;
         force testbench.u_board.nf2_top.nf2_core.ddr2_test.test_num_180 = 'd5;

         #10;
         release testbench.u_board.nf2_top.nf2_core.ddr2_test.state_180;

         #1000;
         release testbench.u_board.nf2_top.nf2_core.ddr2_test.test_state_180;
         release testbench.u_board.nf2_top.nf2_core.ddr2_test.state_180;
         release testbench.u_board.nf2_top.nf2_core.ddr2_test.ddr2_test_reg.test_run;
         release testbench.u_board.nf2_top.nf2_core.ddr2_test.test_num_180;
         release testbench.u_board.nf2_top.nf2_core.dram_done;
         release testbench.u_board.nf2_top.nf2_core.dram_success;
      end
   end

   initial
   begin
      // Force the high bits of the timer signal to zero to make tests
      // complete sooner
      force testbench.u_board.nf2_top.nf2_core.phy_test.port_grp[0].phy_test_port_grp.phy_test_port_ctrl.start_time = 'd1024;
      force testbench.u_board.nf2_top.nf2_core.phy_test.port_grp[1].phy_test_port_grp.phy_test_port_ctrl.start_time = 'd1024;
      force testbench.u_board.nf2_top.nf2_core.phy_test.port_grp[2].phy_test_port_grp.phy_test_port_ctrl.start_time = 'd1024;
      force testbench.u_board.nf2_top.nf2_core.phy_test.port_grp[3].phy_test_port_grp.phy_test_port_ctrl.start_time = 'd1024;

      // Force the phy test size to be 60 to make the test finish sooner
      force testbench.u_board.nf2_top.nf2_core.phy_test.phy_test_reg.size = 'd60;

      // Release it in case users want to override it
      #4000;
      release testbench.u_board.nf2_top.nf2_core.phy_test.phy_test_reg.size;
   end


   // Monitor outputs
   reg sram_test_done_d1;
   reg dram_test_done_d1;
   reg eth_test_done_d1;
   reg sata_test_done_d1;

   always @(posedge testbench.u_board.clk) begin
      if (!NF21_SELFTEST_NO_SRAM_TEST) begin
	 if (sram_test_done_d1 === 1'b0 &&
             testbench.u_board.nf2_top.nf2_core.sram_done === 1'b1)
           $display($time, " INFO: SRAM test: %s", testbench.u_board.nf2_top.nf2_core.sram_fail ? "fail" : "pass");
	 sram_test_done_d1 <= testbench.u_board.nf2_top.nf2_core.sram_done;
      end

      if (!NF21_SELFTEST_NO_DRAM_TEST) begin
	 if (dram_test_done_d1 === 1'b0 &&
             testbench.u_board.nf2_top.nf2_core.dram_done === 1'b1)
           $display($time, " INFO: DRAM test: %s", testbench.u_board.nf2_top.nf2_core.dram_success ? "pass" : "fail");
	 dram_test_done_d1 <= testbench.u_board.nf2_top.nf2_core.dram_done;
      end

      if (!NF21_SELFTEST_NO_PHY_TEST) begin
	 if (eth_test_done_d1 === 1'b0 &&
             testbench.u_board.nf2_top.nf2_core.eth_done === 1'b1)
           $display($time, " INFO: PHY test: %s", testbench.u_board.nf2_top.nf2_core.eth_success ? "pass" : "fail");
	 eth_test_done_d1 <= testbench.u_board.nf2_top.nf2_core.eth_done;
      end

      if (!NF21_SELFTEST_NO_SATA_TEST) begin
	 if (sata_test_done_d1 === 1'b0 &&
             testbench.u_board.nf2_top.nf2_core.serial_test_done === 1'b1)
           $display($time, " INFO: SATA test: %s", testbench.u_board.nf2_top.nf2_core.serial_test_successful ? "pass" : "fail");
	 sata_test_done_d1 <= testbench.u_board.nf2_top.nf2_core.serial_test_done;
      end
   end



   // ==============================================
   // Simulate SRAM error for NF 2.1 self-test
   // ==============================================
   reg [18:0] u_board_sram1_a_d1, u_board_sram1_a_d2;
   reg 	      u_board_sram1_we_b_d1, u_board_sram1_we_b_d2;

   reg [18:0] u_board_sram2_a_d1, u_board_sram2_a_d2;
   reg 	      u_board_sram2_we_b_d1, u_board_sram2_we_b_d2;

   always @(posedge testbench.u_board.clk) begin
      u_board_sram1_a_d1 <= testbench.u_board.sram1.a;
      u_board_sram1_a_d2 <= u_board_sram1_a_d1;

      u_board_sram1_we_b_d1 <= testbench.u_board.sram1.we_b;
      u_board_sram1_we_b_d2 <= u_board_sram1_we_b_d1;

      u_board_sram2_a_d1 <= testbench.u_board.sram2.a;
      u_board_sram2_a_d2 <=u_board_sram2_a_d1;

      u_board_sram2_we_b_d1 <= testbench.u_board.sram2.we_b;
      u_board_sram2_we_b_d2 <= u_board_sram2_we_b_d1;

   end // always @ (posedge testbench.u_board.clk)

   always @(negedge testbench.u_board.clk) begin
      if (NF21_SELFTEST_SRAM_FAULT) begin
	 if ((u_board_sram1_a_d2==19'h 1)&&(u_board_sram2_we_b_d1==1'b 1)) begin
            //sram_1, addr=0x1, read
            force testbench.u_board.sram1.d = 36'h 123456789;
	 end
	 else begin
            release testbench.u_board.sram1.d ;
	 end

	 if ((u_board_sram2_a_d2==19'h 3)&&(u_board_sram2_we_b_d2==1'b 1)) begin
            //sram_2, addr=0x3, read
            force testbench.u_board.sram2.d = 36'h 987654321;
	 end
	 else begin
            release testbench.u_board.sram2.d ;
	 end
      end
   end

   // ==============================================
   // Simulate DRAM error for NF 2.1 self-test
   // ==============================================
   reg [12:0] u_board_ddr2_addr_d1;
   reg 	      u_board_ddr2_casb_d1;
   reg 	      u_board_ddr2_web_d1;

   reg [12:0] u_board_ddr2_addr_d2;
   reg 	      u_board_ddr2_casb_d2;
   reg 	      u_board_ddr2_web_d2;

   reg [12:0] u_board_ddr2_addr_d3;
   reg 	      u_board_ddr2_casb_d3;
   reg 	      u_board_ddr2_web_d3;

   reg 	      u_board_ddr2_row_good;

   always @(posedge testbench.u_board.ddr2_clk0) begin
      u_board_ddr2_addr_d1 <= testbench.u_board.ddr2_addr;
      u_board_ddr2_casb_d1 <= testbench.u_board.ddr2_casb;
      u_board_ddr2_web_d1 <= testbench.u_board.ddr2_web;

      u_board_ddr2_addr_d2 <= u_board_ddr2_addr_d1;
      u_board_ddr2_casb_d2 <= u_board_ddr2_casb_d1;
      u_board_ddr2_web_d2 <= u_board_ddr2_web_d1;

      u_board_ddr2_addr_d3 <= u_board_ddr2_addr_d2;
      u_board_ddr2_casb_d3 <= u_board_ddr2_casb_d2;
      u_board_ddr2_web_d3 <= u_board_ddr2_web_d2;
   end // always @ (posedge testbench.u_board.ddr2_clk0)

   always @(posedge testbench.u_board.ddr2_clk0) begin
      if (NF21_SELFTEST_DRAM_FAULT) begin
	 if (!testbench.u_board.ddr2_rasb)
           u_board_ddr2_row_good <= testbench.u_board.ddr2_addr == 'h0;

	 if (u_board_ddr2_row_good && u_board_ddr2_addr_d3 == 'h0004 && u_board_ddr2_web_d3 && !u_board_ddr2_casb_d3)
           force testbench.u_board.ddr2_dq = 'h 0badbad0;
	 else
           release testbench.u_board.ddr2_dq;
      end
   end // always @ (posedge testbench.u_board.ddr2_clk0)

   // ==============================================
   // Simulate SATA error for NF 2.1 self-test
   // ==============================================

   integer iterations = 0;
   reg [8:0] count_d1;
   always @(posedge testbench.u_board.clk) begin
      if(NF21_SELFTEST_SATA_FAULT) begin
	 count_d1 <= testbench.u_board.nf2_top.nf2_core.serial_test.count;
	 iterations <= iterations + (testbench.u_board.nf2_top.nf2_core.serial_test.count===511 && count_d1===510);
	 if ((iterations == 0 || iterations==1) && testbench.u_board.nf2_top.nf2_core.serial_test.count == 380) begin
	    force testbench.u_board.nf2_top.nf2_core.serial_test.aurora_module_0.frame_check_i.error_count_r = 16'hfff0;
	 end
	 else begin
	    release testbench.u_board.nf2_top.nf2_core.serial_test.aurora_module_0.frame_check_i.error_count_r;
	 end
	 if ((iterations == 0 || iterations==1) && testbench.u_board.nf2_top.nf2_core.serial_test.count >= 400 && testbench.u_board.nf2_top.nf2_core.serial_test.count < 480) begin
	    force testbench.u_board.nf2_top.nf2_core.serial_test.aurora_module_0.frame_check_i.RX_D = 1;
	 end
	 else begin
	    release testbench.u_board.nf2_top.nf2_core.serial_test.aurora_module_0.frame_check_i.RX_D;
	 end
      end
   end // always @ (posedge testbench.u_board.clk)

endmodule // testbench_inc
