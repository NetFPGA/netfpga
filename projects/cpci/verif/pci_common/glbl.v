/***********************************************************************

  File:   glbl.v
  Rev:    3.0.0

  This file contains the global module required for
  Verilog simulation.  It is similar to what is
  provided in $XILINX/verilog/src, and is provided
  here for convenience.

  Copyright (c) 2003 Xilinx, Inc.  All rights reserved.

***********************************************************************/

`timescale  1 ns / 1 ps

module glbl ();

parameter ROC_WIDTH = 100;

wire GSR;
wire GTS;
wire PRLD;

reg GSR_int;
reg GTS_int;
reg PRLD_int;

assign (weak1, weak0) GSR = GSR_int;
assign (weak1, weak0) GTS = GTS_int;
assign (weak1, weak0) PRLD = PRLD_int;

initial
begin
   GSR_int = 1'b1;
   GTS_int = 1'b1;
   PRLD_int = 1'b1;
   #(ROC_WIDTH)
   GSR_int = 1'b0;
   GTS_int = 1'b0;
   PRLD_int = 1'b0;
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
