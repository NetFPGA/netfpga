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
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8,
      parameter TX_WATCHDOG_TIMEOUT = 125000
   )
   (
      output [DATA_WIDTH-1:0]       out_data,
      output [CTRL_WIDTH-1:0]       out_ctrl,
      output                        out_wr,
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
      output                        rx_pkt_removed,
      output  reg                   rx_q_underrun,
      output  reg                   rx_q_overrun,
      output  reg                   rx_timeout,
      output  [11:0]                rx_pkt_byte_cnt,
      output  [9:0]                 rx_pkt_word_cnt,

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

   parameter TX_WATCHDOG_TIMER_WIDTH = log2(TX_WATCHDOG_TIMEOUT);

   // ------------- Wires/reg ------------------

   reg [5:0]                            num_pkts_in_q; //the max count of pkts is 35.

   reg                                  out_ctrl_prev_is_0;

   wire                                 rx_fifo_rd_en;
   wire                                 rx_fifo_wr_en;
   reg                                  rx_pkt_written;
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0]  rx_fifo_din;

   // wires from endianness reordering
   wire [CTRL_WIDTH-1:0]                reordered_out_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_out_data;

   // wires from rx_fifo
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     rx_fifo_dout;
   wire [8:0] 				rx_fifo_wr_data_count;
   wire                                 rx_fifo_full;
   wire                                 rx_fifo_almost_full;
   wire 				rx_fifo_empty;

   // tx watchdog signals
   reg					rx_in_pkt;
   reg [TX_WATCHDOG_TIMER_WIDTH-1:0]    rx_watchdog_timer;
   reg					rx_reset;


   // ------------- Modules -------------------
   generate
      genvar k;

      if(DATA_WIDTH == 32) begin: cpu_fifos32
         // reorder the input and outputs: CPU uses little endian, the User Data Path uses big endian
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign out_ctrl[k] = rx_fifo_dout[CTRL_WIDTH+DATA_WIDTH-1-k];
            assign out_data[8*k+7:8*k] = rx_fifo_dout[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)];
         end

	 // pkt data and ctrl stored in rx_fifo are in little endian
         async_fifo_512x36_progfull_500 rx_fifo
           (.din(rx_fifo_din),
            .dout(rx_fifo_dout),
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
         /* need to reorder for endianness and so that ctrl is next to data on the cpu side*/
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign out_ctrl[CTRL_WIDTH-1-k] = reordered_out_ctrl[k];
            assign out_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = reordered_out_data[8*k+7:8*k];
         end
         assign reordered_out_ctrl = {rx_fifo_dout[35:32], rx_fifo_dout[71:68]};
         assign reordered_out_data = {rx_fifo_dout[31:0], rx_fifo_dout[67:36]};

	 // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_512x36_to_72_progfull_500 rx_fifo
           (.din(rx_fifo_din), // Bus [35 : 0]
            .rd_clk(clk),
            .rd_en(rx_fifo_rd_en),
            .rst(reset || rx_timeout),
            .wr_clk(clk),
            .wr_en(rx_fifo_wr_en),
            .prog_full(rx_fifo_almost_full),
            .dout(rx_fifo_dout), // Bus [71 : 0]
            .empty(rx_fifo_empty),
            .full(rx_fifo_full),
	    .rd_data_count(),
            .wr_data_count(rx_fifo_wr_data_count) // Bus [8 : 0]
	    );

     end // block: cpu_fifos64

   endgenerate

   // -------------- Logic --------------------

   // Generate the FIFO input from the DMA input
   assign rx_fifo_din = {cpu_q_dma_wr_ctrl, cpu_q_dma_wr_data};

   // Monitor when pkts are read
   assign rx_pkt_removed = (rx_fifo_rd_en && (|out_ctrl) && out_ctrl_prev_is_0);

   // if a packet is ready to be sent to the user data
   // path from the CPU, then pipe it out
   assign rx_fifo_rd_en = (| num_pkts_in_q) & out_rdy ;
   assign out_wr = rx_fifo_rd_en;

   assign rx_fifo_wr_en = cpu_q_dma_wr && (!rx_fifo_full);

   /* State machine to track data written into fifo */
   always @(posedge clk) begin
      if(reset) begin
         out_ctrl_prev_is_0      <= 1'b 0;
	 num_pkts_in_q           <= 'h 0;
	 cpu_q_dma_nearly_full   <= 1'b 0;
         rx_pkt_stored <= 1'b 0;

      end // if (reset)

      else begin
         out_ctrl_prev_is_0 <= rx_fifo_rd_en ? (out_ctrl==0) : out_ctrl_prev_is_0;

         if (rx_timeout)
            num_pkts_in_q <= 'h0;
         else begin
            case ({rx_pkt_removed, rx_pkt_stored})
              2'b 10: num_pkts_in_q <= num_pkts_in_q - 'h 1;
              2'b 01: num_pkts_in_q <= num_pkts_in_q + 'h 1;
            endcase // case({rx_pkt_removed, rx_pkt_stored})
         end

	 cpu_q_dma_nearly_full <= rx_fifo_almost_full;

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
         rx_watchdog_timer <= TX_WATCHDOG_TIMEOUT;
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
   assign rx_pkt_byte_cnt = 'h0;
   assign rx_pkt_word_cnt = 'h0;

   always @(posedge clk)
   begin
      rx_q_underrun <= rx_fifo_rd_en && rx_fifo_empty;
      rx_q_overrun <= cpu_q_dma_wr && rx_fifo_full;
   end

endmodule // cpu_dma_rx_queue
