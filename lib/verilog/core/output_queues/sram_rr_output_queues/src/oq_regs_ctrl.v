///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_regs_ctrl.v 5064 2009-02-22 05:20:35Z grg $
//
// Module: oq_regs_ctrl.v
// Project: NF2.1
// Description: Main logic for host interface. This decodes/processes all
// register access data from oq_regs_host_iface. Individual register accesses
// are processed by the "update" modules.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module oq_regs_ctrl
   #(
      parameter SRAM_ADDR_WIDTH     = 19,
      parameter CTRL_WIDTH          = 8,
      parameter NUM_OUTPUT_QUEUES   = 8,
      parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
      parameter NUM_REGS_USED       = 17,
      parameter ADDR_WIDTH          = log2(NUM_REGS_USED),
      parameter MAX_PKT             = 2048/CTRL_WIDTH,   // allow for 2K bytes
      parameter MIN_PKT             = 60/CTRL_WIDTH + 1,
      parameter PKTS_IN_RAM_WIDTH   = log2((2**SRAM_ADDR_WIDTH)/MIN_PKT),
      parameter PKT_LEN_WIDTH       = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH)
   )

   (
      // --- interface to store/remove pkt
      output reg [NUM_OUTPUT_QUEUES-1:0]     enable,

      // --- interface to oq_regs_host_iface
      input                                  reg_req,
      input                                  reg_rd_wr_L_held,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_held,

      input [ADDR_WIDTH-1:0]                 addr,
      input [NUM_OQ_WIDTH-1:0]               q_addr,

      output reg                             result_ready,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_result,

      // --- Interface to full/empty generation logic
      output reg                             initialize,
      output reg [NUM_OQ_WIDTH-1:0]          initialize_oq,

      // --- Register interfaces
      output reg [NUM_OQ_WIDTH-1:0]          reg_addr,

      output reg                             num_pkt_bytes_stored_reg_req,
      input                                  num_pkt_bytes_stored_reg_ack,
      output reg                             num_pkt_bytes_stored_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkt_bytes_stored_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkt_bytes_stored_reg_rd_data,

      output reg                             num_overhead_bytes_stored_reg_req,
      input                                  num_overhead_bytes_stored_reg_ack,
      output reg                             num_overhead_bytes_stored_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_overhead_bytes_stored_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_overhead_bytes_stored_reg_rd_data,

      output reg                             num_pkts_stored_reg_req,
      input                                  num_pkts_stored_reg_ack,
      output reg                             num_pkts_stored_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkts_stored_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkts_stored_reg_rd_data,

      output reg                             num_pkts_dropped_reg_req,
      input                                  num_pkts_dropped_reg_ack,
      output reg                             num_pkts_dropped_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkts_dropped_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkts_dropped_reg_rd_data,

      output reg                             num_pkt_bytes_removed_reg_req,
      input                                  num_pkt_bytes_removed_reg_ack,
      output reg                             num_pkt_bytes_removed_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkt_bytes_removed_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkt_bytes_removed_reg_rd_data,

      output reg                             num_overhead_bytes_removed_reg_req,
      input                                  num_overhead_bytes_removed_reg_ack,
      output reg                             num_overhead_bytes_removed_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_overhead_bytes_removed_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_overhead_bytes_removed_reg_rd_data,

      output reg                             num_pkts_removed_reg_req,
      input                                  num_pkts_removed_reg_ack,
      output reg                             num_pkts_removed_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkts_removed_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkts_removed_reg_rd_data,

      output reg                             oq_addr_hi_reg_req,
      input                                  oq_addr_hi_reg_ack,
      output reg                             oq_addr_hi_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  oq_addr_hi_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       oq_addr_hi_reg_rd_data,

      output reg                             oq_addr_lo_reg_req,
      input                                  oq_addr_lo_reg_ack,
      output reg                             oq_addr_lo_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  oq_addr_lo_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       oq_addr_lo_reg_rd_data,

      output reg                             oq_wr_addr_reg_req,
      input                                  oq_wr_addr_reg_ack,
      output reg                             oq_wr_addr_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  oq_wr_addr_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       oq_wr_addr_reg_rd_data,

      output reg                             oq_rd_addr_reg_req,
      input                                  oq_rd_addr_reg_ack,
      output reg                             oq_rd_addr_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  oq_rd_addr_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       oq_rd_addr_reg_rd_data,

      output reg                             max_pkts_in_q_reg_req,
      input                                  max_pkts_in_q_reg_ack,
      output reg                             max_pkts_in_q_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  max_pkts_in_q_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       max_pkts_in_q_reg_rd_data,

      output reg                             num_pkts_in_q_reg_req,
      input                                  num_pkts_in_q_reg_ack,
      output reg                             num_pkts_in_q_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_pkts_in_q_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_pkts_in_q_reg_rd_data,

      output reg                             num_words_left_reg_req,
      input                                  num_words_left_reg_ack,
      output reg                             num_words_left_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_words_left_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_words_left_reg_rd_data,

      output reg                             num_words_in_q_reg_req,
      input                                  num_words_in_q_reg_ack,
      output reg                             num_words_in_q_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  num_words_in_q_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       num_words_in_q_reg_rd_data,

      output reg                             oq_full_thresh_reg_req,
      input                                  oq_full_thresh_reg_ack,
      output reg                             oq_full_thresh_reg_wr,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  oq_full_thresh_reg_wr_data,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       oq_full_thresh_reg_rd_data,

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

   localparam ADDR_MAX           = `OQ_DEFAULT_ADDR_HIGH(0, NUM_OUTPUT_QUEUES);
   localparam ADDR_INC           = `OQ_DEFAULT_ADDR_LOW(1, NUM_OUTPUT_QUEUES);
   localparam WORDS_IN_Q         = `OQ_DEFAULT_ADDR_HIGH(0, NUM_OUTPUT_QUEUES) -
                                   `OQ_DEFAULT_ADDR_LOW(0, NUM_OUTPUT_QUEUES) + 1;

   // States
   localparam RESET                 = 0;
   localparam NORMAL_OPERATION      = 1;
   localparam READ_HI_LO_ADDR       = 2;
   localparam CLEAR_COUNTERS        = 3;
   localparam INITIALIZE_PAUSE      = 4;

   // ------------- Wires/reg ------------------

   // State variables
   reg [2:0]                           state;

   reg                                 enable_held;

   // Register initialization signals
   reg [NUM_OQ_WIDTH-1:0]              reg_cnt;

   reg [SRAM_ADDR_WIDTH-1:0]           addr_min;
   reg [SRAM_ADDR_WIDTH-1:0]           addr_max;

   // Register request in progress
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_result_nxt;
   reg                                 reg_req_in_progress;

   // Held versions of the low and high addresses (used to calculate the
   // number of words in a queue)
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      oq_addr_hi_reg_rd_data_held;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      oq_addr_lo_reg_rd_data_held;

   // Have the various requests been acknowledged during an initialize output
   // queue operation?
   reg                                 oq_addr_hi_reg_acked;
   reg                                 oq_addr_lo_reg_acked;
   reg                                 num_pkt_bytes_stored_reg_acked;
   reg                                 num_overhead_bytes_stored_reg_acked;
   reg                                 num_pkts_stored_reg_acked;
   reg                                 num_pkts_dropped_reg_acked;
   reg                                 num_pkt_bytes_removed_reg_acked;
   reg                                 num_overhead_bytes_removed_reg_acked;
   reg                                 num_pkts_removed_reg_acked;
   reg                                 num_pkts_in_q_reg_acked;
   reg                                 num_words_left_reg_acked;
   reg                                 num_words_in_q_reg_acked;
   reg                                 oq_wr_addr_reg_acked;
   reg                                 oq_rd_addr_reg_acked;

   // Misc
   wire                                want_initialize_oq;
   wire                                result_ready_local;
   wire                                req_all;

   // -------------- Logic ----------------------

   assign result_ready_local = num_pkt_bytes_stored_reg_ack ||
                               num_overhead_bytes_stored_reg_ack ||
                               num_pkts_stored_reg_ack ||
                               num_pkts_dropped_reg_ack ||
                               num_pkt_bytes_removed_reg_ack ||
                               num_overhead_bytes_removed_reg_ack ||
                               num_pkts_removed_reg_ack ||
                               oq_addr_hi_reg_ack ||
                               oq_addr_lo_reg_ack ||
                               oq_wr_addr_reg_ack ||
                               oq_rd_addr_reg_ack ||
                               max_pkts_in_q_reg_ack ||
                               num_pkts_in_q_reg_ack ||
                               num_words_left_reg_ack ||
                               num_words_in_q_reg_ack ||
                               oq_full_thresh_reg_ack;

   assign want_initialize_oq = reg_data_held[`OQ_INITIALIZE_OQ_BIT_NUM];


   // Main state machine
   //
   // Note: The logic to control the value sent to the registers (ie.
   // _reg_req, _reg_wr and _wr_data) are in a separate always block.
   always @(posedge clk)
   begin
      if (reset) begin
         state <= RESET;
         reg_cnt <= 'h0;

         addr_min <= 0;
         addr_max <= ADDR_MAX;

         reg_req_in_progress <= 1'b0;

         enable <= {NUM_OUTPUT_QUEUES{1'b0}};
         enable_held <= 1'b0;

         initialize     <= 1'b0;
         initialize_oq  <= 'h0;
      end
      else begin
         case (state)
            RESET : begin
               // Walk through the register one by one resetting the values
               if (reg_cnt == NUM_OUTPUT_QUEUES - 1) begin
                  state <= NORMAL_OPERATION;
                  enable <= {NUM_OUTPUT_QUEUES{1'b1}};
               end
               else
                  reg_cnt <= reg_cnt + 'h1;

               addr_min <= addr_min + ADDR_INC;
               addr_max <= addr_max + ADDR_INC;
            end // RESET

            NORMAL_OPERATION : begin
               if (reg_req && !reg_req_in_progress) begin
                  result_ready <= 1'b0;

                  // Handle access to the control register separately
                  if (addr == `OQ_QUEUE_CTRL) begin

                     // If this request is a write to the initialize bit then
                     // we need to go through the process of clearing the
                     // appropriate queue
                     reg_req_in_progress <= !reg_rd_wr_L_held && want_initialize_oq;

                     // Handle writes
                     if (!reg_rd_wr_L_held) begin
                        enable[q_addr] <= reg_data_held[`OQ_ENABLE_SEND_BIT_NUM] &&
                                          !want_initialize_oq;

                        if (want_initialize_oq) begin
                           // Go into the initalization state
                           state <= READ_HI_LO_ADDR;

                           initialize     <= 1'b1;
                           initialize_oq  <= q_addr;

                           enable_held    <= reg_data_held[`OQ_ENABLE_SEND_BIT_NUM];

                           oq_addr_hi_reg_acked <= 1'b0;
                           oq_addr_lo_reg_acked <= 1'b0;
                        end
                     end

                     // Set the result state appropriately
                     result_ready <= reg_rd_wr_L_held || !want_initialize_oq;
                     reg_result <= reg_result_nxt;
                  end
                  else begin
                     // Processing a normal register request.
                     // Record that a register request is in progress
                     reg_req_in_progress    <= 1'b1;
                  end
               end // if (reg_req && !reg_req_in_progress)
               else if (reg_req_in_progress) begin
                  // Wait for a response to be ready
                  if (result_ready_local) begin
                     reg_req_in_progress <= 1'b0;

                     result_ready <= 1'b1;
                     reg_result <= reg_result_nxt;
                  end
                  else if (!reg_req) begin
                     // The host interface has obviously given up (oops)
                     reg_req_in_progress <= 1'b0;
                  end
               end
               else begin
                  result_ready <= 1'b0;
               end
            end

            READ_HI_LO_ADDR : begin
               // If both requests have been acked then go ahead and clear the
               // various counters
               if ((oq_addr_hi_reg_ack && oq_addr_lo_reg_ack) ||
                   (oq_addr_hi_reg_ack && !oq_addr_lo_reg_req) ||
                   (!oq_addr_hi_reg_req && oq_addr_lo_reg_ack)) begin

                  // Clear the request flags
                  state <= CLEAR_COUNTERS;
               end

               // Latch the hi and lo addresses when the come back so that we
               // can calculate the number of words
               if (oq_addr_hi_reg_ack) begin
                  oq_addr_hi_reg_rd_data_held <= oq_addr_hi_reg_rd_data;
               end
               if (oq_addr_lo_reg_ack) begin
                  oq_addr_lo_reg_rd_data_held <= oq_addr_lo_reg_rd_data;
               end

               initialize                 <= 1'b0;

               num_pkt_bytes_stored_reg_acked         <= 1'b0;
               num_overhead_bytes_stored_reg_acked    <= 1'b0;
               num_pkts_stored_reg_acked              <= 1'b0;
               num_pkts_dropped_reg_acked             <= 1'b0;
               num_pkt_bytes_removed_reg_acked        <= 1'b0;
               num_overhead_bytes_removed_reg_acked   <= 1'b0;
               num_pkts_removed_reg_acked             <= 1'b0;
               num_pkts_in_q_reg_acked                <= 1'b0;
               num_words_left_reg_acked               <= 1'b0;
               num_words_in_q_reg_acked               <= 1'b0;
               oq_wr_addr_reg_acked                   <= 1'b0;
               oq_rd_addr_reg_acked                   <= 1'b0;

               oq_addr_hi_reg_acked <= oq_addr_hi_reg_ack || oq_addr_hi_reg_acked;
               oq_addr_lo_reg_acked <= oq_addr_lo_reg_ack || oq_addr_lo_reg_acked;
            end

            CLEAR_COUNTERS : begin
               // Wait for all the request signals to be cleared
               if (!num_pkts_in_q_reg_req &&
                   !num_words_left_reg_req &&
                   !num_words_in_q_reg_req &&
                   !oq_wr_addr_reg_req &&
                   !oq_rd_addr_reg_req) begin
                  state <= INITIALIZE_PAUSE;

                  // Set the enable state to the value desired by the user
                  enable[initialize_oq] <= enable_held;

                  // Notify the register block that we're done
                  reg_req_in_progress  <= 1'b0;
                  result_ready         <= 1'b1;
                  reg_result           <= reg_result_nxt;
               end

               num_pkt_bytes_stored_reg_acked         <= num_pkt_bytes_stored_reg_ack ||
                                                         num_pkt_bytes_stored_reg_acked;
               num_overhead_bytes_stored_reg_acked    <= num_overhead_bytes_stored_reg_ack ||
                                                         num_overhead_bytes_stored_reg_acked;
               num_pkts_stored_reg_acked              <= num_pkts_stored_reg_ack ||
                                                         num_pkts_stored_reg_acked;
               num_pkts_dropped_reg_acked             <= num_pkts_dropped_reg_ack ||
                                                         num_pkts_dropped_reg_acked;
               num_pkt_bytes_removed_reg_acked        <= num_pkt_bytes_removed_reg_ack ||
                                                         num_pkt_bytes_removed_reg_acked;
               num_overhead_bytes_removed_reg_acked   <= num_overhead_bytes_removed_reg_ack ||
                                                         num_overhead_bytes_removed_reg_acked;
               num_pkts_removed_reg_acked             <= num_pkts_removed_reg_ack ||
                                                         num_pkts_removed_reg_acked;
               num_pkts_in_q_reg_acked                <= num_pkts_in_q_reg_ack ||
                                                         num_pkts_in_q_reg_acked;
               num_words_left_reg_acked               <= num_words_left_reg_ack ||
                                                         num_words_left_reg_acked;
               num_words_in_q_reg_acked               <= num_words_in_q_reg_ack ||
                                                         num_words_in_q_reg_acked;
               oq_wr_addr_reg_acked                   <= oq_wr_addr_reg_ack ||
                                                         oq_wr_addr_reg_acked;
               oq_rd_addr_reg_acked                   <= oq_rd_addr_reg_ack ||
                                                         oq_rd_addr_reg_acked;
            end

            INITIALIZE_PAUSE : begin
               state <= NORMAL_OPERATION;
            end
         endcase
      end
   end

   // Generate the register access signals
   //
   // Note: Main state machine is above
   always @*
   begin
      // Set defaults
      reg_addr = q_addr;

      // By default we shouldn't be issuing requests
      num_pkt_bytes_stored_reg_req        = 1'b0;
      num_overhead_bytes_stored_reg_req   = 1'b0;
      num_pkts_stored_reg_req             = 1'b0;
      num_pkts_dropped_reg_req            = 1'b0;
      num_pkt_bytes_removed_reg_req       = 1'b0;
      num_overhead_bytes_removed_reg_req  = 1'b0;
      num_pkts_removed_reg_req            = 1'b0;
      max_pkts_in_q_reg_req               = 1'b0;
      num_pkts_in_q_reg_req               = 1'b0;
      num_words_left_reg_req              = 1'b0;
      num_words_in_q_reg_req              = 1'b0;
      oq_addr_hi_reg_req                  = 1'b0;
      oq_addr_lo_reg_req                  = 1'b0;
      oq_wr_addr_reg_req                  = 1'b0;
      oq_rd_addr_reg_req                  = 1'b0;
      oq_full_thresh_reg_req              = 1'b0;

      // Write enable -- default is the write value from the host interface
      // (except for read-only registers)
      num_pkt_bytes_stored_reg_wr         = !reg_rd_wr_L_held;
      num_overhead_bytes_stored_reg_wr    = !reg_rd_wr_L_held;
      num_pkts_stored_reg_wr              = !reg_rd_wr_L_held;
      num_pkts_dropped_reg_wr             = !reg_rd_wr_L_held;
      num_pkt_bytes_removed_reg_wr        = !reg_rd_wr_L_held;
      num_overhead_bytes_removed_reg_wr   = !reg_rd_wr_L_held;
      num_pkts_removed_reg_wr             = !reg_rd_wr_L_held;
      oq_addr_hi_reg_wr                   = !reg_rd_wr_L_held;
      oq_addr_lo_reg_wr                   = !reg_rd_wr_L_held;
      oq_wr_addr_reg_wr                   = 1'b0;
      oq_rd_addr_reg_wr                   = 1'b0;
      max_pkts_in_q_reg_wr                = !reg_rd_wr_L_held;
      num_pkts_in_q_reg_wr                = 1'b0;
      num_words_left_reg_wr               = 1'b0;
      num_words_in_q_reg_wr               = 1'b0;
      oq_full_thresh_reg_wr               = !reg_rd_wr_L_held;

      // Write data
      // Default to the data from the host_iface modules
      num_pkt_bytes_stored_reg_wr_data       = reg_data_held;
      num_overhead_bytes_stored_reg_wr_data  = reg_data_held;
      num_pkts_stored_reg_wr_data            = reg_data_held;
      num_pkts_dropped_reg_wr_data           = reg_data_held;
      num_pkt_bytes_removed_reg_wr_data      = reg_data_held;
      num_overhead_bytes_removed_reg_wr_data = reg_data_held;
      num_pkts_removed_reg_wr_data           = reg_data_held;
      oq_addr_hi_reg_wr_data                 = reg_data_held;
      oq_addr_lo_reg_wr_data                 = reg_data_held;
      oq_wr_addr_reg_wr_data                 = reg_data_held;
      oq_rd_addr_reg_wr_data                 = reg_data_held;
      max_pkts_in_q_reg_wr_data              = reg_data_held;
      num_pkts_in_q_reg_wr_data              = reg_data_held;
      num_words_left_reg_wr_data             = reg_data_held;
      num_words_in_q_reg_wr_data             = reg_data_held;
      oq_full_thresh_reg_wr_data             = reg_data_held;

      case (state)
         RESET : begin
            reg_addr                               = reg_cnt;

            num_pkt_bytes_stored_reg_wr_data       = 'h0;
            num_overhead_bytes_stored_reg_wr_data  = 'h0;
            num_pkts_stored_reg_wr_data            = 'h0;
            num_pkts_dropped_reg_wr_data           = 'h0;
            num_pkt_bytes_removed_reg_wr_data      = 'h0;
            num_overhead_bytes_removed_reg_wr_data = 'h0;
            num_pkts_removed_reg_wr_data           = 'h0;
            max_pkts_in_q_reg_wr_data              = `OQ_DEFAULT_MAX_PKTS;
            num_pkts_in_q_reg_wr_data              = 1'b0;
            num_words_left_reg_wr_data             = WORDS_IN_Q;
            num_words_in_q_reg_wr_data             = 'h0;
            oq_addr_hi_reg_wr_data                 = addr_max;
            oq_addr_lo_reg_wr_data                 = addr_min;
            oq_wr_addr_reg_wr_data                 = addr_min;
            oq_rd_addr_reg_wr_data                 = addr_min;
            oq_full_thresh_reg_wr_data             = 'h0;

            num_pkt_bytes_stored_reg_wr            = 1'b1;
            num_overhead_bytes_stored_reg_wr       = 1'b1;
            num_pkts_stored_reg_wr                 = 1'b1;
            num_pkts_dropped_reg_wr                = 1'b1;
            num_pkt_bytes_removed_reg_wr           = 1'b1;
            num_overhead_bytes_removed_reg_wr      = 1'b1;
            num_pkts_removed_reg_wr                = 1'b1;
            max_pkts_in_q_reg_wr                   = 1'b1;
            num_pkts_in_q_reg_wr                   = 1'b1;
            num_words_left_reg_wr                  = 1'b1;
            num_words_in_q_reg_wr                  = 1'b1;
            oq_addr_hi_reg_wr                      = 1'b1;
            oq_addr_lo_reg_wr                      = 1'b1;
            oq_wr_addr_reg_wr                      = 1'b1;
            oq_rd_addr_reg_wr                      = 1'b1;
            oq_full_thresh_reg_wr                  = 1'b1;

            num_pkt_bytes_stored_reg_req           = 1'b1;
            num_overhead_bytes_stored_reg_req      = 1'b1;
            num_pkts_stored_reg_req                = 1'b1;
            num_pkts_dropped_reg_req               = 1'b1;
            num_pkt_bytes_removed_reg_req          = 1'b1;
            num_overhead_bytes_removed_reg_req     = 1'b1;
            num_pkts_removed_reg_req               = 1'b1;
            max_pkts_in_q_reg_req                  = 1'b1;
            num_pkts_in_q_reg_req                  = 1'b1;
            num_words_left_reg_req                 = 1'b1;
            num_words_in_q_reg_req                 = 1'b1;
            oq_addr_hi_reg_req                     = 1'b1;
            oq_addr_lo_reg_req                     = 1'b1;
            oq_wr_addr_reg_req                     = 1'b1;
            oq_rd_addr_reg_req                     = 1'b1;
            oq_full_thresh_reg_req                 = 1'b1;
         end // RESET

         NORMAL_OPERATION : begin
            // Wait for a response to be ready
            if (!reg_req_in_progress || result_ready_local || !reg_req) begin
               // Write enable
               num_pkt_bytes_stored_reg_req        = 1'b0;
               num_overhead_bytes_stored_reg_req   = 1'b0;
               num_pkts_stored_reg_req             = 1'b0;
               num_pkts_dropped_reg_req            = 1'b0;
               num_pkt_bytes_removed_reg_req       = 1'b0;
               num_overhead_bytes_removed_reg_req  = 1'b0;
               num_pkts_removed_reg_req            = 1'b0;
               oq_addr_hi_reg_req                  = 1'b0;
               oq_addr_lo_reg_req                  = 1'b0;
               oq_wr_addr_reg_req                  = 1'b0;
               oq_rd_addr_reg_req                  = 1'b0;
               max_pkts_in_q_reg_req               = 1'b0;
               num_pkts_in_q_reg_req               = 1'b0;
               num_words_left_reg_req              = 1'b0;
               num_words_in_q_reg_req              = 1'b0;
               oq_full_thresh_reg_req              = 1'b0;
            end
            else begin
               // Default to the "default" values calculated assuming that we are
               // writing based upon the address register
               //
               // Write enable
               num_pkt_bytes_stored_reg_req        = addr == `OQ_QUEUE_NUM_PKT_BYTES_STORED;
               num_overhead_bytes_stored_reg_req   = addr == `OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED;
               num_pkts_stored_reg_req             = addr == `OQ_QUEUE_NUM_PKTS_STORED;
               num_pkts_dropped_reg_req            = addr == `OQ_QUEUE_NUM_PKTS_DROPPED;
               num_pkt_bytes_removed_reg_req       = addr == `OQ_QUEUE_NUM_PKT_BYTES_REMOVED;
               num_overhead_bytes_removed_reg_req  = addr == `OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED;
               num_pkts_removed_reg_req            = addr == `OQ_QUEUE_NUM_PKTS_REMOVED;
               oq_addr_hi_reg_req                  = addr == `OQ_QUEUE_ADDR_HI;
               oq_addr_lo_reg_req                  = addr == `OQ_QUEUE_ADDR_LO;
               oq_wr_addr_reg_req                  = addr == `OQ_QUEUE_WR_ADDR;
               oq_rd_addr_reg_req                  = addr == `OQ_QUEUE_RD_ADDR;
               max_pkts_in_q_reg_req               = addr == `OQ_QUEUE_MAX_PKTS_IN_Q;
               num_pkts_in_q_reg_req               = addr == `OQ_QUEUE_NUM_PKTS_IN_Q;
               num_words_left_reg_req              = addr == `OQ_QUEUE_NUM_WORDS_LEFT;
               num_words_in_q_reg_req              = addr == `OQ_QUEUE_NUM_WORDS_IN_Q;
               oq_full_thresh_reg_req              = addr == `OQ_QUEUE_FULL_THRESH;
            end
         end

         READ_HI_LO_ADDR : begin
            // Read the lo/hi addresses to enable us to calculate the
            // maximum queue occupancy
            oq_addr_hi_reg_req = !oq_addr_hi_reg_acked && !oq_addr_hi_reg_ack;
            oq_addr_lo_reg_req = !oq_addr_lo_reg_acked && !oq_addr_lo_reg_ack;

            oq_addr_hi_reg_wr = 1'b0;
            oq_addr_lo_reg_wr = 1'b0;
         end

         CLEAR_COUNTERS : begin
            // Set the values to write
            num_pkts_in_q_reg_wr_data              = 1'b0;
            num_words_left_reg_wr_data             = oq_addr_hi_reg_rd_data_held - oq_addr_lo_reg_rd_data_held ;
            num_words_in_q_reg_wr_data             = 'h0;
            oq_wr_addr_reg_wr_data                 = oq_addr_lo_reg_rd_data_held;
            oq_rd_addr_reg_wr_data                 = oq_addr_lo_reg_rd_data_held;
            num_pkt_bytes_stored_reg_wr_data       = 'h0;
            num_overhead_bytes_stored_reg_wr_data  = 'h0;
            num_pkts_stored_reg_wr_data            = 'h0;
            num_pkts_dropped_reg_wr_data           = 'h0;
            num_pkt_bytes_removed_reg_wr_data      = 'h0;
            num_overhead_bytes_removed_reg_wr_data = 'h0;
            num_pkts_removed_reg_wr_data           = 'h0;

            // Set the write enable flags
            num_pkts_in_q_reg_wr             = 1'b1;
            num_words_left_reg_wr            = 1'b1;
            num_words_in_q_reg_wr            = 1'b1;
            oq_wr_addr_reg_wr                = 1'b1;
            oq_rd_addr_reg_wr                = 1'b1;

            num_pkt_bytes_stored_reg_wr      = 1'b1;
            num_overhead_bytes_stored_reg_wr = 1'b1;
            num_pkts_stored_reg_wr           = 1'b1;
            num_pkts_dropped_reg_wr          = 1'b1;
            num_pkt_bytes_removed_reg_wr     = 1'b1;
            num_overhead_bytes_removed_reg_wr= 1'b1;
            num_pkts_removed_reg_wr          = 1'b1;

            num_pkts_in_q_reg_req   = !num_pkts_in_q_reg_acked && !num_pkts_in_q_reg_ack;
            num_words_left_reg_req  = !num_words_left_reg_acked && !num_words_left_reg_ack;
            num_words_in_q_reg_req  = !num_words_in_q_reg_acked && !num_words_in_q_reg_ack;
            oq_wr_addr_reg_req      = !oq_wr_addr_reg_acked && !oq_wr_addr_reg_ack;
            oq_rd_addr_reg_req      = !oq_rd_addr_reg_acked && !oq_rd_addr_reg_ack;
            num_pkt_bytes_stored_reg_req        = !num_pkt_bytes_stored_reg_acked &&
                                                  !num_pkt_bytes_stored_reg_ack;
            num_overhead_bytes_stored_reg_req   = !num_overhead_bytes_stored_reg_acked &&
                                                  !num_overhead_bytes_stored_reg_ack;
            num_pkts_stored_reg_req             = !num_pkts_stored_reg_acked &&
                                                  !num_pkts_stored_reg_ack;
            num_pkts_dropped_reg_req            = !num_pkts_dropped_reg_acked &&
                                                  !num_pkts_dropped_reg_ack;
            num_pkt_bytes_removed_reg_req       = !num_pkt_bytes_removed_reg_acked &&
                                                  !num_pkt_bytes_removed_reg_ack;
            num_overhead_bytes_removed_reg_req  = !num_overhead_bytes_removed_reg_acked &&
                                                  !num_overhead_bytes_removed_reg_ack;
            num_pkts_removed_reg_req            = !num_pkts_removed_reg_acked &&
                                                  !num_pkts_removed_reg_ack;
         end
      endcase
   end

   // Generate the result of the request
   always @*
   begin
      case (addr)
         `OQ_QUEUE_CTRL                         : reg_result_nxt = enable[q_addr];
         `OQ_QUEUE_NUM_PKT_BYTES_STORED         : reg_result_nxt = num_pkt_bytes_stored_reg_rd_data;
         `OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED    : reg_result_nxt = num_overhead_bytes_stored_reg_rd_data;
         `OQ_QUEUE_NUM_PKTS_STORED              : reg_result_nxt = num_pkts_stored_reg_rd_data;
         `OQ_QUEUE_NUM_PKTS_DROPPED             : reg_result_nxt = num_pkts_dropped_reg_rd_data;
         `OQ_QUEUE_NUM_PKT_BYTES_REMOVED        : reg_result_nxt = num_pkt_bytes_removed_reg_rd_data;
         `OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED   : reg_result_nxt = num_overhead_bytes_removed_reg_rd_data;
         `OQ_QUEUE_NUM_PKTS_REMOVED             : reg_result_nxt = num_pkts_removed_reg_rd_data;
         `OQ_QUEUE_ADDR_HI                      : reg_result_nxt = oq_addr_hi_reg_rd_data;
         `OQ_QUEUE_ADDR_LO                      : reg_result_nxt = oq_addr_lo_reg_rd_data;
         `OQ_QUEUE_WR_ADDR                      : reg_result_nxt = oq_wr_addr_reg_rd_data;
         `OQ_QUEUE_RD_ADDR                      : reg_result_nxt = oq_rd_addr_reg_rd_data;
         `OQ_QUEUE_MAX_PKTS_IN_Q                : reg_result_nxt = max_pkts_in_q_reg_rd_data;
         `OQ_QUEUE_NUM_PKTS_IN_Q                : reg_result_nxt = num_pkts_in_q_reg_rd_data;
         `OQ_QUEUE_NUM_WORDS_LEFT               : reg_result_nxt = num_words_left_reg_rd_data;
         `OQ_QUEUE_NUM_WORDS_IN_Q               : reg_result_nxt = num_words_in_q_reg_rd_data;
         `OQ_QUEUE_FULL_THRESH                  : reg_result_nxt = oq_full_thresh_reg_rd_data;
         default                                : reg_result_nxt = 32'h dead_beef;
      endcase
   end

endmodule // oq_regs_ctrl
