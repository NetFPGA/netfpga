///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_core.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_core.v
// Project: NetFPGA
// Description: Core module for a NetFPGA design.
//
// This is instantiated within the nf2_top module.
// This should contain internal logic only - not I/O buffers or pads.
//
///////////////////////////////////////////////////////////////////////////////

module nf2_core (
    // Eth 0 MAC to RGMII interfaces
    output [7:0] gmii_0_txd_int,
    output       gmii_0_tx_en_int,
    output       gmii_0_tx_er_int,
    input        gmii_0_crs_int,
    input        gmii_0_col_int,
    input  [7:0] gmii_0_rxd_reg,
    input        gmii_0_rx_dv_reg,
    input        gmii_0_rx_er_reg,
    input        eth_link_0_status,
    input  [1:0] eth_clock_0_speed,
    input        eth_duplex_0_status,

    // Eth 1 MAC to RGMII interfaces
    output [7:0] gmii_1_txd_int,
    output       gmii_1_tx_en_int,
    output       gmii_1_tx_er_int,
    input        gmii_1_crs_int,
    input        gmii_1_col_int,
    input  [7:0] gmii_1_rxd_reg,
    input        gmii_1_rx_dv_reg,
    input        gmii_1_rx_er_reg,
    input        eth_link_1_status,
    input  [1:0] eth_clock_1_speed,
    input        eth_duplex_1_status,


    // Eth 2 MAC to RGMII interfaces
    output [7:0] gmii_2_txd_int,
    output       gmii_2_tx_en_int,
    output       gmii_2_tx_er_int,
    input        gmii_2_crs_int,
    input        gmii_2_col_int,
    input  [7:0] gmii_2_rxd_reg,
    input        gmii_2_rx_dv_reg,
    input        gmii_2_rx_er_reg,
    input        eth_link_2_status,
    input  [1:0] eth_clock_2_speed,
    input        eth_duplex_2_status,


    // Eth 3 MAC to RGMII interfaces
    output [7:0] gmii_3_txd_int,
    output       gmii_3_tx_en_int,
    output       gmii_3_tx_er_int,
    input        gmii_3_crs_int,
    input        gmii_3_col_int,
    input  [7:0] gmii_3_rxd_reg,
    input        gmii_3_rx_dv_reg,
    input        gmii_3_rx_er_reg,
    input        eth_link_3_status,
    input  [1:0] eth_clock_3_speed,
    input        eth_duplex_3_status,

    input        tx_rgmii_clk_int,
    input        rx_rgmii_0_clk_int,
    input        rx_rgmii_1_clk_int,
    input        rx_rgmii_2_clk_int,
    input        rx_rgmii_3_clk_int,



    // CPCI interface and clock

    input                               cpci_clk_int,   // 62.5 MHz
    input                               cpci_rd_wr_L,
    input                               cpci_req,
    input   [`CPCI_NF2_ADDR_WIDTH-1:0]  cpci_addr,
    input   [`CPCI_NF2_DATA_WIDTH-1:0]  cpci_wr_data,
    output  [`CPCI_NF2_DATA_WIDTH-1:0]  cpci_rd_data,
    output                              cpci_data_tri_en,
    output                              cpci_wr_rdy,
    output                              cpci_rd_rdy,

    output                              nf2_err,


    // ---- SRAM 1

    output [`SRAM_ADDR_WIDTH-1:0]   sram1_addr,
    input  [`SRAM_DATA_WIDTH-1:0]   sram1_rd_data,
    output  [`SRAM_DATA_WIDTH-1:0]  sram1_wr_data,
    output                          sram1_tri_en,
    output                          sram1_we,
    output [3:0]                    sram1_bw,
    output                          sram1_zz,

    // ---- SRAM 2

    output [`SRAM_ADDR_WIDTH-1:0]   sram2_addr,
    input  [`SRAM_DATA_WIDTH-1:0]   sram2_rd_data,
    output  [`SRAM_DATA_WIDTH-1:0]  sram2_wr_data,
    output                          sram2_tri_en,
    output                          sram2_we,
    output [3:0]                    sram2_bw,
    output                          sram2_zz,


    // --- DDR interface
    output [3:0]   ddr2_cmd,
    input          ddr2_cmd_ack,
    output [21:0]  ddr2_addr,
    output [1:0]   ddr2_bank_addr,
    output         ddr2_burst_done,
    input [63:0]   ddr2_rd_data,
    input          ddr2_rd_data_valid,
    output [63:0]  ddr2_wr_data,
    output [7:0]   ddr2_wr_data_mask,
    input          ddr2_auto_ref_req,
    input          ddr2_ar_done,
    output [14:0]  ddr2_config1,
    output [12:0]  ddr2_config2,
    input          ddr2_init_val,

    input          ddr2_reset,
    input          ddr2_reset90,

    input          clk_ddr_200,
    input          clk90_ddr_200,

    // --- CPCI DMA handshake signals
    input [1:0]                  dma_op_code_req,
    input [3:0]                  dma_op_queue_id,
    output [1:0]                 dma_op_code_ack,

    // DMA TX data and flow control
    input                        dma_vld_c2n,
    input [`DMA_DATA_WIDTH-1:0]  dma_data_c2n,
    output                       dma_q_nearly_full_n2c,

    // DMA RX data and flow control
    output                       dma_vld_n2c,
    output [`DMA_DATA_WIDTH-1:0] dma_data_n2c,
    input                        dma_q_nearly_full_c2n,

    // enable to drive tri-state bus
    output                       dma_data_tri_en,

    // CPCI debug data
    input  [`CPCI_DEBUG_DATA_WIDTH-1:0] cpci_debug_data,

    // ---  MDC/MDIO PHY control signals

    output  phy_mdc,
    output  phy_mdata_out,
    input   phy_mdata_in,
    output  phy_mdata_tri,

    //--- Debug bus (goes to LA connector)

    output            debug_led,
    output reg [31:0] debug_data,
    output     [1:0]  debug_clk,


    // --- Serial Pins
/*** not used
    output  serial_TXP_0,
    output  serial_TXN_0,
    input   serial_RXP_0,
    input   serial_RXN_0,

    output  serial_TXP_1,
    output  serial_TXN_1,
    input   serial_RXP_1,
    input   serial_RXN_1,
***/

    // --- Spartan configuration pins
    input   cpci_rp_done,
    input   cpci_rp_init_b,
    input   cpci_rp_cclk,

    output  cpci_rp_en,
    output  cpci_rp_prog_b,
    output  cpci_rp_din,

    output  disable_reset,

    // core clock
    input        core_clk_int,

    // misc
    input        reset

    );

   //------------- local parameters --------------
   localparam DATA_WIDTH = 32;
   localparam CTRL_WIDTH = DATA_WIDTH/8;
   localparam NUM_QUEUES = 8;
   localparam PKT_LEN_CNT_WIDTH = 11;

   //---------------- Wires/regs ------------------

   // CHANGE
   assign 	 nf2_err = 1'b 0;

   wire [NUM_QUEUES-1:0]              out_wr;
   wire [NUM_QUEUES-1:0]              out_rdy;
   wire [DATA_WIDTH-1:0]              out_data [NUM_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0]              out_ctrl [NUM_QUEUES-1:0];

   wire [NUM_QUEUES-1:0]              in_wr;
   wire [NUM_QUEUES-1:0]              in_rdy;
   wire [DATA_WIDTH-1:0]              in_data [NUM_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0]              in_ctrl [NUM_QUEUES-1:0];

   wire                               wr_0_req;
   wire [`SRAM_ADDR_WIDTH-1:0]        wr_0_addr;
   wire [DATA_WIDTH+CTRL_WIDTH-1:0]   wr_0_data;
   wire                               wr_0_ack;

   wire                               rd_0_req;
   wire [`SRAM_ADDR_WIDTH-1:0]        rd_0_addr;
   wire [DATA_WIDTH+CTRL_WIDTH-1:0]   rd_0_data;
   wire                               rd_0_vld;
   wire                               rd_0_ack;

   wire [`SRAM_ADDR_WIDTH-1:0]        sram_addr;

   wire [`CPCI_NF2_ADDR_WIDTH-1:0]    cpci_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpci_reg_rd_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpci_reg_wr_data;

   wire                               core_reg_req;
   wire                               core_reg_rd_wr_L;
   wire                               core_reg_ack;
   wire [`CORE_REG_ADDR_WIDTH-1:0]    core_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    core_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    core_reg_rd_data;

   wire                               sram_reg_req;
   wire                               sram_reg_rd_wr_L;
   wire                               sram_reg_ack;
   wire [`SRAM_REG_ADDR_WIDTH-1:0]    sram_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    sram_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    sram_reg_rd_data;

   wire                               udp_reg_req;
   wire                               udp_reg_rd_wr_L;
   wire                               udp_reg_ack;
   wire [`UDP_REG_ADDR_WIDTH-1:0]     udp_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    udp_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    udp_reg_rd_data;

   wire                               dram_reg_req;
   wire                               dram_reg_rd_wr_L;
   wire                               dram_reg_ack;
   wire [`DRAM_REG_ADDR_WIDTH-1:0]    dram_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dram_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dram_reg_rd_data;

   wire [`MAC_GRP_REG_ADDR_WIDTH-1:0] mac_grp_reg_addr[3:0];
   wire [3:0]                         mac_grp_reg_req;
   wire [3:0]                         mac_grp_reg_rd_wr_L;
   wire [3:0]                         mac_grp_reg_ack;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    mac_grp_reg_wr_data[3:0];
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    mac_grp_reg_rd_data[3:0];

   wire [`CPU_QUEUE_REG_ADDR_WIDTH-1:0] cpu_queue_reg_addr[3:0];
   wire [3:0]                         cpu_queue_reg_req;
   wire [3:0]                         cpu_queue_reg_rd_wr_L;
   wire [3:0]                         cpu_queue_reg_ack;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpu_queue_reg_wr_data[3:0];
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpu_queue_reg_rd_data[3:0];

   wire [3:0]                         cpu_q_dma_pkt_avail;
   wire [3:0]                         cpu_q_dma_rd_rdy;
   wire [3:0]                         cpu_q_dma_rd;
   wire [`DMA_DATA_WIDTH-1:0]         cpu_q_dma_rd_data [3:0];
   wire [`DMA_CTRL_WIDTH-1:0]         cpu_q_dma_rd_ctrl[3:0];

   wire [3:0]                         cpu_q_dma_nearly_full;
   wire [3:0]                         cpu_q_dma_can_wr_pkt;
   wire [3:0]                         cpu_q_dma_wr;
   wire [3:0]                         cpu_q_dma_wr_pkt_vld;
   wire [`DMA_DATA_WIDTH-1:0]         cpu_q_dma_wr_data[3:0];
   wire [`DMA_CTRL_WIDTH-1:0]         cpu_q_dma_wr_ctrl[3:0];

   wire [`DMA_REG_ADDR_WIDTH -1:0]    dma_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dma_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dma_rd_data;

   wire 			      enable_dma;

   //---------------------------------------------
   //
   // MAC rx and tx queues
   //
   //---------------------------------------------

/*
   nf2_mac_grp #(.DATA_WIDTH(DATA_WIDTH),
                 .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH))
   nf2_mac_grp_0
     (// register interface
      .mac_grp_reg_req        (mac_grp_reg_req[0]),
      .mac_grp_reg_rd_wr_L    (mac_grp_reg_rd_wr_L[0]),
      .mac_grp_reg_addr       (mac_grp_reg_addr[0]),
      .mac_grp_reg_wr_data    (mac_grp_reg_wr_data[0]),
      .mac_grp_reg_rd_data    (mac_grp_reg_rd_data[0]),
      .mac_grp_reg_ack        (mac_grp_reg_ack[0]),
      // output to data path interface
      .out_wr                 (in_wr[0]),
      .out_rdy                (in_rdy[0]),
      .out_data               (in_data[0]),
      .out_ctrl               (in_ctrl[0]),
      // input from data path interface
      .in_wr                  (out_wr[0]),
      .in_rdy                 (out_rdy[0]),
      .in_data                (out_data[0]),
      .in_ctrl                (out_ctrl[0]),
      // pins
      .gmii_tx_d              (gmii_0_txd_int),
      .gmii_tx_en             (gmii_0_tx_en_int),
      .gmii_tx_er             (gmii_0_tx_er_int),
      .gmii_crs               (gmii_0_crs_int),
      .gmii_col               (gmii_0_col_int),
      .gmii_rx_d              (gmii_0_rxd_reg),
      .gmii_rx_dv             (gmii_0_rx_dv_reg),
      .gmii_rx_er             (gmii_0_rx_er_reg),
      // misc
      .txgmiimiiclk           (tx_rgmii_clk_int),
      .rxgmiimiiclk           (rx_rgmii_0_clk_int),
      .clk                    (core_clk_int),
      .reset                  (reset)
      );

   nf2_mac_grp #(.DATA_WIDTH(DATA_WIDTH),
                 .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH))
   nf2_mac_grp_1
     (// register interface
      .mac_grp_reg_req        (mac_grp_reg_req[1]),
      .mac_grp_reg_rd_wr_L    (mac_grp_reg_rd_wr_L[1]),
      .mac_grp_reg_addr       (mac_grp_reg_addr[1]),
      .mac_grp_reg_wr_data    (mac_grp_reg_wr_data[1]),
      .mac_grp_reg_rd_data    (mac_grp_reg_rd_data[1]),
      .mac_grp_reg_ack        (mac_grp_reg_ack[1]),
      // output to data path interface
      .out_wr                 (in_wr[2]),
      .out_rdy                (in_rdy[2]),
      .out_data               (in_data[2]),
      .out_ctrl               (in_ctrl[2]),
      // input from data path interface
      .in_wr                  (out_wr[2]),
      .in_rdy                 (out_rdy[2]),
      .in_data                (out_data[2]),
      .in_ctrl                (out_ctrl[2]),
      // pins
      .gmii_tx_d              (gmii_1_txd_int),
      .gmii_tx_en             (gmii_1_tx_en_int),
      .gmii_tx_er             (gmii_1_tx_er_int),
      .gmii_crs               (gmii_1_crs_int),
      .gmii_col               (gmii_1_col_int),
      .gmii_rx_d              (gmii_1_rxd_reg),
      .gmii_rx_dv             (gmii_1_rx_dv_reg),
      .gmii_rx_er             (gmii_1_rx_er_reg),
      // misc
      .txgmiimiiclk           (tx_rgmii_clk_int),
      .rxgmiimiiclk           (rx_rgmii_1_clk_int),
      .clk                    (core_clk_int),
      .reset                  (reset)
      );

   nf2_mac_grp #(.DATA_WIDTH(DATA_WIDTH),
                 .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH))
   nf2_mac_grp_2
     (// register interface
      .mac_grp_reg_req        (mac_grp_reg_req[2]),
      .mac_grp_reg_rd_wr_L    (mac_grp_reg_rd_wr_L[2]),
      .mac_grp_reg_addr       (mac_grp_reg_addr[2]),
      .mac_grp_reg_wr_data    (mac_grp_reg_wr_data[2]),
      .mac_grp_reg_rd_data    (mac_grp_reg_rd_data[2]),
      .mac_grp_reg_ack        (mac_grp_reg_ack[2]),
      // output to data path interface
      .out_wr                 (in_wr[4]),
      .out_rdy                (in_rdy[4]),
      .out_data               (in_data[4]),
      .out_ctrl               (in_ctrl[4]),
      // input from data path interface
      .in_wr                  (out_wr[4]),
      .in_rdy                 (out_rdy[4]),
      .in_data                (out_data[4]),
      .in_ctrl                (out_ctrl[4]),
      // pins
      .gmii_tx_d              (gmii_2_txd_int),
      .gmii_tx_en             (gmii_2_tx_en_int),
      .gmii_tx_er             (gmii_2_tx_er_int),
      .gmii_crs               (gmii_2_crs_int),
      .gmii_col               (gmii_2_col_int),
      .gmii_rx_d              (gmii_2_rxd_reg),
      .gmii_rx_dv             (gmii_2_rx_dv_reg),
      .gmii_rx_er             (gmii_2_rx_er_reg),
      // misc
      .txgmiimiiclk           (tx_rgmii_clk_int),
      .rxgmiimiiclk           (rx_rgmii_2_clk_int),
      .clk                    (core_clk_int),
      .reset                  (reset)
      );

   nf2_mac_grp #(.DATA_WIDTH(DATA_WIDTH),
                 .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH))
   nf2_mac_grp_3
     (// register interface
      .mac_grp_reg_req        (mac_grp_reg_req[3]),
      .mac_grp_reg_rd_wr_L    (mac_grp_reg_rd_wr_L[3]),
      .mac_grp_reg_addr       (mac_grp_reg_addr[3]),
      .mac_grp_reg_wr_data    (mac_grp_reg_wr_data[3]),
      .mac_grp_reg_rd_data    (mac_grp_reg_rd_data[3]),
      .mac_grp_reg_ack        (mac_grp_reg_ack[3]),
      // output to data path interface
      .out_wr                 (in_wr[6]),
      .out_rdy                (in_rdy[6]),
      .out_data               (in_data[6]),
      .out_ctrl               (in_ctrl[6]),
      // input from data path interface
      .in_wr                  (out_wr[6]),
      .in_rdy                 (out_rdy[6]),
      .in_data                (out_data[6]),
      .in_ctrl                (out_ctrl[6]),
      // pins
      .gmii_tx_d              (gmii_3_txd_int),
      .gmii_tx_en             (gmii_3_tx_en_int),
      .gmii_tx_er             (gmii_3_tx_er_int),
      .gmii_crs               (gmii_3_crs_int),
      .gmii_col               (gmii_3_col_int),
      .gmii_rx_d              (gmii_3_rxd_reg),
      .gmii_rx_dv             (gmii_3_rx_dv_reg),
      .gmii_rx_er             (gmii_3_rx_er_reg),
      // misc
      .txgmiimiiclk           (tx_rgmii_clk_int),
      .rxgmiimiiclk           (rx_rgmii_3_clk_int),
      .clk                    (core_clk_int),
      .reset                  (reset)
      );
*/

   //---------------------------------------------
   //
   // CPU Queues
   //
   //---------------------------------------------

/*
   // CPU DMA QUEUE
   generate
      genvar k;
      for(k=0; k<NUM_QUEUES/2; k=k+1) begin: cpu_queues
         cpu_dma_queue
         #(.DATA_WIDTH(DATA_WIDTH),
           .CTRL_WIDTH(CTRL_WIDTH),
           .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH),
	   .DMA_DATA_WIDTH(DMA_DATA_WIDTH),
	   .DMA_CTRL_WIDTH(DMA_CTRL_WIDTH)
	   ) cpu_dma_queue_i

           (.out_data (in_data[2*k+1]),
            .out_ctrl (in_ctrl[2*k+1]),
            .out_wr (in_wr[2*k+1]),
            .out_rdy (in_rdy[2*k+1]),
            .in_data (out_data[2*k+1]),
            .in_ctrl (out_ctrl[2*k+1]),
            .in_wr (out_wr[2*k+1]),
            .in_rdy (out_rdy[2*k+1]),

            // --- Register interface
            .cpu_queue_reg_req (cpu_queue_reg_req[k]),
            .cpu_queue_reg_rd_wr_L (cpu_queue_reg_rd_wr_L[k]),
            .cpu_queue_reg_addr (cpu_queue_reg_addr[k]),
            .cpu_queue_reg_wr_data (cpu_queue_reg_wr_data[k]),
            .cpu_queue_reg_rd_data (cpu_queue_reg_rd_data[k]),
            .cpu_queue_reg_ack (cpu_queue_reg_ack[k]),

	    // --- enable DMA
	    .enable_dma (enable_dma),

            // --- DMA rd rxfifo interface
	    .cpu_q_dma_pkt_avail (cpu_q_dma_pkt_avail[k]),

	    .cpu_q_dma_rd (cpu_q_dma_rd[k]),
	    .cpu_q_dma_rd_data (cpu_q_dma_rd_data[k]),
	    .cpu_q_dma_rd_ctrl (cpu_q_dma_rd_ctrl[k]),

	    // DMA wr txfifo interface
	    .cpu_q_dma_nearly_full (cpu_q_dma_nearly_full[k]),

	    .cpu_q_dma_wr (cpu_q_dma_wr[k]),
	    .cpu_q_dma_wr_data (cpu_q_dma_wr_data[k]),
	    .cpu_q_dma_wr_ctrl (cpu_q_dma_wr_ctrl[k]),

            // --- Misc
            .reset (reset),
            .clk (core_clk_int)
            );
      end // block: cpu_queues

   endgenerate
*/

   //---------------------------------------------
   //
   // CPCI interface
   //
   //---------------------------------------------

   cpci_bus cpci_bus (
        .cpci_rd_wr_L      (cpci_rd_wr_L),
        .cpci_req          (cpci_req),
        .cpci_addr         (cpci_addr),
        .cpci_wr_data      (cpci_wr_data),
        .cpci_rd_data      (cpci_rd_data),
        .cpci_data_tri_en  (cpci_data_tri_en),
        .cpci_wr_rdy       (cpci_wr_rdy),
        .cpci_rd_rdy       (cpci_rd_rdy),

        .fifo_empty        (cpci_reg_fifo_empty),
        .fifo_rd_en        (cpci_reg_fifo_rd_en),
        .bus_rd_wr_L       (cpci_reg_rd_wr_L),
        .bus_addr          (cpci_reg_addr),
        .bus_wr_data       (cpci_reg_wr_data),
        .bus_rd_data       (cpci_reg_rd_data),
        .bus_rd_vld        (cpci_reg_rd_vld),

        .reset           (reset),
        .pci_clk         (cpci_clk_int),
        .core_clk        (core_clk_int)
        );

   // synthesis attribute keep_hierarchy of cpci_bus is false;

   //--------------------------------------------------
   //
   // --- SRAM CONTROLLERS
   // note: register access is unimplemented yet
   //--------------------------------------------------
/*
   wire [DATA_WIDTH+CTRL_WIDTH-1:0] sram1_wr_data_int;
   wire [DATA_WIDTH+CTRL_WIDTH-1:0] sram2_wr_data_int;
   reg  [DATA_WIDTH+CTRL_WIDTH-1:0] sram1_wr_data;
   reg  [DATA_WIDTH+CTRL_WIDTH-1:0] sram2_wr_data;
   reg  [DATA_WIDTH+CTRL_WIDTH-1:0] sram1_rd_data;
   reg  [DATA_WIDTH+CTRL_WIDTH-1:0] sram2_rd_data;
   wire                             sram1_tri_en_int;
   wire                             sram2_tri_en_int;
   reg                              sram1_tri_en;
   reg                              sram2_tri_en;
   wire [CTRL_WIDTH-1:0]            sram1_bw;
   wire [CTRL_WIDTH-1:0]            sram2_bw;
   wire                             sram1_we;
   wire                             sram2_we;

   sram_arbiter
     #(.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .SRAM_DATA_WIDTH(DATA_WIDTH+CTRL_WIDTH))
   sram_arbiter_0
     (// --- Requesters   (read and/or write)
      .wr_0_req           (wr_0_req),
      .wr_0_addr          (wr_0_addr),
      .wr_0_data          (wr_0_data),
      .wr_0_ack           (wr_0_ack),

      .rd_0_req           (rd_0_req),
      .rd_0_addr          (rd_0_addr),
      .rd_0_data          (rd_0_data),
      .rd_0_ack           (rd_0_ack),
      .rd_0_vld           (rd_0_vld),

       // --- sram_access
      .sram_addr          (sram1_addr_int),
      .sram_wr_data       (sram1_wr_data_int),
      .sram_rd_data       (sram1_rd_data),
      .sram_we            (sram1_we_int),
      .sram_bw            (sram1_bw_int),
      .sram_tri_en        (sram1_tri_en_int),

       // --- Misc
      .reset              (reset),
      .clk                (core_clk_int)
      );

   sram_arbiter
     #(.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .SRAM_DATA_WIDTH(DATA_WIDTH+CTRL_WIDTH))
   sram_arbiter_1
     (// --- Requesters   (read and/or write)
      .wr_0_req           (wr_1_req),
      .wr_0_addr          (wr_1_addr),
      .wr_0_data          (wr_1_data),
      .wr_0_ack           (wr_1_ack),

      .rd_0_req           (rd_1_req),
      .rd_0_addr          (rd_1_addr),
      .rd_0_data          (rd_1_data),
      .rd_0_ack           (rd_1_ack),
      .rd_0_vld           (rd_1_vld),

       // --- sram_access
      .sram_addr          (sram2_addr_int),
      .sram_wr_data       (sram2_wr_data_int),
      .sram_rd_data       (sram2_rd_data),
      .sram_we            (sram2_we_int),
      .sram_bw            (sram2_bw_int),
      .sram_tri_en        (sram2_tri_en_int),

       // --- Misc
      .reset              (reset),
      .clk                (core_clk_int)
      );

   assign sram1_data = sram1_tri_en ? sram1_wr_data[35:0] : 36'bz;
   assign sram2_data = sram2_tri_en ? sram2_wr_data[35:0] : 36'bz;
   always @(posedge core_clk_int) begin
      sram1_rd_data   <= sram1_data;
      sram2_rd_data   <= sram2_data;
      sram1_wr_data   <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        sram1_wr_data_int;
      sram2_wr_data   <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        sram2_wr_data_int;
      sram1_we       <= sram1_we_int;
      sram2_we       <= sram2_we_int;
      sram1_bw       <= sram1_bw_int;
      sram2_bw       <= sram2_bw_int;
      sram1_addr     <= sram1_addr_int;
      sram2_addr     <= sram1_addr_int;
      sram1_tri_en    <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        sram1_tri_en_int;
      sram2_tri_en    <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        sram2_tri_en_int;
   end

   assign    sram1_zz = 1'b0;
   assign    sram2_zz = 1'b0;

   // synthesis attribute keep_hierarchy of sram64.sram_arbiter is false;
   // synthesis attribute keep_hierarchy of sram32.sram_arbiter is false;
   // synthesis attribute iob of sram1_data is true;
   // synthesis attribute iob of sram2_data is true;
   // synthesis attribute iob of sram1_bw is true;
   // synthesis attribute iob of sram2_bw is true;
   // synthesis attribute iob of sram1_we is true;
   // synthesis attribute iob of sram2_we is true;
   // synthesis attribute iob of sram1_addr is true;
   // synthesis attribute iob of sram2_addr is true;
*/
   assign sram1_wr_data = 'h0;
   assign sram2_wr_data = 'h0;

   assign sram1_tri_en = 1'b0;
   assign sram2_tri_en = 1'b0;

   assign sram1_addr = 'h0;
   assign sram1_we = 1'b1;
   assign sram1_bw = 1'b1;

   assign sram2_addr = 'h0;
   assign sram2_we = 1'b1;
   assign sram2_bw = 1'b1;



   //--------------------------------------------------
   //
   // --- DDR test
   //
   //--------------------------------------------------
/*   ddr2_test ddr2_test(
               .done             (dram_done),
               .success          (dram_success),
               .cmd              (ddr2_cmd),
               .cmd_ack          (ddr2_cmd_ack),
               .addr             (ddr2_addr),
               .bank_addr        (ddr2_bank_addr),
               .burst_done       (ddr2_burst_done),
               .rd_data          (ddr2_rd_data),
               .rd_data_valid    (ddr2_rd_data_valid),
               .wr_data          (ddr2_wr_data),
               .wr_data_mask     (ddr2_wr_data_mask),
               .config1          (ddr2_config1),
               .config2          (ddr2_config2),
               .init_val         (ddr2_init_val),
               .ar_done          (ddr2_ar_done),
               .auto_ref_req     (ddr2_auto_ref_req),
               .reset            (ddr2_reset),
               .clk              (clk_ddr_200),
               .clk90            (clk90_ddr_200),
               .ctrl_reg_req     (1'b0),
               .ctrl_reg_rd_wr_L (1'b1),
               .ctrl_reg_addr    (10'h0),
               .ctrl_reg_wr_data (0),
               .ctrl_reg_rd_data (),
               .ctrl_reg_ack     (),
               .dram_reg_req     (dram_req),
               .dram_reg_rd_wr_L (dram_rd_wr_L),
               .dram_reg_addr    (dram_addr),
               .dram_reg_wr_data (dram_wr_data),
               .dram_reg_rd_data (dram_rd_data),
               .dram_reg_ack     (dram_ack),
               .clk_core_125     (core_clk_int),
               .reset_core       (reset)
            );
*/
   //-------------------------------------------------
   // User data path
   //-------------------------------------------------

/*
   user_data_path
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_QUEUES),
       .NUM_INPUT_QUEUES(NUM_QUEUES),
       .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH)) user_data_path
       (.in_data_0 (in_data[0]),
        .in_ctrl_0 (in_ctrl[0]),
        .in_wr_0 (in_wr[0]),
        .in_rdy_0 (in_rdy[0]),

        .in_data_1 (in_data[1]),
        .in_ctrl_1 (in_ctrl[1]),
        .in_wr_1 (in_wr[1]),
        .in_rdy_1 (in_rdy[1]),

        .in_data_2 (in_data[2]),
        .in_ctrl_2 (in_ctrl[2]),
        .in_wr_2 (in_wr[2]),
        .in_rdy_2 (in_rdy[2]),

        .in_data_3 (in_data[3]),
        .in_ctrl_3 (in_ctrl[3]),
        .in_wr_3 (in_wr[3]),
        .in_rdy_3 (in_rdy[3]),

        .in_data_4 (in_data[4]),
        .in_ctrl_4 (in_ctrl[4]),
        .in_wr_4 (in_wr[4]),
        .in_rdy_4 (in_rdy[4]),

        .in_data_5 (in_data[5]),
        .in_ctrl_5 (in_ctrl[5]),
        .in_wr_5 (in_wr[5]),
        .in_rdy_5 (in_rdy[5]),

        .in_data_6 (in_data[6]),
        .in_ctrl_6 (in_ctrl[6]),
        .in_wr_6 (in_wr[6]),
        .in_rdy_6 (in_rdy[6]),

        .in_data_7 (in_data[7]),
        .in_ctrl_7 (in_ctrl[7]),
        .in_wr_7 (in_wr[7]),
        .in_rdy_7 (in_rdy[7]),
*/
        /****  not used
         // --- Interface to SATA
         .in_data_5 (in_data[5]),
         .in_ctrl_5 (in_ctrl[5]),
         .in_wr_5 (in_wr[5]),
         .in_rdy_5 (in_rdy[5]),

         // --- Interface to the loopback queue
         .in_data_6 (in_data[6]),
         .in_ctrl_6 (in_ctrl[6]),
         .in_wr_6 (in_wr[6]),
         .in_rdy_6 (in_rdy[6]),

         // --- Interface to a user queue
         .in_data_7 (in_data[7]),
         .in_ctrl_7 (in_ctrl[7]),
         .in_wr_7 (in_wr[7]),
         .in_rdy_7 (in_rdy[7]),
         *****/
/*
        // interface to tx queues
        .out_data_0 (out_data[0]),
        .out_ctrl_0 (out_ctrl[0]),
        .out_wr_0 (out_wr[0]),
        .out_rdy_0 (out_rdy[0]),

        .out_data_1 (out_data[1]),
        .out_ctrl_1 (out_ctrl[1]),
        .out_wr_1 (out_wr[1]),
        .out_rdy_1 (out_rdy[1]),

        .out_data_2 (out_data[2]),
        .out_ctrl_2 (out_ctrl[2]),
        .out_wr_2 (out_wr[2]),
        .out_rdy_2 (out_rdy[2]),

        .out_data_3 (out_data[3]),
        .out_ctrl_3 (out_ctrl[3]),
        .out_wr_3 (out_wr[3]),
        .out_rdy_3 (out_rdy[3]),

        .out_data_4 (out_data[4]),
        .out_ctrl_4 (out_ctrl[4]),
        .out_wr_4 (out_wr[4]),
        .out_rdy_4 (out_rdy[4]),

        .out_data_5 (out_data[5]),
        .out_ctrl_5 (out_ctrl[5]),
        .out_wr_5 (out_wr[5]),
        .out_rdy_5 (out_rdy[5]),

        .out_data_6 (out_data[6]),
        .out_ctrl_6 (out_ctrl[6]),
        .out_wr_6 (out_wr[6]),
        .out_rdy_6 (out_rdy[6]),

        .out_data_7 (out_data[7]),
        .out_ctrl_7 (out_ctrl[7]),
        .out_wr_7 (out_wr[7]),
        .out_rdy_7 (out_rdy[7]),

*/
        /****  not used
         // --- Interface to SATA
         .out_data_5 (out_data[5]),
         .out_ctrl_5 (out_ctrl[5]),
         .out_wr_5 (out_wr[5]),
         .out_rdy_5 (out_rdy[5]),

         // --- Interface to the loopback queue
         .out_data_6 (out_data[6]),
         .out_ctrl_6 (out_ctrl[6]),
         .out_wr_6 (out_wr[6]),
         .out_rdy_6 (out_rdy[6]),

         // --- Interface to a user queue
         .out_data_7 (out_data[7]),
         .out_ctrl_7 (out_ctrl[7]),
         .out_wr_7 (out_wr[7]),
         .out_rdy_7 (out_rdy[7]),
         *****/
/*

        // interface to SRAM
        .wr_0_addr (wr_0_addr),
        .wr_0_req (wr_0_req),
        .wr_0_ack (wr_0_ack),
        .wr_0_data (wr_0_data),
        .rd_0_ack (rd_0_ack),
        .rd_0_data (rd_0_data),
        .rd_0_vld (rd_0_vld),
        .rd_0_addr (rd_0_addr),
        .rd_0_req (rd_0_req),

*/
        // interface to DRAM
        /* TBD */
/*

        // register interface
        .udp_reg_req (udp_reg_req),
        .udp_reg_rd_wr_L (udp_reg_rd_wr_L),
        .udp_reg_addr (udp_reg_addr),
        .udp_reg_wr_data (udp_reg_wr_data),
        .udp_reg_rd_data (udp_reg_rd_data),
        .udp_reg_ack (udp_reg_ack),

        // misc
        .reset (reset),
        .clk (core_clk_int));
*/



   //-------------------------------------------------
   //
   // register address decoder, register bus mux and demux
   //
   //-----------------------------------------------

   nf2_reg_grp nf2_reg_grp_u
     (// interface to cpci_bus
      .fifo_empty        (cpci_reg_fifo_empty),
      .fifo_rd_en        (cpci_reg_fifo_rd_en),
      .bus_rd_wr_L       (cpci_reg_rd_wr_L),
      .bus_addr          (cpci_reg_addr),
      .bus_wr_data       (cpci_reg_wr_data),
      .bus_rd_data       (cpci_reg_rd_data),
      .bus_rd_vld        (cpci_reg_rd_vld),

      // interface to core
      .core_reg_req           (core_reg_req),
      .core_reg_rd_wr_L       (core_reg_rd_wr_L),
      .core_reg_addr          (core_reg_addr),
      .core_reg_wr_data       (core_reg_wr_data),
      .core_reg_rd_data       (core_reg_rd_data),
      .core_reg_ack           (core_reg_ack),

      // interface to SRAM
      .sram_reg_req           (sram_reg_req),
      .sram_reg_rd_wr_L       (sram_reg_rd_wr_L),
      .sram_reg_addr          (sram_reg_addr),
      .sram_reg_wr_data       (sram_reg_wr_data),
      .sram_reg_rd_data       (sram_reg_rd_data),
      .sram_reg_ack           (sram_reg_ack),

      // interface to user data path
      .udp_reg_req            (udp_reg_req),
      .udp_reg_rd_wr_L        (udp_reg_rd_wr_L),
      .udp_reg_addr           (udp_reg_addr),
      .udp_reg_wr_data        (udp_reg_wr_data),
      .udp_reg_rd_data        (udp_reg_rd_data),
      .udp_reg_ack            (udp_reg_ack),

      // interface to DRAM
      .dram_reg_req           (dram_reg_req),
      .dram_reg_rd_wr_L       (dram_reg_rd_wr_L),
      .dram_reg_addr          (dram_reg_addr),
      .dram_reg_wr_data       (dram_reg_wr_data),
      .dram_reg_rd_data       (dram_reg_rd_data),
      .dram_reg_ack           (dram_reg_ack),

      // misc
      .clk                    (core_clk_int),
      .reset                  (reset)

      );

   wire [3:0]                         core_4mb_reg_req;
   wire [3:0]                         core_4mb_reg_rd_wr_L;
   wire [3:0]                         core_4mb_reg_ack;
   wire [4 * (`CORE_REG_ADDR_WIDTH - 2)-1:0] core_4mb_reg_addr;
   wire [4 * `CPCI_NF2_DATA_WIDTH-1:0] core_4mb_reg_wr_data;
   wire [4 * `CPCI_NF2_DATA_WIDTH-1:0] core_4mb_reg_rd_data;

