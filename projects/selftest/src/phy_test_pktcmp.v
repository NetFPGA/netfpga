///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_pktcmp.v 1799 2007-05-22 03:18:34Z grg $
//
// Module: phy_test_pktgen.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
//              This particular module is responsible for comparing packets
//              that arrive on an interface
//
// Note: There is one extra word received after the last data word that
// indicates success/failure (eg. FCS error)
//
///////////////////////////////////////////////////////////////////////////////

module phy_test_pktcmp #(parameter
      CPCI_NF2_DATA_WIDTH = 32,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32
   )
   (
      //--- sigs to/from nf2_mac_grp for RX Fifos (ingress)
      input                               rx_almost_empty,
      input [35:0]                        rx_data,
      output reg                          rx_rd_en,

      //--- sigs to/from phy_test to coordinate the tests
      output [2:0]                        port,             // Source port number
      output [NUM_PATTERNS - 1:0]         pattern,          // Pattern number being received

      input  [10:0]                       pkt_size,         // Packet size
      input  [NUM_PATTERNS - 1:0]         pat_en,           // Pattern enable

      output reg [SEQ_NO_WIDTH - 1:0]     seq_no,           // Sequence number of received packet

      output reg                          locked,           // Is the state machine currently locked

      output                              busy,             // Currently receiving a packets
      output reg                          done,             // Pulses when a packet has been recieved
      output reg                          bad,              // Indicates whether the received packet was good
                                                            // and expected

      // RX log interface
      output reg [31:0]                   log_rx_data,
      output reg [31:0]                   log_exp_data,
      output reg [8:0]                    log_addr,
      output reg                          log_data_wr,
      output reg                          log_done,
      output reg                          log_hold,


      //--- misc
      input             reset,
      input             clk
   );

   // Lose lock after 125,000 clock ticks (1ms/2ms depending on core clock
   // freq)
   localparam LOSE_LOCK_COUNT    = 'd125000;

   // Identify different patters
   localparam ALL_0_PATTERN   = 5'b00001;
   localparam ALL_1_PATTERN   = 5'b00010;
   localparam ALT_01_PATTERN  = 5'b00100;
   localparam ALT_10_PATTERN  = 5'b01000;
   localparam RANDOM_PATTERN  = 5'b10000;

   // Count when the LFSR should be enabled
   localparam START_LFSR = 4;

   // Word locations of various packet components
   localparam DA_HI           = 'd0;
   localparam DA_LO_SA_HI     = 'd1;
   localparam SA_LO           = 'd2;
   localparam SIZE_PATTERN    = 'd3;
   localparam SEQUENCE_NO     = 'd4;
   localparam EOP             = ~{10'd0};


   // Counter to identify when to leave the lock state
   reg [19:0] lock_count;
   reg [19:0] lock_count_nxt;

   // Current/next pattern tracking
   reg [NUM_PATTERNS - 1 : 0] curr_pat;
   reg [NUM_PATTERNS - 1 : 0] next_pat;

   // Packet length related variables
   reg [10:0] size;
   reg [10:0] size_nxt;

   reg [9:0] count;
   reg [9:0] count_d1;
   reg [9:0] last_pos;

   reg done_nxt;

   reg locked_nxt;

   reg rx_rd_en_d1;
   reg rx_rd_en_d2;
   reg bad_nxt;

   reg [2:0] curr_port;
   reg [2:0] curr_port_nxt;

   reg [NUM_PATTERNS - 1:0] curr_pat_nxt;

   reg [SEQ_NO_WIDTH - 1:0] seq_no_nxt;

   wire [3:0] ctrl;
   reg [3:0] ctrl_d1;
   wire [31:0] data;
   reg [31:0] data_d1;

   wire [31:0] gen_data;
   reg [31:0] gen_data_d1;
   wire [3:0] gen_ctrl;
   wire gen_rd_en;

   reg eop;
   reg eop_nxt;

   reg rx_data_good;
   reg rx_da_sa_good;
   reg rx_size_pat_good;


   // Create the ctrl/data signals

   assign ctrl = {rx_data[35], rx_data[26], rx_data[17], rx_data[8]};
   assign data = {rx_data[34:27], rx_data[25:18], rx_data[16:9], rx_data[7:0]};

   // Copy the port and pattern to their outputs
   assign port = curr_port;
   assign pattern = curr_pat;

   // Generate the busy signal
   assign busy = count != 'h0 || !rx_almost_empty;

   assign gen_rd_en = rx_rd_en;


   // =================================
   // Main state machine

   always @(posedge clk)
   begin
      bad <= bad_nxt;
      done <= done_nxt;

      curr_port <= curr_port_nxt;
      curr_pat <= curr_pat_nxt;
      seq_no <= seq_no_nxt;
      size <= size_nxt;
      eop <= eop_nxt;
   end

   // State machine to monitor incoming data
   always @*
   begin
      // Set variables to their default values
      bad_nxt = bad;
      done_nxt = 1'b0;

      curr_port_nxt = curr_port;
      curr_pat_nxt = curr_pat;
      seq_no_nxt = seq_no;
      size_nxt = size;
      eop_nxt = eop;

      if (reset) begin
         bad_nxt = 1'b0;
         curr_port_nxt = 'h0;
         curr_pat_nxt = 'h0;
         seq_no_nxt = 'h0;
         size_nxt = {11{1'b1}};
         eop_nxt = 1'b0;
      end
      else if (rx_rd_en_d2) begin
         case (count_d1)
            'd0 : begin
               // Reset the bad indicator if the first word is good
               if (rx_data_good)
                  bad_nxt = 1'b0;
               else
                  bad_nxt = 1'b1;

               // Record the length
               size_nxt = pkt_size;

               // Reset EOP
               eop_nxt = 1'b0;
            end

            DA_LO_SA_HI : begin
               // If we're currently locked then we should know *exactly* what
               // data we are expecting
               if (locked) begin
                  if (!rx_data_good)
                     bad_nxt = 1'b1;
               end
               // If we're not locked then we need to identify what port we
               // are receiving data on
               else begin
                  if (!rx_da_sa_good)
                     bad_nxt = 1'b1;
                  else
                     curr_port_nxt = data_d1[18:16];
               end
            end

            // Handle this case with the default rule
            /*
             * DA_LO : begin
             *    if (!rx_data_good)
             *       bad_nxt = 1'b1;
             * end
             */

            SIZE_PATTERN : begin
               // If we're locked then we should be expecting a particular
               // pattern
               //
               // If we're not locked that we will have to identify the
               // pattern
               if (locked) begin
                  if (!rx_data_good)
                     bad_nxt = 1'b1;
               end
               else begin
                  if (!rx_size_pat_good)
                     bad_nxt = 1'b1;
               end

               // Record the current pattern that we are processing
               curr_pat_nxt = data_d1[NUM_PATTERNS - 1:0];
            end

            SEQUENCE_NO : begin
               if (curr_pat == RANDOM_PATTERN)
                  seq_no_nxt = data_d1;
               else if ((curr_pat != ALL_0_PATTERN &&
                         curr_pat != ALL_1_PATTERN &&
                         curr_pat != ALT_01_PATTERN &&
                         curr_pat != ALT_10_PATTERN) ||
                        !rx_data_good)
                  bad_nxt = 1'b1;

            end

            EOP : begin
               // Handle end-of-packet
               done_nxt = 1'b1;
               curr_pat_nxt = next_pat;
               eop_nxt = 1'b0;
            end

            default : begin
               if (!rx_data_good)
                  bad_nxt = 1'b1;

               // Perform end of packet processing if appropriate
               //
               // Note: there is no need to check the count as that should
               // be verified by the data/ctrl comparison above (assuming
               // pkt_gen is doing it's job correctly)
               if (|ctrl_d1) begin
                  eop_nxt = 1'b1;
               end
            end
         endcase
      end
   end



   // =================================
   // State machine to generate logs
   //
   // Note: The last word is not a data word but indicates success/failure
   // 0 = success, non-0 = failure
   always @(posedge clk)
   begin
      if (reset) begin
         log_rx_data <= 'h0;
         log_exp_data <= 'h0;
         log_addr <= 'h0;
         log_data_wr <= 1'b0;
         log_done <= 1'b0;
         log_hold <= 1'b0;
      end
      else if (rx_rd_en_d2) begin
         log_rx_data <= data_d1;
         log_exp_data <= gen_data_d1;
         log_addr <= eop ? last_pos : count_d1;
         log_data_wr <= !eop;
         log_done <= eop;
         log_hold <= eop && (bad || data_d1 != 'h0);
      end
      else begin
         log_data_wr <= 1'b0;
         log_done <= 1'b0;
         log_hold <= 1'b0;
      end
   end

   // =================================
   // Maintain a counter so that we know where we are in the packet

   always @(posedge clk)
   begin
      if (reset) begin
         count <= 'h0;
         last_pos <= 'h0;
      end
      else if (rx_rd_en_d1) begin
         // Check if we're seeing the end of packet
         if (|ctrl) begin
            count <= EOP;
            last_pos <= count;
         end
         else if (eop && count == EOP) begin
            count <= 'h0;
         end
         else begin
            count <= count + 'h1;
         end
      end

      count_d1 <= count;

      // Always read data if there's data available
      rx_rd_en <= !rx_almost_empty;
      rx_rd_en_d1 <= rx_rd_en;
      rx_rd_en_d2 <= rx_rd_en_d1;
   end



   // =================================
   // Track whether the module is locked onto a sequence or not

   always @(posedge clk)
   begin
      locked <= locked_nxt;
      lock_count <= lock_count_nxt;
   end

   always @*
   begin
      locked_nxt = locked;
      lock_count_nxt = lock_count + 'h1;

      if (reset) begin
         locked_nxt = 1'b0;
         lock_count_nxt = 'h0;
      end
      else begin
         // Check if we've finished a packet
         if (done) begin
            locked_nxt = !bad;
            lock_count_nxt = 'h0;
         end
         else if (lock_count == LOSE_LOCK_COUNT) begin
            locked_nxt = 1'b0;
         end
      end
   end



   // =================================
   // Pattern identification

   // Work out what the next pattern should be
   //
   // Also, identify whether the pattern has wrapped
   always @(posedge clk)
   begin
      // On reset or idle the next pattern should be 1
      if (reset) begin
         next_pat <= 'h1;
      end
      // Reset the next state once we've read the pattern
      else if (rx_rd_en_d2 && count_d1 == SEQUENCE_NO) begin
         next_pat <= curr_pat;
      end
      // If the next pattern is 0 then we've wrapped so record that fact
      else if (curr_pat != 'h0 && next_pat == 'h0) begin
         next_pat <= 'h1;
      end
      else if ((curr_pat ^ next_pat) == 'h0 ||
               (next_pat & pat_en) == 'h0) begin
         // It's possible that there's only one (or none) available patterns
         // in which case we've got no choice (and wrap must be true if
         // current pattern is non-zero)
         if ((curr_pat ^ pat_en) == 'h0)
            next_pat <= pat_en;
         else
            next_pat <= {next_pat[NUM_PATTERNS - 2 : 0], 1'b0};
      end
   end



   // =================================
   // Comparisons
   always @(posedge clk)
   begin
      case (gen_ctrl)
         4'b1000 : rx_data_good <= data[31:24] == gen_data[31:24] && ctrl == gen_ctrl;
         4'b0100 : rx_data_good <= data[31:16] == gen_data[31:16] && ctrl == gen_ctrl;
         4'b0010 : rx_data_good <= data[31:8] == gen_data[31:8] && ctrl == gen_ctrl;
         default : rx_data_good <= data == gen_data && ctrl == gen_ctrl;
      endcase
      rx_da_sa_good <= data[31:19] == gen_data[31:19] &&
                       data[15:0] == gen_data[15:0] &&
                       ctrl == gen_ctrl &&
                       (data[18:16] == 3'd1 || data[18:16] == 3'd2 ||
                        data[18:16] == 3'd3 || data[18:16] == 3'd4);
      rx_size_pat_good <= data[31:NUM_PATTERNS] == gen_data[31:NUM_PATTERNS] &&
                          ctrl == gen_ctrl;

      data_d1 <= data;
      ctrl_d1 <= ctrl;
      gen_data_d1 <= gen_data;
   end



   // =================================
   // Packet generator to generate the packet for comparison
   //
   phy_test_pktgen #(
      .CPCI_NF2_DATA_WIDTH (CPCI_NF2_DATA_WIDTH),
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_pktgen (
      .data (gen_data),
      .ctrl (gen_ctrl),
      .rd_en (gen_rd_en),

      //.port (count == DA_LO_SA_HI ? curr_port_nxt : curr_port),
      .port (curr_port),
      //.pattern (count == SIZE_PATTERN ? curr_pat_nxt : curr_pat),
      .pattern (curr_pat),
      .pkt_size (size),
      .seq_no (data[SEQ_NO_WIDTH - 1 : 0]),

      .busy (gen_busy),
      .done (gen_done),

      .reset (reset || |ctrl),
      .clk (clk)
   );

endmodule   // phy_test_pktcmp
