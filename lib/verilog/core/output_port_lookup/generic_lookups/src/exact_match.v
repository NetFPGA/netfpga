///////////////////////////////////////////////////////////////////////////////
// $Id: exact_match.v 3647 2008-04-23 02:29:18Z jnaous $
//
// Module: exact_match.v
// Project: generic lookups
// Author: Jad Naous <jnaous@stanford.edu>
// Description: matches a rule using two hash functions. Uses the
//              SRAM to store the lookup table including counters.
//
///////////////////////////////////////////////////////////////////////////////

  module exact_match
    #(parameter NUM_OUTPUT_QUEUES = 8,                  // obvious
      parameter PKT_SIZE_WIDTH = 12,                    // number of bits for pkt size
      parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_DATA_WIDTH = 128,
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter SRAM_DATA_WIDTH = DATA_WIDTH+CTRL_WIDTH,
      parameter EXACT_LOOKUP_PKT_CNTR_WIDTH = 0,  // needs to be overridden!
      parameter EXACT_LOOKUP_LAST_SEEN_WIDTH = 0, // needs to be overridden!
      parameter EXACT_LOOKUP_BYTE_CNTR_WIDTH = 0, // needs to be overridden!
      parameter EXACT_LOOKUP_PKT_CNTR_POS = 0,    // needs to be overridden!
      parameter EXACT_LOOKUP_LAST_SEEN_POS = 0,   // needs to be overridden!
      parameter EXACT_LOOKUP_BYTE_CNTR_POS = 0    // needs to be overridden!
      )
   (// --- Interface for lookups
    input  [PKT_SIZE_WIDTH-1:0]             pkt_size,
    input                                   pkt_size_vld,

    input  [DATA_WIDTH-1:0]                 rule_word,
    input                                   rule_word_vld,

    // --- Interface to arbiter
    output                                  exact_hit,
    output                                  exact_miss,
    output     [ENTRY_DATA_WIDTH-1:0]       exact_data,
    output                                  exact_data_vld,

    input                                   exact_wins,
    input                                   exact_loses,
    // --- SRAM Interface
    output [SRAM_ADDR_WIDTH-1:0]            wr_addr,
    output                                  wr_req,
    input                                   wr_ack,
    output     [SRAM_DATA_WIDTH-1:0]        wr_data,

    input                                   rd_ack,
    input  [SRAM_DATA_WIDTH-1:0]            rd_data,
    input                                   rd_vld,
    output [SRAM_ADDR_WIDTH-1:0]            rd_addr,
    output                                  rd_req,

    // --- Misc
    input [31:0]                            timer,
    input                                   reset,
    input                                   clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS       = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS       = ceildiv(ENTRY_DATA_WIDTH, DATA_WIDTH);

   // calculate number of memory locations an entry uses
   localparam ENTRY_IDX_WIDTH  = log2(NUM_RULE_WORDS+NUM_DATA_WORDS);
   localparam ENTRY_ADDR_WIDTH = SRAM_ADDR_WIDTH - ENTRY_IDX_WIDTH;

   //---------------------- Wires and regs----------------------------
   wire                       rd_0_rdy;
   wire [SRAM_DATA_WIDTH-1:0] rd_0_data;
   wire                       rd_0_vld;
   wire [SRAM_ADDR_WIDTH-1:0] rd_0_addr;
   wire                       rd_0_req;

   wire                       rd_1_rdy;
   wire [SRAM_DATA_WIDTH-1:0] rd_1_data;
   wire                       rd_1_vld;
   wire [SRAM_ADDR_WIDTH-1:0] rd_1_addr;
   wire                       rd_1_req;


   wire [ENTRY_ADDR_WIDTH-1:0] hash_0, hash_1;
   wire [ENTRY_ADDR_WIDTH-1:0] found_entry_hash;
   wire [DATA_WIDTH-1:0]       entry_counters;

   //------------------------- Modules -------------------------------

   /* create two push read ports from the single pull read port from the SRAM */
   sram_muxer
     #(.SRAM_ADDR_WIDTH (SRAM_ADDR_WIDTH),
       .SRAM_DATA_WIDTH (DATA_WIDTH + CTRL_WIDTH))
       sram_muxer
         (// --- interface to SRAM
          .rd_ack      (rd_ack),
          .rd_data     (rd_data),
          .rd_vld      (rd_vld),
          .rd_addr     (rd_addr),
          .rd_req      (rd_req),

          // --- read port 0
          .rd_0_rdy    (rd_0_rdy),
          .rd_0_data   (rd_0_data),
          .rd_0_vld    (rd_0_vld),
          .rd_0_addr   (rd_0_addr),
          .rd_0_req    (rd_0_req),

          // --- read port 1
          .rd_1_rdy    (rd_1_rdy),
          .rd_1_data   (rd_1_data),
          .rd_1_vld    (rd_1_vld),
          .rd_1_addr   (rd_1_addr),
          .rd_1_req    (rd_1_req),

          // --- Misc
          .reset       (reset),
          .clk         (clk)
          );

   /* create two hashes from each new rule */
   header_hash
     #(.OUTPUT_WIDTH     (ENTRY_ADDR_WIDTH),
       .NUM_DATA_WORDS   (NUM_RULE_WORDS))
       header_hash
         (.data              (rule_word),
          .data_vld          (rule_word_vld),
          .hash_0            (hash_0),
          .hash_1            (hash_1),
          .hashes_vld        (hashes_vld),
          .clk               (clk),
          .reset             (reset));

   /* issue the read requests for the rule words
    * using both rule hashes found */
   sram_rule_reader
     #(.NUM_RULE_BYTES     (NUM_RULE_BYTES),
       .ENTRY_ADDR_WIDTH   (ENTRY_ADDR_WIDTH),
       .SRAM_ADDR_WIDTH    (SRAM_ADDR_WIDTH),
       .CTRL_WIDTH         (CTRL_WIDTH),
       .DATA_WIDTH         (DATA_WIDTH))
       sram_rule_reader
         (.hash_0            (hash_0),
          .hash_1            (hash_1),
          .hashes_vld        (hashes_vld),
          .rd_rdy            (rd_0_rdy),
          .rd_addr           (rd_0_addr),
          .rd_req            (rd_0_req),
          .clk               (clk),
          .reset             (reset));

   /* check that the rule words read match the
    * rule words we are looking for */
   sram_rule_checker
     #(.NUM_RULE_BYTES     (NUM_RULE_BYTES),
       .ENTRY_ADDR_WIDTH   (ENTRY_ADDR_WIDTH),
       .SRAM_ADDR_WIDTH    (SRAM_ADDR_WIDTH),
       .CTRL_WIDTH         (CTRL_WIDTH),
       .DATA_WIDTH         (DATA_WIDTH))
       sram_entry_checker
         (.hash_0            (hash_0),
          .hash_1            (hash_1),
          .hashes_vld        (hashes_vld),

          .rule_word         (rule_word),
          .rule_word_vld     (rule_word_vld),

          .rd_vld            (rd_0_vld),
          .rd_data           (rd_0_data[DATA_WIDTH-1:0]),

          .found_entry_hash  (found_entry_hash),
          .entry_hit         (exact_hit),
          .entry_miss        (exact_miss),

          .clk               (clk),
          .reset             (reset));

   /* issue reads for the data in the found entry */
   sram_data_reader
     #(.NUM_RULE_BYTES     (NUM_RULE_BYTES),
       .ENTRY_ADDR_WIDTH   (ENTRY_ADDR_WIDTH),
       .ENTRY_DATA_WIDTH   (ENTRY_DATA_WIDTH),
       .SRAM_ADDR_WIDTH    (SRAM_ADDR_WIDTH),
       .DATA_WIDTH         (DATA_WIDTH),
       .CTRL_WIDTH         (CTRL_WIDTH))
       sram_data_reader
         (.found_entry_hash  (found_entry_hash),
          .entry_hit         (exact_hit),

          .rd_rdy            (rd_1_rdy),
          .rd_addr           (rd_1_addr),
          .rd_req            (rd_1_req),

          .clk               (clk),
          .reset             (reset));

   /* collect the data resulting from reading the entry
    * into a single word */
   sram_data_collector
     #(.NUM_RULE_BYTES     (NUM_RULE_BYTES),
       .ENTRY_ADDR_WIDTH   (ENTRY_ADDR_WIDTH),
       .ENTRY_DATA_WIDTH   (ENTRY_DATA_WIDTH),
       .SRAM_ADDR_WIDTH    (SRAM_ADDR_WIDTH),
       .CTRL_WIDTH         (CTRL_WIDTH),
       .DATA_WIDTH         (DATA_WIDTH))
       sram_data_collector
         (// --- SRAM Interface
          .rd_vld           (rd_1_vld),
          .rd_data          (rd_1_data[DATA_WIDTH-1:0]),

          // --- Lookup results
          .entry_data       (exact_data),
          .entry_counters   (entry_counters),
          .entry_data_vld   (exact_data_vld),

          // --- Misc
          .reset            (reset),
          .clk              (clk)
          );

   /* update the counters in the entry in case of a hit */
   entry_counter_update
     #(.NUM_RULE_BYTES     (NUM_RULE_BYTES),
       .ENTRY_DATA_WIDTH   (ENTRY_DATA_WIDTH),
       .ENTRY_ADDR_WIDTH   (ENTRY_ADDR_WIDTH),
       .SRAM_ADDR_WIDTH    (SRAM_ADDR_WIDTH),
       .DATA_WIDTH         (DATA_WIDTH),
       .CTRL_WIDTH         (CTRL_WIDTH),
       .PKT_CNTR_WIDTH     (EXACT_LOOKUP_PKT_CNTR_WIDTH),
       .LAST_SEEN_WIDTH    (EXACT_LOOKUP_LAST_SEEN_WIDTH),
       .BYTE_CNTR_WIDTH    (EXACT_LOOKUP_BYTE_CNTR_WIDTH),
       .PKT_CNTR_POS       (EXACT_LOOKUP_PKT_CNTR_POS),
       .LAST_SEEN_POS      (EXACT_LOOKUP_LAST_SEEN_POS),
       .BYTE_CNTR_POS      (EXACT_LOOKUP_BYTE_CNTR_POS),
       .PKT_SIZE_WIDTH     (PKT_SIZE_WIDTH))
       entry_counter_update
         (// --- SRAM Interface
          .wr_ack             (wr_ack),
          .wr_data            (wr_data[DATA_WIDTH-1:0]),
          .wr_addr            (wr_addr),
          .wr_req             (wr_req),

          // --- rule maker interface
          .pkt_size           (pkt_size),
          .pkt_size_vld       (pkt_size_vld),

          // --- Lookup results
          .found_entry_hash   (found_entry_hash),
          .entry_hit          (exact_hit),
          .entry_miss         (exact_miss),

          .exact_wins         (exact_wins),
          .exact_loses        (exact_loses),

          .entry_counters     (entry_counters),
          .entry_data_vld     (exact_data_vld),

          // --- Misc
          .timer              (timer[EXACT_LOOKUP_LAST_SEEN_WIDTH-1:0]),
          .reset              (reset),
          .clk                (clk)
          );

   //-------------------------- Logic --------------------------------
   assign     wr_data[DATA_WIDTH+CTRL_WIDTH-1:DATA_WIDTH] = 0;

endmodule // exact_match



