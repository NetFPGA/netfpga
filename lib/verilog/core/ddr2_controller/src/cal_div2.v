`timescale 1ns/100ps

module cal_div2(
		reset,
		iclk,
		oclk
		);

   input reset;
   input iclk;
   output oclk;
   reg 	  oclk;
   reg 	  poclk;


   // asynchronous reset

   always @(posedge iclk) begin
      if (reset) begin
	 poclk <= 1'b0;
	 oclk <= 1'b0;
      end else begin
	 poclk <= ~poclk;
	 oclk <= poclk;
      end
   end
endmodule // cal_div2
