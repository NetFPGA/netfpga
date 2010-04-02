///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: async_fifo_in_72b_out_144b.v
// Project: NetFPGA
// Description: an implementation of 72-bit input/144-bit output
// asynchronous FIFO. It onsists of a 144-bit async FIFO.
//
///////////////////////////////////////////////////////////////////////////////

module async_fifo_in_72b_out_144b
  (
   //-----------------------------
   //wr intfc
   //din is one clk cycle later than wr_en due to set-up time violation fix
   input [71:0] din,
   input wr_en,

   output full,

   input wr_clk,
   input wr_reset,
   input wr_clear_residue,

   //-----------------------------
   //rd intfc
   input rd_en,

   output [143:0] dout,
   output empty,

   input rd_clk,

   //--------------------------
   // async reset
   input arst

   );

   reg [71:0] din_1, din_1_nxt;
   reg 	      din_1_vld;
   reg 	      din_1_vld_a1, din_1_vld_a1_nxt;
   reg 	      fifo_wr_en_nxt, fifo_wr_en;

   wire       fifo_full;

   assign     full = din_1_vld_a1 & fifo_full;


   async_fifo_144b
     async_fifo_144b_u
       (
	//-----------------------------
	//wr intfc
	//input:
	.din         ( {din_1, din} ),
	.wr_en       ( fifo_wr_en ),

	//output:
	.prog_full   (  ),
	.full        ( fifo_full ),

	//wr clk
	.wr_clk      ( wr_clk ),

	//-----------------------------
	//rd intfc
	//input:
	.rd_en       ( rd_en ),

	//output:
	.dout        ( dout ),
	.prog_empty  (  ),
	.empty       ( empty ),

	//rd clk
	.rd_clk      ( rd_clk ),

	//--------------------------
	// async reset
	.rst         ( arst )
 	);


   //-------------------------------------------------
   // Logic in wr_clk domain

   always @(*) begin

      //---------------------------------
      // pkt rd: from 64-bit dram to 72-bit bram
      fifo_wr_en_nxt = 1'b 0;
      din_1_vld_a1_nxt = din_1_vld_a1;
      din_1_nxt = din_1;

      if ( wr_en ) begin

	 if (~ din_1_vld_a1) begin
	    //will load din_1 one cycle later
	    din_1_vld_a1_nxt = 1'b 1;
	 end
	 else begin
	    //will write to fifo_144b_u.din one cycle later
	    fifo_wr_en_nxt = 1'b 1;

	    din_1_vld_a1_nxt = 1'b 0;
	 end

      end // if ( wr_en )

      if ( (~ din_1_vld) & ( din_1_vld_a1 ) )
	din_1_nxt = din;

      if (wr_clear_residue) begin
	 din_1_vld_a1_nxt = 1'b 0;
      end

   end // always @ (*)


   always @(posedge wr_clk) begin
      if (wr_reset) begin

	 din_1        <= 72'h 0;
	 din_1_vld_a1 <= 1'b 0;
	 din_1_vld    <= 1'b 0;
	 fifo_wr_en   <= 1'b 0;

      end
      else begin

	 din_1        <= din_1_nxt;
	 din_1_vld_a1 <= din_1_vld_a1_nxt;
	 din_1_vld    <= din_1_vld_a1;
	 fifo_wr_en   <= fifo_wr_en_nxt;

      end
   end // always @ (posedge wr_clk)


endmodule // async_fifo_in_72b_out_144b
