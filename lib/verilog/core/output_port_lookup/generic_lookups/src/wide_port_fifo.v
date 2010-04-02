///////////////////////////////////////////////////////////////////////////////
// $Id$
//
// Module: wide_port_fifo.v
// Project: event capture
// Description: A fifo that accepts different size inputs and outputs at a cst.
//              size.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1 ns/1 ns

module wide_port_fifo
  #(parameter INPUT_WORD_SIZE   = 8,   // word size
    parameter NUM_INPUTS        = 8,
    parameter OUTPUT_FACTOR     = 8,
    parameter OUTPUT_WORD_SIZE  = OUTPUT_FACTOR*INPUT_WORD_SIZE,    // word size
    parameter DEPTH_BITS        = log2(NUM_INPUTS)+2,   // to point to depth
    parameter NUM_INPUTS_SIZE   = log2(NUM_INPUTS+1)
  )
(
    // data input
    input [INPUT_WORD_SIZE*NUM_INPUTS-1:0] d_in,

    // number of data words to add
    input [NUM_INPUTS_SIZE-1:0] increment,

    // write and read enable
    input  wr_en,
    input  rd_en,

    // data output
    output [OUTPUT_WORD_SIZE-1:0] d_out,
    output empty,
    output full,

    output reg [DEPTH_BITS:0] num_words_in_fifo,

    // misc
    input  clk,
    input  rst
);

function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
endfunction

   parameter DEPTH = 2**DEPTH_BITS;     // FIFO depth in words

   //-------------------- Wire and reg declarations -----------
   // pointers
   reg [DEPTH_BITS-1:0] wr_ptr,rd_ptr;

   // the write-enable pins to the ram
   wire [0:NUM_INPUTS-1] wr_en_ram;

   wire [DEPTH_BITS-1:0] wr_ptr_next;
   wire [DEPTH_BITS-1:0] rd_ptr_next;

   //-------------------- Circuit Logic -------------------------

   generate
      genvar i;
      for(i=0; i<NUM_INPUTS; i=i+1) begin: wr_en_gen
         assign wr_en_ram[i] = (wr_en & ~full && (increment>i));
      end
   endgenerate

   // increment by number of words written
   assign wr_ptr_next = (wr_en & !full) ? wr_ptr+increment : wr_ptr;

   // increment read pointer
   assign rd_ptr_next = (rd_en & !empty)? rd_ptr+OUTPUT_FACTOR : rd_ptr;

   always @(posedge clk) begin
      if(rst) begin
         wr_ptr               <= 0;
         rd_ptr               <= 0;
         num_words_in_fifo    <= 0;
      end

      else begin
         wr_ptr               <= wr_ptr_next;
         rd_ptr               <= rd_ptr_next;

         num_words_in_fifo    <= num_words_in_fifo
                                 + ((wr_en & !full) ? increment : 0)
                                   - ((rd_en & !empty) ? OUTPUT_FACTOR : 0);

      end
   end // always @ (posedge clk)

   assign full = (num_words_in_fifo > DEPTH-NUM_INPUTS);
   assign empty = num_words_in_fifo < OUTPUT_FACTOR;

   // data mem
   wide_port_ram
     #(.INPUT_WORD_SIZE(INPUT_WORD_SIZE),
       .NUM_INPUTS(NUM_INPUTS),
       .DEPTH_BITS(DEPTH_BITS)) wide_port_ram
       (.d_in(d_in),
        .wr_en(wr_en_ram),
        .wr_addr(wr_ptr),
        .rd_addr(rd_ptr),
        .d_out(d_out),
        .clk(clk),
        .rst(rst)
        );

endmodule

