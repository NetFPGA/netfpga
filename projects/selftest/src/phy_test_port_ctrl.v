///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_port_ctrl.v 1790 2007-05-20 20:38:54Z grg $
//
// Module: phy_test_port_ctrl.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Control logic for a single port group.
//
// Maintains the sequence number, tracks whether received sequence numbers are
// within bounds, generates success/failure signals
//
///////////////////////////////////////////////////////////////////////////////

module phy_test_port_ctrl #(parameter
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32,
      SEQ_RANGE = 256          // Allowable range for a sequence
   )
   (
      // Phy test signals
      input [2:0]                   port,
      input [10:0]                  pkt_size,
      input [NUM_PATTERNS - 1:0]    pat_en,

      input                         start,      // Start or continue a test

      input [SEQ_NO_WIDTH - 1 : 0]  init_seq_no, // Initial sequence number
      output reg [SEQ_NO_WIDTH - 1 : 0] tx_seq_no, // Current TX sequence number

      input [SEQ_NO_WIDTH - 1 : 0]  port_1_seq_no, // Current sequence number of port 1
      input [SEQ_NO_WIDTH - 1 : 0]  port_2_seq_no, // Current sequence number of port 2
      input [SEQ_NO_WIDTH - 1 : 0]  port_3_seq_no, // Current sequence number of port 3
      input [SEQ_NO_WIDTH - 1 : 0]  port_4_seq_no, // Current sequence number of port 4

      output reg                    done,
      output reg                    success,
      output reg                    busy,

      // Tx signals
      input                         tx_busy,
      input                         tx_iter_done,

      // Rx signals
      input [2:0]                   rx_port,
      input [NUM_PATTERNS - 1:0]    rx_pattern,
      input [SEQ_NO_WIDTH - 1:0]    rx_seq_no,
      input                         rx_busy,
      input                         rx_done,
      input                         rx_bad,

      // General control signals
      output reg                    start_d1,
      output reg                    restart,
      output reg                    rx_seq_good,

      // misc
      input reset,
      input clk
   );


   // Local parameters
   localparam  RANDOM_PATTERN  = 5'b10000;
   localparam  START_TIME      = 32'd125000000;


   // Internal signals
   wire running;
   wire gen_restart;

   reg [SEQ_NO_WIDTH - 1:0] rx_src_seq_no; // Sequence number of the source

   reg rx_seq_no_in_range;             // Sequence number is in range
   reg [SEQ_NO_WIDTH - 1:0] rx_seq_no_range; // What is the range (minimum) seq no?
   reg rx_seq_no_le_src;               // Is the rx seq no <= the source's seq no?
   reg rx_seq_no_ge_src_range;         // Is the rx seq no >= the min seq no?

   reg has_run;
   reg seen_fail;
   reg seen_pass;

   reg [26:0] timer;

   // Wire to allow simulations to override the parameter with a force
   // statement... sigh
   wire [26:0] start_time = START_TIME;



   // =====================================================
   // Miscellaneous logic

   assign running = tx_busy || rx_busy;
   assign gen_restart = reset ? 1'b0 : (start && !start_d1 && !running);

   always @(posedge clk)
   begin
      has_run <= reset ? 1'b0 : start || has_run;

      restart <= gen_restart;
      start_d1 <= reset ? 1'b0 : start;
   end



   // =====================================================
   // Success identification logic
   //
   // Success should be determined by the following factors:
   //   -- at least 1 packet has been received
   //   -- all received packets were good
   //   -- the system is no longer running
   //   -- a timer has expired to allow "slow" packets to arrive (buffering)
   //
   // Good/bad packets should be forgotten after a period so that the module
   // allows connecting an Ethernet cable during the test.

   always @(posedge clk)
   begin
      if (restart || reset) begin
         seen_fail <= 1'b0;
         seen_pass <= 1'b0;

         done <= 1'b0;
         success <= 1'b0;
         busy <= reset ? 1'b0 : 1'b1;

         timer <= start_time;
      end
      else if (has_run) begin
         if (rx_done) begin
            seen_fail <= rx_bad;
            seen_pass <= !rx_bad;
            timer <= start_time;
         end
         else if (timer == 1) begin
            if (running) begin
               timer <= start_time;
               seen_fail <= 1'b0;
               seen_pass <= 1'b0;
            end
            else begin
               done <= 1'b1;
               success <= seen_pass && !seen_fail;
               timer <= 'h0;
               busy <= 1'b0;
            end
         end
         else if (timer != 0) begin
            timer <= timer - 1;
         end
      end
   end



   // =====================================================
   // Logic to work out whether the received sequence number is within range

   always @*
   begin
      case (rx_port)
         'd1 : rx_src_seq_no = port_1_seq_no;
         'd2 : rx_src_seq_no = port_2_seq_no;
         'd3 : rx_src_seq_no = port_3_seq_no;
         default : rx_src_seq_no = port_4_seq_no;
      endcase
   end

   always @(posedge clk)
   begin
      if (restart || reset) begin
         rx_seq_no_in_range <= 1'b0;
         rx_seq_good <= 1'b1;
      end
      else begin
         if (rx_done && ((pat_en & rx_pattern) == RANDOM_PATTERN) && !rx_bad) begin
            rx_seq_good <= rx_seq_no_in_range;
         end

         // Work out whether the sequence number is within range
         //
         // Handle the calculations differently depending upon whether the
         // range wraps over 0
         if (rx_src_seq_no >= SEQ_RANGE) begin
            rx_seq_no_in_range <= rx_seq_no_le_src && rx_seq_no_ge_src_range;
         end
         else begin
            rx_seq_no_in_range <= rx_seq_no_le_src || rx_seq_no_ge_src_range;
         end
      end

      // There is an offset of one clock cycle between some of these values
      // but near-enough-is-good-enough for these calculations

      // What's the minimum value that is valid (the range)
      rx_seq_no_range <= rx_src_seq_no - SEQ_RANGE;

      // Is the RX seq no <= the src seq no?
      rx_seq_no_le_src <= rx_seq_no <= rx_src_seq_no;

      // Is the RX seq no >= src seq no - range?
      rx_seq_no_ge_src_range <= rx_seq_no >= rx_seq_no_range;
   end



   // =====================================================
   // TX sequence number state machine

   always @(posedge clk)
   begin
      if (restart || reset) begin
         tx_seq_no <= init_seq_no;
      end
      else begin
         if (tx_iter_done) begin
            tx_seq_no <= tx_seq_no + 'h1;
         end
      end
   end

endmodule   // phy_test_port_ctrl
