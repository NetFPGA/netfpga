///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_pktgen.v 1794 2007-05-21 01:38:29Z grg $
//
// Module: phy_test_pktgen.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
//              This particular module is responsible for generating packets
//              only. The packet format is as follows:
//
//              DA: 00:ca:fe:00:01:Port
//              SA: 00:ca:fe:00:00:Port
//              Length: Length
//              Data: 8'b0, pattern (8 bits)
//                    seq_no (or 0)
//                    Pattern
//
// Note: data is muxed -- not the direct output for a flop
//
///////////////////////////////////////////////////////////////////////////////

module phy_test_pktgen #(parameter
      CPCI_NF2_DATA_WIDTH = 32,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32
   )
   (
      output [31:0]                       data,
      output reg [3:0]                    ctrl,
      input                               rd_en,            // Output the next word

      input  [2:0]                        port,             // Source port number
      input  [NUM_PATTERNS - 1:0]         pattern,          // Pattern enable
      input  [10:0]                       pkt_size,         // Packet size
      input  [SEQ_NO_WIDTH - 1:0]         seq_no,           // Initial sequence number

      output reg                          busy,             // Currently transmitting packets
      output reg                          done,             // Indicates the last word of the packet is being output

      //--- misc
      input             reset,
      input             clk
   );

   // Identify different patters
   localparam  ALL_0_PATTERN   = 5'b00001;
   localparam  ALL_1_PATTERN   = 5'b00010;
   localparam  ALT_01_PATTERN  = 5'b00100;
   localparam  ALT_10_PATTERN  = 5'b01000;
   localparam  RANDOM_PATTERN  = 5'b10000;

   // Count when the LFSR should be enabled
   localparam START_LFSR = 'd5;

   // Word locations of various packet components
   localparam DA_HI           = 'd0;
   localparam DA_LO_SA_HI     = 'd1;
   localparam SA_LO           = 'd2;
   localparam SIZE_PATTERN    = 'd3;
   localparam SEQUENCE_NO     = 'd4;

   // Packet length related variables
   reg [8:0] num_words;
   reg [3:0] final_ctrl;

   reg [8:0] count;

   wire [31:0] rand_data;
   reg [31:0] header_nxt;
   reg [31:0] payload;
   reg [31:0] header;

   reg done_nxt;
   wire last_word;

   reg enable_lfsr;

   reg sel_payload;



   // =================================
   // Main state machine responsible for packet transmission
   // Tracks the current word and places data on the output signals

   // Generate the last word signal
   assign last_word = count == num_words - 1;

   always @(posedge clk)
   begin
      // Track the count and calculate the data to send
      if (reset) begin
         count <= 'h0;
         enable_lfsr <= 1'b0;
         final_ctrl <= 4'b0000;
         num_words <= {9{1'b1}};
         ctrl <= 'h0;
         done <= 1'b0;
         busy <= 1'b0;
         sel_payload <= 1'b0;
         header <= 'h0;
      end
      else if (rd_en) begin
         if (last_word) begin
            // If we are on the last word we should reset the
            // counter and move to the next pattern
            //
            // Don't reset the LFSR here as the output may not
            // have been processed yet
            count <= 'h0;
            final_ctrl <= 4'b0000;
            num_words <= {9{1'b1}};
            ctrl <= final_ctrl;
            done <= 1'b1;
            sel_payload <= 1'b1;
            header <= header_nxt;
         end
         else begin
            // Record the size and pattern if we're
            // on the appropriate word
            if (count == SIZE_PATTERN) begin
               // Work out how many words we expect to send
               num_words <= pkt_size[10:2] + (|pkt_size[1:0]);

               // Calculate the control bits for the final word
               case (pkt_size[1:0])
                  2'd0 : final_ctrl <= 4'b0001;
                  2'd1 : final_ctrl <= 4'b1000;
                  2'd2 : final_ctrl <= 4'b0100;
                  2'd3 : final_ctrl <= 4'b0010;
               endcase
            end

            // Enable the LFSR if appropriate
            if (count == START_LFSR)
               enable_lfsr <= 1'b1;
            else if (count == 'h0)
               enable_lfsr <= 1'b0;

            // If we are not on the last word then we should increment the
            // counter but don't touch the pattern
            count <= count + 'h1;
            header <= header_nxt;
            ctrl <= 'h0;
            done <= 1'b0;
            if (count == 'h0)
               sel_payload <= 1'b0;
            else if (count == SEQUENCE_NO)
               sel_payload <= 1'b1;
         end
         busy <= 1'b1;
      end
      else if (count == 'h0)
         busy <= 1'b0;
   end

   assign data = sel_payload ? payload : header;



   // =================================
   // Muxes to work out what data to transmit

   always @*
   begin
      case (count)
         //DA_HI       : header_nxt = 32'h 00_ca_fe_00;
         DA_LO_SA_HI : header_nxt = {8'h 01, 5'd0, port, 16'h 00_ca};
         SA_LO       : header_nxt = {24'h fe_00_00, 5'd0, port};
         SIZE_PATTERN: header_nxt = {4'hf, 1'b0, pkt_size, 8'd0, {(8 - NUM_PATTERNS){1'b0}}, pattern};
         default     : header_nxt = 32'h 00_ca_fe_00;
      endcase
   end

   always @*
   begin
      case (pattern)
         ALL_0_PATTERN  : payload = 32'h 00000000;
         ALL_1_PATTERN  : payload = 32'h ffffffff;
         ALT_01_PATTERN : payload = 32'h 55555555;
         ALT_10_PATTERN : payload = 32'h aaaaaaaa;
         default        : payload = rand_data;
      endcase
   end



   // =================================
   // LFSR to generate random patterns
   //
   // The LFSR should only progress when we are generating a random pattern at
   // only when we are in the payload section.
   //
   // The first word should actually be repeated twice in the payload to allow
   // the receiver to start an identical LFSR
   lfsr32 patgen (
      .val (rand_data),
      .rd (pattern == RANDOM_PATTERN && rd_en && enable_lfsr),
      .seed (seq_no),
      .reset (reset || !enable_lfsr),
      .clk (clk)
   );

endmodule   // phy_test_pktgen
