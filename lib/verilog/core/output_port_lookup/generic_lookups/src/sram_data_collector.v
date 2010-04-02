/*******************************************************************************
 * $Id$
 *
 * Module: sram_data_collector.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: collects the reads of the data from the entry found in SRAM
 *
 *******************************************************************************/

module sram_data_collector
    #(parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_DATA_WIDTH = 128,
      parameter ENTRY_ADDR_WIDTH = 15,
      parameter FLIP_BYTE_ORDER = 1,   // flip the bytes ordering of the lookup/data
      parameter SRAM_ADDR_WIDTH = 19,
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- SRAM Interface
    input                                   rd_vld,
    input [DATA_WIDTH-1:0]                  rd_data,

    // --- Lookup results
    output     [ENTRY_DATA_WIDTH-1:0]       entry_data,
    output reg [DATA_WIDTH-1:0]             entry_counters,
    output reg                              entry_data_vld,

    // --- Misc
    input                                   reset,
    input                                   clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS       = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS       = ceildiv(ENTRY_DATA_WIDTH, DATA_WIDTH);

   localparam WAIT_FOR_DATA        = 0;
   localparam COLLECT_DATA_WORDS   = 1;

   //---------------------- Wires and regs----------------------------
   reg                           state;
   reg [log2(NUM_DATA_WORDS):0]  count;

   wire [log2(NUM_DATA_WORDS):0] count_plus_1;

   reg [DATA_WIDTH-1:0]          entry_data_words[NUM_DATA_WORDS-1:0];

   wire [ENTRY_DATA_WIDTH-1:0]   entry_data_int;

   //-------------------------- Logic --------------------------------

   assign count_plus_1     = count + 1'b1;

   generate
      genvar i;
      for(i=0; i<NUM_DATA_WORDS-1; i=i+1) begin:gen_data_words
         assign entry_data_int[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = entry_data_words[i];
      end
      assign entry_data_int[ENTRY_DATA_WIDTH-1:(NUM_DATA_WORDS-1)*DATA_WIDTH]
                 = entry_data_words[NUM_DATA_WORDS-1];

      if(FLIP_BYTE_ORDER) begin
         for(i=0; i<ENTRY_DATA_WIDTH/8; i=i+1) begin:swap_data_bytes
            assign entry_data[8*i+7:8*i]  = entry_data_int[ENTRY_DATA_WIDTH-1-i*8:ENTRY_DATA_WIDTH-8-i*8];
         end
      end
      else begin
         assign entry_data 	 = entry_data_int;
      end
   endgenerate


   always @(posedge clk) begin
      if(reset) begin
         state             <= WAIT_FOR_DATA;
         entry_data_vld    <= 1'b0;
      end
      else begin

         entry_data_vld <= 1'b0;

         case (state)
            WAIT_FOR_DATA: begin
               if(rd_vld) begin
                  /* first word is the counters word */
                  entry_counters       <= rd_data;
                  state                <= COLLECT_DATA_WORDS;
                  count                <= 0;
               end
            end

            COLLECT_DATA_WORDS: begin
               if(rd_vld) begin
                  if(count >= NUM_DATA_WORDS-1) begin
                     state              <= WAIT_FOR_DATA;
                     entry_data_vld     <= 1'b1;
                  end
                  entry_data_words[count]    <= rd_data;
                  count                      <= count_plus_1;
               end // if (rd_rdy)
            end
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // sram_read_issuer
