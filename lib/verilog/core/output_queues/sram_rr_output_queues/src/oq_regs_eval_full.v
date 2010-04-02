///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_regs_eval_full.v 2346 2007-10-06 19:13:06Z jnaous $
//
// Module: oq_regs_eval_full.v
// Project: NF2.1
// Description: Evaluates whether a queue is full
//
// Currently looks at the number of packets in the queue and the number of
// words left
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module oq_regs_eval_full
  #(
      parameter SRAM_ADDR_WIDTH     = 19,
      parameter CTRL_WIDTH          = 8,
      parameter UDP_REG_SRC_WIDTH   = 2,
      parameter NUM_OUTPUT_QUEUES   = 8,
      parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
      parameter PKT_LEN_WIDTH       = 11,
      parameter PKT_WORDS_WIDTH     = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter MAX_PKT             = 2048/CTRL_WIDTH,   // allow for 2K bytes,
      parameter MIN_PKT             = 60/CTRL_WIDTH + 1,
      parameter PKTS_IN_RAM_WIDTH   = log2((2**SRAM_ADDR_WIDTH)/MIN_PKT)
   )

   (
      // --- Inputs from dst update ---
      input                               dst_update,
      input [NUM_OQ_WIDTH-1:0]            dst_oq,
      input [PKTS_IN_RAM_WIDTH-1:0]       dst_max_pkts_in_q,
      input [PKTS_IN_RAM_WIDTH-1:0]       dst_num_pkts_in_q,
      input                               dst_num_pkts_in_q_done,

      input [SRAM_ADDR_WIDTH-1:0]         dst_oq_full_thresh,
      input [SRAM_ADDR_WIDTH-1:0]         dst_num_words_left,
      input                               dst_num_words_left_done,

      // --- Inputs from src update ---
      input                               src_update,
      input [NUM_OQ_WIDTH-1:0]            src_oq,
      input [PKTS_IN_RAM_WIDTH-1:0]       src_max_pkts_in_q,
      input [PKTS_IN_RAM_WIDTH-1:0]       src_num_pkts_in_q,
      input                               src_num_pkts_in_q_done,

      input [SRAM_ADDR_WIDTH-1:0]         src_oq_full_thresh,
      input [SRAM_ADDR_WIDTH-1:0]         src_num_words_left,
      input                               src_num_words_left_done,

      // --- Clear the flag ---
      input                               initialize,
      input [NUM_OQ_WIDTH-1:0]            initialize_oq,

      output     [NUM_OUTPUT_QUEUES-1:0]  full,


      // --- Misc
      input                               clk,
      input                               reset
   );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2


   // ------------- Internal parameters --------------


   // ------------- Wires/reg ------------------

   reg [NUM_OUTPUT_QUEUES-1:0]   full_pkts_in_q;
   reg [NUM_OUTPUT_QUEUES-1:0]   full_words_left;

   wire                          src_full_pkts_in_q;
   reg                           src_full_pkts_in_q_held;
   wire                          dst_full_pkts_in_q;

   wire                          src_full_words_left;
   reg                           src_full_words_left_held;
   wire                          dst_full_words_left;

   reg                           dst_update_d1;
   reg                           src_update_d1;

   reg [PKTS_IN_RAM_WIDTH-1:0]   dst_max_pkts_in_q_held;
   reg [PKTS_IN_RAM_WIDTH-1:0]   src_max_pkts_in_q_held;

   reg [PKTS_IN_RAM_WIDTH-1:0]   dst_oq_full_thresh_held;
   reg [PKTS_IN_RAM_WIDTH-1:0]   src_oq_full_thresh_held;

   reg [NUM_OQ_WIDTH-1:0]        dst_oq_held;
   reg [NUM_OQ_WIDTH-1:0]        src_oq_held;

   reg                           src_num_pkts_in_q_done_held;
   reg                           src_num_words_left_done_held;

   // ------------- Logic ------------------

   assign full = full_pkts_in_q | full_words_left;



   assign src_full_pkts_in_q = src_num_pkts_in_q >= src_max_pkts_in_q_held &&
                               src_max_pkts_in_q_held != 0;

   assign dst_full_pkts_in_q = dst_num_pkts_in_q >= dst_max_pkts_in_q_held &&
                               dst_max_pkts_in_q_held != 0;

   assign src_full_words_left = src_num_words_left <= src_oq_full_thresh_held ||
                                src_num_words_left < 2 * MAX_PKT;

   assign dst_full_words_left = dst_num_words_left <= dst_oq_full_thresh_held ||
                                dst_num_words_left < 2 * MAX_PKT;



   always @(posedge clk)
   begin
      dst_update_d1 <= dst_update;
      src_update_d1 <= src_update;

      if (reset) begin
         full_pkts_in_q <= 'h0;
         full_words_left <= 'h0;
      end
      else begin
         if (dst_update) begin
            dst_oq_held <= dst_oq;
         end

         if (src_update) begin
            src_oq_held <= src_oq;
         end

         // Latch the maximums the cycle immediately following the update
         // notifications. The update notifications are linked to the read
         // ports of the appropriate registers so the read value will always
         // be returned in the next cycle.
         if (dst_update_d1) begin
            dst_max_pkts_in_q_held <= dst_max_pkts_in_q;
            dst_oq_full_thresh_held <= dst_oq_full_thresh;
         end

         if (src_update_d1) begin
            src_max_pkts_in_q_held <= src_max_pkts_in_q;
            src_oq_full_thresh_held <= src_oq_full_thresh;
         end


         // Update the full status giving preference to stores over removes
         // since we don't want to accidentally try adding to a full queue

         // Number of packets in queue
         if (dst_num_pkts_in_q_done) begin
            full_pkts_in_q[dst_oq_held] <= dst_full_pkts_in_q;

            src_num_pkts_in_q_done_held <= src_num_pkts_in_q_done;
            src_full_pkts_in_q_held <= src_full_pkts_in_q;
         end
         else if (src_num_pkts_in_q_done) begin
            full_pkts_in_q[src_oq_held] <= src_full_pkts_in_q;
         end
         else if (src_num_pkts_in_q_done_held) begin
            full_pkts_in_q[src_oq_held] <= src_full_pkts_in_q_held;
         end
         else if (initialize) begin
            full_pkts_in_q[initialize_oq] <= 1'b0;
         end


         // Number of words left:
         if (dst_num_words_left_done) begin
            full_words_left[dst_oq_held] <= dst_full_words_left;

            src_num_words_left_done_held <= src_num_words_left_done;
            src_full_words_left_held <= src_full_words_left;
         end
         else if (src_num_words_left_done) begin
            full_words_left[src_oq_held] <= src_full_words_left;
         end
         else if (src_num_words_left_done_held) begin
            full_words_left[src_oq_held] <= src_full_words_left_held;
         end
         else if (initialize) begin
            full_words_left[initialize_oq] <= 1'b0;
         end
      end
   end

endmodule // oq_regs_eval_full
