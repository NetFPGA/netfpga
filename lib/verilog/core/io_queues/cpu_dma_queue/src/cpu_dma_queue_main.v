///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_main.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: cpu_dma_queue_main.v
// Project: NF2.1
// Description: Main module for CPU DMA queue
//
//              a slim CPU rx_fifo and tx_fifo connecting to the DMA interface
//
//              Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
// Note: A watchdog is included to monitor the state of the TX queue to ensure
// that permanent lockup never occurs.
//
// A watchdog timer starts whenever data is written to the TX fifo. (The timer
// is reset on every write.) If the timer expires and the fifo is non-empty
// but has zero complete packets then the fifo is reset.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_queue_main
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

      input  [DATA_WIDTH-1:0]       in_data,
      input  [CTRL_WIDTH-1:0]       in_ctrl,
      input                         in_wr,
      output                        in_rdy,

      // --- DMA rd rxfifo interface
      output reg                    cpu_q_dma_pkt_avail,

      input                         cpu_q_dma_rd,
      output [DMA_DATA_WIDTH-1:0]   cpu_q_dma_rd_data,
      output [DMA_CTRL_WIDTH-1:0]   cpu_q_dma_rd_ctrl,

      // DMA wr txfifo interface
      output reg                    cpu_q_dma_nearly_full,

      input                         cpu_q_dma_wr,
      input [DMA_DATA_WIDTH-1:0]    cpu_q_dma_wr_data,
      input [DMA_CTRL_WIDTH-1:0]    cpu_q_dma_wr_ctrl,

      // Register interface -- RX
      input                         rx_queue_en,
      output                        rx_pkt_stored,
      output                        rx_pkt_dropped,
      output                        rx_pkt_removed,
      output                        rx_q_underrun,
      output                        rx_q_overrun,
      output  [11:0]                rx_pkt_byte_cnt,
      output  [9:0]                 rx_pkt_word_cnt,

      // Register interface -- TX
      input                         tx_queue_en,
      output                        tx_pkt_stored,
      output                        tx_pkt_removed,
      output                        tx_q_underrun,
      output                        tx_q_overrun,
      output reg                    tx_timeout,
      output [11:0]                 tx_pkt_byte_cnt,
      output [9:0]                  tx_pkt_word_cnt,

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

   reg [5:0]                            reg_rx_num_pkts_in_q; //the max count of pkts is 35.
   reg [5:0]                            reg_tx_num_pkts_in_q; //the max count of pkts is 35.

   reg                                  out_ctrl_prev_is_0;
   reg                                  in_ctrl_prev_is_0;

   wire                                 rx_fifo_rd_en;
   wire                                 rx_pkt_read;
   reg                                  rx_pkt_written;

   wire                                 tx_fifo_rd_en;
   wire                                 tx_fifo_wr_en;
   wire                                 tx_pkt_read;
   reg                                  tx_pkt_written;
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0]  tx_fifo_din;

   // wires from endianness reordering
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     rx_fifo_din;
   wire [CTRL_WIDTH-1:0]                reordered_in_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_in_data;
   wire [CTRL_WIDTH-1:0]                reordered_out_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_out_data;

   // wires from rx_fifo
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0]  rx_fifo_dout;
   wire [`CPCI_NF2_DATA_WIDTH/8-1:0] 	cpu_q_reg_rd_ctrl;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] 	cpu_q_reg_rd_data;
   wire [8:0] 				rx_fifo_rd_data_count;
   wire                                 rx_fifo_almost_full;
   wire 				rx_fifo_empty;

   // wires from tx_fifo
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     tx_fifo_dout;
   wire [8:0] 				tx_fifo_wr_data_count;
   wire                                 tx_fifo_full, tx_fifo_almost_full;
   wire 				tx_fifo_empty;

   // tx watchdog signals
   reg					tx_in_pkt;
   reg [TX_WATCHDOG_TIMER_WIDTH-1:0]    tx_watchdog_timer;
   reg					tx_reset;


   // ------------- Modules -------------------
   generate
      genvar k;

      if(DATA_WIDTH == 32) begin: cpu_fifos32
         // reorder the input and outputs: CPU uses little endian, the User Data Path uses big endian
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign rx_fifo_din[CTRL_WIDTH+DATA_WIDTH-1-k] = in_ctrl[k];
            assign rx_fifo_din[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
            assign out_ctrl[k] = tx_fifo_dout[CTRL_WIDTH+DATA_WIDTH-1-k];
            assign out_data[8*k+7:8*k] = tx_fifo_dout[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)];
         end

	 // pkt data and ctrl stored in rx_fifo are in little endian
         async_fifo_512x36_progfull_500 rx_fifo
           (.din(rx_fifo_din),
	    .dout(rx_fifo_dout),
            .clk(clk),
            .rst(reset),
            .rd_data_count(rx_fifo_rd_data_count),
	    .wr_data_count(  ),
            .wr_en(in_wr),
            .rd_en(rx_fifo_rd_en),
            .full(  ),
            .prog_full(rx_fifo_almost_full),
            .empty(rx_fifo_empty)
	    );

	 // pkt data and ctrl stored in tx_fifo are in little endian
         async_fifo_512x36_progfull_500 tx_fifo
           (.din(tx_fifo_din),
            .dout(tx_fifo_dout),
            .clk(clk),
            .wr_en(tx_fifo_wr_en),
            .rd_en(tx_fifo_rd_en),
            .rst(reset || tx_timeout),
	    .rd_data_count(  ),
            .wr_data_count(tx_fifo_wr_data_count),
            .full(tx_fifo_full),
            .prog_full(tx_fifo_almost_full),
            .empty(tx_fifo_empty)
	    );

      end // block: cpu_rx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         /* need to reorder for endianness and so that ctrl is next to data on the cpu side*/
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign reordered_in_ctrl[CTRL_WIDTH-1-k] = in_ctrl[k];
            assign reordered_in_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
            assign out_ctrl[CTRL_WIDTH-1-k] = reordered_out_ctrl[k];
            assign out_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = reordered_out_data[8*k+7:8*k];
         end
         assign rx_fifo_din = {reordered_in_ctrl[3:0], reordered_in_data[31:0],
                               reordered_in_ctrl[7:4], reordered_in_data[63:32]};
         assign reordered_out_ctrl = {tx_fifo_dout[35:32], tx_fifo_dout[71:68]};
         assign reordered_out_data = {tx_fifo_dout[31:0], tx_fifo_dout[67:36]};

         // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_256x72_to_36 rx_fifo
           (.din(rx_fifo_din),
            .rd_clk(clk),
            .rd_en(rx_fifo_rd_en),
            .rst(reset),
            .wr_clk(clk),
            .wr_en(in_wr),
            .almost_full(rx_fifo_almost_full),
	    .dout(rx_fifo_dout),
            .empty(rx_fifo_empty),
            .full(),
            .rd_data_count(rx_fifo_rd_data_count)
	    );

	 // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_512x36_to_72_progfull_500 tx_fifo
           (.din(tx_fifo_din), // Bus [35 : 0]
            .rd_clk(clk),
            .rd_en(tx_fifo_rd_en),
            .rst(reset || tx_timeout),
            .wr_clk(clk),
            .wr_en(tx_fifo_wr_en),
            .prog_full(tx_fifo_almost_full),
            .dout(tx_fifo_dout), // Bus [71 : 0]
            .empty(tx_fifo_empty),
            .full(tx_fifo_full),
	    .rd_data_count(),
            .wr_data_count(tx_fifo_wr_data_count) // Bus [8 : 0]
	    );

     end // block: cpu_fifos64

   endgenerate

   // -------------- Logic --------------------
   assign tx_fifo_din = {cpu_q_dma_wr_ctrl, cpu_q_dma_wr_data};

   assign {cpu_q_dma_rd_ctrl, cpu_q_dma_rd_data} = rx_fifo_dout;

   /* monitor pkt padding */
   always @(posedge clk) begin
      if(reset) begin
         tx_pkt_written <= 1'b 0;
         rx_pkt_written <= 1'b 0;

      end
      else begin
         rx_pkt_written <= (in_wr && (|in_ctrl) && in_ctrl_prev_is_0);
         tx_pkt_written <= tx_fifo_wr_en && (| cpu_q_dma_wr_ctrl);

      end // else: !if(reset)
   end // always @ (posedge clk)

   /* monitor when pkts are read */
   assign tx_pkt_read    = (tx_fifo_rd_en && (|out_ctrl) && out_ctrl_prev_is_0);
   assign rx_pkt_read    = (| cpu_q_dma_rd_ctrl) && rx_fifo_rd_en;

   /* if a packet is ready to be sent to the user data
    * path from the CPU, then pipe it out */
   assign tx_fifo_rd_en = (| reg_tx_num_pkts_in_q) & out_rdy ;
   assign out_wr = tx_fifo_rd_en;

   assign in_rdy = !rx_fifo_almost_full;

   assign tx_fifo_wr_en = cpu_q_dma_wr && (!tx_fifo_full);
   assign rx_fifo_rd_en = cpu_q_dma_rd && (!rx_fifo_empty);

   /* run the counters and mux between write and update */
   always @(posedge clk) begin
      if(reset) begin
         out_ctrl_prev_is_0       <= 1'b 0;
         in_ctrl_prev_is_0        <= 1'b 0;

	 reg_rx_num_pkts_in_q <= 'h 0;
	 reg_tx_num_pkts_in_q <= 'h 0;

	 cpu_q_dma_pkt_avail <= 1'b 0;
	 cpu_q_dma_nearly_full <= 1'b 0;

      end // if (reset)

      else begin
         out_ctrl_prev_is_0 <= tx_fifo_rd_en ? (out_ctrl==0) : out_ctrl_prev_is_0;
         in_ctrl_prev_is_0  <= in_wr ? (in_ctrl==0) : in_ctrl_prev_is_0;

	 case ({rx_pkt_read, rx_pkt_written})
           2'b 10: reg_rx_num_pkts_in_q <= reg_rx_num_pkts_in_q - 'h 1;
           2'b 01: reg_rx_num_pkts_in_q <= reg_rx_num_pkts_in_q + 'h 1;
         endcase // case({rx_pkt_read, rx_pkt_written})

         if (tx_timeout)
            reg_tx_num_pkts_in_q <= 'h0;
         else begin
            case ({tx_pkt_read, tx_pkt_written})
              2'b 10: reg_tx_num_pkts_in_q <= reg_tx_num_pkts_in_q - 'h 1;
              2'b 01: reg_tx_num_pkts_in_q <= reg_tx_num_pkts_in_q + 'h 1;
            endcase // case({tx_pkt_read, tx_pkt_written})
         end

	 cpu_q_dma_pkt_avail <= (| reg_rx_num_pkts_in_q);
	 cpu_q_dma_nearly_full <= tx_fifo_almost_full;

      end // else: !if(reset)

   end // always @ (posedge clk)



   // Watchdog timer logic
   //
   // Attempts to reset the TX fifo if the fifo enters a "lock-up" state in
   // which there is data in the FIFO but not a complete packet. (Can't
   // start a new DMA transfer but also can't start removing the packet.)
   always @(posedge clk)
   begin
      if (reset || tx_fifo_wr_en || tx_fifo_rd_en) begin
         tx_watchdog_timer <= TX_WATCHDOG_TIMEOUT;
         tx_timeout <= 1'b0;
      end
      else begin
         if (!tx_fifo_empty) begin
            if (tx_watchdog_timer > 0) begin
               tx_watchdog_timer <= tx_watchdog_timer - 'h1;
            end
         end

         // Generate a time-out if the timer has expired, there is data in the
         // FIFO (but not a whole packet) and we didn't just assert the
         // timeout signal.
         tx_timeout <= (tx_watchdog_timer == 'h0) && !tx_fifo_empty &&
                       (reg_tx_num_pkts_in_q == 'h0) && !tx_timeout;
      end
   end

   // Register update logic
   //
   // Note: The connections seem back-to-front but this is because of
   // differences in meaning. In *this* module, TX/RX are relative to the
   // *host*, in the register context they are relative to the *board*.
   //
   // Confusing... yes :-/
   assign rx_pkt_stored = tx_pkt_written;
   assign rx_pkt_dropped = 'h0;
   assign rx_pkt_removed = tx_pkt_read;
   assign rx_q_underrun = 'h0;
   assign rx_q_overrun = 'h0;
   assign rx_pkt_byte_cnt = 'h0;
   assign rx_pkt_word_cnt = 'h0;

   assign tx_pkt_stored = rx_pkt_written;
   assign tx_pkt_removed = rx_pkt_read;
   assign tx_q_underrun = 'h0;
   assign tx_q_overrun = 'h0;
   assign tx_pkt_byte_cnt = 'h0;
   assign tx_pkt_word_cnt = 'h0;

endmodule // cpu_dma_queue_main
