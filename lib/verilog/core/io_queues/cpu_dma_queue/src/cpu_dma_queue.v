///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue.v 2265 2007-09-17 22:02:57Z grg $
//
// Module: cpu_dma_queue.v
// Project: NF2.1
// Description: Queues/FIFOs sitting between the DMA interface and the user
//              data path.
//
///////////////////////////////////////////////////////////////////////////////

  module cpu_dma_queue
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8,
      parameter ENABLE_HEADER = 1,
      parameter PORT_NUMBER = 0,
      parameter USE_REGS = `CPU_QUEUE_REGS_ENABLE
      )
   (output [DATA_WIDTH-1:0]              out_data,
    output [CTRL_WIDTH-1:0]              out_ctrl,
    output                               out_wr,
    input                                out_rdy,

    input  [DATA_WIDTH-1:0]              in_data,
    input  [CTRL_WIDTH-1:0]              in_ctrl,
    input                                in_wr,
    output                               in_rdy,

    // --- DMA rd rxfifo interface
    output                               cpu_q_dma_pkt_avail,
    output                               cpu_q_dma_rd_rdy,

    input                                cpu_q_dma_rd,
    output [DMA_DATA_WIDTH-1:0]          cpu_q_dma_rd_data,
    output [DMA_CTRL_WIDTH-1:0]          cpu_q_dma_rd_ctrl,

    // DMA wr txfifo interface
    output                               cpu_q_dma_nearly_full,
    output                               cpu_q_dma_can_wr_pkt,

    input                                cpu_q_dma_wr,
    input                                cpu_q_dma_wr_pkt_vld,
    input [DMA_DATA_WIDTH-1:0]           cpu_q_dma_wr_data,
    input [DMA_CTRL_WIDTH-1:0]           cpu_q_dma_wr_ctrl,

    // Register interface
    input                                reg_req,
    input                                reg_rd_wr_L,
    input  [`MAC_GRP_REG_ADDR_WIDTH-1:0] reg_addr,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]    reg_wr_data,

    output [`CPCI_NF2_DATA_WIDTH-1:0]    reg_rd_data,
    output                               reg_ack,

    // --- Misc
    input                                reset,
    input                                clk
    );

   // -------- Internal parameters --------------


   // ------------- Wires/reg ------------------

   wire                          rx_queue_en;
   wire                          rx_pkt_stored;
   wire                          rx_pkt_removed;
   wire                          rx_pkt_dropped;
   wire                          rx_q_underrun;
   wire                          rx_q_overrun;
   wire  [11:0]                  rx_pkt_byte_cnt;
   wire  [9:0]                   rx_pkt_word_cnt;


   wire                          tx_queue_en;
   wire                          tx_pkt_stored;
   wire                          tx_pkt_removed;
   wire                          tx_q_underrun;
   wire                          tx_q_overrun;
   wire [11:0]                   tx_pkt_byte_cnt;
   wire [9:0]                    tx_pkt_word_cnt;

   // ------------- Modules -------------------


cpu_dma_rx_queue #(
      .DATA_WIDTH          (DATA_WIDTH),
      .CTRL_WIDTH          (CTRL_WIDTH),
      .DMA_DATA_WIDTH      (DMA_DATA_WIDTH),
      .DMA_CTRL_WIDTH      (DMA_CTRL_WIDTH),
      .ENABLE_HEADER       (ENABLE_HEADER),
      .PORT_NUMBER         (PORT_NUMBER)
   ) cpu_dma_rx_queue (
      .out_data                     (out_data),
      .out_ctrl                     (out_ctrl),
      .out_wr                       (out_wr),
      .out_rdy                      (out_rdy),

      // DMA wr txfifo interface
      .cpu_q_dma_nearly_full        (cpu_q_dma_nearly_full),
      .cpu_q_dma_can_wr_pkt         (cpu_q_dma_can_wr_pkt),

      .cpu_q_dma_wr                 (cpu_q_dma_wr),
      .cpu_q_dma_wr_pkt_vld         (cpu_q_dma_wr_pkt_vld),
      .cpu_q_dma_wr_data            (cpu_q_dma_wr_data),
      .cpu_q_dma_wr_ctrl            (cpu_q_dma_wr_ctrl),

      // Register interface -- RX
      .rx_queue_en                  (rx_queue_en),
      .rx_pkt_stored                (rx_pkt_stored),
      .rx_pkt_dropped               (rx_pkt_dropped),
      .rx_pkt_removed               (rx_pkt_removed),
      .rx_q_underrun                (rx_q_underrun),
      .rx_q_overrun                 (rx_q_overrun),
      .rx_pkt_byte_cnt              (rx_pkt_byte_cnt),
      .rx_pkt_word_cnt              (rx_pkt_word_cnt),

      // --- Misc
      .reset                        (reset),
      .clk                          (clk)
   );


cpu_dma_tx_queue
   #(
      .DATA_WIDTH          (DATA_WIDTH),
      .CTRL_WIDTH          (CTRL_WIDTH),
      .DMA_DATA_WIDTH      (DMA_DATA_WIDTH),
      .DMA_CTRL_WIDTH      (DMA_CTRL_WIDTH),
      .ENABLE_HEADER       (ENABLE_HEADER)
   ) cpu_dma_tx_queue (
      .in_data                      (in_data),
      .in_ctrl                      (in_ctrl),
      .in_wr                        (in_wr),
      .in_rdy                       (in_rdy),

      // --- DMA rd nterface
      .cpu_q_dma_pkt_avail          (cpu_q_dma_pkt_avail),
      .cpu_q_dma_rd_rdy             (cpu_q_dma_rd_rdy),

      .cpu_q_dma_rd                 (cpu_q_dma_rd),
      .cpu_q_dma_rd_data            (cpu_q_dma_rd_data),
      .cpu_q_dma_rd_ctrl            (cpu_q_dma_rd_ctrl),

      // Register interface -- TX
      .tx_queue_en                  (tx_queue_en),
      .tx_pkt_stored                (tx_pkt_stored),
      .tx_pkt_removed               (tx_pkt_removed),
      .tx_q_underrun                (tx_q_underrun),
      .tx_q_overrun                 (tx_q_overrun),
      .tx_pkt_byte_cnt              (tx_pkt_byte_cnt),
      .tx_pkt_word_cnt              (tx_pkt_word_cnt),

      // --- Misc
      .reset                        (reset),
      .clk                          (clk)
   );


generate
if(USE_REGS == `CPU_QUEUE_REGS_ENABLE) begin
   cpu_dma_queue_regs cpu_dma_queue_regs (
      // Register interface
      .reg_req                               (reg_req),
      .reg_rd_wr_L                           (reg_rd_wr_L),
      .reg_addr                              (reg_addr),
      .reg_wr_data                           (reg_wr_data),

      .reg_rd_data                           (reg_rd_data),
      .reg_ack                               (reg_ack),

      // interface to rx queue
      .rx_queue_en                           (rx_queue_en),

      .rx_pkt_stored                         (rx_pkt_stored),
      .rx_pkt_dropped                        (rx_pkt_dropped),
      .rx_pkt_removed                        (rx_pkt_removed),
      .rx_q_underrun                         (rx_q_underrun),
      .rx_q_overrun                          (rx_q_overrun),
      .rx_pkt_byte_cnt                       (rx_pkt_byte_cnt),
      .rx_pkt_word_cnt                       (rx_pkt_word_cnt),


      // interface to tx queue
      .tx_queue_en                           (tx_queue_en),

      .tx_pkt_stored                         (tx_pkt_stored),
      .tx_pkt_removed                        (tx_pkt_removed),
      .tx_q_underrun                         (tx_q_underrun),
      .tx_q_overrun                          (tx_q_overrun),
      .tx_pkt_byte_cnt                       (tx_pkt_byte_cnt),
      .tx_pkt_word_cnt                       (tx_pkt_word_cnt),

      // --- Misc
      .reset                                 (reset),
      .clk                                   (clk)
   );
