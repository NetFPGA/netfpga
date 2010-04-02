/******************************************************************************
 * $Id$
 *
 * Module: rule_selector.v
 * Project: generic lookup
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: concatenates parts of packet as rule words
 *
 * The user selects which bytes he is interested in from each word in the
 * first 8 words of the packet. As the packet passes through, these bytes
 * are pulled off and concatenated.
 *
 * If there is a module header that contains additional data to match against,
 * then this can be specified using the additional_word_bytes_mask and
 * additional_word_ctrl. The order of additional word and IOQ header should be
 * known.
 *
 * THE RULE HAS TO BE A MULTIPLE OF 8 BYTES!
 *
 *****************************************************************************/

`timescale 1 ns/1 ns

module rule_selector
  #(parameter NUM_RULE_BYTES = 48,               // rule length
    parameter TOTAL_LOOKUP_BYTES = 64,           // number of bytes to choose from
    parameter SELECT_BYTES_MASK = 64'h0,         // indicates what bytes to use from the packet
    parameter INCLUDE_SRC_PORT = 1'b0,           // is the src port part of the rule?
    parameter INCLUDE_ADDITIONAL_WORD = 1'b0,    // use an additional rule from a module header?
    parameter ADDITIONAL_WORD_BYTES_MASK = 8'h0, // mask to use on additional module header
    parameter ADDITIONAL_WORD_CTRL = 0,          // identifies module header to use
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter PKT_SIZE_WIDTH = 12)
    ( // --- Interface to datapath
      input  [DATA_WIDTH-1:0]                   in_data,
      input  [CTRL_WIDTH-1:0]                   in_ctrl,
      input                                     in_wr,

      // --- Interface to lookup modules
      output reg [PKT_SIZE_WIDTH-1:0]           pkt_size,
      output reg                                pkt_size_vld,

      output [DATA_WIDTH-1:0]                   rule_word,
      output reg                                rule_word_vld,

      output reg [7:0]                          pkt_src_port,
      output reg                                pkt_src_port_vld,

      // --- Misc
      input                                     reset,
      input                                     clk
      );

   `LOG2_FUNC

   //------------------ Internal Parameter ---------------------------
   localparam MODULE_HDRS          = 0;
   localparam PKT_WORDS            = 1;
   localparam WAIT_EOP             = 2;

   localparam TOTAL_LOOKUP_WORDS   = TOTAL_LOOKUP_BYTES/CTRL_WIDTH;

   //---------------------- Wires/Regs -------------------------------
   wire [CTRL_WIDTH-1:0]                select_bytes_mask_word;
   wire [CTRL_WIDTH-1:0]                select_bytes_mask_words[TOTAL_LOOKUP_WORDS-1:0];

   reg [1:0]                            state, state_next;
   reg [CTRL_WIDTH-1:0]                 word_select_bytes;
   reg [log2(TOTAL_LOOKUP_WORDS)-1:0]   counter, counter_next;
   reg                                  pkt_size_vld_nxt;
   reg                                  pkt_src_port_vld_nxt;
   reg [DATA_WIDTH-1:0]                 in_data_d1;
   wire [7:0]                           in_data_d1_bytes[CTRL_WIDTH-1:0];

   wire [log2(CTRL_WIDTH):0]            num_fields;
   wire [CTRL_WIDTH*log2(CTRL_WIDTH)-1:0] ordered_field_indices;

   wire [DATA_WIDTH-1:0]                  rule_to_store;

   wire [log2(CTRL_WIDTH)-1:0]            ordered_field_indices_words[CTRL_WIDTH-1:0];

   //------------------------ Logic ----------------------------------

   /*
    * Split up the linear mask into words and reverse so that
    * the words are ligned up correctly with the packet data.
    *
    * That's because m.s. bit of the bytes mask corresponds to the
    * first byte of the packet (bits 63:56).
    */
   generate
      genvar i;
      for(i = 0; i < TOTAL_LOOKUP_WORDS; i = i + 1) begin:mask_words
         assign select_bytes_mask_words[TOTAL_LOOKUP_WORDS-i-1]
                         = SELECT_BYTES_MASK[(i+1)*CTRL_WIDTH - 1:i*CTRL_WIDTH];
      end
   endgenerate
   assign select_bytes_mask_word = select_bytes_mask_words[counter];

   /*
    * Choose the correct mask for the bytes
    * at each word.
    */
   always @(*) begin
      word_select_bytes      = 0;
      pkt_size_vld_nxt       = 0;
      state_next             = state;
      counter_next           = counter;
      pkt_src_port_vld_nxt   = 0;
      case (state)
        MODULE_HDRS: begin
           if(in_wr) begin
              // get the pkt size and the input port
              if(in_ctrl==ADDITIONAL_WORD_CTRL && INCLUDE_ADDITIONAL_WORD) begin
                 word_select_bytes   = ADDITIONAL_WORD_BYTES_MASK;
              end

              else if(in_ctrl==`IO_QUEUE_STAGE_NUM) begin
                 if(INCLUDE_SRC_PORT) begin
                    word_select_bytes                        = 0;
                    word_select_bytes[`IOQ_SRC_PORT_POS/8]   = 1'b1;
                 end
                 pkt_size_vld_nxt       = 1'b1;
                 pkt_src_port_vld_nxt   = 1'b1;
              end

              // pkt started
              else if(in_ctrl==0) begin
                 state_next          = PKT_WORDS;
                 counter_next        = counter + 1'b1;
                 word_select_bytes   = select_bytes_mask_word;
              end
           end // if (in_wr)
        end // case: MODULE_HDRS

        PKT_WORDS: begin
           if(in_wr) begin
              word_select_bytes   = select_bytes_mask_word;
              if(counter == TOTAL_LOOKUP_WORDS-1 || in_ctrl != 0) begin
                 counter_next   = 0;
                 state_next  = (in_ctrl != 0) ? MODULE_HDRS : WAIT_EOP;
              end
              else begin
                 counter_next   = counter + 1'b1;
              end
           end
        end // case: PKT_WORDS

        WAIT_EOP: begin
           if(in_wr && in_ctrl != 0) begin
              state_next = MODULE_HDRS;
           end
        end

      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         counter             <= 0;
         state               <= 0;
         pkt_size_vld        <= 0;
         pkt_src_port_vld    <= 0;
      end
      else begin
         counter             <= counter_next;
         state               <= state_next;
         pkt_size_vld        <= pkt_size_vld_nxt;
         pkt_src_port_vld    <= pkt_src_port_vld_nxt;
      end // else: !if(reset)

      pkt_size        <= in_data[`IOQ_BYTE_LEN_POS + PKT_SIZE_WIDTH - 1 : `IOQ_BYTE_LEN_POS];
      pkt_src_port    <= in_data[`IOQ_SRC_PORT_POS + 7 : `IOQ_SRC_PORT_POS];
      in_data_d1      <= in_data;

   end // always @ (posedge clk)

   //------------------------ Packer Module ----------------------------------
   /* Pack the fields so that all the valid ones are at
    * the lowest addresses. The output of this modules are the
    * indices of the packed entries */
   parametrizable_packer
     #(.NUM_ENTRIES(CTRL_WIDTH)) parametrizable_packer
       (.valid_entries(word_select_bytes),
        .ordered_entries(ordered_field_indices),
        .num_valid_entries(num_fields),
        .clk (clk),
        .reset (reset));

   //-------------------- Get the ordered fields ----------------------
   generate
      for(i=0; i<CTRL_WIDTH; i = i+1) begin: gen_ordered_fields
         assign ordered_field_indices_words[i] = ordered_field_indices[log2(CTRL_WIDTH)*(i+1)-1:log2(CTRL_WIDTH)*i];
         assign in_data_d1_bytes[CTRL_WIDTH-1-i] = in_data_d1[8*i+7:8*i];
         assign rule_to_store[8*i+7:8*i] = in_data_d1_bytes[ordered_field_indices_words[i]];
      end
   endgenerate


   //------------------------ Packing FIFO ----------------------------------
   /* put the rule into this fifo which can write
    * a variable number of words and output a constant
    * size word */
   wide_port_fifo
     #(.INPUT_WORD_SIZE(8),
       .NUM_INPUTS(CTRL_WIDTH),
       .OUTPUT_FACTOR(8))
       wide_port_fifo(
                      .d_in (rule_to_store),
                      .increment(num_fields),
                      .wr_en(rule_fifo_wr_en),
                      .rd_en(rule_word_vld),
                      .d_out(rule_word),
                      .full(rule_fifo_full),
                      .empty(rule_fifo_empty),
                      .num_words_in_fifo(),
                      .clk(clk),
                      .rst(reset)
                      );
   assign rule_fifo_wr_en = |num_fields & !rule_fifo_full;

   // synthesis translate_off
   always @(posedge clk) begin
      if(rule_fifo_full && |num_fields) begin
         $display("%t %m ERROR: need to write rule bytes but rule fifo full.\n", $time);
         $stop;
      end
   end
   // synthesis translate_on

   /* whenever we have a word ready, just send it out */
   always @(*) begin
      rule_word_vld = !rule_fifo_empty;
   end

endmodule // field_selector

