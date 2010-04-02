///////////////////////////////////////////////////////////////////////////////
// $Id: wide_port_ram.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: wide_port_ram
// Project: event capture
// Description: A ram that allows writing large words and taking them out segmented
//
// Notes: This is fully parametrizable except for that OUTPUT_WORD_SIZE=2*INPUT_WORD_SIZE
///////////////////////////////////////////////////////////////////////////////
`timescale 1 ns/1 ns

module wide_port_ram
  #(parameter INPUT_WORD_SIZE  = 32,
    parameter NUM_INPUTS       = 5,
    parameter OUTPUT_WORD_SIZE = 2*INPUT_WORD_SIZE,
    parameter DEPTH_BITS       = 5      // to point to depth in input sized words
    )
    (
     // data input
     input [INPUT_WORD_SIZE*NUM_INPUTS-1:0] d_in,
     // wr_en (1 bit per port)
     input [NUM_INPUTS-1:0]  wr_en,

     // start of write and rd addresses
     input [DEPTH_BITS-1:0] wr_addr,
     input [DEPTH_BITS-1:0] rd_addr,

     // data output
     output [OUTPUT_WORD_SIZE-1:0] d_out,

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
   endfunction // log2

   parameter DEPTH       = 2**DEPTH_BITS;       // RAM depth in INPUT_WORD_SIZE words

   // data fifo
   reg [INPUT_WORD_SIZE-1:0]  ram_words [DEPTH-1:0];

   wire [INPUT_WORD_SIZE-1:0] d_in_words[NUM_INPUTS-1:0];
   wire [DEPTH_BITS-1:0]      wr_addr_inc[NUM_INPUTS-1:0];
   wire [DEPTH_BITS-1:0]      rd_addr_plus1;

   generate
      genvar j;
      for(j=0; j<NUM_INPUTS; j=j+1) begin: gen_words
         assign d_in_words[j] = d_in[INPUT_WORD_SIZE*(j+1)-1:INPUT_WORD_SIZE*j];
	 assign wr_addr_inc[j] = wr_addr+j;
      end
   endgenerate

   // write into the ram
   integer 	i;
   always @(posedge clk) begin
      for(i=0; i<NUM_INPUTS; i=i+1) begin
	 ram_words[wr_addr_inc[i]] <= wr_en[i] ? d_in_words[i] : ram_words[wr_addr_inc[i]];
      end
   end

   assign rd_addr_plus1 = rd_addr+1'b1;
   assign d_out={ram_words[rd_addr], ram_words[rd_addr_plus1]};

endmodule // wide_port_ram
