/***************************************
 * $Id$
 *
 * Module: rotate.v
 * Author: Jad Naous
 * Project: utils
 * Description: Rotates a vector by some amount
 *
 * Change history:
 *
 ***************************************/

module rotate
  #(parameter UNIT_SIZE   = 1,
    parameter NUM_UNITS   = 4,
    parameter SHIFT_LEFT  = 1,
    parameter INPUT_SIZE  = UNIT_SIZE*NUM_UNITS,
    parameter ROTATE_SIZE = log2(NUM_UNITS))
    (input     [0:INPUT_SIZE-1]   din,
     input     [ROTATE_SIZE-1:0]  rotation,
     output    [0:INPUT_SIZE-1]   dout);

   wire [0:INPUT_SIZE-1] all_rotations[0:NUM_UNITS-1];

   `LOG2_FUNC

   generate
      genvar i;
      assign all_rotations[0] = din;
      if(SHIFT_LEFT) begin
         for(i=1; i<NUM_UNITS; i=i+1) begin: gen_rotations
            assign all_rotations[i] = {din[i*UNIT_SIZE : INPUT_SIZE-1], din[0:i*UNIT_SIZE-1]};
         end
      end
      else begin
         for(i=1; i<NUM_UNITS; i=i+1) begin: gen_rotations
            assign all_rotations[i] = {din[INPUT_SIZE-i*UNIT_SIZE : INPUT_SIZE-1], din[0:INPUT_SIZE-i*UNIT_SIZE-1]};
         end
      end
   endgenerate

   assign dout = all_rotations[rotation];
endmodule // rotate
