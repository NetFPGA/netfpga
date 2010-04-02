///////////////////////////////////////////////////////////////////////////////
// $Id: small_fifo.v 1998 2007-07-21 01:22:57Z grg $
//
// Module: small_fifo.v
// Project: utils
// Description: small fifo with no fallthrough i.e. data valid after rd is high
//
// Change history:
//   7/20/07 -- Set nearly full to 2^MAX_DEPTH_BITS - 1 by default so that it
//              goes high a clock cycle early.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

  module small_fifo_v2
    #(parameter WIDTH = 72,
      parameter MAX_DEPTH_BITS = 3,
      parameter PROG_FULL_THRESHOLD = 2**MAX_DEPTH_BITS - 1)
      (

       input [WIDTH-1:0] din,     // Data in
       input          wr_en,   // Write enable

       input          rd_en,   // Read the next word

       output reg [WIDTH-1:0]  dout,    // Data out
       output reg     full,
       output reg     nearly_full,
       output reg     prog_full,
       output reg     empty,

       input          reset,
       input          clk
       );


   parameter          MAX_DEPTH        = 2 ** MAX_DEPTH_BITS;

   reg [WIDTH-1:0]    queue [MAX_DEPTH - 1 : 0];
   reg [MAX_DEPTH_BITS - 1 : 0] rd_ptr;
   reg [MAX_DEPTH_BITS - 1 : 0] wr_ptr;
   wire [MAX_DEPTH_BITS - 1 : 0] rd_ptr_nxt;
   wire [MAX_DEPTH_BITS - 1 : 0] wr_ptr_nxt;
   wire [MAX_DEPTH_BITS - 1 : 0] wr_ptr_nxt_2;
   reg [MAX_DEPTH_BITS : 0]     depth;

   // Sample the data
   always @(posedge clk) begin
      if (wr_en) begin
         queue[wr_ptr] <= din;
      end
      if (rd_en) begin
         dout <=
                 // synthesis translate_off
                 #1
                 // synthesis translate_on
                 queue[rd_ptr];
      end
   end // always @ (posedge clk)

   assign wr_ptr_nxt = (wr_en && !full) ? wr_ptr + 1'b1 : wr_ptr;
   assign wr_ptr_nxt_2 = (wr_en && !full) ? wr_ptr + 2'h2 : wr_ptr;
   assign rd_ptr_nxt = (rd_en && !empty) ? rd_ptr + 1'b1 : rd_ptr;

   always @(posedge clk) begin
      if (reset) begin
         rd_ptr         <= 0;
         wr_ptr         <= 0;
         full           <= 0;
         empty          <= 1;
         nearly_full    <= 0;
         depth          <= 0;
         prog_full      <= 0;
      end
      else begin
         wr_ptr <= wr_ptr_nxt;
         rd_ptr <= rd_ptr_nxt;
         if (wr_en & ~rd_en) begin
            depth <=
                     // synthesis translate_off
                     #1
                     // synthesis translate_on
                     depth + 'h1;
         end
         else if (~wr_en & rd_en) begin
            depth <=
                     // synthesis translate_off
                     #1
                     // synthesis translate_on
                     depth - 'h1;
         end

         if(wr_en && (wr_ptr_nxt == rd_ptr_nxt)) begin
            full <= 1'b1;
         end
         else if(rd_en) begin
            full <= 1'b0;
         end

         if(rd_en && (wr_ptr_nxt == rd_ptr_nxt)) begin
            empty <= 1'b1;
         end
         else if(wr_en) begin
            empty <= 1'b0;
         end

         if(wr_en && ((wr_ptr_nxt == rd_ptr_nxt) || (wr_ptr_nxt_2 == rd_ptr_nxt))) begin
            nearly_full <= 1'b1;
         end
         else if(rd_en && !full) begin
            nearly_full <= 1'b0;
         end

         if((wr_en && !rd_en && (depth == PROG_FULL_THRESHOLD-1)) || (depth > PROG_FULL_THRESHOLD)) begin
            prog_full <= 1'b1;
         end
         else if ((rd_en && !wr_en && (depth == PROG_FULL_THRESHOLD)) || (depth < PROG_FULL_THRESHOLD)) begin
            prog_full <= 1'b0;
         end
      end
   end // always @ (posedge clk)

   // synthesis translate_off
   always @(posedge clk)
   begin
      if (wr_en && depth == MAX_DEPTH) begin
         $display("%t ERROR: Attempt to write to full FIFO: %m", $time);
         $stop;
      end
      if (rd_en && depth == 'h0) begin
         $display("%t ERROR: Attempt to read an empty FIFO: %m", $time);
         $stop;
      end

      if (depth == MAX_DEPTH && full == 0) begin
         $display("%t ERROR: FIFO full but full signal not asserted: %m", $time);
         $stop;
      end
      if (depth != MAX_DEPTH && full == 1) begin
         $display("%t ERROR: FIFO not full but full signal asserted: %m", $time);
         $stop;
      end

      if (depth == 0 && empty == 0) begin
         $display("%t ERROR: FIFO empty but empty signal not asserted: %m", $time);
         $stop;
      end
      if (depth != 0 && empty == 1) begin
         $display("%t ERROR: FIFO not empty but empty signal asserted: %m", $time);
         $stop;
      end

      if (depth >= MAX_DEPTH-1 && nearly_full == 0) begin
         $display("%t ERROR: FIFO nearly full but nearly_full not asserted: %m", $time);
         $stop;
      end
      if (depth < MAX_DEPTH-1 && nearly_full == 1) begin
         $display("%t ERROR: FIFO not nearly full but nearly_full asserted: %m", $time);
         $stop;
      end

      if (depth >= PROG_FULL_THRESHOLD && prog_full == 0) begin
         $display("%t ERROR: FIFO at or above PROG_FULL_THRESHOLD but prog_full not asserted: %m", $time);
         $stop;
      end
      if (depth < PROG_FULL_THRESHOLD && prog_full == 1) begin
         $display("%t ERROR: FIFO below PROG_FULL_THRESHOLD but prog_full asserted: %m", $time);
         $stop;
      end
   end
   // synthesis translate_on

endmodule // small_fifo

// synthesis translate_off
module small_fifo_tester();

   reg [31:0] din = 0;
   reg        wr_en = 0;
   reg        rd_en = 0;
   wire [31:0] dout;
   wire        full;
   wire        nearly_full;
   wire        prog_full;
   wire        empty;
   reg         clk = 0;
   reg         reset = 0;

   integer     count = 0;

   always #8 clk = ~clk;

   small_fifo
     #(.WIDTH (32),
       .MAX_DEPTH_BITS (3),
       .PROG_FULL_THRESHOLD (4))
       fifo
        (.din           (din),
         .wr_en         (wr_en),
         .rd_en         (rd_en),
         .dout          (dout),
         .full          (full),
         .nearly_full   (nearly_full),
         .prog_full     (prog_full),
         .empty         (empty),
         .reset         (reset),
         .clk           (clk)
         );

   always @(posedge clk) begin
      count <= count + 1;
      reset <= 0;
      wr_en <= 0;
      rd_en <= 0;
      if(count < 2) begin
         reset <= 1'b1;
      end
      else if(count < 2 + 8) begin
         wr_en <= 1;
         din <= din + 1'b1;
      end
      else if(count < 2 + 8 + 3) begin
         rd_en <= 1;
      end
      else if(count < 2 + 8 + 3 + 2) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
         rd_en <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8 + 4) begin
         rd_en <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8 + 4 + 8) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
         rd_en <= 1'b1;
      end
   end // always @ (posedge clk)
endmodule // small_fifo_tester
// synthesis translate_on

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
