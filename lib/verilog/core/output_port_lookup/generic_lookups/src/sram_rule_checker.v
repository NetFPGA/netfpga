/*******************************************************************************
 * $Id$
 *
 * Module: sram_rule_checker.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: Checks that the rules read from SRAM match the rule in the packet
 *
 *******************************************************************************/

module sram_rule_checker
    #(parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_ADDR_WIDTH = 15,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter FLIP_BYTE_ORDER = 1,  // flip the bytes ordering of the lookup/data
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- Interface for lookups
    input  [ENTRY_ADDR_WIDTH-1:0]           hash_0,
    input  [ENTRY_ADDR_WIDTH-1:0]           hash_1,
    input                                   hashes_vld,

    input  [DATA_WIDTH-1:0]                 rule_word,
    input                                   rule_word_vld,

    // --- SRAM Interface
    input                                   rd_vld,
    input  [DATA_WIDTH-1:0]                 rd_data,

    // --- results
    output reg [ENTRY_ADDR_WIDTH-1:0]       found_entry_hash,
    output reg                              entry_hit,
    output reg                              entry_miss,

    // --- Misc
    input                                   reset,
    input                                   clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS      = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);

   localparam NUM_STATES          = 3;
   localparam WAIT_FOR_WORDS      = 1,
              READ_HASH_0_WORDS   = 2,
              READ_HASH_1_WORDS   = 4;

   //---------------------- Wires and regs----------------------------
   reg                         hashes_fifo_rd_en;
   wire [ENTRY_ADDR_WIDTH-1:0] dout_hash_1, dout_hash_0;

   reg [NUM_STATES-1:0]        state, state_nxt;
   reg [3:0]                   count, count_nxt;
   wire [3:0]                  count_plus_1;

   wire [DATA_WIDTH-1:0]       dout_rule_word_0;
   wire [DATA_WIDTH-1:0]       dout_rule_word_1;

   reg                         match_0, match_1;
   reg                         match_0_nxt, match_1_nxt;
   reg                         rule_fifo_rd_en_0, rule_fifo_rd_en_1;

   /* pipelining and byte swapping if necessary */
   reg                         rd_vld_local;
   reg [DATA_WIDTH-1:0]        rd_data_local;
   wire [DATA_WIDTH-1:0]       rd_data_int;

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

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH), .MAX_DEPTH_BITS(3))
      rule_fifo_0
        (.din           (rule_word),
         .wr_en         (rule_word_vld),
         .rd_en         (rule_fifo_rd_en_0),
         .dout          (dout_rule_word_0),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (rule_fifo_empty_0),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH), .MAX_DEPTH_BITS(3))
      rule_fifo_1
        (.din           (rule_word),
         .wr_en         (rule_word_vld),
         .rd_en         (rule_fifo_rd_en_1),
         .dout          (dout_rule_word_1),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (rule_fifo_empty_1),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------- Logic --------------------------------

   generate
      genvar  i;
      if(FLIP_BYTE_ORDER) begin
	 for(i=0; i<DATA_WIDTH/8; i=i+1) begin:gen_flip
            assign rd_data_int[8*i+7:8*i]  = rd_data[DATA_WIDTH-1-i*8:DATA_WIDTH-8-i*8];
	 end
      end
      else begin
	 assign rd_data_int = rd_data;
      end
   endgenerate

   assign count_plus_1 = count + 1'b1;

   always @(*) begin
      // defaults
      entry_hit            = 0;
      entry_miss           = 0;
      match_0_nxt          = match_0;
      match_1_nxt          = match_1;
      count_nxt            = count;
      state_nxt            = state;
      hashes_fifo_rd_en    = 0;
      rule_fifo_rd_en_0    = 0;
      rule_fifo_rd_en_1    = 0;
      found_entry_hash     = (match_0===1'b1) ? dout_hash_0 : dout_hash_1;
      case (state)
         WAIT_FOR_WORDS: begin
            if(rd_vld_local) begin
               // synthesis translate_off
               if(hashes_fifo_empty) begin
                  $display("%t %m ERROR: sram read when no hashes present.\n", $time);
                  $stop;
               end
               // synthesis translate_on
               rule_fifo_rd_en_0     = 1;
               match_0_nxt           = (rd_data_local == dout_rule_word_0);
               state_nxt             = READ_HASH_0_WORDS;
               count_nxt             = 1;
            end
         end

         READ_HASH_0_WORDS: begin
            if(rd_vld_local) begin
               if(count >= NUM_RULE_WORDS) begin
                  rule_fifo_rd_en_1    = 1;
                  match_1_nxt          = (rd_data_local == dout_rule_word_1);
                  state_nxt            = READ_HASH_1_WORDS;
                  count_nxt            = 1;
               end
               else begin
                  rule_fifo_rd_en_0    = 1;
                  match_0_nxt          = match_0 && (rd_data_local == dout_rule_word_0);
                  count_nxt            = count_plus_1;
               end
            end // if (rd_vld_local)
         end // case: READ_HASH_0_WORDS

         READ_HASH_1_WORDS: begin
            if(rd_vld_local) begin
               if(count >= NUM_RULE_WORDS-1) begin
                  state_nxt            = WAIT_FOR_WORDS;
                  hashes_fifo_rd_en    = 1'b1;
                  entry_miss           = ! ((match_0===1'b1) || ((match_1===1'b1) && (rd_data_local === dout_rule_word_1)));
                  entry_hit            = (match_0===1'b1) || ((match_1===1'b1) && (rd_data_local === dout_rule_word_1));
               end
               rule_fifo_rd_en_1    = 1;
               match_1_nxt          = match_1 && (rd_data_local == dout_rule_word_1);
               count_nxt            = count_plus_1;
            end // if (rd_vld_local)
         end // case: READ_HASH_1_WORDS
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state            <= WAIT_FOR_WORDS;
         match_0          <= 0;
         match_1          <= 0;
         count            <= 1;
         rd_vld_local     <= 0;
         rd_data_local    <= 0;
      end
      else begin
         state            <= state_nxt;
         match_0          <= match_0_nxt;
         match_1          <= match_1_nxt;
         count            <= count_nxt;
         rd_vld_local     <= rd_vld;
	 rd_data_local    <= rd_data_int;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // sram_rule_checker
