/*******************************************************************************
 * $Id$
 *
 * Module: sram_data_reader.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: Issues reads for the data found in the lookup entry
 *
 *******************************************************************************/

module sram_data_reader
    #(parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_DATA_WIDTH = 128,
      parameter ENTRY_ADDR_WIDTH = 15,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- Interface to rule checker
    input  [ENTRY_ADDR_WIDTH-1:0]           found_entry_hash,
    input                                   entry_hit,

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
   localparam NUM_RULE_WORDS     = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS     = ceildiv(ENTRY_DATA_WIDTH, DATA_WIDTH);
   localparam ENTRY_IDX_WIDTH    = SRAM_ADDR_WIDTH - ENTRY_ADDR_WIDTH;

   localparam WAIT_FOR_HIT       = 0;
   localparam READ_DATA_WORDS    = 1;

   //---------------------- Wires and regs----------------------------
   reg                           hash_fifo_rd_en;
   wire [ENTRY_ADDR_WIDTH-1:0]   dout_hash;

   reg                           state;
   reg [log2(NUM_DATA_WORDS):0]  count;

   wire [log2(NUM_DATA_WORDS):0] count_plus_1;
   wire [SRAM_ADDR_WIDTH-1:0]    rd_addr_plus_1;

   //------------------------- Modules -------------------------------
   fallthrough_small_fifo
     #(.WIDTH(ENTRY_ADDR_WIDTH), .MAX_DEPTH_BITS(1))
      hashes_fifo
        (.din           (found_entry_hash),
         .wr_en         (entry_hit),
         .rd_en         (hash_fifo_rd_en),
         .dout          (dout_hash),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (hash_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------- Logic --------------------------------

   assign rd_addr_plus_1   = rd_addr + 1'b1;
   assign count_plus_1     = count + 1'b1;

   always @(posedge clk) begin
      if(reset) begin
         rd_req 	    <= 0;
         state 		    <= WAIT_FOR_HIT;
         hash_fifo_rd_en    <= 0;
      end
      else begin

         // defaults
         rd_req             <= 0;
         hash_fifo_rd_en    <= 0;

         case (state)
            WAIT_FOR_HIT: begin
               if(!hash_fifo_empty && rd_rdy) begin
                  /* first word is the counters word */
                  rd_addr              <= {dout_hash, NUM_RULE_WORDS[ENTRY_IDX_WIDTH-1:0]};
                  rd_req               <= 1'b1;
                  state                <= READ_DATA_WORDS;
                  count                <= 0;
                  hash_fifo_rd_en      <= 1'b1;
               end
            end

            READ_DATA_WORDS: begin
               if(rd_rdy) begin
                  if(count >= NUM_DATA_WORDS-1) begin
                     state   <= WAIT_FOR_HIT;
                  end
                  rd_addr    <= rd_addr_plus_1;
                  rd_req     <= 1'b1;
                  count      <= count_plus_1;
               end // if (rd_rdy)
            end
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // sram_read_issuer
