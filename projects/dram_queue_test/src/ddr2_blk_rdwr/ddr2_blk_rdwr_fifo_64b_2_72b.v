///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: ddr2_blk_rdwr_fifo_64b_2_72b.v
// Project: NetFPGA
// Description: This module accepts 64-bit input and provides 72-bit output.
//
// output "rd_data_d1" is available one clk cycle later than rd_en assertion.
// output "rd_data"    is available at the same cycle as rd_en asserts.
//
// 2010/2/12: James Hongyi Zeng : Use 2 FIFOs to make module more stable
//
///////////////////////////////////////////////////////////////////////////////

module ddr2_blk_rdwr_fifo_64b_2_72b
  (
   //----------------------
   // wr intfc
   //input:
   input [63:0] wr_data,
   input wr_en,

   //output:
   output full,

   //----------------------
   // rd intfc
   //input:
   input rd_en,

   //output:
   output reg [71:0] rd_data_d1,
   output     [71:0] rd_data,
   output empty,

   //-------------------
   //misc:
   input clk,
   input rst
   );


   reg [71:0] residual, residual_nxt;
   wire       fifo_empty_64bit, fifo_nearly_full_64bit;
   wire       fifo_empty_72bit, fifo_nearly_full_72bit;
   reg 	      fifo_rd_en_64bit, fifo_wr_en_72bit;
   wire [63:0] fifo_rd_data_64bit;
   reg  [71:0] fifo_wr_data_72bit;
   reg [3:0]  byte_cnt, byte_cnt_nxt;


   assign full = fifo_nearly_full_64bit;

   assign empty = fifo_empty_72bit;

   always @(*) begin

      residual_nxt = residual;
      byte_cnt_nxt = byte_cnt;

      fifo_rd_en_64bit = 1'b0;
      fifo_wr_en_72bit = 1'b0;

      fifo_wr_data_72bit = 72'b0;

	  case (byte_cnt)
	   4'd 0: begin
		  if(~fifo_empty_64bit) begin
		      residual_nxt = {fifo_rd_data_64bit, 8'b0};
		      byte_cnt_nxt = byte_cnt + 1;
		      fifo_rd_en_64bit = 1'b1;
		  end
	   end

	   4'd 1: begin
	      fifo_wr_data_72bit = {residual[71:8], fifo_rd_data_64bit[63-:8]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[55:0], 16'b0};
	      end
	   end

	   4'd 2: begin
	      fifo_wr_data_72bit = {residual[71:16], fifo_rd_data_64bit[63-:16]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[47:0], 24'b0};
	      end
	   end

	   4'd 3: begin
	      fifo_wr_data_72bit = {residual[71:24], fifo_rd_data_64bit[63-:24]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[39:0], 32'b0};
	      end
	   end

	   4'd 4: begin
	      fifo_wr_data_72bit = {residual[71:32], fifo_rd_data_64bit[63-:32]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[31:0], 40'b0};
	      end
	   end

	   4'd 5: begin
	      fifo_wr_data_72bit = {residual[71:40], fifo_rd_data_64bit[63-:40]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[23:0], 48'b0};
	      end
	   end

	   4'd 6: begin
	      fifo_wr_data_72bit = {residual[71:48], fifo_rd_data_64bit[63-:48]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[15:0], 56'b0};
	      end
	   end

	   4'd 7: begin
	      fifo_wr_data_72bit = {residual[71:56], fifo_rd_data_64bit[63-:56]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = byte_cnt + 1;
	          residual_nxt = {fifo_rd_data_64bit[7:0], 64'b0};
	      end
	   end

	   4'd 8: begin
	      fifo_wr_data_72bit = {residual[71:64], fifo_rd_data_64bit[63:0]};
	      if(~fifo_empty_64bit & ~fifo_nearly_full_72bit) begin
	          fifo_wr_en_72bit = 1'b1;
	          fifo_rd_en_64bit = 1'b1;
	          byte_cnt_nxt = 0;
	          residual_nxt = {72'b0};
	      end
	   end

	 endcase // case(byte_cnt)

   end // always @ (*)


   always @(posedge clk)
     if (rst) begin
	residual <= 72'h 0;
	byte_cnt <= 4'h 0;
	rd_data_d1 <= 72'b 0;

     end
     else begin
	residual <= residual_nxt;
	byte_cnt <= byte_cnt_nxt;
	rd_data_d1 <= rd_data;

     end


   //---------------------------
   //instantiation
   fallthrough_small_fifo
     #(.WIDTH(64),
       .MAX_DEPTH_BITS(3)
       )
       fallthrough_small_fifo_64bit
       (
	//----------------------
	//wr intfc
	//output:
	.full        ( ),
	.nearly_full ( fifo_nearly_full_64bit ),
	.prog_full   (),

	//input:
	.din         ( wr_data ),
	.wr_en       ( wr_en ),

	//rd intfc
	//output:
	.dout        ( fifo_rd_data_64bit ),
	.empty       ( fifo_empty_64bit ),

	//input:
	.rd_en       ( fifo_rd_en_64bit ),

	//-----------------------
	//misc:
	.clk         ( clk ),
	.reset       ( rst )

	);

	fallthrough_small_fifo
     #(.WIDTH(72),
       .MAX_DEPTH_BITS(3)
       )
       fallthrough_small_fifo_72bit
       (
	//----------------------
	//wr intfc
	//output:
	.full        (  ),
	.nearly_full ( fifo_nearly_full_72bit ),
	.prog_full   (),

	//input:
	.din         ( fifo_wr_data_72bit ),
	.wr_en       ( fifo_wr_en_72bit ),

	//rd intfc
	//output:
	.dout        ( rd_data ),
	.empty       ( fifo_empty_72bit ),

	//input:
	.rd_en       ( rd_en ),

	//-----------------------
	//misc:
	.clk         ( clk ),
	.reset       ( rst )

	);

endmodule // ddr2_blk_rdwr_fifo_64b_2_72b





