///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: cpu_dma_tx_queue.v
// Project: NF2.1
// Description: Transmit queue for CPU DMA queue
//
//              A slim CPU tx_fifo connecting to the DMA interface.
//              FIFO is first-word-fall-through.
//
// Note (1): Transmit is relative to the NetFPGA -- this is, transmit represents
// transfers from the NetFPGA to the host.
//
// Note (2): A watchdog is included to monitor the state of the TX queue to
// ensure that permanent lockup never occurs.
//
// A watchdog timer starts whenever data is written to the TX fifo. (The timer
// is reset on every write.) If the timer expires and the fifo is non-empty
// but has zero complete packets then the fifo is reset.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_tx_queue
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8,
      parameter TX_WATCHDOG_TIMEOUT = 125000
   )
   (
      input  [DATA_WIDTH-1:0]       in_data,
      input  [CTRL_WIDTH-1:0]       in_ctrl,
      input                         in_wr,
      output                        in_rdy,

      // --- DMA rd nterface
      output reg                    cpu_q_dma_pkt_avail,

      input                         cpu_q_dma_rd,
      output [DMA_DATA_WIDTH-1:0]   cpu_q_dma_rd_data,
      output [DMA_CTRL_WIDTH-1:0]   cpu_q_dma_rd_ctrl,

      // Register interface -- TX
      input                         tx_queue_en,
      output reg                    tx_pkt_stored,
      output                        tx_pkt_removed,
      output reg                    tx_q_underrun,
      output reg                    tx_q_overrun,
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

   reg [5:0]                            num_pkts_in_q; //the max count of pkts is 35.

   reg                                  in_ctrl_prev_is_0;

   wire                                 tx_fifo_rd_en;

   // wires from endianness reordering
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     tx_fifo_din;
   wire [CTRL_WIDTH-1:0]                reordered_in_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_in_data;
   wire [CTRL_WIDTH-1:0]                reordered_out_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_out_data;

   // wires from tx_fifo
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0]  tx_fifo_dout;
   wire [`CPCI_NF2_DATA_WIDTH/8-1:0] 	cpu_q_reg_rd_ctrl;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] 	cpu_q_reg_rd_data;
   wire                                 tx_fifo_almost_full;
   wire 				tx_fifo_full;
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
            assign tx_fifo_din[CTRL_WIDTH+DATA_WIDTH-1-k] = in_ctrl[k];
            assign tx_fifo_din[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
         end

	 // pkt data and ctrl stored in tx_fifo are in little endian
         async_fifo_512x36_progfull_500 tx_fifo
           (.din(tx_fifo_din),
	    .dout(tx_fifo_dout),
            .clk(clk),
            .rst(reset || tx_timeout),
            .rd_data_count(),
	    .wr_data_count(),
            .wr_en(in_wr),
            .rd_en(tx_fifo_rd_en),
            .full(tx_fifo_full),
            .prog_full(tx_fifo_almost_full),
            .empty(tx_fifo_empty)
	    );

      end // block: cpu_tx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         /* need to reorder for endianness and so that ctrl is next to data on the cpu side*/
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign reordered_in_ctrl[CTRL_WIDTH-1-k] = in_ctrl[k];
            assign reordered_in_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
         end
         assign tx_fifo_din = {reordered_in_ctrl[3:0], reordered_in_data[31:0],
                               reordered_in_ctrl[7:4], reordered_in_data[63:32]};

         // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_256x72_to_36 tx_fifo
           (.din(tx_fifo_din),
            .rd_clk(clk),
            .rd_en(tx_fifo_rd_en),
            .rst(reset || tx_timeout),
            .wr_clk(clk),
            .wr_en(in_wr),
            .almost_full(tx_fifo_almost_full),
	    .dout(tx_fifo_dout),
            .empty(tx_fifo_empty),
            .full(tx_fifo_full),
            .rd_data_count()
	    );

     end // block: cpu_fifos64

   endgenerate

   // -------------- Logic --------------------

   // Generate the DMA outputs based upon the FIFO output
   assign {cpu_q_dma_rd_ctrl, cpu_q_dma_rd_data} = tx_fifo_dout;

   // Monitor when pkts are read
   assign tx_pkt_removed = (| cpu_q_dma_rd_ctrl) && cpu_q_dma_rd;

   // Internal signal generation
   assign in_rdy = !tx_fifo_almost_full;
   assign tx_fifo_rd_en = cpu_q_dma_rd && (!tx_fifo_empty);

   /* State machine to track data written into fifo */
   always @(posedge clk) begin
      if(reset) begin
         in_ctrl_prev_is_0    <= 1'b 0;
	 num_pkts_in_q        <= 'h 0;
	 cpu_q_dma_pkt_avail  <= 1'b 0;
         tx_pkt_stored <= 1'b 0;
      end // if (reset)
      else begin
         in_ctrl_prev_is_0  <= in_wr ? (in_ctrl==0) : in_ctrl_prev_is_0;

         if (tx_timeout)
            num_pkts_in_q <= 'h0;
         else begin
            case ({tx_pkt_removed, tx_pkt_stored})
              2'b 10: num_pkts_in_q <= num_pkts_in_q - 'h 1;
              2'b 01: num_pkts_in_q <= num_pkts_in_q + 'h 1;
            endcase // case({tx_pkt_removed, tx_pkt_stored})
         end

	 cpu_q_dma_pkt_avail <= (| num_pkts_in_q);

         tx_pkt_stored <= (in_wr && (|in_ctrl) && in_ctrl_prev_is_0);
      end // else: !if(reset)
   end // always @ (posedge clk)



   // Watchdog timer logic
   //
   // Attempts to reset the TX fifo if the fifo enters a "lock-up" state in
   // which there is data in the FIFO but not a complete packet. (Can't
   // start a new DMA transfer but also can't start removing the packet.)
   always @(posedge clk)
   begin
      if (reset || in_wr || tx_fifo_rd_en) begin
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
                       (num_pkts_in_q == 'h0) && !tx_timeout;
      end
   end

   // Register update logic
   assign tx_pkt_byte_cnt = 'h0;
   assign tx_pkt_word_cnt = 'h0;

   always @(posedge clk)
   begin
      tx_q_underrun <= cpu_q_dma_rd && tx_fifo_empty;
      tx_q_overrun <= in_wr && tx_fifo_full;
   end

endmodule // cpu_dma_tx_queue
