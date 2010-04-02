///////////////////////////////////////////////////////////////////////////////
// $Id: wildcard_match.v 3686 2008-05-05 18:32:57Z jnaous $
//
// Module: wildcard_match.v
// Project: generic lookups
// Author: Jad Naous <jnaous@stanford.edu>
// Description: matches a rule allowing a wildcard
//   Uses a register block to maintain counters associated with the table
//
///////////////////////////////////////////////////////////////////////////////


  module wildcard_match
    #(parameter NUM_OUTPUT_QUEUES = 8,                  // obvious
      parameter PKT_SIZE_WIDTH = 12,                    // number of bits for pkt size
      parameter NUM_RULE_BYTES = 48,                    // number of bytes in the rule we are looking for
      parameter ENTRY_DATA_WIDTH = 128,                 // length of the data read when rule is found in bits
      parameter UDP_REG_SRC_WIDTH = 2,                  // identifies which module started this request
      parameter WILDCARD_TABLE_SIZE = 32,               // number of entries we can fit in the table
      parameter WILDCARD_REG_ADDR_WIDTH = 6,            // should be overridden
      parameter WILDCARD_LOOKUP_BLOCK_TAG = 3,          // should be overridden
      parameter DATA_WIDTH = 64
      )
   (// --- Interface for lookups
    input [DATA_WIDTH-1:0]                 rule_word,
    input                                  rule_word_vld,
    input [PKT_SIZE_WIDTH-1:0]             pkt_size,
    input                                  pkt_size_vld,

    // --- Interface to arbiter
    output                                 wildcard_hit,
    output                                 wildcard_miss,
    output [ENTRY_DATA_WIDTH-1:0]          wildcard_data,
    output                                 wildcard_data_vld,
    input                                  wildcard_wins,
    input                                  wildcard_loses,

    // --- Interface to registers
    input                                  reg_req_in,
    input                                  reg_ack_in,
    input                                  reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

    output                                 reg_req_out,
    output                                 reg_ack_out,
    output                                 reg_rd_wr_L_out,
    output     [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
    output     [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
    output     [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

    // --- Misc
    input [31:0]                           timer,
    input                                  reset,
    input                                  clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_BITS        = NUM_RULE_BYTES*8;

   /* these are 64-bit words */
   localparam NUM_RULE_WORDS       = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS       = ceildiv(ENTRY_DATA_WIDTH, DATA_WIDTH);

   /* these are 32-bit words */
   localparam WILDCARD_NUM_DATA_WORDS_USED = 2*NUM_DATA_WORDS;
   localparam WILDCARD_NUM_CMP_WORDS_USED  = 2*NUM_RULE_WORDS;

   localparam WILDCARD_NUM_REGS_USED = (2 // for the read and write address registers
                                        + WILDCARD_NUM_DATA_WORDS_USED  // for data associated with an entry
                                        + WILDCARD_NUM_CMP_WORDS_USED   // for the data to match on
                                        + WILDCARD_NUM_CMP_WORDS_USED   // for the don't cares
                                        );

   localparam LUT_DEPTH_BITS = log2(WILDCARD_TABLE_SIZE);

   //---------------------- Wires and regs----------------------------
   wire                                                      cam_busy;
   wire                                                      cam_match;
   wire [WILDCARD_TABLE_SIZE-1:0]                            cam_match_addr;
   wire [NUM_RULE_BITS-1:0]                                  cam_cmp_din, cam_cmp_data_mask;
   wire [NUM_RULE_BITS-1:0]                                  cam_din, cam_data_mask;
   wire                                                      cam_we;
   wire [LUT_DEPTH_BITS-1:0]                                 cam_wr_addr;

   wire [WILDCARD_NUM_CMP_WORDS_USED-1:0]                    cam_busy_ind;
   wire [WILDCARD_NUM_CMP_WORDS_USED-1:0]                    cam_match_ind;
   wire [WILDCARD_NUM_CMP_WORDS_USED-1:0]                    cam_match_addr_ind[WILDCARD_TABLE_SIZE-1:0];
   wire [31:0]                                               cam_cmp_din_ind[WILDCARD_NUM_CMP_WORDS_USED-1:0];
   wire [31:0]                                               cam_cmp_data_mask_ind[WILDCARD_NUM_CMP_WORDS_USED-1:0];
   wire [31:0]                                               cam_din_ind[WILDCARD_NUM_CMP_WORDS_USED-1:0];
   wire [31:0]                                               cam_data_mask_ind[WILDCARD_NUM_CMP_WORDS_USED-1:0];

   wire [`UDP_REG_ADDR_WIDTH-1:0]                            cam_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]                           cam_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]                              cam_reg_src_out;

   wire [LUT_DEPTH_BITS-1:0]                                 wildcard_address;
   wire [LUT_DEPTH_BITS-1:0]                                 dout_wildcard_address;

   reg [WILDCARD_TABLE_SIZE-1:0]                             wildcard_hit_address_decoded;
   wire [WILDCARD_TABLE_SIZE*PKT_SIZE_WIDTH - 1:0]           wildcard_hit_address_decoded_expanded;
   wire [WILDCARD_TABLE_SIZE*PKT_SIZE_WIDTH - 1:0]           wildcard_entry_hit_byte_size;
   wire [WILDCARD_TABLE_SIZE*32 - 1:0]                       wildcard_entry_last_seen_timestamps;

   wire [PKT_SIZE_WIDTH-1:0]                                 dout_pkt_size;

   reg [PKT_SIZE_WIDTH-1:0]                                  wildcard_entry_hit_byte_size_word [WILDCARD_TABLE_SIZE-1:0];
   reg [31:0]                                                wildcard_entry_last_seen_timestamps_words[WILDCARD_TABLE_SIZE-1:0];

   integer                                                   i;

   reg                                                       rule_vld;
   wire [NUM_RULE_BITS-1:0]                                  rule;
   reg [log2(NUM_RULE_WORDS)-1:0]                            rule_word_count;
   reg [DATA_WIDTH-1:0]                                      rule_word_store[NUM_RULE_WORDS-1:0];

   wire                                                      wildcard_lookup_done;

   reg                                                       wildcard_wins_local;
   reg                                                       wildcard_loses_local;

   //------------------------- Modules -------------------------------

   unencoded_cam_lut_sm
     #(.CMP_WIDTH (NUM_RULE_BITS),
       .DATA_WIDTH (ENTRY_DATA_WIDTH),
       .LUT_DEPTH  (WILDCARD_TABLE_SIZE),
       .TAG (WILDCARD_LOOKUP_BLOCK_TAG),
       .REG_ADDR_WIDTH (WILDCARD_REG_ADDR_WIDTH))
       wildcard_cam_lut_sm
         (// --- Interface for lookups
          .lookup_req          (rule_vld),
          .lookup_cmp_data     (rule),
          .lookup_cmp_dmask    ({NUM_RULE_BITS{1'b0}}),
          .lookup_ack          (wildcard_lookup_done),
          .lookup_hit          (wildcard_hit),
          .lookup_data         (wildcard_data),
          .lookup_address      (wildcard_address),

          // --- Interface to registers
          .reg_req_in          (reg_req_in),
          .reg_ack_in          (reg_ack_in),
          .reg_rd_wr_L_in      (reg_rd_wr_L_in),
          .reg_addr_in         (reg_addr_in),
          .reg_data_in         (reg_data_in),
          .reg_src_in          (reg_src_in),

          .reg_req_out         (cam_reg_req_out),
          .reg_ack_out         (cam_reg_ack_out),
          .reg_rd_wr_L_out     (cam_reg_rd_wr_L_out),
          .reg_addr_out        (cam_reg_addr_out),
          .reg_data_out        (cam_reg_data_out),
          .reg_src_out         (cam_reg_src_out),

          // --- CAM interface
          .cam_busy            (cam_busy),
          .cam_match           (cam_match),
          .cam_match_addr      (cam_match_addr),
          .cam_cmp_din         (cam_cmp_din),
          .cam_din             (cam_din),
          .cam_we              (cam_we),
          .cam_wr_addr         (cam_wr_addr),
          .cam_cmp_data_mask   (cam_cmp_data_mask),
          .cam_data_mask       (cam_data_mask),

          // --- Misc
          .reset               (reset),
          .clk                 (clk));

   /* Split up the CAM into multiple smaller CAMs to improve timing */
   generate
      genvar ii,j;
      for (ii=0; ii<WILDCARD_NUM_CMP_WORDS_USED; ii=ii+1) begin:gen_cams
         wire [WILDCARD_TABLE_SIZE-1:0] cam_match_addr_temp;
         srl_cam_unencoded_32x32 cam
           (
            // Outputs
            .busy                             (cam_busy_ind[ii]),
            .match                            (cam_match_ind[ii]),
            .match_addr                       (cam_match_addr_temp),
            // Inputs
            .clk                              (clk),
            .cmp_din                          (cam_cmp_din_ind[ii]),
            .din                              (cam_din_ind[ii]),
            .cmp_data_mask                    (cam_cmp_data_mask_ind[ii]),
            .data_mask                        (cam_data_mask_ind[ii]),
            .we                               (cam_we),
            .wr_addr                          (cam_wr_addr)
            );
         if(ii < WILDCARD_NUM_CMP_WORDS_USED - 1) begin
            assign cam_cmp_din_ind[ii]         = cam_cmp_din[32*ii + 31: 32*ii];
            assign cam_din_ind[ii]             = cam_din[32*ii + 31: 32*ii];
            assign cam_cmp_data_mask_ind[ii]   = cam_cmp_data_mask[32*ii + 31: 32*ii];
            assign cam_data_mask_ind[ii]       = cam_data_mask[32*ii + 31: 32*ii];
            assign cam_cmp_din_ind[ii]         = cam_cmp_din[32*ii + 31: 32*ii];
         end
         else begin
            assign cam_cmp_din_ind[ii]         = cam_cmp_din[NUM_RULE_BITS-1: 32*ii];
            assign cam_din_ind[ii]             = cam_din[NUM_RULE_BITS-1: 32*ii];
            assign cam_cmp_data_mask_ind[ii]   = cam_cmp_data_mask[NUM_RULE_BITS-1: 32*ii];
            assign cam_data_mask_ind[ii]       = cam_data_mask[NUM_RULE_BITS-1: 32*ii];
            assign cam_cmp_din_ind[ii]         = cam_cmp_din[NUM_RULE_BITS-1: 32*ii];
         end // else: !if(ii < WILDCARD_NUM_CMP_WORDS_USED - 1)

         for (j=0; j<WILDCARD_TABLE_SIZE; j=j+1) begin:gen_match_addr_mem
            assign cam_match_addr_ind[j][ii] = cam_match_addr_temp[j];
         end
      end // block: gen_cams

      for (ii=0; ii<WILDCARD_TABLE_SIZE; ii=ii+1) begin:gen_match_addr
         assign cam_match_addr[ii] = &cam_match_addr_ind[ii];
      end
   endgenerate

   assign cam_busy  = |cam_busy_ind;
   assign cam_match = |cam_match_addr;

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (WILDCARD_LOOKUP_BLOCK_TAG),
       .REG_ADDR_WIDTH (WILDCARD_REG_ADDR_WIDTH),
       .NUM_COUNTERS (WILDCARD_TABLE_SIZE  // for number of bytes
                      +WILDCARD_TABLE_SIZE // for number of packets
                      ),
       .RESET_ON_READ (0),
       .NUM_SOFTWARE_REGS (0),
       .NUM_HARDWARE_REGS (WILDCARD_TABLE_SIZE), // for last seen timestamps
       .COUNTER_INPUT_WIDTH (PKT_SIZE_WIDTH), // max pkt size
       .REG_START_ADDR (WILDCARD_NUM_REGS_USED) // used for the access to the cam/lut
       )
   generic_regs
     (
      .reg_req_in        (cam_reg_req_out),
      .reg_ack_in        (cam_reg_ack_out),
      .reg_rd_wr_L_in    (cam_reg_rd_wr_L_out),
      .reg_addr_in       (cam_reg_addr_out),
      .reg_data_in       (cam_reg_data_out),
      .reg_src_in        (cam_reg_src_out),

      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),

      // --- counters interface
      .counter_updates   ({wildcard_hit_address_decoded_expanded,
                           wildcard_entry_hit_byte_size}
                          ),
      .counter_decrement ({(2*WILDCARD_TABLE_SIZE){1'b0}}),

      // --- SW regs interface
      .software_regs     (),

      // --- HW regs interface
      .hardware_regs     ({wildcard_entry_last_seen_timestamps}),

      .clk               (clk),
      .reset             (reset));

   /* we might receive four input packets simultaneously from ethernet. In addition,
    * we might receive a pkt from DMA. So we need at least 5 spots. */
   fallthrough_small_fifo
     #(.WIDTH(PKT_SIZE_WIDTH),
       .MAX_DEPTH_BITS(3))
      pkt_size_fifo
        (.din           (pkt_size),
         .wr_en         (pkt_size_vld),
         .rd_en         (fifo_rd_en),
         .dout          (dout_pkt_size),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (pkt_size_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(LUT_DEPTH_BITS),
       .MAX_DEPTH_BITS(3))
      address_fifo
        (.din           (wildcard_address),
         .wr_en         (wildcard_lookup_done),
         .rd_en         (fifo_rd_en),
         .dout          (dout_wildcard_address),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (address_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------- Logic --------------------------------
   assign wildcard_miss       = wildcard_lookup_done & !wildcard_hit;
   assign wildcard_data_vld   = wildcard_lookup_done & wildcard_hit;
   assign fifo_rd_en          = wildcard_wins_local || wildcard_loses_local;

   /* Register signals to help meet timing */
   always @(posedge clk) begin
      if(reset) begin
         wildcard_wins_local     <= 0;
         wildcard_loses_local    <= 0;
      end
      else begin
         wildcard_wins_local     <= wildcard_wins;
         wildcard_loses_local    <= wildcard_loses;
      end
   end // always @ (posedge clk)

   /* update the generic register interface if wildcard matching
    * wins the arbitration */
   always @(*) begin
      wildcard_hit_address_decoded = 0;
      for(i=0; i<WILDCARD_TABLE_SIZE; i=i+1) begin
         wildcard_entry_hit_byte_size_word[i] = 0;
      end
      if(wildcard_wins_local) begin
         wildcard_hit_address_decoded[dout_wildcard_address] = 1;
         wildcard_entry_hit_byte_size_word[dout_wildcard_address]
           = dout_pkt_size;
      end
   end // always @ (*)

   generate
      genvar gi;
      for(gi=0; gi<WILDCARD_TABLE_SIZE; gi=gi+1) begin:concat
         assign wildcard_entry_hit_byte_size[gi*PKT_SIZE_WIDTH +: PKT_SIZE_WIDTH]
                = wildcard_entry_hit_byte_size_word[gi];
         assign wildcard_entry_last_seen_timestamps[gi*32 +: 32]
                = wildcard_entry_last_seen_timestamps_words[gi];
         assign wildcard_hit_address_decoded_expanded[gi*PKT_SIZE_WIDTH +: PKT_SIZE_WIDTH]
                ={{(PKT_SIZE_WIDTH-1){1'b0}}, wildcard_hit_address_decoded[gi]};
      end
   endgenerate

   // update the timestamp of the entry
   always @(posedge clk) begin
      if(cam_we) begin
         wildcard_entry_last_seen_timestamps_words[cam_wr_addr] <= timer;
      end
      else if(wildcard_wins_local) begin
         wildcard_entry_last_seen_timestamps_words[dout_wildcard_address] <= timer;
      end
   end // always @ (posedge clk)

   /* Store all the rule words and generate a signal indicating
    * when the words are complete */
   always @(posedge clk) begin
      if(reset) begin
         rule_vld           <= 0;
         rule_word_count    <= 0;
      end
      else begin
         rule_vld  <= 0;
         if(rule_word_vld) begin
            if(rule_word_count == NUM_RULE_WORDS-1) begin
               rule_word_count    <= 0;
               rule_vld           <= 1'b1;
            end
            else begin
               rule_word_count    <= rule_word_count + 1'b1;
            end
            rule_word_store[rule_word_count]    <= rule_word;
         end // if (rule_word_vld)
      end // else: !if(reset)
   end // always @ (posedge clk)

   /* create a bitvector from all the rule words */
   generate
      genvar ri;
      for(ri=0; ri<NUM_RULE_WORDS; ri=ri+1) begin:gen_rule
         assign rule[(ri+1)*DATA_WIDTH-1:ri*DATA_WIDTH] = rule_word_store[NUM_RULE_WORDS - ri - 1];
      end
   endgenerate

endmodule // wildcard_match


