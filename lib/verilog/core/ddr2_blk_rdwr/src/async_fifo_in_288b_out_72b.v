///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: async_fifo_in_288b_out_72b.v
// Project: NetFPGA
// Description: an implementation of 288-bit input/72-bit output
// asynchronous FIFO. It consists of two instances of
// 144-bit input/36-bit output asynchronous FIFOs
//
///////////////////////////////////////////////////////////////////////////////

module async_fifo_in_288b_out_72b
  (

   //-----------------------------------
   //wr intfc
   input [287:0] din,
   input wr_en,

   output almost_full,
   output full,

   input wr_clk,

   //-----------------------------------
   //rd intfc
   input rd_en,

   output almost_empty,
   output empty,
   output [71:0] dout,

   input rd_clk,

   //-----------------------------------
   // async reset
   input rst
   );

   async_fifo_in_144b_out_36b
     high_half
       (
	//-----------------------------------
	//wr intfc
	//input:
        .din         (
		       {din[287:252],
			din[215:180],
			din[143:108],
			din[ 71: 36]}
		       ),
        .wr_en       ( wr_en ),

	//output:
        .almost_full ( almost_full_hi ),
        .full        ( full_hi ),

	//clk:
        .wr_clk      ( wr_clk ),

	//-----------------------------------
	//rd intfc
	//input:
        .rd_en        ( rd_en ),

	//output:
        .almost_empty ( almost_empty_hi ),
        .empty        ( empty_hi ),
        .dout         ( dout[71:36] ),

	//clk:
        .rd_clk       ( rd_clk ),

	//-----------------------------------
	// async rst
        .rst          ( rst )
	);

   async_fifo_in_144b_out_36b
     low_half
       (
	//-----------------------------------
	//wr intfc
	//input:
        .din         (
		       {din[251:216],
			din[179:144],
			din[107: 72],
			din[ 35:  0]}
		       ),
        .wr_en       ( wr_en ),

	//output:
        .almost_full ( almost_full_lo ),
        .full        ( full_lo ),

	//clk:
        .wr_clk      ( wr_clk ),

	//-----------------------------------
	//rd intfc
	//input:
        .rd_en        ( rd_en ),

	//output:
        .almost_empty ( almost_empty_lo ),
        .empty        ( empty_lo ),
        .dout         ( dout[35:0] ),

	//clk:
        .rd_clk       ( rd_clk ),

	//-----------------------------------
	// async rst
        .rst          ( rst )

	);

   assign almost_full = almost_full_hi | almost_full_lo;
   assign full = full_hi | full_lo;

   assign almost_empty = almost_empty_hi | almost_empty_lo;
   assign empty = empty_hi | empty_lo;


endmodule // async_fifo_in_288b_out_72b