reg_grp #(
      .REG_ADDR_BITS(`CORE_REG_ADDR_WIDTH),
      .NUM_OUTPUTS(4)
   ) core_4mb_reg_grp
   (
      // Upstream register interface
      .reg_req             (core_reg_req),
      .reg_rd_wr_L         (core_reg_rd_wr_L),
      .reg_addr            (core_reg_addr),
      .reg_wr_data         (core_reg_wr_data),

      .reg_ack             (core_reg_ack),
      .reg_rd_data         (core_reg_rd_data),


      // Downstream register interface
      .local_reg_req       (core_4mb_reg_req),
      .local_reg_rd_wr_L   (core_4mb_reg_rd_wr_L),
      .local_reg_addr      (core_4mb_reg_addr),
      .local_reg_wr_data   (core_4mb_reg_wr_data),

      .local_reg_ack       (core_4mb_reg_ack),
      .local_reg_rd_data   (core_4mb_reg_rd_data),


      //-- misc
      .clk                 (core_clk_int),
      .reset               (reset)
   );

   wire [15:0]                         core_256kb_0_reg_req;
   wire [15:0]                         core_256kb_0_reg_rd_wr_L;
   wire [15:0]                         core_256kb_0_reg_ack;
   wire [16 * (`CORE_REG_ADDR_WIDTH - 2 - 4)-1:0] core_256kb_0_reg_addr;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_0_reg_wr_data;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_0_reg_rd_data;

