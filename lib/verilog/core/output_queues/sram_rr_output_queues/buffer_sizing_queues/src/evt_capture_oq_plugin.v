///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: evt_capture_oq_plugin.v 3271 2008-01-29 22:33:17Z jnaous $
//
// Module: evt_capture_oq_plugin.v
// Project: NF2.1 router buffer sizing
// Description: counts number of packets and words in each output queue
//
///////////////////////////////////////////////////////////////////////////////

module evt_capture_oq_plugin

  #(parameter NUM_OUTPUT_QUEUES   = 8,
    parameter PKT_WORDS_WIDTH     = 8,
    parameter SRAM_ADDR_WIDTH     = 19,
    parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
    parameter SIG_VALUE_SIZE      = 8,
    parameter ALL_SIG_VALUES_SIZE = 3*SIG_VALUE_SIZE,
    parameter SIGNAL_ID_SIZE      = log2(NUM_OUTPUT_QUEUES),
    parameter ALL_SIGNAL_IDS_SIZE = 3*SIGNAL_ID_SIZE)

    ( input                                pkt_stored,
      input                                pkt_dropped,
      input [PKT_WORDS_WIDTH-1:0]          stored_pkt_total_word_length,
      input [NUM_OQ_WIDTH-1:0]             dst_oq,

      input                                pkt_removed,
      input [PKT_WORDS_WIDTH-1:0]          removed_pkt_total_word_length,
      input [NUM_OQ_WIDTH-1:0]             removed_oq,

      output reg [2:0]                     oq_signals,
      output reg [ALL_SIGNAL_IDS_SIZE-1:0] oq_signal_ids,
      output [`CPCI_NF2_DATA_WIDTH*2*NUM_OUTPUT_QUEUES-1:0] oq_abs_regs,
      output reg [ALL_SIG_VALUES_SIZE-1:0] oq_signal_values,

      input                                clk,
      input                                reset);


   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   // ----------------- Internal parameters ----------------
   parameter MAX_NUM_PKTS_WIDTH = SRAM_ADDR_WIDTH-3; // SRAM_WIDTH - min pkt size
   parameter MAX_WORDS_WIDTH    = SRAM_ADDR_WIDTH;   // SRAM_WIDTH

   // -------------------- wires/regs ----------------------
   reg [MAX_NUM_PKTS_WIDTH-1:0] num_pkts  [NUM_OUTPUT_QUEUES-1:0];
   reg [MAX_WORDS_WIDTH-1:0]    num_words [NUM_OUTPUT_QUEUES-1:0];
   integer                      i;

   // ---------------------- Logic -------------------------

   // --- Count the number of pkts and words in the output queues
   always @(posedge clk) begin
      if(reset) begin
         for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin
            num_pkts[i]     <= 0;
            num_words[i]    <= 0;
         end
      end
      else begin
         if(dst_oq==removed_oq && pkt_stored && pkt_removed) begin
            num_words[dst_oq] <= num_words[dst_oq] +
                                 stored_pkt_total_word_length -
                                 removed_pkt_total_word_length;
         end
         else begin
            if(pkt_stored) begin
               num_pkts[dst_oq]  <= num_pkts[dst_oq] + 1'b1;
               num_words[dst_oq] <= num_words[dst_oq] + stored_pkt_total_word_length;
            end

            if(pkt_removed) begin
               num_pkts[removed_oq]  <= num_pkts[removed_oq] - 1'b1;
               num_words[removed_oq] <= num_words[removed_oq] - removed_pkt_total_word_length;
            end
         end // else: !if(dst_oq==removed_oq && pkt_stored && pkt_removed)
      end // else: !if(reset)
   end // always @ (posedge clk)

   // --- Put all the values in a long array
   generate
      genvar j;
      for(j=0; j<NUM_OUTPUT_QUEUES; j=j+1) begin: pack_output
         assign oq_abs_regs[j*64+63:j*64] = {{(32-MAX_NUM_PKTS_WIDTH){1'b0}},
					     num_pkts[j],
					     {(32-MAX_WORDS_WIDTH){1'b0}},
					     num_words[j]};
      end
   endgenerate

   //--- Latch the signals to be sent to the event capture module
   always @(posedge clk) begin
      // signal the events
      oq_signals          <= {pkt_dropped, pkt_removed, pkt_stored};

      // set the size of the packet
      oq_signal_values    <= {{SIG_VALUE_SIZE{1'b0}},
			      removed_pkt_total_word_length[SIG_VALUE_SIZE-1:0],
			      stored_pkt_total_word_length[SIG_VALUE_SIZE-1:0]};

      // send the queue on which the event occurred
      oq_signal_ids       <= {dst_oq, removed_oq, dst_oq};
   end

endmodule // evt_capture_oq_plugin

