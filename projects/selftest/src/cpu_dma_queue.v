///////////////////////////////////////////////////////////////////////////////
// $Id: cpu_dma_queue.v 5990 2010-03-10 22:14:12Z grg $
//
// Module: cpu_dma_queue.v
// Project: NF2.1
// Description: If enable_dma signal is asserted, supports CPU access to
//              rx_fifo and tx_fifo using DMA. Otherwise,
//              supports CPU access to rx_fifo and tx_fifo using
//              register read and write.
//
//              Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
///////////////////////////////////////////////////////////////////////////////

  module cpu_dma_queue
    #(parameter DATA_WIDTH = 32,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8
      )
   (
    // --- DMA rd rxfifo interface
    output reg cpu_q_dma_pkt_avail,

    input cpu_q_dma_rd,
    output [DMA_DATA_WIDTH-1:0] cpu_q_dma_rd_data,
    output [DMA_CTRL_WIDTH-1:0] cpu_q_dma_rd_ctrl,

    // DMA wr txfifo interface
    output reg cpu_q_dma_nearly_full,

    input cpu_q_dma_wr,
    input [DMA_DATA_WIDTH-1:0] cpu_q_dma_wr_data,
    input [DMA_CTRL_WIDTH-1:0] cpu_q_dma_wr_ctrl,

    // --- Misc
    input                                reset,
    input                                clk
    );

   // -------- Internal parameters --------------
   parameter TX_FIFO_DEPTH = 512;

   // ------------- Wires/reg ------------------

   wire                                 rx_fifo_rd_en;

    // wires from rx_fifo
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0]   rx_fifo_dout;
   wire [8:0] 				rx_fifo_rd_data_count;
   wire                                 rx_fifo_almost_full, rx_fifo_full;
   wire 				rx_fifo_empty;
   wire [`CPCI_NF2_DATA_WIDTH*9/8-1:0] 	rx_fifo_din;



   // ------------- Modules -------------------

   // pkt data and ctrl stored in rx_fifo are in little endian
   async_fifo_512x36_progfull_500 rx_tx_fifo
     (
      //wr
      .din(rx_fifo_din),
      .wr_data_count(  ),
      .wr_en(rx_fifo_wr_en),
      .full( rx_fifo_full ),
      .prog_full(rx_fifo_almost_full),
      .wr_clk(clk),

      //rd
      .dout(rx_fifo_dout),
      .rd_data_count(rx_fifo_rd_data_count),
      .rd_clk(clk),
      .rd_en(rx_fifo_rd_en),
      .empty(rx_fifo_empty),

      //misc
      .rst(reset)
      );

   // -------------- Logic --------------------

   /* monitor when pkts are read */

   /* if a packet is ready to be sent to the user data
    * path from the CPU, then pipe it out */
   assign rx_fifo_din = {cpu_q_dma_wr_ctrl, cpu_q_dma_wr_data};
   assign rx_fifo_wr_en = (cpu_q_dma_wr) && (!rx_fifo_full);
   assign rx_fifo_rd_en = (cpu_q_dma_rd) && (!rx_fifo_empty);
   assign {cpu_q_dma_rd_ctrl, cpu_q_dma_rd_data} = rx_fifo_dout;


   //the dma_engine module in CPCI doesn't support
   //pause in the middle of transfering a packet from Spartan
   //to Virtex. The cpu_q_dma_nearly_full is only checked
   //before a packet is transferred from the CPCI. So
   //when cpu_q_dma_nearly_full is deasserted, the cpu tx_fifo
   //must be able to take in a maximum legal packet.
   //In NetFPGA 2.1 platform, that's 2KB.
   //after dma_engine module is able to support pause in the course
   //of DMA tx, it's safe to drive cpu_q_dma_nearly_full by
   //the tx_fifo_almost_full signal.

   /* run the counters and mux between write and update */
   always @(posedge clk) begin
      if(reset) begin
	 cpu_q_dma_pkt_avail <= 1'b 0;
	 cpu_q_dma_nearly_full <= 1'b 0;

      end // if (reset)

      else begin
	 cpu_q_dma_pkt_avail <= ~rx_fifo_empty;
	 cpu_q_dma_nearly_full <= rx_fifo_almost_full;

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // cpu_dma_queue
