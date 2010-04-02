///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_pktsrc.v 1793 2007-05-21 01:17:54Z grg $
//
// Module: phy_test_pktgen.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Provides a source of packets for a given port
//
// Note: The pattern enable input is only sampled when the module transitions
// from IDLE to ACTIVE
//
///////////////////////////////////////////////////////////////////////////////

module phy_test_pktsrc #(parameter
      CPCI_NF2_DATA_WIDTH = 32,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32
   )
   (
      //--- sigs to/from nf2_mac_grp for TX Fifos (egress)
      output reg [35:0]                   tx_data,
      output reg                          tx_wr_en,
      input                               tx_almost_full,

      //--- sigs to/from phy_test to coordinate the tests
      input  [2:0]                        port,             // Source port number

      input  [10:0]                       pkt_size,         // Packet size
      input  [NUM_PATTERNS - 1:0]         pat_en,           // Pattern enable
      input  [SEQ_NO_WIDTH - 1:0]         seq_no,           // Initial sequence number

      input                               start,            // Begin sending packets

      output reg [NUM_PATTERNS - 1:0]     curr_pat,         // Current pattern being transmitted

      output                              busy,             // Currently transmitting packets
      output reg                          pkt_done,         // Pulses when the packet has been transmitted
      output reg                          iter_done,        // Pulses when the all patterns have been transmitted

      //--- misc
      input             reset,
      input             clk
   );

   // State machine states
   localparam  IDLE             = 2'd0;
   localparam  FIND_PATTERN     = 2'd1;
   localparam  XMIT             = 2'd2;

   // Identify different patters
   localparam  ALL_0_PATTERN   = 5'b00001;
   localparam  ALL_1_PATTERN   = 5'b00010;
   localparam  ALT_01_PATTERN  = 5'b00100;
   localparam  ALT_10_PATTERN  = 5'b01000;
   localparam  RANDOM_PATTERN  = 5'b10000;

   // Count when the LFSR should be enabled
   localparam START_LFSR = 4;

   // State variable
   reg [2:0] state;
   reg [2:0] state_nxt;

   // Which patterns are enabled
   reg [NUM_PATTERNS - 1 : 0] enable_pat;
   reg [NUM_PATTERNS - 1 : 0] enable_pat_nxt;

   // Current/next pattern tracking
   reg [NUM_PATTERNS - 1 : 0] next_pat;
   reg next_pat_wrap;
   wire next_pat_good;

   // Packet length related variables
   reg [10:0] size;
   reg [10:0] size_nxt;

   reg iter_done_nxt;
   reg pkt_done_nxt;

   wire gen_done;
   wire gen_busy;

   wire [31:0] gen_data;
   wire [3:0] gen_ctrl;
   reg gen_rd_en;
   reg gen_data_rdy;
   reg gen_done_hold;

   wire [35:0] tx_data_nxt;

   reg tx_almost_full_d1;

   wire last_word;


   // Calculate whether the word that's about to be transmitted is the last
   // word in the packet
   //
   // True when the tx buffer is not full and the done flag is asserted by
   // the packet generator
   assign last_word = !tx_almost_full &&
            ((tx_almost_full_d1 && gen_done_hold) ||
             (!tx_almost_full_d1 && gen_done));

   // =================================
   // Main state machine

   always @(posedge clk) begin
      state <= state_nxt;
      enable_pat <= enable_pat_nxt;
      size <= size_nxt;
      iter_done <= iter_done_nxt;
      pkt_done <= pkt_done_nxt;
   end

   always @*
   begin
      // Begin by setting values to their previous value
      state_nxt = state;
      enable_pat_nxt = enable_pat;
      size_nxt = size;
      iter_done_nxt = 1'b0;
      pkt_done_nxt = 1'b0;

      if (reset) begin
         state_nxt = IDLE;
         enable_pat_nxt = {NUM_PATTERNS{1'b1}};
         size_nxt = 'h0;
      end
      else begin
         case (state)
            IDLE : begin
               // Check if we should be starting transmission
               // (only start if some tests are enabled)
               if (start && |pat_en) begin
                  state_nxt = FIND_PATTERN;
                  enable_pat_nxt = pat_en;
                  size_nxt = pkt_size;
               end
            end

            FIND_PATTERN : begin
               // Start transmitting when we've found the first pattern to
               // transmit
               if (next_pat_good)
                  state_nxt = XMIT;
            end

            XMIT : begin
               // Return to the IDLE state only when the tests are done and
               // start is deasserted
               if (last_word && next_pat_wrap && !start)
                  state_nxt = IDLE;

               if (last_word)
                  pkt_done_nxt = 1'b1;

               if (last_word && next_pat_wrap)
                  iter_done_nxt = 1'b1;
            end
         endcase
      end
   end

   // Generate the busy signal
   assign busy = state != IDLE;



   // =================================
   // Packet transmission
   //
   // Places data on the output signals

   always @(posedge clk)
   begin
      // Track the pattern to send
      if (reset || state == IDLE || state == FIND_PATTERN) begin
         curr_pat <= next_pat;
      end
      else if (last_word) begin
         // If we are on the last word we should move to the next pattern
         //if (gen_done) begin
            curr_pat <= next_pat;
         //end
      end

      // Work out whether we can actually do a write
      //
      // Only true if we're transmitting, the TX buffer is not full,
      // and either start is assertd or we haven't transmitted the last word
      //tx_wr_en <= state == XMIT && !tx_almost_full && (!(gen_done && next_pat_wrap) || start);
      tx_wr_en <= state == XMIT && !tx_almost_full && gen_data_rdy;

      // Move to the next data word if we've just read and written something
      if ((tx_wr_en || !tx_almost_full) && gen_rd_en)
         tx_data <= tx_data_nxt;

      // Work out when to read data from the packet generator
      gen_rd_en <= (state == FIND_PATTERN && next_pat_good) ||
                   (state == XMIT && !tx_almost_full);

      // Is there data ready to be written?
      if (reset || state == IDLE)
         gen_data_rdy <= 1'b0;
      else
         gen_data_rdy <= gen_rd_en || gen_data_rdy;

      // Record the state of done (since done is pulsed)
      if (reset)
         gen_done_hold <= 1'b0;
      else if (gen_rd_en)
         gen_done_hold <= gen_done;

      tx_almost_full_d1 <= tx_almost_full;
   end

   // Output the data
   assign tx_data_nxt = {gen_ctrl[3], gen_data[31:24],
                         gen_ctrl[2], gen_data[23:16],
                         gen_ctrl[1], gen_data[15:8],
                         gen_ctrl[0], gen_data[7:0]};



   // =================================
   // Pattern identification

   // Work out what the next pattern should be
   //
   // Also, identify whether the pattern has wrapped
   always @(posedge clk)
   begin
      // On reset or idle the next pattern should be 1
      if (reset || state == IDLE) begin
         next_pat <= 'h1;
         next_pat_wrap <= 1'b0;
      end
      // If the next pattern is 0 then we've wrapped so record that fact
      else if (curr_pat != 'h0 && next_pat == 'h0) begin
         next_pat <= 'h1;
         next_pat_wrap <= 1'b1;
      end
      else if ((curr_pat ^ next_pat) == 'h0 ||
               (next_pat & enable_pat) == 'h0) begin
         // It's possible that there's only one (or none) available patterns
         // in which case we've got no choice (and wrap must be true if
         // current pattern is non-zero)
         if ((curr_pat ^ enable_pat) == 'h0) begin
            next_pat <= enable_pat;
            next_pat_wrap <= (curr_pat ^ next_pat) == 'h0;
         end
         else begin
            next_pat <= {next_pat[NUM_PATTERNS - 2 : 0], 1'b0};
            // If the current pattern is equal ot the current pattern then
            // we've just transitioned so clear the wrap flag
            if ((curr_pat ^ next_pat) == 'h0)
               next_pat_wrap <= 1'b0;
         end
      end
   end

   assign next_pat_good = (next_pat & enable_pat) != 'h0;



   // =================================
   // Packet generator to generate the actual packet
   //
   phy_test_pktgen #(
      .CPCI_NF2_DATA_WIDTH (CPCI_NF2_DATA_WIDTH),
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_pktgen (
      .data (gen_data),
      .ctrl (gen_ctrl),
      .rd_en (gen_rd_en),

      .port (port),
      .pattern (curr_pat),
      .pkt_size (size),
      .seq_no (seq_no),

      .busy (gen_busy),
      .done (gen_done),

      .reset (reset || state == IDLE),
      .clk (clk)
   );

endmodule   // phy_test_pktgen
