///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: ddr2_blk_rdwr_fifo_72b_2_64b.v
// Project: NetFPGA
// Description: This module accepts 72-bit input and provides 64-bit output
//
///////////////////////////////////////////////////////////////////////////////

module ddr2_blk_rdwr_fifo_72b_2_64b
  (
   //----------------------
   // wr intfc
   //input:
   input [71:0] wr_data,
   input wr_en,

   //output:
   output full,

   //----------------------
   // rd intfc
   //input:
   input rd_en,

   //output:
   output [63:0] rd_data,
   output empty,

   //misc:
   input clk,
   input rst
   );

   reg [63:0] residual, residual_nxt;
   reg [63:0] fifo_wr_data, fifo_wr_data_d1;
   reg [3:0]  byte_cnt, byte_cnt_nxt;
   wire       fifo_full, fifo_nearly_full;
   reg 	      fifo_wr_en, fifo_wr_en_d1;

   assign full = (byte_cnt == 4'd 8) || fifo_nearly_full;

   always @(*) begin

      fifo_wr_en = 1'b 0;
      fifo_wr_data = 64'h 0;
      residual_nxt = residual;
      byte_cnt_nxt = byte_cnt;

      if (wr_en) begin
	 fifo_wr_en = 1'b 1;
	 byte_cnt_nxt = byte_cnt + 4'h 1;
	       end // if (wr_en)

      else begin

	 if (byte_cnt == 4'd 8) begin
	    fifo_wr_en = 1'b 1;
	    byte_cnt_nxt = 4'd 0;

	 end

      end // else: !if(wr_en)

	 case (byte_cnt)
	   4'd 0: begin
	      fifo_wr_data = wr_data[71:8];
	      if (wr_en) residual_nxt = {wr_data[7:0], 56'h 0};

	   end

	   4'd 1: begin
	      fifo_wr_data = {residual[63:56], wr_data[71:16]};
	      if (wr_en) residual_nxt = {wr_data[15:0], 48'h 0};

	   end

	   4'd 2: begin
	      fifo_wr_data = {residual[63:48], wr_data[71:24]};
	      if (wr_en) residual_nxt = {wr_data[23:0], 40'h 0};

	   end

	   4'd 3: begin
	      fifo_wr_data = {residual[63:40], wr_data[71:32]};
	      if (wr_en) residual_nxt = {wr_data[31:0], 32'h 0};

	   end

	   4'd 4: begin
	      fifo_wr_data = {residual[63:32], wr_data[71:40]};
	      if (wr_en) residual_nxt = {wr_data[39:0], 24'h 0};

	   end

	   4'd 5: begin
	      fifo_wr_data = {residual[63:24], wr_data[71:48]};
	      if (wr_en) residual_nxt = {wr_data[47:0], 16'h 0};

	   end

	   4'd 6: begin
	      fifo_wr_data = {residual[63:16], wr_data[71:56]};
	      if (wr_en) residual_nxt = {wr_data[55:0], 8'h 0};

	   end

	   4'd 7: begin
	      fifo_wr_data = {residual[63:8], wr_data[71:64]};
	      if (wr_en) residual_nxt = wr_data[63:0];

	   end

	   4'd 8: begin
		fifo_wr_data = residual;
	    //residual_nxt = 64'h 0;
	   end

	 endcase // case(byte_cnt)



   end // always @ (*)


   always @(posedge clk)
     if (rst) begin
	residual <= 64'h 0;
	byte_cnt <= 4'h 0;

	fifo_wr_en_d1 <= 1'b 0;
	fifo_wr_data_d1 <= 64'h 0;

     end
     else begin
	residual <= residual_nxt;
	byte_cnt <= byte_cnt_nxt;

	fifo_wr_en_d1 <= fifo_wr_en;
	fifo_wr_data_d1 <= fifo_wr_data;

     end


   //---------------------------
   //instantiation
   fallthrough_small_fifo
     #(.WIDTH(64),
       .MAX_DEPTH_BITS(3),
       .PROG_FULL_THRESHOLD (4)
       )
       fallthrough_small_fifo
       (
	//------------------
	//wr intfc
	//output:
	.full        ( fifo_full ),
	.prog_full   ( fifo_nearly_full ),
	//.almost_full (),

	//input:
	.din         ( fifo_wr_data_d1 ),
	.wr_en       ( fifo_wr_en_d1 ),

	//-----------------
	//rd intfc
	//output:
	.dout         ( rd_data ),
	.empty        ( empty ),

	//input:
	.rd_en        ( rd_en ),

	//-----------------
	//misc:
	.clk          ( clk ),
	.reset        ( rst )

	);

endmodule // ddr2_blk_rdwr_fifo_72b_2_64b


