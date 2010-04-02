///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: async_fifo_in_72b_out_288b.v
// Project: NetFPGA
// Description: an implementation of 72-bit input/288-bit output
// asynchronous FIFO. It onsists of two 144-bit async FIFOs.
//
///////////////////////////////////////////////////////////////////////////////


module async_fifo_in_72b_out_288b
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

   output [287:0] dout,
   output empty,

   input rd_clk,

   //--------------------------
   // async reset
   input arst
   );

   reg [215:0] din_1, din_1_nxt;
   reg 	      din_1_latch_a1, din_1_latch_a1_nxt;
   reg [1:0]  din_1_cnt_a1, din_1_cnt_a1_nxt;

   reg 	      fifo_wr_en_nxt, fifo_wr_en;

   wire       fifo_prog_full_1, fifo_prog_full_0;
   wire       fifo_prog_full = fifo_prog_full_1 | fifo_prog_full_0;

   assign     full = (din_1_cnt_a1 == 3) & fifo_prog_full;

   wire       empty_1, empty_0;
   assign     empty = empty_1 | empty_0;


   async_fifo_144b
     async_fifo_144b_u0
       (
	//-----------------------------
	//wr intfc
	//input:
	.din         ( {din_1[71: 0], din} ),
	.wr_en       ( fifo_wr_en ),

	//output:
	.prog_full   (  fifo_prog_full_0 ),
	.full        (  ),

	//wr clk
	.wr_clk      ( wr_clk ),

	//-----------------------------
	//rd intfc
	//input:
	.rd_en       ( rd_en ),

	//output:
	.dout        ( dout[143:0] ),
	.prog_empty  (  ),
	.empty       ( empty_0 ),

	//rd clk
	.rd_clk      ( rd_clk ),

	//--------------------------
	// async reset
	.rst         ( arst )
 	);

   async_fifo_144b
     async_fifo_144b_u1
       (
	//-----------------------------
	//wr intfc
	//input:
	.din         ( din_1[215: 72] ),
	.wr_en       ( fifo_wr_en ),

	//output:
	.prog_full   ( fifo_prog_full_1 ),
	.full        (  ),

	//wr clk
	.wr_clk      ( wr_clk ),

	//-----------------------------
	//rd intfc
	//input:
	.rd_en       ( rd_en ),

	//output:
	.dout        ( dout[287:144] ),
	.prog_empty  (  ),
	.empty       ( empty_1 ),

	//rd clk
	.rd_clk      ( rd_clk ),

	//--------------------------
	// async reset
	.rst         ( arst )
 	);


   //-------------------------------------------------
   // Logic in wr_clk domain

   always @(*) begin

      fifo_wr_en_nxt = 1'b 0;
      din_1_latch_a1_nxt = 1'b 0;
      din_1_cnt_a1_nxt = din_1_cnt_a1;
      din_1_nxt = din_1;

      if ( wr_en ) begin

	 if (din_1_cnt_a1 < 3) begin
	    //will load din_1 one cycle later
	    din_1_latch_a1_nxt = 1'b 1;
	    din_1_cnt_a1_nxt = din_1_cnt_a1 + 1;

	 end
	 else begin
	    //will write to fifo_144b_u.din one cycle later
	    fifo_wr_en_nxt = 1'b 1;
	    din_1_cnt_a1_nxt = 2'b 0;
	 end

      end // if ( wr_en )

      if (din_1_latch_a1)
	din_1_nxt = {din_1[215:0], din};

      if (wr_clear_residue) begin
	 din_1_cnt_a1_nxt = 2'b 0;
      end

   end // always @ (*)


   always @(posedge wr_clk) begin
      if (wr_reset) begin

	 din_1          <= 216'h 0;
	 din_1_latch_a1 <= 1'b 0;
	 din_1_cnt_a1   <= 2'b 0;
	 fifo_wr_en     <= 1'b 0;

      end
      else begin

	 din_1          <= din_1_nxt;
	 din_1_latch_a1 <= din_1_latch_a1_nxt;
	 din_1_cnt_a1   <= din_1_cnt_a1_nxt;
	 fifo_wr_en     <= fifo_wr_en_nxt;

      end
   end // always @ (posedge wr_clk)

endmodule // async_fifo_in_72b_out_288b
