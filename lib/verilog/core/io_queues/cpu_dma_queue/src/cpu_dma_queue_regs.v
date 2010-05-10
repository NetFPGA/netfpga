///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_regs.v 2265 2007-09-17 22:02:57Z grg $
//
// Module: cpu_dma_queue_regs.v
// Project: NF2.1
// Description: Register module for the CPU DMA queue
//
// The "deltas" in this block are designed to store the updates that need to
// be applied to the registers in RAM. An example would be the number of
// packets that have arrived since the appropriate register in RAM was last
// updated. These deltas are applied periodically to RAM (in which case the
// deltas are reset).
//
//
// To add registers to this block the following steps should be followed:
//   1. Add the register to the appropriate defines file
//   2. Create a new delta register. The delta register should hold the
//      changes since the previous update
//   3. Add code to update the delta register. This code should:
//        i) reset the delta register on reset
//       ii) set the delta register to the current input when the real
//           register in RAM is being updated (this is so that the update is
//           not lost)
//      iii) set the delta register to its current value + the input during
//           other cycles
//      eg.
//         if (reset)
//            tx_pkt_stored_delta <= 'h0;
//         else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_PKTS_ENQUEUED)
//            tx_pkt_stored_delta <= tx_pkt_stored;
//         else
//            tx_pkt_stored_delta <= tx_pkt_stored_delta + tx_pkt_stored;
//
//   4. Update the number of registers
//   5. Add a line to the case statement in the main state machine that
//      applies the delta when reg_cnt is at the correct address.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_queue_regs
   (
      // Register interface
      input                                  reg_req,
      input                                  reg_rd_wr_L,
      input  [`CPU_QUEUE_REG_ADDR_WIDTH-1:0] reg_addr,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_wr_data,

      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_rd_data,
      output reg                             reg_ack,

      // interface to rx queue
      output                                 rx_queue_en,
      input                                  rx_pkt_stored,
      input                                  rx_pkt_removed,
      input                                  rx_pkt_dropped,
      input                                  rx_q_overrun,
      input                                  rx_q_underrun,
      input  [11:0]                          rx_pkt_byte_cnt,
      input  [9:0]                           rx_pkt_word_cnt,


      // interface to tx queue
      output                                 tx_queue_en,
      input                                  tx_pkt_stored,
      input                                  tx_pkt_removed,
      input                                  tx_q_overrun,
      input                                  tx_q_underrun,
      input [11:0]                           tx_pkt_byte_cnt,
      input [9:0]                            tx_pkt_word_cnt,

      // --- Misc
      input                                  reset,
      input                                  clk
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

   // -------- Internal parameters --------------

   localparam NUM_REGS_USED         = 17; /* don't forget to update this when adding regs */
   localparam REG_FILE_ADDR_WIDTH   = log2(NUM_REGS_USED);
   //localparam REG_FILE_DEPTH        = 2 ** REG_FILE_ADDR_WIDTH;

   // Calculations for register sizes
   // -------------------------------
   //
   // A cycle is 16 clocks max
   //      (13 reg + 1 reg read/write < 16)
   //
   // Min packet size: is 8 words
   //
   // Max packets per period = 2  (16 / 8)

   // Word/byte count widths. Should support 2k packets -- i.e. up to 2048
   // bytes per packet
   //
   // Note: don't need to increase the size to allow for multiple packets
   // in a single cycle since we can't fit large packets in a single cycle
   localparam WORD_CNT_WIDTH  = 10; // 2^10 = 1024 [0..1023]
   localparam BYTE_CNT_WIDTH  = 12; // 2^12 = 4096 [0..4095]

   localparam DELTA_WIDTH = BYTE_CNT_WIDTH + 1;

   // States
   localparam RESET = 0;
   localparam NORMAL = 1;


   // ------------- Wires/reg ------------------

   // Register file and related registers
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file [0:NUM_REGS_USED-1];

   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file_in;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     reg_file_out;

   reg                                 reg_file_wr;
   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_file_addr;




   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg_nxt;

   wire [REG_FILE_ADDR_WIDTH-1:0]      addr;

   wire                                addr_good;

   reg [3:0]                           reset_long;

   reg                                 reg_req_d1;


   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_cnt;
   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_cnt_nxt;


   reg                                 state;
   reg                                 state_nxt;

   // Signals for temporarily storing the deltas for the registers
   reg [WORD_CNT_WIDTH-1:0]            rx_word_cnt_delta;
   reg [BYTE_CNT_WIDTH-1:0]            rx_byte_cnt_delta;

   reg [WORD_CNT_WIDTH-1:0]            tx_word_cnt_delta;
   reg [BYTE_CNT_WIDTH-1:0]            tx_byte_cnt_delta;

   // Can't receive multiple packets less than a single cycle
   reg                                 rx_pkt_dropped_bad_delta;
   reg                                 rx_pkt_stored_delta;

   // Can't send multiple packets in less than a single cycle
   reg                                 tx_pkt_removed_delta;

   reg [1:0]                           tx_pkt_stored_delta;

   reg [1:0]                           rx_pkt_removed_delta;

   reg [2:0]                           tx_queue_delta;
   reg [2:0]                           rx_queue_delta;

   // Overrun/underrun tracking
   reg [REG_FILE_ADDR_WIDTH-1:0]       tx_num_underruns_delta;
   reg [REG_FILE_ADDR_WIDTH-1:0]       tx_num_overruns_delta;

   reg [REG_FILE_ADDR_WIDTH-1:0]       rx_num_underruns_delta;
   reg [REG_FILE_ADDR_WIDTH-1:0]       rx_num_overruns_delta;

   wire                                new_reg_req;

   reg [DELTA_WIDTH-1:0]               delta;

   // -------------------------------------------
   // Register file RAM
   // -------------------------------------------

   always @(posedge clk) begin
      if (reg_file_wr)
         reg_file[reg_file_addr] <= reg_file_in;
   end

   assign reg_file_out = reg_file[reg_file_addr];


   // -------------- Logic --------------------

   // Track the deltas
   //
   // These are committed later to the register file
   always @(posedge clk) begin
      if (reset)
         rx_pkt_dropped_bad_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_PKTS_DROPPED_BAD)
         rx_pkt_dropped_bad_delta <= rx_pkt_dropped;
      else
         rx_pkt_dropped_bad_delta <= rx_pkt_dropped_bad_delta  || rx_pkt_dropped;


      if (reset)
         rx_pkt_stored_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_PKTS_ENQUEUED )
         rx_pkt_stored_delta <= rx_pkt_stored;
      else
         rx_pkt_stored_delta <= rx_pkt_stored_delta  || rx_pkt_stored;


      if (reset)
         rx_word_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_WORDS_PUSHED)
         rx_word_cnt_delta <= rx_pkt_removed ? rx_pkt_word_cnt : 'h0;
      else if (rx_pkt_removed)
         rx_word_cnt_delta <= rx_word_cnt_delta + rx_pkt_word_cnt;


      if (reset)
         rx_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_BYTES_PUSHED)
         rx_byte_cnt_delta <= rx_pkt_removed ? rx_pkt_byte_cnt : 'h0;
      else if (rx_pkt_removed)
         rx_byte_cnt_delta <= rx_byte_cnt_delta + rx_pkt_byte_cnt;


      if (reset)
         tx_pkt_removed_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_PKTS_DEQUEUED)
         tx_pkt_removed_delta <= tx_pkt_removed;
      else
         tx_pkt_removed_delta <= tx_pkt_removed_delta  || tx_pkt_removed;


      if (reset)
         tx_word_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_WORDS_PUSHED)
         tx_word_cnt_delta <= tx_pkt_stored ? tx_pkt_word_cnt : 'h0;
      else if (tx_pkt_stored)
         tx_word_cnt_delta <= tx_word_cnt_delta + tx_pkt_word_cnt;


      if (reset)
         tx_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_BYTES_PUSHED)
         tx_byte_cnt_delta <= tx_pkt_stored ? tx_pkt_byte_cnt : 'h0;
      else if (tx_pkt_stored)
         tx_byte_cnt_delta <= tx_byte_cnt_delta + tx_pkt_byte_cnt;


      if (reset)
         tx_queue_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_PKTS_IN_QUEUE) begin
         case({tx_pkt_removed, tx_pkt_stored})
            2'b01 : tx_queue_delta <= 'h1;
            2'b10 : tx_queue_delta <= - 'h1;
            default : tx_queue_delta <= 'h0;
         endcase
      end
      else begin
         case({tx_pkt_removed, tx_pkt_stored})
            2'b01 : tx_queue_delta <= tx_queue_delta + 'h1;
            2'b10 : tx_queue_delta <= tx_queue_delta - 'h1;
            default : tx_queue_delta <= tx_queue_delta;
         endcase
      end


      if (reset)
         tx_pkt_stored_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_PKTS_ENQUEUED)
         tx_pkt_stored_delta <= tx_pkt_stored;
      else
         tx_pkt_stored_delta <= tx_pkt_stored_delta + tx_pkt_stored;


      if (reset)
         rx_pkt_removed_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_PKTS_DEQUEUED)
         rx_pkt_removed_delta <= rx_pkt_removed;
      else
         rx_pkt_removed_delta <= rx_pkt_removed_delta + rx_pkt_removed;


      if (reset)
         rx_num_underruns_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_UNDERRUNS)
         rx_num_underruns_delta <= rx_q_underrun;
      else
         rx_num_underruns_delta <= rx_num_underruns_delta + rx_q_underrun;


      if (reset)
         rx_num_overruns_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_OVERRUNS)
         rx_num_overruns_delta <= rx_q_overrun;
      else
         rx_num_overruns_delta <= rx_num_overruns_delta + rx_q_overrun;


      if (reset)
         rx_queue_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_RX_QUEUE_NUM_PKTS_IN_QUEUE) begin
         case ({rx_pkt_removed, rx_pkt_stored})
            2'b01 : rx_queue_delta <= 'h1;
            2'b10 : rx_queue_delta <= - 'h1;
            default : rx_queue_delta <= 'h0;
         endcase
      end
      else begin
         case ({rx_pkt_removed, rx_pkt_stored})
            2'b01 : rx_queue_delta <= rx_queue_delta + 'h1;
            2'b10 : rx_queue_delta <= rx_queue_delta - 'h1;
            default : rx_queue_delta <= rx_queue_delta;
         endcase
      end

      if (reset)
         tx_num_underruns_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_UNDERRUNS)
         tx_num_underruns_delta <= tx_q_underrun;
      else
         tx_num_underruns_delta <= tx_num_underruns_delta + tx_q_underrun;


      if (reset)
         tx_num_overruns_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `CPU_QUEUE_TX_QUEUE_NUM_OVERRUNS)
         tx_num_overruns_delta <= tx_q_overrun;
      else
         tx_num_overruns_delta <= tx_num_overruns_delta + tx_q_overrun;

   end // always block for delta logic

   /* extend the reset */
   always @(posedge clk) begin
      /*if (reset) reset_long <= 4'hf;
      else reset_long <= {reset_long[2:0], 1'b0};*/
      reset_long <= {reset_long[2:0], reset};
   end

   //assign control_reg = reg_file[`CPU_QUEUE_CONTROL];
   assign rx_queue_en         = !control_reg[`CPU_QUEUE_CONTROL_RX_QUEUE_DISABLE_POS];
   assign tx_queue_en         = !control_reg[`CPU_QUEUE_CONTROL_TX_QUEUE_DISABLE_POS];

   assign addr                = reg_addr[REG_FILE_ADDR_WIDTH-1:0];
   assign addr_good           = reg_addr[`CPU_QUEUE_REG_ADDR_WIDTH-1:REG_FILE_ADDR_WIDTH] == 'h0 &&
                                          addr < NUM_REGS_USED;

   assign new_reg_req         = reg_req && !reg_req_d1;

   always @*
   begin
      // Set the defaults
      state_nxt = state;
      control_reg_nxt = control_reg;
      reg_file_in = reg_file_out;
      reg_cnt_nxt = reg_cnt;
      reg_file_addr = 'h0;
      reg_file_wr = 1'b0;
      delta = 1'b0;


      if (reset) begin
         state_nxt = RESET;
         reg_cnt_nxt = 'h0;
         reg_file_in = 'h0;
         reg_file_addr = 'h0;
         control_reg_nxt = 'h0;
      end
      else begin
         case (state)
            RESET : begin
               if (reg_cnt == NUM_REGS_USED - 1) begin
                  state_nxt = NORMAL;
                  reg_cnt_nxt = 'h0;
               end
               else
                  reg_cnt_nxt = reg_cnt + 'h1;

               reg_file_in = 'h0;
               reg_file_wr = 1'b1;
               reg_file_addr = reg_cnt;
            end

            NORMAL : begin
               if(new_reg_req) begin // read request
                  reg_file_addr = addr;
                  reg_file_wr = addr_good && !reg_rd_wr_L;
                  reg_file_in = reg_wr_data;

                  if (addr == `CPU_QUEUE_CONTROL) begin
                     if (!reg_rd_wr_L)
                        control_reg_nxt = reg_wr_data;
                  end
                  // The following code does reset on read
                  //
                  //reg_file_wr = addr_good;

                  //if (addr == `CPU_QUEUE_CONTROL) begin
                  //   if (reg_rd_wr_L)
                  //      reg_file_in = reg_file_out;
                  //   else begin
                  //      reg_file_in = reg_wr_data;
                  //      control_reg_nxt = reg_wr_data;
                  //   end
                  //end
                  //else
                  //   reg_file_in = 'h0;
               end
               else begin
                  reg_file_wr = 1'b1;
                  reg_file_addr = reg_cnt;

                  if (reg_cnt == NUM_REGS_USED - 1)
                     reg_cnt_nxt = 'h0;
                  else
                     reg_cnt_nxt = reg_cnt + 'h1;

                  case (reg_cnt)
                     `CPU_QUEUE_CONTROL :                        delta = 0;
                     `CPU_QUEUE_RX_QUEUE_NUM_PKTS_ENQUEUED :     delta = rx_pkt_stored_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_PKTS_DEQUEUED :     delta = rx_pkt_removed_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_PKTS_DROPPED_BAD :  delta = rx_pkt_dropped_bad_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_UNDERRUNS :         delta = rx_num_underruns_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_OVERRUNS :          delta = rx_num_overruns_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_WORDS_PUSHED :      delta = rx_word_cnt_delta;
                     `CPU_QUEUE_RX_QUEUE_NUM_BYTES_PUSHED :      delta = rx_byte_cnt_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_PKTS_ENQUEUED :     delta = tx_pkt_stored_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_PKTS_DEQUEUED :     delta = tx_pkt_removed_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_WORDS_PUSHED :      delta = tx_word_cnt_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_BYTES_PUSHED :      delta = tx_byte_cnt_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_UNDERRUNS :         delta = tx_num_underruns_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_OVERRUNS :          delta = tx_num_overruns_delta;
                     `CPU_QUEUE_TX_QUEUE_NUM_PKTS_IN_QUEUE :     delta = {{(DELTA_WIDTH - 3){tx_queue_delta[2]}}, tx_queue_delta};
                     `CPU_QUEUE_RX_QUEUE_NUM_PKTS_IN_QUEUE :     delta = {{(DELTA_WIDTH - 3){rx_queue_delta[2]}}, rx_queue_delta};
                     default :                                  delta = 0;
                  endcase // case (reg_cnt)

                  reg_file_in = reg_file_out + {{(`CPCI_NF2_DATA_WIDTH - DELTA_WIDTH){delta[DELTA_WIDTH-1]}}, delta};
               end // if () else
            end // NORMAL

         endcase // case (state)
      end
   end

   always @(posedge clk) begin
      state       <= state_nxt;
      reg_cnt     <= reg_cnt_nxt;
      reg_req_d1  <= reg_req;
      control_reg <= control_reg_nxt;

      if( reset ) begin
         reg_rd_data  <= 0;
         reg_ack      <= 0;
      end
      else begin
         // Register access logic
         if(new_reg_req) begin // read request
            if(addr_good) begin
               if (addr == `CPU_QUEUE_CONTROL)
                  reg_rd_data <= control_reg;
               else
                  reg_rd_data <= reg_file_out;
            end
            else begin
               reg_rd_data <= 32'hdead_beef;
            end
         end

         // requests complete after one cycle
         reg_ack <= new_reg_req;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // cpu_dma_queue_regs
