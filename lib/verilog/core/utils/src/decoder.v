/***************************************************
 * $Id$
 *
 * Module: decoder.v
 * Project: NF2.1
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: parametrizable binary decoder.
 *
 * Usually just specify the INPUT_WIDTH. OUTPUT_WIDTH
 * is optional. Defaults to 2**INPUT_WIDTH.
 ***************************************************/

module decoder
  #(parameter INPUT_WIDTH  = 5,
    parameter OUTPUT_WIDTH = 2**INPUT_WIDTH
    )

    (input [INPUT_WIDTH-1:0]   encoded_input,
     output reg [OUTPUT_WIDTH-1:0] unencoded_output);

   always@(*) begin
      unencoded_output = 0;
      unencoded_output[encoded_input] = 1'b1;
   end
endmodule

