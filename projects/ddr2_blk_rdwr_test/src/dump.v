///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: dump.v
// Project: NetFPGA
// Description: simulation waveform dump
//
///////////////////////////////////////////////////////////////////////////////

module dump;

   //synthesis translate_off

   initial begin
      $timeformat(-9, 2, "ns", 10); // -9=ns  2=digits after.
   end

/* -----\/----- EXCLUDED -----\/-----
   initial begin
	$dumpfile("testdump.vcd");
	$dumpvars(3,testbench);
	$dumpvars(0,testbench.u_board.nf2_top);
     end
 -----/\----- EXCLUDED -----/\----- */

/* -----\/----- EXCLUDED -----\/-----
   initial begin
	$vcdplusfile("testdump.vpd");
	$vcdpluson(3,testbench);
	$vcdpluson(0,testbench.u_board.nf2_top);
     end
 -----/\----- EXCLUDED -----/\----- */

   //synthesis translate_on

endmodule // dump

