///////////////////////////////////////////////////////////////////////////////
// $Id: lfsr32.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: lfsr32.v
// Project: NetFPGA
// Description: 32-bit pseudo-random number generator
//
///////////////////////////////////////////////////////////////////////////////

module lfsr32
(
      // Note: indexing is "weird" (32 -> 1) because this is how
      // LFSRs are usually specified.
      output reg [32:1] val,

      input rd,      // Read a value

      input [32:1] seed,

      input reset,
      input clk
);

reg [32:1] prev_val;

always @(posedge clk)
begin
   if (reset)
      val <= seed;
   else if (rd)
      val <= {val[31:1], val[32] ^ val[31] ^ val[30] ^ val[10]};

   prev_val <= val;
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
