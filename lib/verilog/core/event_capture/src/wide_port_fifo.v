///////////////////////////////////////////////////////////////////////////////
// $Id: wide_port_fifo.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: wide_port_fifo.v
// Project: event capture
// Description: A fifo that accepts different size inputs and outputs at a cst.
//              size.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1 ns/1 ns

module wide_port_fifo
  #(parameter INPUT_WORD_SIZE   = 32,   // word size
    parameter NUM_INPUTS        = 32,
    parameter OUTPUT_WORD_SIZE  = 2*INPUT_WORD_SIZE,    // word size
    parameter DEPTH_BITS        = log2(NUM_INPUTS),   // to point to depth
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
   endfunction // log2

   parameter DEPTH = 2**DEPTH_BITS;     // FIFO depth in words

   //-------------------- Wire and reg declarations -----------
   // pointers
   reg [DEPTH_BITS-1:0] wr_ptr,rd_ptr;

   // the write-enable pins to the ram
   wire [NUM_INPUTS-1:0] wr_en_ram;

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
   assign rd_ptr_next = (rd_en & !empty)? rd_ptr+2 : rd_ptr;

   always @(posedge clk) begin
      if(rst) begin
         wr_ptr<=0;
         rd_ptr<=0;
         num_words_in_fifo <= 0;
      end

      else begin
         wr_ptr <= wr_ptr_next;
         rd_ptr <= rd_ptr_next;

         num_words_in_fifo <= num_words_in_fifo + ((wr_en & !full) ? increment : 0) - ((rd_en & !empty) ? 2 : 0);

      end
   end // always @ (posedge clk)

   assign full = (num_words_in_fifo > DEPTH-NUM_INPUTS);
   assign empty = num_words_in_fifo < 2;

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
