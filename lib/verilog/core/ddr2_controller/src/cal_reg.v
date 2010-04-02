/******************************************************************
 **
 * This module registers the input signal twice. It is used for
 * registering the phClkDiv2 and hexClk
 * */

`timescale 1ns/100ps

module cal_reg(
	       reset,
	       clk,
	       dInp,
	       iReg,
	       dReg
	       );
   input     reset;
   input     clk;
   input     dInp;
   output    iReg;
   output    dReg;

   reg 	     dReg /* synthesis syn_replicate = 0 */;
   reg 	     iReg/* synthesis syn_replicate = 0 */;


   always @(posedge clk) begin
      if (reset) begin
	 iReg <= 1'b0;
	 dReg <= 1'b0;
      end else begin
	 iReg <= dInp;
	 dReg <= iReg;
      end
   end

endmodule