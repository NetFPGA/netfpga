///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_main.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: cpu_dma_rx_queue.v
// Project: NF2.1
// Description: Receive queue for CPU DMA queue
//
//              A slim CPU rx_fifo connecting to the DMA interface.
//              FIFO is first-word-fall-through.
//
//              Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
// Note (1): Receive is relative to the NetFPGA -- this is, receive represents
// transfers from the host to the NetFPGA.
//
// Note (2): A watchdog is included to monitor the state of the TX queue to
// ensure that permanent lockup never occurs.
//
// A watchdog timer starts whenever data is written to the TX fifo. (The timer
// is reset on every write.) If the timer expires and the fifo is non-empty
// but has zero complete packets then the fifo is reset.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_rx_queue
   #(
      parameter DATA_WIDTH       = 64,
      parameter CTRL_WIDTH       = DATA_WIDTH/8,
      parameter ENABLE_HEADER    = 0,
      parameter STAGE_NUMBER     = 'hff,
      parameter DMA_DATA_WIDTH   = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH   = DMA_DATA_WIDTH/8,
      parameter RX_WATCHDOG_TIMEOUT = 125000,
      parameter PORT_NUMBER      = 0
   )
   (
      output reg [DATA_WIDTH-1:0]   out_data,
      output reg [CTRL_WIDTH-1:0]   out_ctrl,
      output reg                    out_wr,
      input                         out_rdy,

      // DMA wr txfifo interface
      output reg                    cpu_q_dma_nearly_full,

      input                         cpu_q_dma_wr,
      input [DMA_DATA_WIDTH-1:0]    cpu_q_dma_wr_data,
      input [DMA_CTRL_WIDTH-1:0]    cpu_q_dma_wr_ctrl,

      // Register interface -- RX
      input                         rx_queue_en,
      output  reg                   rx_pkt_stored,
      output                        rx_pkt_dropped,
      output  reg                   rx_pkt_removed,
      output  reg                   rx_q_underrun,
      output  reg                   rx_q_overrun,
      output  reg                   rx_timeout,
      output  reg [11:0]            rx_pkt_byte_cnt,
      output  reg [9:0]             rx_pkt_word_cnt,

      // --- Misc
      input                         reset,
      input                         clk
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

   parameter RX_WATCHDOG_TIMER_WIDTH = log2(RX_WATCHDOG_TIMEOUT);

   localparam MAX_PKT_SIZE             = 2048;

   localparam LAST_WORD_BYTE_CNT_WIDTH = log2(CTRL_WIDTH);
   localparam PKT_BYTE_CNT_WIDTH       = log2(MAX_PKT_SIZE)+1;
   localparam PKT_WORD_CNT_WIDTH       = PKT_BYTE_CNT_WIDTH - LAST_WORD_BYTE_CNT_WIDTH;

   // ------------- Wires/reg ------------------

   reg [5:0]                           num_pkts_in_q; //the max count of pkts is 35.

   reg                                 input_in_pkt;
   reg                                 output_in_pkt;
   reg                                 output_in_pkt_nxt;

   reg                                 rx_fifo_rd_en;
   wire                                rx_fifo_wr_en;

   // wires from rx_fifo
   wire [8:0] 			       rx_fifo_wr_data_count;
   wire                                rx_fifo_full;
   wire                                rx_fifo_almost_full;
   wire                                rx_fifo_empty;

   // tx watchdog signals
   reg [RX_WATCHDOG_TIMER_WIDTH-1:0]   rx_watchdog_timer;

   wire [DATA_WIDTH-1:0]               out_data_local;
   wire [CTRL_WIDTH-1:0]               out_ctrl_local;

   reg [PKT_BYTE_CNT_WIDTH-1:0]        num_bytes_written;

   wire [PKT_BYTE_CNT_WIDTH-1:0]       pkt_byte_len_out;
   wire [PKT_WORD_CNT_WIDTH-1:0]       pkt_word_len_out;

   wire [`IOQ_WORD_LEN_POS - `IOQ_SRC_PORT_POS-1:0] port_number = PORT_NUMBER;

   wire [DMA_DATA_WIDTH-1:0]           rx_fifo_data_in;
   wire [DMA_CTRL_WIDTH-1:0]           rx_fifo_ctrl_in;

   wire [PKT_WORD_CNT_WIDTH-1:0]       rx_pkt_word_cnt_nxt;

   reg [DATA_WIDTH-1:0]                out_data_nxt;
   reg [CTRL_WIDTH-1:0]                out_ctrl_nxt;
   reg                                 out_wr_nxt;
   wire                                pkt_len_nearly_full;

   // ------------- Modules -------------------

   generate
      if(DATA_WIDTH == 32) begin: cpu_fifos32

         async_fifo_512x36_progfull_500 rx_fifo
           (.din({rx_fifo_ctrl_in, rx_fifo_data_in}),
            .dout({out_ctrl_local, out_data_local}),
            .clk(clk),
            .wr_en(rx_fifo_wr_en),
            .rd_en(rx_fifo_rd_en),
            .rst(reset || rx_timeout),
	    .rd_data_count(  ),
            .wr_data_count(rx_fifo_wr_data_count),
            .full(rx_fifo_full),
            .prog_full(rx_fifo_almost_full),
            .empty(rx_fifo_empty)
	    );

      end // block: cpu_rx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         wire [CTRL_WIDTH+DATA_WIDTH-1:0]    rx_fifo_dout;
         wire [CTRL_WIDTH+DATA_WIDTH-1:0]    rx_fifo_din;

         // The control/data words are mixed due to 32->64 bit conversion.
         // Reorder these.
         assign out_ctrl_local = {rx_fifo_dout[71:68], rx_fifo_dout[35:32]};
         assign out_data_local = {rx_fifo_dout[67:36], rx_fifo_dout[31:0]};

         // Pad the data being written to add ensure a whole number of words
         reg need_pad;
         always @(posedge clk)
         begin
            if (reset)
               need_pad <= 0;
            else begin
               if (rx_fifo_wr_en)
                  need_pad <= !need_pad;
               else if (!input_in_pkt && need_pad)
                  need_pad <= 0;
            end
         end
         assign rx_fifo_din = (need_pad && !input_in_pkt) ? 'h0 :
            {rx_fifo_ctrl_in, rx_fifo_data_in};

         async_fifo_512x36_to_72_progfull_500 rx_fifo
           (.din(rx_fifo_din), // Bus [35 : 0]
            .rd_clk(clk),
            .rd_en(rx_fifo_rd_en),
            .rst(reset || rx_timeout),
            .wr_clk(clk),
            .wr_en(rx_fifo_wr_en || (need_pad && !input_in_pkt)),
            .prog_full(rx_fifo_almost_full),
            .dout(rx_fifo_dout), // Bus [71 : 0]
            .empty(rx_fifo_empty),
            .full(rx_fifo_full),
	    .rd_data_count(),
            .wr_data_count(rx_fifo_wr_data_count) // Bus [8 : 0]
	    );

     end // block: cpu_fifos64

   endgenerate


   /* Whenever a packet is received, this fifo will store its status
    * and length after it is done. This is used to indicate that a packet is
    * available and whether it is good to read.
    * The depth of this fifo has to be the max number of pkt in the
    * rxfifo.
    */
  fallthrough_small_fifo
    #(.WIDTH (PKT_BYTE_CNT_WIDTH+1),
      .MAX_DEPTH_BITS (3)
   ) pkt_len_fifo (

     .din            ({1'b1, rx_pkt_byte_cnt}),
     .wr_en          (rx_pkt_stored),

     .rd_en          (rx_pkt_removed),

     .dout           ({pkt_len_fifo_dout, pkt_byte_len_out}),
     .full           (),
     .nearly_full    (pkt_len_nearly_full),
     .prog_full      (),
     .empty          (pkt_len_fifo_empty),

     .reset          (reset),
     .clk            (clk)
   );


   // -------------- Logic --------------------

   generate
      // Reorder the input: CPU uses little endian, the User Data Path uses
      // big endian
      genvar k;
      for(k=0; k<DMA_CTRL_WIDTH; k=k+1) begin: reorder_endianness
         assign rx_fifo_ctrl_in[k] = cpu_q_dma_wr_ctrl[DMA_CTRL_WIDTH-1-k];
         assign rx_fifo_data_in[8*k+:8] = cpu_q_dma_wr_data[DMA_DATA_WIDTH-8-8*k+:8];
      end

      // Calculate the word length of the packet
      if (ENABLE_HEADER) begin
         assign pkt_word_len_out = pkt_byte_len_out[LAST_WORD_BYTE_CNT_WIDTH-1:0] == 0 ?
            pkt_byte_len_out[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] :
            pkt_byte_len_out[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] + 1;
      end
   endgenerate

   // Calculate the word length based on the byte length
   assign rx_pkt_word_cnt_nxt = cpu_q_dma_wr_data[LAST_WORD_BYTE_CNT_WIDTH-1:0] == 'h0 ?
      cpu_q_dma_wr_data[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] :
      cpu_q_dma_wr_data[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] + 'h1;


   // Output state machine
   always @* begin
      output_in_pkt_nxt = output_in_pkt;
      rx_fifo_rd_en = 0;
      rx_pkt_removed = 0;
      out_data_nxt = 'h0;
      out_ctrl_nxt = 'h0;
      out_wr_nxt = 0;

      if (reset) begin
         output_in_pkt_nxt = 0;
      end
      else begin
         // Check that the output is ready and that we have a packet
         // (indicated by the pkt_len_fifo being non-empty)
         if (out_rdy && !pkt_len_fifo_empty) begin
            if (ENABLE_HEADER && !output_in_pkt) begin
               out_data_nxt =
                     {pkt_word_len_out,
                      port_number,
                      {(`IOQ_SRC_PORT_POS - PKT_BYTE_CNT_WIDTH){1'b0}},
                      pkt_byte_len_out};
               out_ctrl_nxt = STAGE_NUMBER;
               output_in_pkt_nxt = 1;
            end
            else begin
               out_data_nxt = out_data_local;
               out_ctrl_nxt = out_ctrl_local;
               if (out_ctrl_local != 'h0) begin
                  output_in_pkt_nxt = 0;
                  rx_pkt_removed = 1;
               end
               rx_fifo_rd_en = 1;
            end
            out_wr_nxt = 1;
         end
      end
   end

   always @(posedge clk) begin
      output_in_pkt <= output_in_pkt_nxt;
      out_data <= out_data_nxt;
      out_ctrl <= out_ctrl_nxt;
      out_wr <= out_wr_nxt;
   end

   assign rx_fifo_wr_en = cpu_q_dma_wr && (!rx_fifo_full) && input_in_pkt;

   // State machine to track data written into fifo */
   always @(posedge clk) begin
      if(reset) begin
         rx_pkt_byte_cnt         <= 'h0;
         rx_pkt_word_cnt         <= 'h0;
         input_in_pkt            <= 1'b 0;
	 num_pkts_in_q           <= 'h 0;
	 cpu_q_dma_nearly_full   <= 1'b 0;
         rx_pkt_stored           <= 1'b 0;
         num_bytes_written       <= 'h 0;
      end // if (reset)

      else begin
         // Track where we are in a packet
         if (cpu_q_dma_wr && !input_in_pkt) begin
            input_in_pkt <= 1;
            rx_pkt_byte_cnt <= cpu_q_dma_wr_data;
            rx_pkt_word_cnt <= rx_pkt_word_cnt_nxt;
         end
         else if (cpu_q_dma_wr && input_in_pkt && cpu_q_dma_wr_ctrl != 0)
            input_in_pkt <= 0;

         // Calculate the number of bytes written
         //if (rx_fifo_wr_en) begin
         //   if (!input_in_pkt)
         //      num_bytes_written <= 'h4;
         //   else begin
         //      case (cpu_q_dma_wr_ctrl)
         //         'h8:     num_bytes_written <= num_bytes_written + 4;
         //         'h4:     num_bytes_written <= num_bytes_written + 3;
         //         'h2:     num_bytes_written <= num_bytes_written + 2;
         //         'h1:     num_bytes_written <= num_bytes_written + 1;
         //         default: num_bytes_written <= num_bytes_written + 4;
         //      endcase
         //   end
         //end

         if (rx_timeout)
            num_pkts_in_q <= 'h0;
         else begin
            case ({rx_pkt_removed, rx_pkt_stored})
              2'b 10: num_pkts_in_q <= num_pkts_in_q - 'h 1;
              2'b 01: num_pkts_in_q <= num_pkts_in_q + 'h 1;
            endcase // case({rx_pkt_removed, rx_pkt_stored})
         end

	 cpu_q_dma_nearly_full <= rx_fifo_almost_full ||
                                  pkt_len_nearly_full;

         rx_pkt_stored <= rx_fifo_wr_en && (| cpu_q_dma_wr_ctrl);
      end // else: !if(reset)

   end // always @ (posedge clk)



   // Watchdog timer logic
   //
   // Attempts to reset the TX fifo if the fifo enters a "lock-up" state in
   // which there is data in the FIFO but not a complete packet. (Can't
   // start a new DMA transfer but also can't start removing the packet.)
   always @(posedge clk)
   begin
      if (reset || rx_fifo_wr_en || rx_fifo_rd_en) begin
         rx_watchdog_timer <= RX_WATCHDOG_TIMEOUT;
         rx_timeout <= 1'b0;
      end
      else begin
         if (!rx_fifo_empty) begin
            if (rx_watchdog_timer > 0) begin
               rx_watchdog_timer <= rx_watchdog_timer - 'h1;
            end
         end

         // Generate a time-out if the timer has expired, there is data in the
         // FIFO (but not a whole packet) and we didn't just assert the
         // timeout signal.
         rx_timeout <= (rx_watchdog_timer == 'h0) && !rx_fifo_empty &&
                       (num_pkts_in_q == 'h0) && !rx_timeout;
      end
   end

   // Register update logic
   assign rx_pkt_dropped = 'h0;

   always @(posedge clk)
   begin
      rx_q_underrun <= rx_fifo_rd_en && rx_fifo_empty;
      rx_q_overrun <= cpu_q_dma_wr && rx_fifo_full;
   end

endmodule // cpu_dma_rx_queue
