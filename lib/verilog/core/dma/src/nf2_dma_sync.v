//////////////////////////////////////////////////////////////////////////////
// $Id: nf2_dma_sync.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_dma_sync.v
// Project: NetFPGA-1G
// Description: DMA synchronizer
//
// Provides signal synchronization between CPCI clk domain and
// system clk domain
//
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// txfifo_rd_data includes:
//  1 bit. 1'b 0 for "data format"; 1'b 1 for "req format"
//  1 bit. EOP in "data format". 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//         in "req format", 1'b 0 for "dma tx", 1'b 1 for "dma rx"
//  2 bits. bytecnt in "data format". 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
//          always 2'b 00 in "req format"
// 32 bits. pkt data in "data format".
//         {28'b 0, 4-bits queue_id} in "req format"
//
// rxfifo_wr_data includes:
//  1 bit. EOP. 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//  2 bits. bytecnt. 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
// 32 bits. pkt data .
//
///////////////////////////////////////////////////////////////////////////////

module nf2_dma_sync
  #(parameter DMA_DATA_WIDTH = 32,
    parameter NUM_CPU_QUEUES = 4)
    (
     // -- signals from/to bus FSM
     output reg [NUM_CPU_QUEUES-1:0] cpci_cpu_q_dma_pkt_avail,
     output reg [NUM_CPU_QUEUES-1:0] cpci_cpu_q_dma_can_wr_pkt,

     output cpci_txfifo_full,
     output cpci_txfifo_nearly_full,
     input cpci_txfifo_wr,
     input [DMA_DATA_WIDTH +4:0] cpci_txfifo_wr_data,

     output cpci_rxfifo_empty,
     input cpci_rxfifo_rd_inc,
     output [DMA_DATA_WIDTH +2:0] cpci_rxfifo_rd_data,

     // --- signals from/to NetFPGA core logic
     input [NUM_CPU_QUEUES-1:0] sys_cpu_q_dma_pkt_avail,
     input [NUM_CPU_QUEUES-1:0] sys_cpu_q_dma_can_wr_pkt,

     output sys_txfifo_empty,
     output [DMA_DATA_WIDTH +4:0] sys_txfifo_rd_data,
     input sys_txfifo_rd_inc,

     output sys_rxfifo_full,
     output sys_rxfifo_nearly_full,
     input sys_rxfifo_wr,
     input [DMA_DATA_WIDTH +2:0] sys_rxfifo_wr_data,

     //clks and resets
     input cpci_clk,
     input cpci_reset,

     input sys_clk,
     input sys_reset
   );

   reg [NUM_CPU_QUEUES-1:0] cpci_sync_cpu_q_dma_pkt_avail;
   reg [NUM_CPU_QUEUES-1:0] cpci_sync_cpu_q_dma_can_wr_pkt;

   always @(posedge cpci_clk)
     if (cpci_reset) begin
	cpci_sync_cpu_q_dma_pkt_avail <= 'h 0;
	cpci_sync_cpu_q_dma_can_wr_pkt <= 'h 0;

	cpci_cpu_q_dma_pkt_avail <= 'h 0;
	cpci_cpu_q_dma_can_wr_pkt <= 'h 0;
     end

     else begin
	cpci_sync_cpu_q_dma_pkt_avail <= sys_cpu_q_dma_pkt_avail;
	cpci_sync_cpu_q_dma_can_wr_pkt <= sys_cpu_q_dma_can_wr_pkt;

	cpci_cpu_q_dma_pkt_avail <= cpci_sync_cpu_q_dma_pkt_avail;
	cpci_cpu_q_dma_can_wr_pkt <= cpci_sync_cpu_q_dma_can_wr_pkt;
     end

   //---------------------------------------
   // Instantiations

   small_async_fifo #(.DSIZE(DMA_DATA_WIDTH +5),
		      .ASIZE(3),
		      .ALMOST_FULL_SIZE(5),
		      .ALMOST_EMPTY_SIZE(3))
     tx_async_fifo (
		    //wr interface
		    .wfull ( cpci_txfifo_full ),
		    .w_almost_full ( cpci_txfifo_nearly_full ),
		    .wdata ( cpci_txfifo_wr_data ),
		    .winc ( cpci_txfifo_wr ),
		    .wclk ( cpci_clk ),
		    .wrst_n ( ~cpci_reset ),

		    //rd interface
		    .rdata ( sys_txfifo_rd_data ),
		    .rempty ( sys_txfifo_empty ),
		    .r_almost_empty (  ),
		    .rinc ( sys_txfifo_rd_inc ),
		    .rclk ( sys_clk ),
		    .rrst_n ( ~sys_reset )
		    );

   small_async_fifo #(.DSIZE(DMA_DATA_WIDTH +3),
		      .ASIZE(3),
		      .ALMOST_FULL_SIZE(5),
		      .ALMOST_EMPTY_SIZE(3))
     rx_async_fifo (
		    //wr interface
		    .wfull ( sys_rxfifo_full ),
		    .w_almost_full ( sys_rxfifo_nearly_full ),
		    .wdata ( sys_rxfifo_wr_data ),
		    .winc ( sys_rxfifo_wr ),
		    .wclk ( sys_clk ),
		    .wrst_n ( ~sys_reset ),

		    //rd interface
		    .rdata ( cpci_rxfifo_rd_data ),
		    .rempty ( cpci_rxfifo_empty ),
		    .r_almost_empty (  ),
		    .rinc ( cpci_rxfifo_rd_inc ),
		    .rclk ( cpci_clk ),
		    .rrst_n ( ~cpci_reset )
		    );

endmodule // nf2_dma_sync