reg_grp #(
      .REG_ADDR_BITS(`CORE_REG_ADDR_WIDTH - 2),
      .NUM_OUTPUTS(16)
   ) core_256kb_0_reg_grp
   (
      // Upstream register interface
      .reg_req             (core_4mb_reg_req[`WORD(1,1)]),
      .reg_ack             (core_4mb_reg_ack[`WORD(1,1)]),
      .reg_rd_wr_L         (core_4mb_reg_rd_wr_L[`WORD(1,1)]),
      .reg_addr            (core_4mb_reg_addr[`WORD(1, `CORE_REG_ADDR_WIDTH - 2)]),

      .reg_rd_data         (core_4mb_reg_rd_data[`WORD(1, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data         (core_4mb_reg_wr_data[`WORD(1, `CPCI_NF2_DATA_WIDTH)]),


      // Downstream register interface
      .local_reg_req       (core_256kb_0_reg_req),
      .local_reg_rd_wr_L   (core_256kb_0_reg_rd_wr_L),
      .local_reg_addr      (core_256kb_0_reg_addr),
      .local_reg_wr_data   (core_256kb_0_reg_wr_data),

      .local_reg_ack       (core_256kb_0_reg_ack),
      .local_reg_rd_data   (core_256kb_0_reg_rd_data),


      //-- misc
      .clk                 (core_clk_int),
      .reset               (reset)
   );


prog_main prog_main (
      // Control register interface signals
      .ctrl_reg_req        (core_256kb_0_reg_req[`WORD(1,1)]),
      .ctrl_reg_ack        (core_256kb_0_reg_ack[`WORD(1,1)]),
      .ctrl_reg_rd_wr_L    (core_256kb_0_reg_rd_wr_L[`WORD(1,1)]),

      .ctrl_reg_addr       (core_256kb_0_reg_addr[`WORD(1,`CORE_REG_ADDR_WIDTH - 2 - 4)]),

      .ctrl_reg_rd_data    (core_256kb_0_reg_rd_data[`WORD(1,`CPCI_NF2_DATA_WIDTH)]),
      .ctrl_reg_wr_data    (core_256kb_0_reg_wr_data[`WORD(1,`CPCI_NF2_DATA_WIDTH)]),

      // RAM register interface signals
      .ram_reg_req         (core_256kb_0_reg_req[`WORD(2,1)]),
      .ram_reg_ack         (core_256kb_0_reg_ack[`WORD(2,1)]),
      .ram_reg_rd_wr_L     (core_256kb_0_reg_rd_wr_L[`WORD(2,1)]),

      .ram_reg_addr        (core_256kb_0_reg_addr[`WORD(2,`CORE_REG_ADDR_WIDTH - 2 - 4)]),

      .ram_reg_rd_data     (core_256kb_0_reg_rd_data[`WORD(2,`CPCI_NF2_DATA_WIDTH)]),
      .ram_reg_wr_data     (core_256kb_0_reg_wr_data[`WORD(2,`CPCI_NF2_DATA_WIDTH)]),

      .disable_reset       (disable_reset),

      // Reprogramming signals
      .cpci_rp_done        (cpci_rp_done),
      .cpci_rp_init_b      (cpci_rp_init_b),
      .cpci_rp_cclk        (cpci_rp_cclk),

      .cpci_rp_en          (cpci_rp_en),
      .cpci_rp_prog_b      (cpci_rp_prog_b),
      .cpci_rp_din         (cpci_rp_din),

      //
      .clk                 (core_clk_int),
      .reset               (reset)
   );

device_id_reg #(
      .DEVICE_ID  (`DEVICE_ID),
      .MAJOR      (`DEVICE_MAJOR),
      .MINOR      (`DEVICE_MINOR),
      .REVISION   (`DEVICE_REVISION),
      .PROJ_DIR   (`DEVICE_PROJ_DIR),
      .PROJ_NAME  (`DEVICE_PROJ_NAME),
      .PROJ_DESC  (`DEVICE_PROJ_DESC)
   ) device_id_reg (
      // Register interface signals
      .reg_req          (core_256kb_0_reg_req[`WORD(0,1)]),
      .reg_ack          (core_256kb_0_reg_ack[`WORD(0,1)]),
      .reg_rd_wr_L      (core_256kb_0_reg_rd_wr_L[`WORD(0,1)]),

      .reg_addr         (core_256kb_0_reg_addr[`WORD(0,`CORE_REG_ADDR_WIDTH - 2 - 4)]),

      .reg_rd_data      (core_256kb_0_reg_rd_data[`WORD(0,`CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data      (core_256kb_0_reg_wr_data[`WORD(0,`CPCI_NF2_DATA_WIDTH)]),

      //
      .clk              (core_clk_int),
      .reset            (reset)
   );

   // ====================================
   // Unused register blocks

   generate
      genvar k;

      // 4 MB blocks
      for (k = 0; k < 4; k = k + 1) begin: unused_reg_4mb
         if (k != 1) begin
            unused_reg
               #(
                  .REG_ADDR_WIDTH(`CORE_REG_ADDR_WIDTH - 2)
               ) unused_reg_4mb_0 (
                  // Register interface signals
                  .reg_req          (core_4mb_reg_req[`WORD(k,1)]),
                  .reg_ack          (core_4mb_reg_ack[`WORD(k,1)]),
                  .reg_rd_wr_L      (core_4mb_reg_rd_wr_L[`WORD(k,1)]),

                  .reg_addr         (core_4mb_reg_addr[`WORD(k, `CORE_REG_ADDR_WIDTH - 2)]),

                  .reg_rd_data      (core_4mb_reg_rd_data[`WORD(k, `CPCI_NF2_DATA_WIDTH)]),
                  .reg_wr_data      (core_4mb_reg_wr_data[`WORD(k, `CPCI_NF2_DATA_WIDTH)]),

                  //
                  .clk              (core_clk_int),
                  .reset            (reset)
               );
         end // if (k != 1)
      end // block: unused_reg_4mb

      // 256 KB blocks
      for (k = 3; k < 16; k = k + 1) begin: unused_reg_256kb
         unused_reg
            #(
               .REG_ADDR_WIDTH(`CORE_REG_ADDR_WIDTH - 2 - 4)
            ) unused_reg (
               // Register interface signals
               .reg_req          (core_256kb_0_reg_req[`WORD(k,1)]),
               .reg_ack          (core_256kb_0_reg_ack[`WORD(k,1)]),
               .reg_rd_wr_L      (core_256kb_0_reg_rd_wr_L[`WORD(k,1)]),

               .reg_addr         (core_256kb_0_reg_addr[`WORD(k,`CORE_REG_ADDR_WIDTH - 2 - 4)]),

               .reg_rd_data      (core_256kb_0_reg_rd_data[`WORD(k,`CPCI_NF2_DATA_WIDTH)]),
               .reg_wr_data      (core_256kb_0_reg_wr_data[`WORD(k,`CPCI_NF2_DATA_WIDTH)]),

               //
               .clk              (core_clk_int),
               .reset            (reset)
            );
      end // block: unused_reg_256kb
   endgenerate


   //--------------------------------------------------
   //
   // --- NetFPGA PHY controller
   //
   //--------------------------------------------------

/*
   nf2_phy nf2_phy (
        .phy_busy     (),
        .phy_wr_req   (1'b0),
        .phy_rd_req   (1'b0),
        .phy_rd_vld   (),
        .phy_rd_data  (),
        .phy_wr_data  (32'h0),
        .phy_mdc      (phy_mdc),
        .phy_mdata_out(phy_mdata_out),
        .phy_mdata_tri(phy_mdata_tri),
        .phy_mdata_in (phy_mdata_in),
        .reset        (reset),
        .clk          (core_clk_int)
        );
*/

   //synthesis attribute keep of phy_busy    is "true";
   //synthesis attribute keep of phy_wr_req    is "true";
   //synthesis attribute keep of phy_rd_req    is "true";
   //synthesis attribute keep of phy_rd_vld    is "true";
   //synthesis attribute keep of phy_rd_data    is "true";
   //synthesis attribute keep of wr_data    is "true";

/*
   nf2_dma
     #(.NUM_CPU_QUEUES (NUM_QUEUES/2),
       .PKT_LEN_CNT_WIDTH (PKT_LEN_CNT_WIDTH),
       .DMA_DATA_WIDTH (DMA_DATA_WIDTH),
       .DMA_CTRL_WIDTH (DMA_DATA_WIDTH/8),
       .USER_DATA_PATH_WIDTH (DATA_WIDTH)
       ) nf2_dma
       (
	// --- signals to/from CPU rx queues
	.cpu_q_dma_pkt_avail ( cpu_q_dma_pkt_avail ),

	// ---- signals to/from CPU rx queue 0
	.cpu_q_dma_rd_0 ( cpu_q_dma_rd[0] ),
	.cpu_q_dma_rd_data_0 ( cpu_q_dma_rd_data[0] ),
	.cpu_q_dma_rd_ctrl_0 ( cpu_q_dma_rd_ctrl[0] ),

	// ---- signals to/from CPU rx queue 1
	.cpu_q_dma_rd_1 ( cpu_q_dma_rd[1] ),
	.cpu_q_dma_rd_data_1 ( cpu_q_dma_rd_data[1] ),
	.cpu_q_dma_rd_ctrl_1 ( cpu_q_dma_rd_ctrl[1] ),

	// ---- signals to/from CPU rx queue 2
	.cpu_q_dma_rd_2 ( cpu_q_dma_rd[2] ),
	.cpu_q_dma_rd_data_2 ( cpu_q_dma_rd_data[2] ),
	.cpu_q_dma_rd_ctrl_2 ( cpu_q_dma_rd_ctrl[2] ),

	// ---- signals to/from CPU rx queue 3
	.cpu_q_dma_rd_3 ( cpu_q_dma_rd[3] ),
	.cpu_q_dma_rd_data_3 ( cpu_q_dma_rd_data[3] ),
	.cpu_q_dma_rd_ctrl_3 ( cpu_q_dma_rd_ctrl[3] ),

	// signals to/from CPU tx queues
	.cpu_q_dma_nearly_full ( cpu_q_dma_nearly_full ),

	// signals to/from CPU tx queue 0
	.cpu_q_dma_wr_0 ( cpu_q_dma_wr[0] ),
	.cpu_q_dma_wr_data_0 ( cpu_q_dma_wr_data[0] ),
	.cpu_q_dma_wr_ctrl_0 ( cpu_q_dma_wr_ctrl[0] ),

	// signals to/from CPU tx queue 1
	.cpu_q_dma_wr_1 ( cpu_q_dma_wr[1] ),
	.cpu_q_dma_wr_data_1 ( cpu_q_dma_wr_data[1] ),
	.cpu_q_dma_wr_ctrl_1 ( cpu_q_dma_wr_ctrl[1] ),

	// signals to/from CPU tx queue 2
	.cpu_q_dma_wr_2 ( cpu_q_dma_wr[2] ),
	.cpu_q_dma_wr_data_2 ( cpu_q_dma_wr_data[2] ),
	.cpu_q_dma_wr_ctrl_2 ( cpu_q_dma_wr_ctrl[2] ),

	// signals to/from CPU tx queue 3
	.cpu_q_dma_wr_3 ( cpu_q_dma_wr[3] ),
	.cpu_q_dma_wr_data_3 ( cpu_q_dma_wr_data[3] ),
	.cpu_q_dma_wr_ctrl_3 ( cpu_q_dma_wr_ctrl[3] ),

	// --- signals to/from CPCI pins
	.dma_op_code_req ( dma_op_code_req ),
	.dma_op_queue_id ( dma_op_queue_id ),
	.dma_op_code_ack ( dma_op_code_ack ),

	// DMA TX data and flow control
	.dma_vld_c2n ( dma_vld_c2n ),
	.dma_data_c2n ( dma_data_c2n ),
	.dma_dest_q_nearly_full_n2c ( dma_q_nearly_full_n2c ),

	// DMA RX data and flow control
	.dma_vld_n2c ( dma_vld_n2c ),
	.dma_data_n2c ( dma_data_n2c ),
	.dma_dest_q_nearly_full_c2n ( dma_q_nearly_full_c2n ),

	// enable to drive tri-state bus
	.dma_data_tri_en ( dma_data_tri_en ),

	// ----from reg_grp dma interface
	.dma_reg_req ( dma_req ),
	.dma_reg_rd_wr_L ( dma_rd_wr_L ),
	.dma_reg_addr ( dma_addr ),
	.dma_reg_wr_data ( dma_wr_data ),
	.dma_reg_ack ( dma_ack ),
	.dma_reg_rd_data ( dma_rd_data ),

	// --- output port to cpu_queue
	.enable_dma ( enable_dma ),

	//--- misc
	.reset ( reset ),
	.clk ( core_clk_int ),
	.cpci_clk ( cpci_clk_int )
	);
*/

   //--------------------------------------------------
   //
   // --- Logic Analyzer signals
   //
   //--------------------------------------------------

   reg [31:0] tmp_debug;

   always @(posedge core_clk_int) begin
      tmp_debug  <= cpci_debug_data;
      debug_data[31:5] <= tmp_debug[31:5];
      debug_data[0] <= cpci_rp_prog_b;
      debug_data[1] <= cpci_rp_init_b;
      debug_data[2] <= cpci_rp_done;
      debug_data[3] <= cpci_rp_en;
      debug_data[4] <= cpci_rp_din;
   end


   INV invert_clk(.I(core_clk_int), .O(not_core_clk_int));

   FDDRRSE debug_clk_0_ddr_iob
     (.Q  (debug_clk[0]),
      .D0 (1'b0),
      .D1 (1'b1),
      .C0 (core_clk_int),
      .C1 (not_core_clk_int),
      .CE (1'b1),
      .R  (1'b0),
      .S  (1'b0)
      );

   /*FDDRRSE debug_clk_1_ddr_iob
     (.Q  (debug_clk[1]),
      .D0 (1'b0),
      .D1 (1'b1),
      .C0 (core_clk_int),
      .C1 (not_core_clk_int),
      .CE (1'b1),
      .R  (1'b0),
      .S  (1'b0)
      );*/
   assign debug_clk[1] = cpci_rp_cclk;



    // Eth 0 MAC to RGMII interfaces
    assign gmii_0_txd_int = 'h0;
    assign gmii_0_tx_en_int = 'h0;
    assign gmii_0_tx_er_int = 'h0;

    // Eth 1 MAC to RGMII interfaces
    assign gmii_1_txd_int = 'h0;
    assign gmii_1_tx_en_int = 'h0;
    assign gmii_1_tx_er_int = 'h0;


    // Eth 2 MAC to RGMII interfaces
    assign gmii_2_txd_int = 'h0;
    assign gmii_2_tx_en_int = 'h0;
    assign gmii_2_tx_er_int = 'h0;


    // Eth 3 MAC to RGMII interfaces
    assign gmii_3_txd_int = 'h0;
    assign gmii_3_tx_en_int = 'h0;
    assign gmii_3_tx_er_int = 'h0;

    assign dma_q_nearly_full_n2c = 'h0;

    // DMA RX data and flow control
    assign dma_vld_n2c = 'h0;
    assign dma_data_n2c = 'h0;

    // enable to drive tri-state bus
    assign dma_data_tri_en = 'h0;

endmodule // nf2_core
