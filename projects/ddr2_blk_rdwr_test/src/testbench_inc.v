///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: testbench_inc.v
// Project: NetFPGA
// Description: Testbench overrides
//
///////////////////////////////////////////////////////////////////////////////

module testbench_inc;

   // synthesis translate_off

   // test only blocks 0~50 of DDR2 DRAM
   defparam testbench.u_board.nf2_top.nf2_core_u.ddr2_blk_rdwr_test_u.STOP_BLK_NUM=50;

   initial begin
      $display("NF2.1 testbench_inc.v is included.");
   end

   // synthesis translate_on

endmodule // testbench_inc
