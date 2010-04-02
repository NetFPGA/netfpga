/*******************************************************************************
 * $Id$
 *
 * Module: sram_rule_reader.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: Issues reads for both hashes of a rule when it comes in.
 *
 *******************************************************************************/

module sram_rule_reader
    #(parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_ADDR_WIDTH = 15,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- Interface for lookups
    input  [ENTRY_ADDR_WIDTH-1:0]           hash_0,
    input  [ENTRY_ADDR_WIDTH-1:0]           hash_1,
    input                                   hashes_vld,

    // --- SRAM Interface
    input                                   rd_rdy,
    output reg [SRAM_ADDR_WIDTH-1:0]        rd_addr,
    output reg                              rd_req,

    // --- Misc
    input                                   reset,
    input                                   clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS      = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam ENTRY_IDX_WIDTH     = SRAM_ADDR_WIDTH - ENTRY_ADDR_WIDTH;

   localparam NUM_STATES          = 3;
   localparam WAIT_FOR_WORDS      = 1,
              READ_HASH_0_WORDS   = 2,
              READ_HASH_1_WORDS   = 4;

   //---------------------- Wires and regs----------------------------
   reg                         hashes_fifo_rd_en;
   wire [ENTRY_ADDR_WIDTH-1:0] dout_hash_1, dout_hash_0;

   reg [NUM_STATES-1:0]        state;
   reg [3:0]                   count; /* probably can be smaller,
                                       * but it's one bit, so who cares? */

   wire [3:0]                  count_plus_1;
   wire [SRAM_ADDR_WIDTH-1:0]  rd_addr_plus_1;

   //------------------------- Modules -------------------------------
   fallthrough_small_fifo
     #(.WIDTH(2*ENTRY_ADDR_WIDTH), .MAX_DEPTH_BITS(1))
      hashes_fifo
        (.din           ({hash_1, hash_0}),
         .wr_en         (hashes_vld),
         .rd_en         (hashes_fifo_rd_en),
         .dout          ({dout_hash_1, dout_hash_0}),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (hashes_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------- Logic --------------------------------

   assign rd_addr_plus_1     = rd_addr + 1'b1;
   assign count_plus_1       = count + 1'b1;

   always @(posedge clk) begin
      if(reset) begin
         rd_req               <= 0;
         state                <= WAIT_FOR_WORDS;
         hashes_fifo_rd_en    <= 0;
      end
      else begin

         // defaults
         rd_req               <= 0;
         hashes_fifo_rd_en    <= 0;

         case (state)
            WAIT_FOR_WORDS: begin
               if(!hashes_fifo_empty && rd_rdy) begin
                  rd_addr              <= {dout_hash_0, {ENTRY_IDX_WIDTH{1'b0}}};
                  rd_req               <= 1'b1;
                  state                <= READ_HASH_0_WORDS;
                  count                <= 1;
               end
            end

            READ_HASH_0_WORDS: begin
               if(rd_rdy) begin
                  if(count >= NUM_RULE_WORDS) begin
                     rd_addr              <= {dout_hash_1, {ENTRY_IDX_WIDTH{1'b0}}};
                     rd_req               <= 1'b1;
                     count                <= 1;
                     state                <= READ_HASH_1_WORDS;
                     hashes_fifo_rd_en    <= 1'b1;
                  end
                  else begin
                     rd_addr    <= rd_addr_plus_1;
                     rd_req     <= 1'b1;
                     count      <= count_plus_1;
                  end
               end // if (rd_rdy)
            end // case: READ_HASH_0_WORDS

            READ_HASH_1_WORDS: begin
               if(rd_rdy) begin
                  if(count >= NUM_RULE_WORDS-1) begin
                     state <= WAIT_FOR_WORDS;
                  end
                  rd_addr    <= rd_addr_plus_1;
                  rd_req     <= 1'b1;
                  count      <= count_plus_1;
               end // if (rd_rdy)
            end // case: READ_HASH_1_WORDS
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // sram_rule_reader
