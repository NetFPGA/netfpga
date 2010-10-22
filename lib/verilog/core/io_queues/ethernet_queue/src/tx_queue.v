///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: tx_queue.v 2080 2007-08-02 17:19:29Z grg $
//
// Module: tx_queue.v
// Project: NF2.1
// Description: Instantiates the speed matching FIFO that accepts
//              packets from the core and sends it to the MAC
//
// On the read side is the 125/12.5/1.25MHz MAC clock which reads
// data 9 bits wide from the fifo (bit 8 is EOP).
//
///////////////////////////////////////////////////////////////////////////////

module tx_queue
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter ENABLE_HEADER = 0,
      parameter STAGE_NUMBER = 'hff
   )

   (input  [DATA_WIDTH-1:0]              in_data,
    input  [CTRL_WIDTH-1:0]              in_ctrl,
    input                                in_wr,
    output                               in_rdy,

    // --- MAC side signals (txcoreclk domain)

    input                                gmac_tx_ack,
    output reg                           gmac_tx_dvld,
    output [7:0]                         gmac_tx_data,

    // --- Register interface
    input                                tx_queue_en,
    output                               tx_pkt_sent,
    output reg                           tx_pkt_stored,
    output reg [11:0]                    tx_pkt_byte_cnt,
    output reg [9:0]                     tx_pkt_word_cnt,

    // --- Misc

    input                                reset,
    input                                clk,
    input                                txcoreclk
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

   // ------------ Internal Params --------
   parameter NUM_BITS_BYTE_CNT  = log2(CTRL_WIDTH);

   // read state machine states (one-hot)
   parameter IDLE = 1;
   parameter WAIT_FOR_ACK = 2;
   parameter WAIT_FOR_EOP = 4;
   parameter WAIT_FOR_BYTE_COUNT = 8;
   parameter TX_DONE = 16;

   // Number of packets waiting:
   //
   // 4096 / 64 = 64 = 2**6
   //
   // so, need 7 bits to represent the number of packets waiting
   localparam NUM_PKTS_WAITING_WIDTH = 7;

   // ------------- Regs/ wires -----------

   wire [DATA_WIDTH+CTRL_WIDTH-1:0] arranged_din;
   wire                             eop;
   reg                              tx_fifo_rd_en;
   wire                             tx_fifo_empty;
   wire                             tx_fifo_almost_full;

   reg                              reset_txclk;

   reg                              pkt_sent_txclk; // pulses when a packet has been removed
   reg [NUM_BITS_BYTE_CNT-1:0]      byte_count;     // keeps track of the bytes to take out padding
   reg                              byte_count_ld;
   reg                              byte_count_en;
   reg [4:0]                        tx_mac_state_nxt, tx_mac_state;
   reg                              gmac_tx_dvld_nxt;

   reg                              tx_queue_en_txclk;
   reg                              tx_queue_en_sync;
   // synthesis attribute ASYNC_REG of tx_queue_en_sync is TRUE;

   reg [NUM_PKTS_WAITING_WIDTH-1:0] txf_num_pkts_waiting;
   wire                             txf_pkts_avail;

   wire                             txfifo_wr;

   // ------------ Modules -------------

   /* pkts removed from the output queues are buffered here
    * before going to the MAC. The size is chosen so that
    * we can fit 2 max sized pkts. This allows us to operate at line speed.
    * If we start with a full fifo, by the time the 1st pkt is read,
    * a new pkt is already available.*/
   generate
   if(DATA_WIDTH==32) begin: tx_fifo_32
      txfifo_1024x36_to_9 gmac_tx_fifo
        (
         .din(arranged_din),
         .wr_en(txfifo_wr),
         .wr_clk(clk),

         .dout({eop,gmac_tx_data}),
         .rd_en(tx_fifo_rd_en),
         .rd_clk(txcoreclk),

         .empty(tx_fifo_empty),
         .full(),
         .almost_full(tx_fifo_almost_full),
         .rst(reset)
         );
   end
   else if(DATA_WIDTH==64) begin: tx_fifo_64
      txfifo_512x72_to_9 gmac_tx_fifo
        (
         .din(arranged_din),
         .wr_en(txfifo_wr),
         .wr_clk(clk),

         .dout({eop,gmac_tx_data}),
         .rd_en(tx_fifo_rd_en),
         .rd_clk(txcoreclk),

         .empty(tx_fifo_empty),
         .full(),
         .almost_full(tx_fifo_almost_full),
         .rst(reset)
         );
   end
   endgenerate

   /* these modules move pulses from one clk domain to the other */
   pulse_synchronizer tx_pkt_stored_sync
     (.pulse_in_clkA (tx_pkt_stored),
      .clkA          (clk),
      .pulse_out_clkB(pkt_stored_txclk),
      .clkB          (txcoreclk),
      .reset_clkA    (reset),
      .reset_clkB    (reset_txclk));

   pulse_synchronizer tx_pkt_sent_sync
     (.pulse_in_clkA (pkt_sent_txclk),
      .clkA          (txcoreclk),
      .pulse_out_clkB(tx_pkt_sent),
      .clkB          (clk),
      .reset_clkA    (reset_txclk),
      .reset_clkB    (reset));

   // ------------- Logic ------------

   // extend reset over to MAC domain
   reg reset_long;
   // synthesis attribute ASYNC_REG of reset_long is TRUE ;
   always @(posedge clk) begin
      if (reset) reset_long <= 1;
      else if (reset_txclk) reset_long <= 0;
   end
   always @(posedge txcoreclk) reset_txclk <= reset_long;

   //
   //------ Following is in core clock domain (62MHz/125 MHz)
   //

   // Generate the txfifo_wr signal
   //
   // If there are no headers coming this is just the write signal
   //
   // If there could be headers coming in then we need to drop the headers.
   //   - control bits at beginning of the packet == header
   //   - no control bits set == data
   //   - control bit set at end of packet == data
   generate
      if (ENABLE_HEADER) begin
         reg in_pkt;

         // Work out whether we're in a packet or not
         always @(posedge clk) begin
            if (reset)
               in_pkt <= 1'b0;
            else if (in_wr) begin
               if (in_pkt && |in_ctrl)
                  in_pkt <= 1'b0;
               else if (!in_pkt && !(|in_ctrl))
                  in_pkt <= 1'b1;
            end
         end

         assign txfifo_wr = in_wr && (!(|in_ctrl) || in_pkt);

         always @(posedge clk) begin
            tx_pkt_stored <= reset ? 0 : in_wr && (|in_ctrl) && in_pkt;

            if (reset) begin
               tx_pkt_byte_cnt <= 'h0;
               tx_pkt_word_cnt <= 'h0;
            end
            else if (in_wr && !in_pkt) begin
               if (in_ctrl == STAGE_NUMBER) begin
                  tx_pkt_byte_cnt <= in_data[`IOQ_BYTE_LEN_POS +: 16];
                  tx_pkt_word_cnt <= in_data[`IOQ_WORD_LEN_POS +: 16];
               end
            end
         end

      end // if (ENABLE_HEADER)
      else begin

         assign txfifo_wr = in_wr;

         always @(posedge clk) begin
            tx_pkt_stored <= reset ? 0 : in_wr && (|in_ctrl);
         end

         initial
         begin
            tx_pkt_byte_cnt = 'h0;
            tx_pkt_word_cnt = 'h0;
         end

      end // if (ENABLE_HEADER) else
   endgenerate

   assign in_rdy = ~tx_fifo_almost_full;

   /* we have to combine the ctrl bits with the data
    */
   generate
   genvar i;
   for (i=0; i<CTRL_WIDTH; i=i+1)
     begin: swap_dout
        assign arranged_din[i*9+8:i*9] = {in_ctrl[i], in_data[i*8+7:i*8]};
     end
   endgenerate

   //
   //------ Following is in MAC clock domain (125MHz/12.5Mhz/1.25Mhz) -----------
   //

   // sync the enable signal from the core to the tx clock domains
   always @(posedge txcoreclk) begin
      if(reset_txclk) begin
         tx_queue_en_sync    <= 0;
         tx_queue_en_txclk   <= 0;
      end
      else begin
         tx_queue_en_sync    <= tx_queue_en;
         tx_queue_en_txclk   <= tx_queue_en_sync;
      end // else: !if(reset_txclk)
   end // always @ (posedge txcoreclk)

   assign  txf_pkts_avail = (txf_num_pkts_waiting != 'h0);

   //
   // ------ BEGIN STATE MACHINE
   //
   always @* begin
      // set defaults
      tx_mac_state_nxt = tx_mac_state;
      gmac_tx_dvld_nxt = 0;
      tx_fifo_rd_en = 0;
      byte_count_ld = 0;
      byte_count_en = 0;
      pkt_sent_txclk = 0;

      case (tx_mac_state)

        IDLE: if (txf_pkts_avail & !tx_fifo_empty & tx_queue_en_txclk) begin
           tx_fifo_rd_en = 1;   // this will make DOUT of FIFO valid after the NEXT clock
           gmac_tx_dvld_nxt = 1;
           tx_mac_state_nxt = WAIT_FOR_ACK;
           byte_count_ld = 1;
        end

        WAIT_FOR_ACK: begin
           gmac_tx_dvld_nxt = 1;
           if (gmac_tx_ack) begin   // now provide the rest of the packet
              tx_fifo_rd_en = 1;
              gmac_tx_dvld_nxt = 1;
              byte_count_en = 1;
              tx_mac_state_nxt = WAIT_FOR_EOP;
           end
        end

        WAIT_FOR_EOP: begin
           if (eop) begin
              if (&byte_count) begin // the last data byte was the last of the word so we are done.
                 tx_mac_state_nxt = IDLE;
                 pkt_sent_txclk = 1;
              end
              else begin // need to keep reading until we have read last of the word
                 tx_fifo_rd_en = 1;
                 byte_count_en = 1;
                 tx_mac_state_nxt = WAIT_FOR_BYTE_COUNT;
              end
           end // if (eop)
           else begin // Not EOP - keep reading!
              tx_fifo_rd_en = 1;
              gmac_tx_dvld_nxt = 1;
              byte_count_en = 1;
           end
        end

        WAIT_FOR_BYTE_COUNT: begin
           if (&byte_count) begin
              tx_mac_state_nxt = IDLE;
              pkt_sent_txclk = 1;
           end
           else begin // need to keep reading until we have read last byte of the word
              tx_fifo_rd_en = 1;
              byte_count_en = 1;
           end
        end

        default: begin // synthesis translate_off
          if (!reset && $time > 4000) $display("%t ERROR: (%m) state machine in illegal state 0x%x",
                   $time, tx_mac_state);
           // synthesis translate_on
        end

      endcase // case(tx_mac_state)

   end // always @ *

   //
   // ------ END STATE MACHINE
   //

   // update sequential elements
   always @(posedge txcoreclk) begin
      if (reset_txclk) begin
         txf_num_pkts_waiting <= 'h0;
         tx_mac_state <= IDLE;
         gmac_tx_dvld <= 0;
      end
      else begin
         case ({pkt_sent_txclk, pkt_stored_txclk})
           2'b01 : txf_num_pkts_waiting <= txf_num_pkts_waiting + 1;
           2'b10 : txf_num_pkts_waiting <= txf_num_pkts_waiting - 1;
           default: begin end
         endcase
         tx_mac_state <= tx_mac_state_nxt;
         gmac_tx_dvld <= gmac_tx_dvld_nxt;
      end
   end // always @ (posedge txcoreclk)

   // byte counter.
   always @(posedge txcoreclk)
     if ( reset_txclk | byte_count_ld ) byte_count <= 0;
     else if ( byte_count_en )    byte_count <= byte_count + 1;

   // synthesis translate_off
   integer total_byte_count;
   always @(posedge txcoreclk)
     if ( reset_txclk | byte_count_ld ) total_byte_count <= 0;
     else if ( byte_count_en )    total_byte_count <= total_byte_count + 1;
   // synthesis translate_on

endmodule // tx_queue
