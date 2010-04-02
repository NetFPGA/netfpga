///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: mac_grp_regs.v 5374 2009-04-28 18:21:20Z g9coving $
//
// Module: mac_grp_hdr_regs.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
// Note: only works when the ENABLE_HEADER option is set
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
//         else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_PKTS_ENQUEUED)
//            tx_pkt_stored_delta <= tx_pkt_stored;
//         else
//            tx_pkt_stored_delta <= tx_pkt_stored_delta + tx_pkt_stored;
//
//   4. Update the number of registers
//   5. Add a line to the case statement in the main state machine that
//      applies the delta when reg_cnt is at the correct address.
//
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module mac_grp_regs
   #( parameter CTRL_WIDTH = 8 )

   ( input                                mac_grp_reg_req,
     input                                mac_grp_reg_rd_wr_L,
     input  [`MAC_GRP_REG_ADDR_WIDTH-1:0] mac_grp_reg_addr,
     input  [`CPCI_NF2_DATA_WIDTH-1:0]    mac_grp_reg_wr_data,

     output reg [`CPCI_NF2_DATA_WIDTH-1:0] mac_grp_reg_rd_data,
     output reg                           mac_grp_reg_ack,

     // interface to mac controller
     output                               reset_MAC,
     output                               disable_crc_check,
     output                               disable_crc_gen,
     output                               enable_jumbo_rx,
     output                               enable_jumbo_tx,
     output                               rx_mac_en,
     output                               tx_mac_en,

     // interface to rx queue
     input                                rx_pkt_good,
     input                                rx_pkt_bad,
     input                                rx_pkt_dropped,
     input  [11:0]                        rx_pkt_byte_cnt,
     input  [9:0]                         rx_pkt_word_cnt,
     input                                rx_pkt_pulled,

     output                               rx_queue_en,

     // interface to tx queue
     output                               tx_queue_en,
     input                                tx_pkt_sent,
     input                                tx_pkt_stored,
     input [11:0]                         tx_pkt_byte_cnt,
     input [9:0]                          tx_pkt_word_cnt,

     input                                clk,
     input                                reset
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
   localparam NUM_REGS_USED         = 13; /* don't forget to update this when adding regs */
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

   reg                                 mac_grp_reg_req_d1;


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
   reg                                 rx_pkt_dropped_full_delta;
   reg                                 rx_pkt_dropped_bad_delta;
   reg                                 rx_pkt_stored_delta;

   // Can't send multiple packets in less than a single cycle
   reg                                 tx_pkt_sent_delta;

   reg [1:0]                           tx_pkt_stored_delta;

   reg [1:0]                           rx_pkt_pulled_delta;

   reg [2:0]                           tx_queue_delta;
   reg [2:0]                           rx_queue_delta;


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
         rx_pkt_dropped_full_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_FULL)
         rx_pkt_dropped_full_delta <= rx_pkt_dropped;
      else
         rx_pkt_dropped_full_delta <= rx_pkt_dropped_full_delta  || rx_pkt_dropped;


      if (reset)
         rx_pkt_dropped_bad_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_BAD)
         rx_pkt_dropped_bad_delta <= rx_pkt_bad;
      else
         rx_pkt_dropped_bad_delta <= rx_pkt_dropped_bad_delta  || rx_pkt_bad;


      if (reset)
         rx_pkt_stored_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_PKTS_STORED )
         rx_pkt_stored_delta <= rx_pkt_good;
      else
         rx_pkt_stored_delta <= rx_pkt_stored_delta  || rx_pkt_good;


      if (reset)
         rx_word_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_WORDS_PUSHED)
         rx_word_cnt_delta <= rx_pkt_pulled ? rx_pkt_word_cnt : 'h0;
      else if (rx_pkt_pulled)
         rx_word_cnt_delta <= rx_word_cnt_delta + rx_pkt_word_cnt;


      if (reset)
         rx_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_BYTES_PUSHED)
         rx_byte_cnt_delta <= rx_pkt_pulled ? rx_pkt_byte_cnt : 'h0;
      else if (rx_pkt_pulled)
         rx_byte_cnt_delta <= rx_byte_cnt_delta + rx_pkt_byte_cnt;


      if (reset)
         tx_pkt_sent_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_PKTS_SENT)
         tx_pkt_sent_delta <= tx_pkt_sent;
      else
         tx_pkt_sent_delta <= tx_pkt_sent_delta  || tx_pkt_sent;


      if (reset)
         tx_word_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_WORDS_PUSHED)
         tx_word_cnt_delta <= tx_pkt_stored ? tx_pkt_word_cnt : 'h0;
      else if (tx_pkt_stored)
         tx_word_cnt_delta <= tx_word_cnt_delta + tx_pkt_word_cnt;


      if (reset)
         tx_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_BYTES_PUSHED)
         tx_byte_cnt_delta <= tx_pkt_stored ? tx_pkt_byte_cnt : 'h0;
      else if (tx_pkt_stored)
         tx_byte_cnt_delta <= tx_byte_cnt_delta + tx_pkt_byte_cnt;


      if (reset)
         tx_queue_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_PKTS_IN_QUEUE) begin
         case({tx_pkt_sent, tx_pkt_stored})
            2'b01 : tx_queue_delta <= 'h1;
            2'b10 : tx_queue_delta <= - 'h1;
            default : tx_queue_delta <= 'h0;
         endcase
      end
      else begin
         case({tx_pkt_sent, tx_pkt_stored})
            2'b01 : tx_queue_delta <= tx_queue_delta + 'h1;
            2'b10 : tx_queue_delta <= tx_queue_delta - 'h1;
            default : tx_queue_delta <= tx_queue_delta;
         endcase
      end


      if (reset)
         tx_pkt_stored_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_TX_QUEUE_NUM_PKTS_ENQUEUED)
         tx_pkt_stored_delta <= tx_pkt_stored;
      else
         tx_pkt_stored_delta <= tx_pkt_stored_delta + tx_pkt_stored;


      if (reset)
         rx_pkt_pulled_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_PKTS_DEQUEUED)
         rx_pkt_pulled_delta <= rx_pkt_pulled;
      else
         rx_pkt_pulled_delta <= rx_pkt_pulled_delta + rx_pkt_pulled;


      if (reset)
         rx_queue_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `MAC_GRP_RX_QUEUE_NUM_PKTS_IN_QUEUE) begin
         case ({rx_pkt_pulled, rx_pkt_good})
            2'b01 : rx_queue_delta <= 'h1;
            2'b10 : rx_queue_delta <= - 'h1;
            default : rx_queue_delta <= 'h0;
         endcase
      end
      else begin
         case ({rx_pkt_pulled, rx_pkt_good})
            2'b01 : rx_queue_delta <= rx_queue_delta + 'h1;
            2'b10 : rx_queue_delta <= rx_queue_delta - 'h1;
            default : rx_queue_delta <= rx_queue_delta;
         endcase
      end
   end // always block for delta logic

   /* extend the reset */
   always @(posedge clk) begin
      /*if (reset) reset_long <= 4'hf;
      else reset_long <= {reset_long[2:0], 1'b0};*/
      reset_long <= {reset_long[2:0], reset};
   end

   //assign control_reg = reg_file[`MAC_GRP_CONTROL];
   assign rx_queue_en         = !control_reg[`MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM];
   assign tx_queue_en         = !control_reg[`MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM];
   assign reset_MAC           = control_reg[`MAC_GRP_RESET_MAC_BIT_NUM] | (|reset_long);
   assign enable_jumbo_tx     = !control_reg[`MAC_GRP_MAC_DIS_JUMBO_TX_BIT_NUM];
   assign enable_jumbo_rx     = !control_reg[`MAC_GRP_MAC_DIS_JUMBO_RX_BIT_NUM];
   assign disable_crc_check   = control_reg[`MAC_GRP_MAC_DIS_CRC_CHECK_BIT_NUM];
   assign disable_crc_gen     = control_reg[`MAC_GRP_MAC_DIS_CRC_GEN_BIT_NUM];
   assign rx_mac_en           = !control_reg[`MAC_GRP_MAC_DISABLE_RX_BIT_NUM];
   assign tx_mac_en           = !control_reg[`MAC_GRP_MAC_DISABLE_TX_BIT_NUM];

   assign addr                = mac_grp_reg_addr[REG_FILE_ADDR_WIDTH-1:0];
   assign addr_good           = mac_grp_reg_addr[`MAC_GRP_REG_ADDR_WIDTH-1:REG_FILE_ADDR_WIDTH] == 'h0 &&
                                          addr < NUM_REGS_USED;

   assign new_reg_req         = mac_grp_reg_req && !mac_grp_reg_req_d1;

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
                  reg_file_wr = addr_good && !mac_grp_reg_rd_wr_L;
                  reg_file_in = mac_grp_reg_wr_data;

                  if (addr == `MAC_GRP_CONTROL) begin
                     if (!mac_grp_reg_rd_wr_L)
                        control_reg_nxt = mac_grp_reg_wr_data;
                  end
                  // The following code does reset on read
                  //
                  //reg_file_wr = addr_good;

                  //if (addr == `MAC_GRP_CONTROL) begin
                  //   if (mac_grp_reg_rd_wr_L)
                  //      reg_file_in = reg_file_out;
                  //   else begin
                  //      reg_file_in = mac_grp_reg_wr_data;
                  //      control_reg_nxt = mac_grp_reg_wr_data;
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
                     `MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_FULL : delta = rx_pkt_dropped_full_delta;
                     `MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_BAD :  delta = rx_pkt_dropped_bad_delta;
                     `MAC_GRP_RX_QUEUE_NUM_PKTS_STORED :       delta = rx_pkt_stored_delta;
                     `MAC_GRP_RX_QUEUE_NUM_WORDS_PUSHED :      delta = rx_word_cnt_delta;
                     `MAC_GRP_RX_QUEUE_NUM_BYTES_PUSHED :      delta = rx_byte_cnt_delta;
                     `MAC_GRP_TX_QUEUE_NUM_PKTS_SENT :         delta = tx_pkt_sent_delta;
                     `MAC_GRP_TX_QUEUE_NUM_WORDS_PUSHED :      delta = tx_word_cnt_delta;
                     `MAC_GRP_TX_QUEUE_NUM_BYTES_PUSHED :      delta = tx_byte_cnt_delta;
                     `MAC_GRP_CONTROL :                        delta = 0;
                     `MAC_GRP_TX_QUEUE_NUM_PKTS_IN_QUEUE :     delta = {{(DELTA_WIDTH - 3){tx_queue_delta[2]}}, tx_queue_delta};
                     `MAC_GRP_TX_QUEUE_NUM_PKTS_ENQUEUED :     delta = tx_pkt_stored_delta;
                     `MAC_GRP_RX_QUEUE_NUM_PKTS_DEQUEUED :     delta = rx_pkt_pulled_delta;
                     `MAC_GRP_RX_QUEUE_NUM_PKTS_IN_QUEUE :     delta = {{(DELTA_WIDTH - 3){rx_queue_delta[2]}}, rx_queue_delta};
                     default :                                 delta = 0;
                  endcase // case (reg_cnt)

                  reg_file_in = reg_file_out + {{(`CPCI_NF2_DATA_WIDTH - DELTA_WIDTH){delta[DELTA_WIDTH-1]}}, delta};
               end // if () else
            end // NORMAL

         endcase // case (state)
      end
   end

   always @(posedge clk) begin
      state                 <= state_nxt;
      reg_cnt               <= reg_cnt_nxt;
      mac_grp_reg_req_d1    <= mac_grp_reg_req;
      control_reg           <= control_reg_nxt;

      if( reset ) begin
         mac_grp_reg_rd_data  <= 0;
         mac_grp_reg_ack      <= 0;
      end
      else begin
         // Register access logic
         if(new_reg_req) begin // read request
            if(addr_good) begin
               mac_grp_reg_rd_data <= reg_file_out;
            end
            else begin
               mac_grp_reg_rd_data <= 32'hdead_beef;
            end
         end

         // requests complete after one cycle
         mac_grp_reg_ack <= new_reg_req;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // mac_grp_hdr_regs
