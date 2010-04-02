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
   output reg [71:0] rd_data,
   output empty,

   //-------------------
   //misc:
   input clk,
   input rst
   );


   reg [71:0] residual, residual_nxt;
   wire [63:0] fifo_rd_data;
   reg [3:0]  byte_cnt, byte_cnt_nxt;
   wire       fifo_empty, fifo_full, fifo_nearly_full;
   reg 	      fifo_rd_en;

   assign     full = fifo_nearly_full;

   assign empty = ~ ( (byte_cnt == 4'd 9) || ( (| byte_cnt) && (! fifo_empty) ) );

   always @(*) begin

      residual_nxt = residual;
      byte_cnt_nxt = byte_cnt;

      fifo_rd_en = 1'b 0;
      rd_data = 72'h 0;
	 case (byte_cnt)
	   4'd 0: begin

	   end

	   4'd 1: begin
	      rd_data = {residual[71:64], fifo_rd_data[63:0]};
	   end

	   4'd 2: begin
	      rd_data = {residual[71:56], fifo_rd_data[63:8]};
	   end

	   4'd 3: begin
	      rd_data = {residual[71:48], fifo_rd_data[63:16]};
	   end

	   4'd 4: begin
	      rd_data = {residual[71:40], fifo_rd_data[63:24]};
	   end

	   4'd 5: begin
	      rd_data = {residual[71:32], fifo_rd_data[63:32]};
	   end

	   4'd 6: begin
	      rd_data = {residual[71:24], fifo_rd_data[63:40]};
	   end

	   4'd 7: begin
	      rd_data = {residual[71:16], fifo_rd_data[63:48]};
	   end

	   4'd 8: begin
	      rd_data = {residual[71:8], fifo_rd_data[63:56]};
	   end

	   4'd 9: begin
	      rd_data = residual[71:0];
	   end

	 endcase // case(byte_cnt)
      if (rd_en) begin

	 case (byte_cnt)
	   4'd 0: begin

	   end

	   4'd 1: begin
	      residual_nxt = 72'h 0;
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:64], fifo_rd_data[63:0]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 2: begin
	      residual_nxt = {fifo_rd_data[7:0], 64'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:56], fifo_rd_data[63:8]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 3: begin
	      residual_nxt = {fifo_rd_data[15:0], 56'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:48], fifo_rd_data[63:16]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 4: begin
	      residual_nxt = {fifo_rd_data[23:0], 48'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:40], fifo_rd_data[63:24]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 5: begin
	      residual_nxt = {fifo_rd_data[31:0], 40'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:32], fifo_rd_data[63:32]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 6: begin
	      residual_nxt = {fifo_rd_data[39:0], 32'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:24], fifo_rd_data[63:40]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 7: begin
	      residual_nxt = {fifo_rd_data[47:0], 24'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:16], fifo_rd_data[63:48]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 8: begin
	      residual_nxt = {fifo_rd_data[55:0], 16'h 0};
	      byte_cnt_nxt = byte_cnt - 4'h 1;

	      //rd_data = {residual[71:8], fifo_rd_data[63:56]};
	      fifo_rd_en = 1'b 1;

	   end

	   4'd 9: begin

	      if (! fifo_empty) begin
		 residual_nxt = {fifo_rd_data[63:0], 8'h 0};
		 byte_cnt_nxt = byte_cnt - 4'h 1;

		 fifo_rd_en = 1'b 1;

	      end
	      else begin
		 residual_nxt = 72'h 0;
		 byte_cnt_nxt = 4'h 0;

	      end

	      //rd_data = residual[71:0];

	   end // case: 4'd 9

	 endcase // case(byte_cnt)

      end // if (rd_en)

      else begin
	 // !(rd_en)
	 if (~ fifo_empty) begin

	    case (byte_cnt)
	      4'd 0: begin
		 residual_nxt = {fifo_rd_data[63:0], 8'h 0};
		 byte_cnt_nxt = 4'd 8;

		 fifo_rd_en = 1'b 1;
	      end

	      4'd 1: begin
		 residual_nxt = {residual[71:64], fifo_rd_data[63:0]};
		 byte_cnt_nxt = 4'd 9;

		 fifo_rd_en = 1'b 1;
	      end

	    endcase // case(byte_cnt)

	 end // if (! fifo_empty)

      end // else: !if (rd_en)

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
       .MAX_DEPTH_BITS(4)
       )
       fallthrough_small_fifo
       (
	//----------------------
	//wr intfc
	//output:
	.full        ( fifo_full ),
	.nearly_full ( fifo_nearly_full ),
	.prog_full   (),

	//input:
	.din         ( wr_data ),
	.wr_en       ( wr_en ),

	//rd intfc
	//output:
	.dout        ( fifo_rd_data ),
	.empty       ( fifo_empty ),

	//input:
	.rd_en       ( fifo_rd_en ),

	//-----------------------
	//misc:
	.clk         ( clk ),
	.reset       ( rst )

	);

endmodule // ddr2_blk_rdwr_fifo_64b_2_72b