end // block:cpu_dma_queue_regs with full registers support
else begin
   cpu_dma_queue_no_regs cpu_dma_queue_regs (
      // Register interface
      .reg_req                               (reg_req),
      .reg_rd_wr_L                           (reg_rd_wr_L),
      .reg_addr                              (reg_addr),
      .reg_wr_data                           (reg_wr_data),

      .reg_rd_data                           (reg_rd_data),
      .reg_ack                               (reg_ack),

      // interface to rx queue
      .rx_queue_en                           (rx_queue_en),

      .rx_pkt_stored                         (rx_pkt_stored),
      .rx_pkt_dropped                        (rx_pkt_dropped),
      .rx_pkt_removed                        (rx_pkt_removed),
      .rx_q_underrun                         (rx_q_underrun),
      .rx_q_overrun                          (rx_q_overrun),
      .rx_pkt_byte_cnt                       (rx_pkt_byte_cnt),
      .rx_pkt_word_cnt                       (rx_pkt_word_cnt),


      // interface to tx queue
      .tx_queue_en                           (tx_queue_en),

      .tx_pkt_stored                         (tx_pkt_stored),
      .tx_pkt_removed                        (tx_pkt_removed),
      .tx_q_underrun                         (tx_q_underrun),
      .tx_q_overrun                          (tx_q_overrun),
      .tx_pkt_byte_cnt                       (tx_pkt_byte_cnt),
      .tx_pkt_word_cnt                       (tx_pkt_word_cnt),

      // --- Misc
      .reset                                 (reset),
      .clk                                   (clk)
   );
end // block:cpu_dma_queue_regs with only queue_en registers support
endgenerate

   // -------------- Logic --------------------

endmodule // cpu_dma_queue
