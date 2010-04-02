///////////////////////////////////////////////////////////////////////////////
// $Id: small_fifo.v 1998 2007-07-21 01:22:57Z grg $
//
// Module: fallthrough_small_fifo.v
// Project: utils
// Description: small fifo with fallthrough i.e. data valid when rd is high
//
// Change history:
//   7/20/07 -- Set nearly full to 2^MAX_DEPTH_BITS - 1 by default so that it
//              goes high a clock cycle early.
//   2/11/09 -- jnaous: Rewrote to make much more efficient.
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

  module fallthrough_small_fifo
    #(parameter WIDTH = 72,
      parameter MAX_DEPTH_BITS = 3,
      parameter PROG_FULL_THRESHOLD = 2**MAX_DEPTH_BITS - 1)
    (

     input [WIDTH-1:0] din,     // Data in
     input          wr_en,   // Write enable

     input          rd_en,   // Read the next word

     output [WIDTH-1:0]  dout,    // Data out
     output         full,
     output         nearly_full,
     output         prog_full,
     output reg     empty,

     input          reset,
     input          clk
     );

   reg  fifo_rd_en, empty_nxt;

   small_fifo
     #(.WIDTH (WIDTH),
       .MAX_DEPTH_BITS (MAX_DEPTH_BITS),
       .PROG_FULL_THRESHOLD (PROG_FULL_THRESHOLD))
       fifo
        (.din           (din),
         .wr_en         (wr_en),
         .rd_en         (fifo_rd_en),
         .dout          (dout),
         .full          (full),
         .nearly_full   (nearly_full),
         .prog_full     (prog_full),
         .empty         (fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   always @(*) begin
      empty_nxt  = empty;
      fifo_rd_en = 0;
      case (empty)
         1'b1: begin
            if(!fifo_empty) begin
               fifo_rd_en = 1;
               empty_nxt  = 0;
            end
         end

         1'b0: begin
            if(rd_en) begin
               if(fifo_empty) begin
                  empty_nxt = 1;
               end
               else begin
                  fifo_rd_en = 1;
               end
            end
         end
      endcase // case(empty)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         empty <= 1'b1;
      end
      else begin
         empty <= empty_nxt;
      end
   end

   // synthesis translate_off
   always @(posedge clk)
   begin
      if (wr_en && full) begin
         $display("%t ERROR: Attempt to write to full FIFO: %m", $time);
      end
      if (rd_en && empty) begin
         $display("%t ERROR: Attempt to read an empty FIFO: %m", $time);
      end
   end // always @ (posedge clk)
   // synthesis translate_on

endmodule // fallthrough_small_fifo_v2

// synthesis translate_off
module fallthrough_small_fifo_tester();

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

   fallthrough_small_fifo
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
      else if(count < 2 + 9) begin
         wr_en <= 1;
         din <= din + 1'b1;
      end
      else if(count < 2 + 8 + 4) begin
         rd_en <= 1;
      end
      else if(count < 2 + 8 + 4 + 2) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
      end
      else if(count < 2 + 8 + 4 + 2 + 8) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
         rd_en <= 1'b1;
      end
      else if(count < 2 + 8 + 4 + 2 + 8 + 4) begin
         rd_en <= 1'b1;
      end
      else if(count < 2 + 8 + 4 + 2 + 8 + 4 + 8) begin
         din <= din + 1'b1;
         wr_en <= 1'b1;
         rd_en <= 1'b1;
      end
   end // always @ (posedge clk)
endmodule // fallthrough_small_fifo_tester
// synthesis translate_on

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
