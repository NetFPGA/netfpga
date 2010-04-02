///////////////////////////////////////////////////////////////////////////////
// $Id: fifo_8x32.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: fifo_8x32.v
// Project: CPCI (PCI Control FPGA)
// Description: Small 8 x 32-bit FIFO
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////


module fifo_8x32(
            // PCI Signals
            input [31:0]   din,     // Data in
            input          wr_en,   // Write enable

            input          rd_en,   // Read the next word

            output [31:0]  dout,    // Data out
            output         full,
            output         empty,

            input          reset,
            input          clk
         );


parameter MAX_DEPTH_BITS   = 3;
parameter MAX_DEPTH        = 2 ** MAX_DEPTH_BITS;

reg [31:0] queue [MAX_DEPTH - 1 : 0];
reg [MAX_DEPTH_BITS - 1 : 0] rd_ptr;
reg [MAX_DEPTH_BITS - 1 : 0] wr_ptr;
reg [MAX_DEPTH_BITS - 1 + 1 : 0] depth;

// Sample the data
always @(posedge clk)
begin
   if (wr_en)
      queue[wr_ptr] <= din;
end

always @(posedge clk)
begin
   if (reset) begin
      rd_ptr <= 'h0;
      wr_ptr <= 'h0;
      depth <= 'h0;
   end
   else begin
      if (wr_en) wr_ptr <= wr_ptr + 'h1;
      if (rd_en) rd_ptr <= rd_ptr + 'h1;
      if (wr_en & ~rd_en) depth <= depth + 'h1;
      if (~wr_en & rd_en) depth <= depth - 'h1;
   end
end

assign dout = queue[rd_ptr];
assign full = depth == MAX_DEPTH;
assign empty = depth == 'h0;

// synthesis translate_off
always @(posedge clk)
begin
   if (wr_en && depth == MAX_DEPTH && !rd_en)
      $display($time, " ERROR: Attempt to write to full FIFO: %m");
   if (rd_en && depth == 'h0)
      $display($time, " ERROR: Attempt to read an empty FIFO: %m");
end
// synthesis translate_on

endmodule // fifo_8x32

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
