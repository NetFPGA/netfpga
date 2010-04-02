/***************************************************
 * $Id$
 *
 * Module: priority_encoder.v
 * Project: NF2.1
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: parametrizable priority encoder.
 *
 * Highest priority by default given to rightmost bit.
 *
 * Usually just specify the OUTPUT_WIDTH. INPUT_WIDTH
 * is optional. Defaults to 2**OUTPUT_WIDTH.
 *
 ***************************************************/
module priority_encoder
  #(parameter OUTPUT_WIDTH = 8,
    parameter RIGHT_TO_LEFT_PRIORITY = 1)

    (input  [0:(2**OUTPUT_WIDTH)-1]  unencoded_input,
     output [OUTPUT_WIDTH-1:0]       encoded_output,
     output                          valid);

   localparam INPUT_WIDTH = 2**OUTPUT_WIDTH;
   localparam INPUT_VAL_WIDTH = INPUT_WIDTH*OUTPUT_WIDTH;
   localparam STYLE = 0;

   generate
      genvar i,j;
      if(STYLE==0) begin
         for(i=0; i<OUTPUT_WIDTH; i=i+1) begin:gen_levels
            for(j=0; j<INPUT_WIDTH/(2**(i+1)); j=j+1) begin:gen_nodes
               wire [OUTPUT_WIDTH-1:0] value;
               wire                    valid;

               wire [OUTPUT_WIDTH-1:0] left_val;
               wire                    left_vld;
               wire [OUTPUT_WIDTH-1:0] right_val;
               wire                    right_vld;

               if(i==0) begin
                  assign left_val    = j*2;
                  assign left_vld    = unencoded_input[j*2];
                  assign right_val   = j*2 + 1;
                  assign right_vld   = unencoded_input[j*2+1];
               end
               else begin
                  assign left_val    = gen_levels[i-1].gen_nodes[j*2].value;
                  assign left_vld    = gen_levels[i-1].gen_nodes[j*2].valid;
                  assign right_val   = gen_levels[i-1].gen_nodes[j*2+1].value;
                  assign right_vld   = gen_levels[i-1].gen_nodes[j*2+1].valid;
               end // else: !if(i==0)

               assign value = (RIGHT_TO_LEFT_PRIORITY ?
                               (right_vld ? right_val : left_val) :
                               (left_vld ? left_val : right_val));
               assign valid = right_vld | left_vld;
            end // block: gen_nodes
         end // block: gen_levels
         // synthesis attribute priority_extract of encoded_output is "force"
         assign       encoded_output = gen_levels[OUTPUT_WIDTH-1].gen_nodes[0].value;
         assign       valid = gen_levels[OUTPUT_WIDTH-1].gen_nodes[0].valid;
      end // if (STYLE==0)

      else begin
         for(i=0; i<OUTPUT_WIDTH; i=i+1) begin:gen_levels
            for(j=0; j<INPUT_WIDTH/(2**(i+1)); j=j+1) begin:gen_nodes
               wire [i:0]              value;
               wire                    valid;

               if(i==0) begin
                  assign value = RIGHT_TO_LEFT_PRIORITY ? unencoded_input[j*2+1] : unencoded_input[j*2];
                  assign valid = unencoded_input[j*2+1] | unencoded_input[j*2];
               end
               else begin
                  wire [i-1:0]  left_val;
                  wire          left_vld;
                  wire [i-1:0]  right_val;
                  wire          right_vld;
                  assign left_val    = gen_levels[i-1].gen_nodes[j*2].value;
                  assign left_vld    = gen_levels[i-1].gen_nodes[j*2].valid;
                  assign right_val   = gen_levels[i-1].gen_nodes[j*2+1].value;
                  assign right_vld   = gen_levels[i-1].gen_nodes[j*2+1].valid;
                  assign value       = (RIGHT_TO_LEFT_PRIORITY ?
                                        (right_vld ? {1'b1, right_val} : {1'b0, left_val}) :
                                        (left_vld ? {1'b0, left_val} : {1'b1, right_val}));
                  assign valid       = right_vld | left_vld;
               end // else: !if(i==0)
            end // block: gen_nodes
         end // block: gen_levels

         // synthesis attribute priority_extract of encoded_output is "force"
         assign       encoded_output = gen_levels[OUTPUT_WIDTH-1].gen_nodes[0].value;
         assign       valid = gen_levels[OUTPUT_WIDTH-1].gen_nodes[0].valid;
      end // else: !if(STYLE==0)
   endgenerate
endmodule

// synthesise translate_off
module pri_encode_test ();
   reg [0:7] unencoded_input = 8'h0;
   wire [2:0] encoded_output;
   wire valid;

   priority_encoder
     #(.OUTPUT_WIDTH(3))
     priority_encoder
     (.valid (valid),
      .encoded_output (encoded_output),
      .unencoded_input (unencoded_input));

   initial begin
      unencoded_input[7] = 1'b1;
      unencoded_input[2] = 1'b1;
      unencoded_input[3] = 1'b1;

      #2 if(encoded_output != 7) $display("%t ERROR: Wrong pri exp: %u, found: %u, unenc:%08x %m", $time, 7, encoded_output, unencoded_input);

      #2 unencoded_input = 0;
      unencoded_input[6] = 1'b1;
      unencoded_input[3] = 1'b1;
      unencoded_input[0]  = 1'b1;

      #2 if(encoded_output != 6) $display("%t ERROR: Wrong pri exp: %u, found: %u, unenc:%08x %m", $time, 6, encoded_output, unencoded_input);

      #2 unencoded_input = 0;
      unencoded_input[0]  = 1'b1;

      #2 if(encoded_output != 0) $display("%t ERROR: Wrong pri exp: %u, found: %u, unenc:%08x %m", $time, 0, encoded_output, unencoded_input);

      #2 unencoded_input = 0;
      unencoded_input[7] = 1'b1;

      #2 if(encoded_output != 7) $display("%t ERROR: Wrong pri exp: %u, found: %u, unenc:%08x %m", $time, 7, encoded_output, unencoded_input);

      #2 unencoded_input = 255;

      #2 if(encoded_output != 7) $display("%t ERROR: Wrong pri exp: %u, found: %u, unenc:%08x %m", $time, 7, encoded_output, unencoded_input);

      #2 $display("%t Test ended.", $time);
   end // initial begin
endmodule // pri_encode_test
// synthesise translate_on