module wide_port_fifo_tester ();

   reg [63:0] d_in = 0;
   reg [3:0]  increment = 0;
   reg 	      wr_en = 0;
   reg 	      rd_en = 0;
   wire [63:0] d_out;
   reg 	       clk = 0;
   reg         rst = 0;
   integer     count = 0;
   wire        empty;

   always #8 clk = ~clk;

   always @(posedge clk) begin
      count <= count + 1'b1;

      case (count)
	 0: begin
	    rst <= 1;
	 end

	 1: begin
	    rst <= 0;
	 end

	 2: begin
	    d_in <= {8'h00,
		    8'h11,
		    8'h22,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00};
	    increment <= 3;
	    wr_en <= 1'b1;
	 end // case: 2

	 3: begin
	    d_in <= {8'h33,
		    8'h44,
		    8'h55,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00};
	    increment <= 3;
	    wr_en <= 1'b1;
	 end // case: 2

	 4: begin
	    d_in <= {8'h66,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00};
	    increment <= 1;
	    wr_en <= 1'b1;
	 end // case: 2

	 5: begin
	    d_in <= {8'h77,
		    8'h88,
		    8'h99,
		    8'haa,
		    8'hbb,
		    8'hcc,
		    8'hdd,
		    8'hee};
	    increment <= 8;
	    wr_en <= 1'b1;
	 end // case: 2

	 6: begin
	    d_in <={8'hff,
		    8'h00,
		    8'h11,
		    8'h22,
		    8'h33,
		    8'h44,
		    8'h00,
		    8'h00
		    };
	    increment <= 6;
	    wr_en <= 1'b1;
	 end // case: 2

	 7: begin
	    d_in <={8'h55,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00
		    };
	    increment <= 1;
	    wr_en <= 1'b1;
	 end // case: 2

	 8: begin
	    d_in <= {8'h66,
		    8'h77,
		    8'h88,
		    8'h99,
		    8'h00,
		    8'h00,
		    8'h00,
		    8'h00};
	    increment <= 4;
	    wr_en <= 1'b1;
	 end // case: 2

	 9: begin
	    d_in <= {
		    8'haa,
		    8'hbb,
		    8'hcc,
		    8'hdd,
		    8'hee,
		    8'hff,
		    8'h00,
		    8'h00
		     };
	    increment <= 7;
	    wr_en <= 1'b1;
	 end // case: 2

	 10: begin
	    d_in <= {8'h11,
		    8'h22,
		    8'h33,
		    8'h44,
		     8'h00,
		    8'h00,
		    8'h00,
		    8'h00
		    };
	    increment <= 4;
	    wr_en <= 1'b1;
	 end // case: 2

	 11: begin
	    d_in <= {
		    8'h55,
		    8'h66,
		    8'h77,
		    8'h88,
		    8'h99,
		     8'h00,
		    8'h00,
		    8'h00};
	    increment <= 5;
	    wr_en <= 1'b1;
	 end // case: 2

	 12: begin
	    d_in <={8'haa,
		    8'hbb,
		    8'hcc,
		    8'hdd,
		    8'hee,
		    8'hff,
		    8'h00,
		    8'h00
		    };
	    increment <= 6;
	    wr_en <= 1'b1;
	 end // case: 2

	 15: begin
	    $finish;
	 end

      endcase // case(count)
   end // always @ (posedge clk)

   reg hi = 0;
   reg rd_en_d1;
   always @(posedge clk) begin
      if (!empty) begin
	 if(!hi) begin
	    if(d_out !== 64'h0011223344556677) begin
	       $display("%t %m ERROR: mismatch! expected 0x0011223344556677 found 0x%016x\n", $time, d_out);
	    end
	 end
	 else begin
	    if(d_out !== 64'h8899aabbccddeeff) begin
	       $display("%t %m ERROR: mismatch! expected 0x8899aabbccddeeff found 0x%016x\n", $time, d_out);
	    end
	 end // else: !if(!hi)
	 hi <= ~ hi;
      end // if (!empty)
   end // always @ (posedge clk)

   wide_port_fifo wide_port_fifo
    ( // data input
      .d_in (d_in),

      // number of data words to add
      .increment (increment),

      // write and read enable
      .wr_en (wr_en),
      .rd_en (!empty),

      // data output
      .d_out (d_out),
      .empty (empty),
      .full (full),

      .num_words_in_fifo (),

      // misc
      .clk (clk),
      .rst (rst)
      );

endmodule // wide_port_fifo_tester

