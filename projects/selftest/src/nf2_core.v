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

module nf2_core #(
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
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

      output [`SRAM_ADDR_WIDTH-1:0]    sram1_addr,
      input  [`SRAM_DATA_WIDTH-1:0]    sram1_rd_data,
      output  [`SRAM_DATA_WIDTH-1:0]   sram1_wr_data,
      output                           sram1_tri_en,
      output                           sram1_we,
      output [3:0]                     sram1_bw,
      output                           sram1_zz,

      // ---- SRAM 2

      output [`SRAM_ADDR_WIDTH-1:0]    sram2_addr,
      input  [`SRAM_DATA_WIDTH-1:0]    sram2_rd_data,
      output  [`SRAM_DATA_WIDTH-1:0]   sram2_wr_data,
      output                           sram2_tri_en,
      output                           sram2_we,
      output [3:0]                     sram2_bw,
      output                           sram2_zz,

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
      output  serial_TXP_0,
      output  serial_TXN_0,
      input   serial_RXP_0,
      input   serial_RXN_0,

      output  serial_TXP_1,
      output  serial_TXN_1,
      input   serial_RXP_1,
      input   serial_RXN_1,

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
   localparam NUM_MACS = 4;
   localparam DATA_WIDTH = 64;
   localparam CTRL_WIDTH = DATA_WIDTH/8;
   localparam NUM_QUEUES = 8;
   localparam PKT_LEN_CNT_WIDTH = 11;

   //---------------- Wires/regs ------------------

   // FIXME
   assign        nf2_err = 1'b 0;

   // Do NOT disable resets
   assign disable_reset = 1'b0;

   // SRAM 1 -- Port 1
   wire s1_req_1;
   wire s1_rd_1;
   wire s1_ack_1;
   wire [`SRAM_ADDR_WIDTH-1:0] s1_addr_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] s1_wr_data_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] s1_rd_data_1;

   wire [`SRAM_DATA_WIDTH-1:0]    sram1_rd_data_d;
   wire [`SRAM_ADDR_WIDTH-1:0]    sram1_addr_e;
   wire [`SRAM_DATA_WIDTH-1:0]    sram1_wr_data_e;
   wire 			  sram1_tri_en_e;
   wire 			  sram1_we_e;

   // SRAM 2 -- Port 1
   wire s2_req_1;
   wire s2_rd_1;
   wire s2_ack_1;
   wire [`SRAM_ADDR_WIDTH-1:0] s2_addr_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] s2_wr_data_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] s2_rd_data_1;

   wire [`SRAM_DATA_WIDTH-1:0] 	  sram2_rd_data_d;
   wire [`SRAM_ADDR_WIDTH-1:0] 	  sram2_addr_e;
   wire [`SRAM_DATA_WIDTH-1:0] 	  sram2_wr_data_e;
   wire 			  sram2_tri_en_e;
   wire 			  sram2_we_e;

   // TODO: Consider adding a configuration vector here somewhere possibly?

   // Self test signals
   wire sram_done;
   wire sram_fail;
   wire eth_done;
   wire eth_success;
   wire dram_done;
   wire dram_success;

   // Ethernet MAC signals
   wire        reset_MAC;

   wire [35:0] txf_data [NUM_MACS-1:0];
   wire        txf_wr_en [NUM_MACS-1:0];
   wire        txf_full [NUM_MACS-1:0];
   wire        txf_almost_full [NUM_MACS-1:0];
   wire        txf_prog_full [NUM_MACS-1:0];        // 0 = room for max pkt
   wire [7:0]  txf_num_pkts_waiting[NUM_MACS-1:0];
   wire        txf_pkt_sent_ok [NUM_MACS-1:0];        // pulsed
   wire        txf_pkt_underrun [NUM_MACS-1:0];       // pulsed 1 = error

   wire  [7:0]  rxf_num_pkts_waiting[NUM_MACS-1:0];
   wire        rxf_pkt_avail [NUM_MACS-1:0];
   wire        rxf_empty [NUM_MACS-1:0];
   wire        rxf_almost_empty [NUM_MACS-1:0];
   wire        rxf_pkt_lost [NUM_MACS-1:0];
   wire        rxf_pkt_rcvd [NUM_MACS-1:0];
   wire [35:0] rxf_data[NUM_MACS-1:0];
   wire        rxf_rd_en[NUM_MACS-1:0];

   wire        eth_restart;

   wire [`CPCI_NF2_ADDR_WIDTH-1:0]    cpci_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpci_reg_rd_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    cpci_reg_wr_data;

   wire                                core_reg_req;
   wire                                core_reg_rd_wr_L;
   wire                                core_reg_ack;
   wire [`CORE_REG_ADDR_WIDTH-1:0]     core_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     core_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     core_reg_rd_data;

   wire [3:0]                          core_4mb_reg_req;
   wire [3:0]                          core_4mb_reg_rd_wr_L;
   wire [3:0]                          core_4mb_reg_ack;
   wire [4 * `BLOCK_SIZE_1M_REG_ADDR_WIDTH-1:0] core_4mb_reg_addr;
   wire [4 * `CPCI_NF2_DATA_WIDTH-1:0] core_4mb_reg_wr_data;
   wire [4 * `CPCI_NF2_DATA_WIDTH-1:0] core_4mb_reg_rd_data;

   wire [15:0]                         core_256kb_0_reg_req;
   wire [15:0]                         core_256kb_0_reg_rd_wr_L;
   wire [15:0]                         core_256kb_0_reg_ack;
   wire [16 * `BLOCK_SIZE_64k_REG_ADDR_WIDTH-1:0] core_256kb_0_reg_addr;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_0_reg_wr_data;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_0_reg_rd_data;

   wire [15:0]                         core_256kb_1_reg_req;
   wire [15:0]                         core_256kb_1_reg_rd_wr_L;
   wire [15:0]                         core_256kb_1_reg_ack;
   wire [16 * `BLOCK_SIZE_64k_REG_ADDR_WIDTH-1:0] core_256kb_1_reg_addr;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_1_reg_wr_data;
   wire [16 * `CPCI_NF2_DATA_WIDTH-1:0] core_256kb_1_reg_rd_data;

   wire                                sram_reg_req;
   wire                                sram_reg_rd_wr_L;
   wire                                sram_reg_ack;
   wire [`SRAM_REG_ADDR_WIDTH-1:0]     sram_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     sram_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     sram_reg_rd_data;

   wire [1:0]                          sram_lsb_reg_req;
   wire [1:0]                          sram_lsb_reg_rd_wr_L;
   wire [1:0]                          sram_lsb_reg_ack;
   wire [2 * `SRAM_REG_ADDR_WIDTH-1:0] sram_lsb_reg_addr;
   wire [2 * `CPCI_NF2_DATA_WIDTH-1:0] sram_lsb_reg_wr_data;
   wire [2 * `CPCI_NF2_DATA_WIDTH-1:0] sram_lsb_reg_rd_data;


   wire                                udp_reg_req;
   wire                                udp_reg_rd_wr_L;
   wire                                udp_reg_ack;
   wire [`UDP_REG_ADDR_WIDTH-1:0]      udp_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     udp_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     udp_reg_rd_data;

   wire                                dram_reg_req;
   wire                                dram_reg_rd_wr_L;
   wire                                dram_reg_ack;
   wire [`DRAM_REG_ADDR_WIDTH-1:0]     dram_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     dram_reg_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     dram_reg_rd_data;

   wire [7:0] gmii_txd_int[NUM_MACS - 1:0];
   wire       gmii_tx_en_int[NUM_MACS - 1:0];
   wire       gmii_tx_er_int[NUM_MACS - 1:0];
   wire       gmii_crs_int[NUM_MACS - 1:0];
   wire       gmii_col_int[NUM_MACS - 1:0];
   wire [7:0] gmii_rxd_reg[NUM_MACS - 1:0];
   wire       gmii_rx_dv_reg[NUM_MACS - 1:0];
   wire       gmii_rx_er_reg[NUM_MACS - 1:0];
   wire       eth_link_status[NUM_MACS - 1:0];
   wire [1:0] eth_clock_speed[NUM_MACS - 1:0];
   wire       eth_duplex_status[NUM_MACS - 1:0];
   wire       rx_rgmii_clk_int[NUM_MACS - 1:0];


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

   wire                               dma_req;
   wire                               dma_rd_wr_L;
   wire                               dma_ack;
   wire [`DMA_REG_ADDR_WIDTH -1:0]    dma_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dma_wr_data;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]    dma_rd_data;

   wire [`SRAM_DATA_WIDTH - `CPCI_NF2_DATA_WIDTH -1: 0] s1_rd_data_msb,
                                                        s1_wr_data_msb,
                                                        s2_rd_data_msb,
                                                        s2_wr_data_msb;

   //-------- TODO: The following need to be hooked up to registers --------- //
   wire enable_txf_transmit = 1'b1;
   wire enable_rxf_receive = 1'b1;
   wire [5:0]    mac_config_reg = 6'b000011;
   assign reset_MAC = reset;
   //-------- TODO: The stuff above need to be hooked up to registers ---------//

   generate
      genvar i;
      for(i=0; i<NUM_MACS; i=i+1) begin: mac_groups
         nf2_mac_grp nf2_mac_grp (
              .txf_data               (txf_data[i]),
              .txf_wr_en              (txf_wr_en[i]),
              .txf_full               (txf_full[i]),
              .txf_almost_full        (txf_almost_full[i]),
              .txf_prog_full          (txf_prog_full[i]),
              .txf_num_pkts_waiting   (txf_num_pkts_waiting[i]),
              .txf_pkt_sent_ok        (txf_pkt_sent_ok[i]),
              .txf_pkt_underrun       (txf_pkt_underrun[i]),

              .rxf_empty              (rxf_empty[i]),
              .rxf_almost_empty       (rxf_almost_empty[i]),
              .rxf_pkt_lost           (rxf_pkt_lost[i]),
              .rxf_pkt_rcvd           (rxf_pkt_rcvd[i]),
              .rxf_num_pkts_waiting   (rxf_num_pkts_waiting[i]),
              .rxf_data               (rxf_data[i]),
              .rxf_rd_en              (rxf_rd_en[i]),
              .rxf_pkt_avail          (rxf_pkt_avail[i]),

              .gmii_tx_d              (gmii_txd_int[i]),
              .gmii_tx_en             (gmii_tx_en_int[i]),
              .gmii_tx_er             (gmii_tx_er_int[i]),
              .gmii_crs               (gmii_crs_int[i]),
              .gmii_col               (gmii_col_int[i]),
              .gmii_rx_d              (gmii_rxd_reg[i]),
              .gmii_rx_dv             (gmii_rx_dv_reg[i]),
              .gmii_rx_er             (gmii_rx_er_reg[i]),

              .enable_txf_transmit    (enable_txf_transmit),
              .enable_rxf_receive     (enable_rxf_receive),
              .mac_config_reg         (mac_config_reg),
              .txgmiimiiclk           (tx_rgmii_clk_int),
              .rxgmiimiiclk           (rx_rgmii_clk_int[0]),
              .clk                    (core_clk_int),
              .reset_MAC              (reset_MAC || eth_restart)
              );
      end // block: mac_groups

   endgenerate

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

        .fifo_empty        (cpci_reg_fifo_empty ),
        .fifo_rd_en        (cpci_reg_fifo_rd_en ),
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

   //-------------------------------------------------
   //
   // register address decoder, register bus mux and demux
   //
   //-----------------------------------------------

   nf2_reg_grp nf2_reg_grp_u
     (// interface to cpci_bus
      .fifo_empty             (cpci_reg_fifo_empty),
      .fifo_rd_en             (cpci_reg_fifo_rd_en),
      .bus_rd_wr_L            (cpci_reg_rd_wr_L),
      .bus_addr               (cpci_reg_addr),
      .bus_wr_data            (cpci_reg_wr_data),
      .bus_rd_data            (cpci_reg_rd_data),
      .bus_rd_vld             (cpci_reg_rd_vld),

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


   reg_grp #(
      .REG_ADDR_BITS(`SRAM_REG_ADDR_WIDTH),
      .NUM_OUTPUTS(2)
   ) sram_reg_grp
   (
      // Upstream register interface
      .reg_req             (sram_reg_req),
      .reg_rd_wr_L         (sram_reg_rd_wr_L),
      .reg_addr            (sram_reg_addr),
      .reg_wr_data         (sram_reg_wr_data),

      .reg_ack             (sram_reg_ack),
      .reg_rd_data         (sram_reg_rd_data),


      // Downstream register interface
      .local_reg_req       (sram_lsb_reg_req),
      .local_reg_rd_wr_L   (sram_lsb_reg_rd_wr_L),
      .local_reg_addr      (sram_lsb_reg_addr),
      .local_reg_wr_data   (sram_lsb_reg_wr_data),

      .local_reg_ack       (sram_lsb_reg_ack),
      .local_reg_rd_data   (sram_lsb_reg_rd_data),


      //-- misc
      .clk                 (core_clk_int),
      .reset               (reset)
   );

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

   reg_grp #(
      .REG_ADDR_BITS(`CORE_REG_ADDR_WIDTH - 2),
      .NUM_OUTPUTS(16)
   ) core_256kb_0_reg_grp
   (
      // Upstream register interface
      .reg_req             (core_4mb_reg_req[`WORD(1,1)]),
      .reg_ack             (core_4mb_reg_ack[`WORD(1,1)]),
      .reg_rd_wr_L         (core_4mb_reg_rd_wr_L[`WORD(1,1)]),
      .reg_addr            (core_4mb_reg_addr[`WORD(1, `BLOCK_SIZE_1M_REG_ADDR_WIDTH)]),

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

   reg_grp #(
      .REG_ADDR_BITS(`CORE_REG_ADDR_WIDTH - 2),
      .NUM_OUTPUTS(16)
   ) core_256kb_1_reg_grp
   (
      // Upstream register interface
      .reg_req             (core_4mb_reg_req[`WORD(2,1)]),
      .reg_ack             (core_4mb_reg_ack[`WORD(2,1)]),
      .reg_rd_wr_L         (core_4mb_reg_rd_wr_L[`WORD(2,1)]),
      .reg_addr            (core_4mb_reg_addr[`WORD(2, `BLOCK_SIZE_1M_REG_ADDR_WIDTH)]),

      .reg_rd_data         (core_4mb_reg_rd_data[`WORD(2, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data         (core_4mb_reg_wr_data[`WORD(2, `CPCI_NF2_DATA_WIDTH)]),


      // Downstream register interface
      .local_reg_req       (core_256kb_1_reg_req),
      .local_reg_rd_wr_L   (core_256kb_1_reg_rd_wr_L),
      .local_reg_addr      (core_256kb_1_reg_addr),
      .local_reg_wr_data   (core_256kb_1_reg_wr_data),

      .local_reg_ack       (core_256kb_1_reg_ack),
      .local_reg_rd_data   (core_256kb_1_reg_rd_data),


      //-- misc
      .clk                 (core_clk_int),
      .reset               (reset)
   );

   //--------------------------------------------------
   //
   // --- Device ID register
   //
   //     Provides a set of registers to uniquely identify the design
   //     - Design/Device ID
   //     - Revision
   //     - Description
   //
   //--------------------------------------------------

   device_id_reg
`ifdef DEVICE_ID
   #(
      .DEVICE_ID  (`DEVICE_ID),
      .MAJOR      (`DEVICE_MAJOR),
      .MINOR      (`DEVICE_MINOR),
      .REVISION   (`DEVICE_REVISION),
      .PROJ_DIR   (`DEVICE_PROJ_DIR),
      .PROJ_NAME  (`DEVICE_PROJ_NAME),
      .PROJ_DESC  (`DEVICE_PROJ_DESC)
   )
`endif
   device_id_reg (
      // Register interface signals
      .reg_req          (core_256kb_0_reg_req[`WORD(`DEV_ID_BLOCK_ADDR,1)]),
      .reg_ack          (core_256kb_0_reg_ack[`WORD(`DEV_ID_BLOCK_ADDR,1)]),
      .reg_rd_wr_L      (core_256kb_0_reg_rd_wr_L[`WORD(`DEV_ID_BLOCK_ADDR,1)]),
      .reg_addr         (core_256kb_0_reg_addr[`WORD(`DEV_ID_BLOCK_ADDR,`DEV_ID_REG_ADDR_WIDTH)]),
      .reg_rd_data      (core_256kb_0_reg_rd_data[`WORD(`DEV_ID_BLOCK_ADDR,`CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data      (core_256kb_0_reg_wr_data[`WORD(`DEV_ID_BLOCK_ADDR,`CPCI_NF2_DATA_WIDTH)]),

      //
      .clk              (core_clk_int),
      .reset            (reset)
   );






   //--------------------------------------------------
   //
   // --- NetFPGA MDIO controller
   //
   //--------------------------------------------------

   nf2_mdio nf2_mdio (
        .phy_reg_req     (core_256kb_0_reg_req[`WORD(`MDIO_BLOCK_ADDR,1)]),
        .phy_reg_rd_wr_L (core_256kb_0_reg_rd_wr_L[`WORD(`MDIO_BLOCK_ADDR,1)]),
        .phy_reg_ack     (core_256kb_0_reg_ack[`WORD(`MDIO_BLOCK_ADDR, 1)]),
        .phy_reg_addr    (core_256kb_0_reg_addr[`WORD(`MDIO_BLOCK_ADDR, `MDIO_REG_ADDR_WIDTH)]),
        .phy_reg_rd_data (core_256kb_0_reg_rd_data[`WORD(`MDIO_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
        .phy_reg_wr_data (core_256kb_0_reg_wr_data[`WORD(`MDIO_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
        .phy_mdc         (phy_mdc),
        .phy_mdata_out   (phy_mdata_out),
        .phy_mdata_tri   (phy_mdata_tri),
        .phy_mdata_in    (phy_mdata_in),
        .reset           (reset),
        .clk             (core_clk_int)
        );




   //--------------------------------------------------
   //
   // --- Dummy logic for Spartan reprogramming
   //
   //--------------------------------------------------

   assign cpci_rp_en = 1'b0;
   assign cpci_rp_prog_b = 1'b1;
   assign cpci_rp_din = cpci_rp_cclk && cpci_rp_done && cpci_rp_init_b;



   //--------------------------------------------------
   //
   // --- CPU DMA queues
   //
   //--------------------------------------------------

   generate
      genvar k;
      for(k=0; k<4; k=k+1) begin: cpu_queues
         wire                       cpu_rdy;
         wire                       cpu_wr;
         wire [CTRL_WIDTH-1:0]      cpu_ctrl;
         wire [DATA_WIDTH-1:0]      cpu_data;

         cpu_dma_queue #(
            .DATA_WIDTH     (DATA_WIDTH),
            .CTRL_WIDTH     (CTRL_WIDTH)
           ) cpu_dma_queue_i

           (
            //.out_data               (cpu_data),
            //.out_ctrl               (cpu_ctrl),
            //.out_wr                 (cpu_wr),
            //.out_rdy                (cpu_rdy),

            //.in_data                (cpu_data),
            //.in_ctrl                (cpu_ctrl),
            //.in_wr                  (cpu_wr),
            //.in_rdy                 (cpu_rdy),

            // --- DMA rd rxfifo interface
            .cpu_q_dma_pkt_avail    (cpu_q_dma_pkt_avail[k]),
            .cpu_q_dma_rd_rdy       (cpu_q_dma_rd_rdy[k]),

            .cpu_q_dma_rd           (cpu_q_dma_rd[k]),
            .cpu_q_dma_rd_data      (cpu_q_dma_rd_data[k]),
            .cpu_q_dma_rd_ctrl      (cpu_q_dma_rd_ctrl[k]),

            // DMA wr txfifo interface
            .cpu_q_dma_nearly_full  (cpu_q_dma_nearly_full[k]),
            .cpu_q_dma_can_wr_pkt   (cpu_q_dma_can_wr_pkt[k]),

            .cpu_q_dma_wr           (cpu_q_dma_wr[k]),
            .cpu_q_dma_wr_pkt_vld   (cpu_q_dma_wr_pkt_vld[k]),
            .cpu_q_dma_wr_data      (cpu_q_dma_wr_data[k]),
            .cpu_q_dma_wr_ctrl      (cpu_q_dma_wr_ctrl[k]),

            //.reg_req                (core_256kb_0_reg_req[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,1)]),
            //.reg_ack                (core_256kb_0_reg_ack[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,1)]),
            //.reg_rd_wr_L            (core_256kb_0_reg_rd_wr_L[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,1)]),
            //.reg_addr               (core_256kb_0_reg_addr[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,
            //                         `BLOCK_SIZE_64k_REG_ADDR_WIDTH)]),
            //.reg_rd_data            (core_256kb_0_reg_rd_data[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,
            //                         `CPCI_NF2_DATA_WIDTH)]),
            //.reg_wr_data            (core_256kb_0_reg_wr_data[`WORD(`CPU_QUEUE_0_BLOCK_ADDR + k,
            //                         `CPCI_NF2_DATA_WIDTH)]),
            // --- Misc
            .reset                  (reset),
            .clk                    (core_clk_int)
            );
         //cpu_dma_queue cpu_dma_queue_i
         // (
         //   // --- DMA rd rxfifo interface
         //   .cpu_q_dma_pkt_avail (cpu_q_dma_pkt_avail[k]),

         //   .cpu_q_dma_rd (cpu_q_dma_rd[k]),
         //   .cpu_q_dma_rd_data (cpu_q_dma_rd_data[k]),
         //   .cpu_q_dma_rd_ctrl (cpu_q_dma_rd_ctrl[k]),

         //   // DMA wr txfifo interface
         //   .cpu_q_dma_nearly_full (cpu_q_dma_nearly_full[k]),

         //   .cpu_q_dma_wr (cpu_q_dma_wr[k]),
         //   .cpu_q_dma_wr_data (cpu_q_dma_wr_data[k]),
         //   .cpu_q_dma_wr_ctrl (cpu_q_dma_wr_ctrl[k]),

         //   // --- Misc
         //   .reset (reset),
         //   .clk (core_clk_int)
         //   );
      end // block: cpu_queues

   endgenerate


   //--------------------------------------------------
   //
   // --- SRAM CONTROLLER 1
   //
   //--------------------------------------------------

   nf2_sram_sm_fast nf2_sram_sm1
     (
      .sram_test_req       (sram_running),
      .sram_test_addr      (sram1_addr_e),
      .sram_test_wr_data   (sram1_wr_data_e),
      .sram_test_tri_en    (sram1_tri_en_e),
      .sram_test_we_bw     (sram1_we_e),
      .sram_test_rd_data   (sram1_rd_data_d),

      .reg_req             (sram_lsb_reg_req[`WORD(0,1)]),
      .reg_rd_wr_L         (sram_lsb_reg_rd_wr_L[`WORD(0,1)]),
      .reg_ack             (sram_lsb_reg_ack[`WORD(0, 1)]),
      .reg_addr            (sram_lsb_reg_addr[`WORD(0, `SRAM_REG_ADDR_WIDTH)]),
      .reg_rd_data         ({s1_rd_data_msb, sram_lsb_reg_rd_data[`WORD(0, `CPCI_NF2_DATA_WIDTH)]}),
      .reg_wr_data         ({s1_wr_data_msb, sram_lsb_reg_wr_data[`WORD(0, `CPCI_NF2_DATA_WIDTH)]}),

      .sram_addr           (sram1_addr),
      .sram_wr_data        (sram1_wr_data),
      .sram_rd_data        (sram1_rd_data),
      .sram_tri_en         (sram1_tri_en),
      .sram_we_bw          (sram1_we),

      .reset               (reset),
      .clk                 (core_clk_int)
      );

   assign sram1_bw[3:0] = {4{sram1_we}};
   assign sram1_zz = 1'b0;
   // synthesis attribute keep_hierarchy of nf2_sram_sm1 is false;

   //--------------------------------------------------
   //
   // --- SRAM CONTROLLER 2
   //
   //--------------------------------------------------

   nf2_sram_sm_fast nf2_sram_sm2
     (
      .sram_test_req       (sram_running),
      .sram_test_addr      (sram2_addr_e),
      .sram_test_wr_data   (sram2_wr_data_e),
      .sram_test_tri_en    (sram2_tri_en_e),
      .sram_test_we_bw     (sram2_we_e),
      .sram_test_rd_data   (sram2_rd_data_d),

      .reg_req             (sram_lsb_reg_req[`WORD(1,1)]),
      .reg_rd_wr_L         (sram_lsb_reg_rd_wr_L[`WORD(1,1)]),
      .reg_ack             (sram_lsb_reg_ack[`WORD(1, 1)]),
      .reg_addr            (sram_lsb_reg_addr[`WORD(1, `SRAM_REG_ADDR_WIDTH)]),
      .reg_rd_data         ({s2_rd_data_msb, sram_lsb_reg_rd_data[`WORD(1, `CPCI_NF2_DATA_WIDTH)]}),
      .reg_wr_data         ({s2_wr_data_msb, sram_lsb_reg_wr_data[`WORD(1, `CPCI_NF2_DATA_WIDTH)]}),

      .sram_addr           (sram2_addr),
      .sram_wr_data        (sram2_wr_data),
      .sram_rd_data        (sram2_rd_data),
      .sram_tri_en         (sram2_tri_en),
      .sram_we_bw          (sram2_we),

      .reset               (reset),
      .clk                 (core_clk_int)
      );

   assign sram2_bw[3:0] = {4{sram2_we}};
   assign sram2_zz = 1'b0;
  // synthesis attribute keep_hierarchy of nf2_sram_sm2 is false;

   //--------------------------------------------------
   //
   // --- Unused register signals
   //
   //--------------------------------------------------

   unused_reg #(
      .REG_ADDR_WIDTH(`BLOCK_SIZE_1M_REG_ADDR_WIDTH)
   ) unused_reg_core_4mb_3 (
      // Register interface signals
      .reg_req             (core_4mb_reg_req[`WORD(3,1)]),
      .reg_ack             (core_4mb_reg_ack[`WORD(3,1)]),
      .reg_rd_wr_L         (core_4mb_reg_rd_wr_L[`WORD(3,1)]),
      .reg_addr            (core_4mb_reg_addr[`WORD(3, `BLOCK_SIZE_1M_REG_ADDR_WIDTH)]),

      .reg_rd_data         (core_4mb_reg_rd_data[`WORD(3, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data         (core_4mb_reg_wr_data[`WORD(3, `CPCI_NF2_DATA_WIDTH)]),

      //
      .clk           (core_clk_int),
      .reset         (reset)
   );

   generate
      //genvar i;
      for (i = 0; i < 16; i = i + 1) begin: unused_reg_core_256kb_0
         if (i != `DEV_ID_BLOCK_ADDR &&
             i != `MDIO_BLOCK_ADDR &&
             i != `DMA_BLOCK_ADDR)
            unused_reg #(
               .REG_ADDR_WIDTH(`BLOCK_SIZE_64k_REG_ADDR_WIDTH)
            ) unused_reg_core_256kb_0_x (
               // Register interface signals
               .reg_req             (core_256kb_0_reg_req[`WORD(i,1)]),
               .reg_ack             (core_256kb_0_reg_ack[`WORD(i,1)]),
               .reg_rd_wr_L         (core_256kb_0_reg_rd_wr_L[`WORD(i,1)]),
               .reg_addr            (core_256kb_0_reg_addr[`WORD(i, `BLOCK_SIZE_64k_REG_ADDR_WIDTH)]),

               .reg_rd_data         (core_256kb_0_reg_rd_data[`WORD(i, `CPCI_NF2_DATA_WIDTH)]),
               .reg_wr_data         (core_256kb_0_reg_wr_data[`WORD(i, `CPCI_NF2_DATA_WIDTH)]),

               //
               .clk           (core_clk_int),
               .reset         (reset)
            );
      end
   endgenerate

   generate
      //genvar i;
      for (i = 0; i < 16; i = i + 1) begin: unused_reg_core_256kb_1
         if (
	    i != `REG_FILE_BLOCK_ADDR &&
	    i != `REG_REFLECT_TEST_BLOCK_ADDR &&
	    i != `SRAM_MSB_BLOCK_ADDR &&
	    i != `DRAM_TEST_BLOCK_ADDR &&
	    i != `SRAM_TEST_BLOCK_ADDR &&
	    i != `PHY_TEST_BLOCK_ADDR &&
	    i != `SERIAL_TEST_BLOCK_ADDR &&
            i != `CLOCK_TEST_BLOCK_ADDR)
            unused_reg #(
               .REG_ADDR_WIDTH(`BLOCK_SIZE_64k_REG_ADDR_WIDTH)
            ) unused_reg_core_256kb_1_x (
               // Register interface signals
               .reg_req             (core_256kb_1_reg_req[`WORD(i,1)]),
               .reg_ack             (core_256kb_1_reg_ack[`WORD(i,1)]),
               .reg_rd_wr_L         (core_256kb_1_reg_rd_wr_L[`WORD(i,1)]),
               .reg_addr            (core_256kb_1_reg_addr[`WORD(i, `BLOCK_SIZE_64k_REG_ADDR_WIDTH)]),

               .reg_rd_data         (core_256kb_1_reg_rd_data[`WORD(i, `CPCI_NF2_DATA_WIDTH)]),
               .reg_wr_data         (core_256kb_1_reg_wr_data[`WORD(i, `CPCI_NF2_DATA_WIDTH)]),

               //
               .clk           (core_clk_int),
               .reset         (reset)
            );
      end
   endgenerate

   unused_reg #(
      .REG_ADDR_WIDTH(`UDP_REG_ADDR_WIDTH)
   ) unused_reg_udp (
      // Register interface signals
      .reg_req             (udp_reg_req),
      .reg_ack             (udp_reg_ack),
      .reg_rd_wr_L         (udp_reg_rd_wr_L),
      .reg_addr            (udp_reg_addr),

      .reg_rd_data         (udp_reg_rd_data),
      .reg_wr_data         (udp_reg_wr_data),

      //
      .clk           (core_clk_int),
      .reset         (reset)
   );

   //--------------------------------------------------
   //
   // --- Register tests
   //
   //--------------------------------------------------
   reg_file_test reg_file_test (
      .reg_req        (core_256kb_1_reg_req[`WORD(`REG_FILE_BLOCK_ADDR,1)]),
      .reg_rd_wr_L    (core_256kb_1_reg_rd_wr_L[`WORD(`REG_FILE_BLOCK_ADDR,1)]),
      .reg_ack        (core_256kb_1_reg_ack[`WORD(`REG_FILE_BLOCK_ADDR, 1)]),
      .reg_addr       (core_256kb_1_reg_addr[`WORD(`REG_FILE_BLOCK_ADDR, `REG_FILE_REG_ADDR_WIDTH)]),
      .reg_rd_data    (core_256kb_1_reg_rd_data[`WORD(`REG_FILE_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data    (core_256kb_1_reg_wr_data[`WORD(`REG_FILE_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      .clk                 (core_clk_int),
      .reset               (reset)
   );

   reg_addr_reflect reg_addr_reflect (
      .reg_req       (core_256kb_1_reg_req[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR,1)]),
      .reg_rd_wr_L   (core_256kb_1_reg_rd_wr_L[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR,1)]),
      .reg_ack       (core_256kb_1_reg_ack[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR, 1)]),
      .reg_addr      (core_256kb_1_reg_addr[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR, `REG_REFLECT_TEST_REG_ADDR_WIDTH)]),
      .reg_rd_data   (core_256kb_1_reg_rd_data[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data   (core_256kb_1_reg_wr_data[`WORD(`REG_REFLECT_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      .clk                    (core_clk_int),
      .reset                  (reset)
   );


   //--------------------------------------------------
   //
   // --- SRAM MSB interface registers
   //
   //--------------------------------------------------
   reg_sram_msb reg_sram_msb (
          .reg_req         (core_256kb_1_reg_req[`WORD(`SRAM_MSB_BLOCK_ADDR,1)]),
          .reg_rd_wr_L     (core_256kb_1_reg_rd_wr_L[`WORD(`SRAM_MSB_BLOCK_ADDR,1)]),
          .reg_ack         (core_256kb_1_reg_ack[`WORD(`SRAM_MSB_BLOCK_ADDR, 1)]),
          .reg_addr        (core_256kb_1_reg_addr[`WORD(`SRAM_MSB_BLOCK_ADDR, `SRAM_MSB_REG_ADDR_WIDTH)]),
          .reg_rd_data     (core_256kb_1_reg_rd_data[`WORD(`SRAM_MSB_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
          .reg_wr_data     (core_256kb_1_reg_wr_data[`WORD(`SRAM_MSB_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

          .s1_rd_data_msb  (s1_rd_data_msb), //[`SRAM_DATA_WIDTH - CPCI_NF2_DATA_WIDTH -1: 0]
          .s1_wr_data_msb  (s1_wr_data_msb), //[`SRAM_DATA_WIDTH - CPCI_NF2_DATA_WIDTH -1: 0]

          .s2_rd_data_msb  (s2_rd_data_msb), //[`SRAM_DATA_WIDTH - CPCI_NF2_DATA_WIDTH -1: 0]
          .s2_wr_data_msb  (s2_wr_data_msb), //[`SRAM_DATA_WIDTH - CPCI_NF2_DATA_WIDTH -1: 0]

          .clk             (core_clk_int),
          .reset           (reset)
          );


   //--------------------------------------------------
   //
   // --- DDR test
   //
   //--------------------------------------------------
   ddr2_test ddr2_test(
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

               .ctrl_reg_req     (core_256kb_1_reg_req[`WORD(`DRAM_TEST_BLOCK_ADDR,1)]),
               .ctrl_reg_rd_wr_L (core_256kb_1_reg_rd_wr_L[`WORD(`DRAM_TEST_BLOCK_ADDR,1)]),
               .ctrl_reg_ack     (core_256kb_1_reg_ack[`WORD(`DRAM_TEST_BLOCK_ADDR, 1)]),
               .ctrl_reg_addr    (core_256kb_1_reg_addr[`WORD(`DRAM_TEST_BLOCK_ADDR, `DRAM_TEST_REG_ADDR_WIDTH)]),
               .ctrl_reg_rd_data (core_256kb_1_reg_rd_data[`WORD(`DRAM_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
               .ctrl_reg_wr_data (core_256kb_1_reg_wr_data[`WORD(`DRAM_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

               // DRAM direct access registers
               .dram_reg_req     (dram_reg_req),
               .dram_reg_rd_wr_L (dram_reg_rd_wr_L),
               .dram_reg_addr    (dram_reg_addr),
               .dram_reg_wr_data (dram_reg_wr_data),
               .dram_reg_rd_data (dram_reg_rd_data),
               .dram_reg_ack     (dram_reg_ack),

               .clk_core_125     (core_clk_int),
               .reset_core       (reset)
            );


   //--------------------------------------------------
   //
   // --- SRAM test
   //
   //--------------------------------------------------

   sram_test_fast sram_test_u
     (
      //intfc to test console
      .running          (sram_running),
      .done             (sram_done),
      .fail             (sram_fail),

      //intfc to cpu
      .reg_req          (core_256kb_1_reg_req[`WORD(`SRAM_TEST_BLOCK_ADDR,1)]),
      .reg_rd_wr_L      (core_256kb_1_reg_rd_wr_L[`WORD(`SRAM_TEST_BLOCK_ADDR,1)]),
      .reg_ack          (core_256kb_1_reg_ack[`WORD(`SRAM_TEST_BLOCK_ADDR, 1)]),
      .reg_addr         (core_256kb_1_reg_addr[`WORD(`SRAM_TEST_BLOCK_ADDR, `SRAM_TEST_REG_ADDR_WIDTH)]),
      .reg_rd_data      (core_256kb_1_reg_rd_data[`WORD(`SRAM_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data      (core_256kb_1_reg_wr_data[`WORD(`SRAM_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      //intfc to sram 1
      .sram_addr_1      (sram1_addr_e),
      .sram_wr_data_1   (sram1_wr_data_e),
      .sram_rd_data_1   (sram1_rd_data_d),
      .sram_tri_en_1    (sram1_tri_en_e),
      .sram_we_bw_1     (sram1_we_e),

      //intfc to sram 2
      .sram_addr_2      (sram2_addr_e),
      .sram_wr_data_2   (sram2_wr_data_e),
      .sram_rd_data_2   (sram2_rd_data_d),
      .sram_tri_en_2    (sram2_tri_en_e),
      .sram_we_bw_2     (sram2_we_e),

      //intfc to misc
      .clk              (core_clk_int),
      .reset            (reset)
      );

   //--------------------------------------------------
   //
   // --- Phy test
   //
   //--------------------------------------------------
   phy_test phy_test (

      //--- sigs to/from nf2_mac_grp for Rx FIFOs (ingress)
      .rx_0_almost_empty      (rxf_almost_empty[0]),
      .rx_0_data              (rxf_data[0]),
      .rx_0_rd_en             (rxf_rd_en[0]),

      .rx_1_almost_empty      (rxf_almost_empty[1]),
      .rx_1_data              (rxf_data[1]),
      .rx_1_rd_en             (rxf_rd_en[1]),

      .rx_2_almost_empty      (rxf_almost_empty[2]),
      .rx_2_data              (rxf_data[2]),
      .rx_2_rd_en             (rxf_rd_en[2]),

      .rx_3_almost_empty      (rxf_almost_empty[3]),
      .rx_3_data              (rxf_data[3]),
      .rx_3_rd_en             (rxf_rd_en[3]),

      //--- sigs to/from cnet_mac_grp for Tx FIFOs (egress)

      .tx_0_data              (txf_data[0]),
      .tx_0_wr_en             (txf_wr_en[0]),
      .tx_0_almost_full       (txf_almost_full[0]),

      .tx_1_data              (txf_data[1]),
      .tx_1_wr_en             (txf_wr_en[1]),
      .tx_1_almost_full       (txf_almost_full[1]),

      .tx_2_data              (txf_data[2]),
      .tx_2_wr_en             (txf_wr_en[2]),
      .tx_2_almost_full       (txf_almost_full[2]),

      .tx_3_data              (txf_data[3]),
      .tx_3_wr_en             (txf_wr_en[3]),
      .tx_3_almost_full       (txf_almost_full[3]),

      //--- sigs to test console
      .done                   (eth_done),
      .success                (eth_success),
      .mac_reset              (eth_restart),

      //--- sigs to registers
      .reg_req                (core_256kb_1_reg_req[`WORD(`PHY_TEST_BLOCK_ADDR,1)]),
      .reg_rd_wr_L            (core_256kb_1_reg_rd_wr_L[`WORD(`PHY_TEST_BLOCK_ADDR,1)]),
      .reg_ack                (core_256kb_1_reg_ack[`WORD(`PHY_TEST_BLOCK_ADDR, 1)]),
      .reg_addr               (core_256kb_1_reg_addr[`WORD(`PHY_TEST_BLOCK_ADDR, `PHY_TEST_REG_ADDR_WIDTH)]),

      .reg_rd_data            (core_256kb_1_reg_rd_data[`WORD(`PHY_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data            (core_256kb_1_reg_wr_data[`WORD(`PHY_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      // misc
      .reset                  (reset),
      .clk                    (core_clk_int)
   );


   //--------------------------------------------------
   //
   // --- SATA test
   //
   //--------------------------------------------------

   serial_test serial_test
   ( // --- Testing interface
     .test_running            (serial_test_running),
     .test_done               (serial_test_done),
     .test_successful         (serial_test_successful),

     // --- Interface to register demux
     .serial_tst_reg_req      (core_256kb_1_reg_req[`WORD(`SERIAL_TEST_BLOCK_ADDR,1)]),
     .serial_tst_reg_rd_wr_L  (core_256kb_1_reg_rd_wr_L[`WORD(`SERIAL_TEST_BLOCK_ADDR,1)]),
     .serial_tst_reg_ack      (core_256kb_1_reg_ack[`WORD(`SERIAL_TEST_BLOCK_ADDR, 1)]),
     .serial_tst_reg_addr     (core_256kb_1_reg_addr[`WORD(`SERIAL_TEST_BLOCK_ADDR, `SERIAL_TEST_REG_ADDR_WIDTH)]),
     .serial_tst_reg_rd_data  (core_256kb_1_reg_rd_data[`WORD(`SERIAL_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
     .serial_tst_reg_wr_data  (core_256kb_1_reg_wr_data[`WORD(`SERIAL_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),


     // --- MGT interface
     .serial_TXP_0            (serial_TXP_0),
     .serial_TXN_0            (serial_TXN_0),
     .serial_RXP_0            (serial_RXP_0),
     .serial_RXN_0            (serial_RXN_0),
     .serial_TXP_1            (serial_TXP_1),
     .serial_TXN_1            (serial_TXN_1),
     .serial_RXP_1            (serial_RXP_1),
     .serial_RXN_1            (serial_RXN_1),

     // --- Misc
     .clk                     (core_clk_int),
     .reset                   (reset)
     );



   //--------------------------------------------------
   //
   // --- Clock-test results
   //
   //--------------------------------------------------
   clk_test_reg clk_test_reg (
      // Register interface signals
      .reg_req       (core_256kb_1_reg_req[`WORD(`CLOCK_TEST_BLOCK_ADDR,1)]),
      .reg_rd_wr_L   (core_256kb_1_reg_rd_wr_L[`WORD(`CLOCK_TEST_BLOCK_ADDR,1)]),
      .reg_ack       (core_256kb_1_reg_ack[`WORD(`CLOCK_TEST_BLOCK_ADDR, 1)]),
      .reg_addr      (core_256kb_1_reg_addr[`WORD(`CLOCK_TEST_BLOCK_ADDR, `CLOCK_TEST_REG_ADDR_WIDTH)]),
      .reg_rd_data   (core_256kb_1_reg_rd_data[`WORD(`CLOCK_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data   (core_256kb_1_reg_wr_data[`WORD(`CLOCK_TEST_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      //-- misc
      .clk           (core_clk_int),
      .reset         (reset)
   );



   //--------------------------------------------------
   //
   // --- DMA controller
   //
   //--------------------------------------------------
   nf2_dma
     #(.NUM_CPU_QUEUES (NUM_QUEUES/2),
       .PKT_LEN_CNT_WIDTH (PKT_LEN_CNT_WIDTH),
       .USER_DATA_PATH_WIDTH (DATA_WIDTH)
       ) nf2_dma
       (
         // --- signals to/from CPU rx queues
         .cpu_q_dma_pkt_avail          (cpu_q_dma_pkt_avail),

         // ---- signals to/from CPU rx queue 0
         .cpu_q_dma_rd_rdy_0           ( cpu_q_dma_rd_rdy[0] ),
         .cpu_q_dma_rd_0               ( cpu_q_dma_rd[0] ),
         .cpu_q_dma_rd_data_0          ( cpu_q_dma_rd_data[0] ),
         .cpu_q_dma_rd_ctrl_0          ( cpu_q_dma_rd_ctrl[0] ),

         // ---- signals to/from CPU rx queue 1
         .cpu_q_dma_rd_rdy_1           ( cpu_q_dma_rd_rdy[1] ),
         .cpu_q_dma_rd_1               ( cpu_q_dma_rd[1] ),
         .cpu_q_dma_rd_data_1          ( cpu_q_dma_rd_data[1] ),
         .cpu_q_dma_rd_ctrl_1          ( cpu_q_dma_rd_ctrl[1] ),

         // ---- signals to/from CPU rx queue 2
         .cpu_q_dma_rd_rdy_2           ( cpu_q_dma_rd_rdy[2] ),
         .cpu_q_dma_rd_2               ( cpu_q_dma_rd[2] ),
         .cpu_q_dma_rd_data_2          ( cpu_q_dma_rd_data[2] ),
         .cpu_q_dma_rd_ctrl_2          ( cpu_q_dma_rd_ctrl[2] ),

         // ---- signals to/from CPU rx queue 3
         .cpu_q_dma_rd_rdy_3           ( cpu_q_dma_rd_rdy[3] ),
         .cpu_q_dma_rd_3               ( cpu_q_dma_rd[3] ),
         .cpu_q_dma_rd_data_3          ( cpu_q_dma_rd_data[3] ),
         .cpu_q_dma_rd_ctrl_3          ( cpu_q_dma_rd_ctrl[3] ),

         // signals to/from CPU tx queues
         .cpu_q_dma_nearly_full        (cpu_q_dma_nearly_full),
         .cpu_q_dma_can_wr_pkt         (cpu_q_dma_can_wr_pkt),

         // signals to/from CPU tx queue 0
         .cpu_q_dma_wr_0               ( cpu_q_dma_wr[0] ),
         .cpu_q_dma_wr_pkt_vld_0       ( cpu_q_dma_wr_pkt_vld[0] ),
         .cpu_q_dma_wr_data_0          ( cpu_q_dma_wr_data[0] ),
         .cpu_q_dma_wr_ctrl_0          ( cpu_q_dma_wr_ctrl[0] ),

         // signals to/from CPU tx queue 1
         .cpu_q_dma_wr_1               ( cpu_q_dma_wr[1] ),
         .cpu_q_dma_wr_pkt_vld_1       ( cpu_q_dma_wr_pkt_vld[1] ),
         .cpu_q_dma_wr_data_1          ( cpu_q_dma_wr_data[1] ),
         .cpu_q_dma_wr_ctrl_1          ( cpu_q_dma_wr_ctrl[1] ),

         // signals to/from CPU tx queue 2
         .cpu_q_dma_wr_2               ( cpu_q_dma_wr[2] ),
         .cpu_q_dma_wr_pkt_vld_2       ( cpu_q_dma_wr_pkt_vld[2] ),
         .cpu_q_dma_wr_data_2          ( cpu_q_dma_wr_data[2] ),
         .cpu_q_dma_wr_ctrl_2          ( cpu_q_dma_wr_ctrl[2] ),

         // signals to/from CPU tx queue 3
         .cpu_q_dma_wr_3               ( cpu_q_dma_wr[3] ),
         .cpu_q_dma_wr_pkt_vld_3       ( cpu_q_dma_wr_pkt_vld[3] ),
         .cpu_q_dma_wr_data_3          ( cpu_q_dma_wr_data[3] ),
         .cpu_q_dma_wr_ctrl_3          ( cpu_q_dma_wr_ctrl[3] ),

         // --- signals to/from CPCI pins
         .dma_op_code_req              (dma_op_code_req),
         .dma_op_queue_id              (dma_op_queue_id),
         .dma_op_code_ack              (dma_op_code_ack),

         // DMA TX data and flow control
         .dma_vld_c2n                  (dma_vld_c2n),
         .dma_data_c2n                 (dma_data_c2n),
         .dma_dest_q_nearly_full_n2c   (dma_q_nearly_full_n2c),

         // DMA RX data and flow control
         .dma_vld_n2c                  (dma_vld_n2c),
         .dma_data_n2c                 (dma_data_n2c),
         .dma_dest_q_nearly_full_c2n   (dma_q_nearly_full_c2n),

         // enable to drive tri-state bus
         .dma_data_tri_en              (dma_data_tri_en),

         // ----from reg_grp dma interface
         .dma_reg_req                  (core_256kb_0_reg_req[`WORD(`DMA_BLOCK_ADDR,1)]),
         .dma_reg_rd_wr_L              (core_256kb_0_reg_rd_wr_L[`WORD(`DMA_BLOCK_ADDR,1)]),
         .dma_reg_ack                  (core_256kb_0_reg_ack[`WORD(`DMA_BLOCK_ADDR, 1)]),
         .dma_reg_addr                 (core_256kb_0_reg_addr[`WORD(`DMA_BLOCK_ADDR, `DMA_REG_ADDR_WIDTH)]),
         .dma_reg_rd_data              (core_256kb_0_reg_rd_data[`WORD(`DMA_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),
         .dma_reg_wr_data              (core_256kb_0_reg_wr_data[`WORD(`DMA_BLOCK_ADDR, `CPCI_NF2_DATA_WIDTH)]),

         //--- misc
         .reset                        (reset),
         .clk                          (core_clk_int),
         .cpci_clk                     (cpci_clk_int)
        );



   //--------------------------------------------------
   //
   // --- Self-test results
   //     Attempt to summarize the result by lighting up a LED
   //
   //--------------------------------------------------
   wire result;

   // Invert the signal before placing it on the LED
   assign debug_led = ~result;

   selftest_result test_res (
         .result           (result),
         .dram_done        (dram_done),
         .dram_success     (dram_success),
         .sram_done        (sram_done),
         .sram_success     (~sram_fail),
         .serial_done      (serial_test_done),
         .serial_success   (serial_test_successful),
         .eth_done         (eth_done),
         .eth_success      (eth_success),
         .clk              (core_clk_int),
         .reset            (reset)
   );

   assign nf2_err = 0;


   //--------------------------------------------------
   //
   // --- Logic Analyzer signals
   //
   //--------------------------------------------------

   reg [31:0] tmp_debug;

   always @(posedge core_clk_int) begin
      tmp_debug  <= cpci_debug_data;
      debug_data <= tmp_debug;
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

   FDDRRSE debug_clk_1_ddr_iob
     (.Q  (debug_clk[1]),
      .D0 (1'b0),
      .D1 (1'b1),
      .C0 (core_clk_int),
      .C1 (not_core_clk_int),
      .CE (1'b1),
      .R  (1'b0),
      .S  (1'b0)
      );


   //--------------------------------------------------
   //
   // --- MAC signal encapsulation/decapsulation
   //
   //--------------------------------------------------

   // --- Mac 0
   assign gmii_0_txd_int         = gmii_txd_int[0];
   assign gmii_0_tx_en_int       = gmii_tx_en_int[0];
   assign gmii_0_tx_er_int       = gmii_tx_er_int[0];

   assign gmii_crs_int[0]        = gmii_0_crs_int;
   assign gmii_col_int[0]        = gmii_0_col_int;
   assign gmii_rxd_reg[0]        = gmii_0_rxd_reg;
   assign gmii_rx_dv_reg[0]      = gmii_0_rx_dv_reg;
   assign gmii_rx_er_reg[0]      = gmii_0_rx_er_reg;
   assign eth_link_status[0]     = eth_link_0_status;
   assign eth_clock_speed[0]     = eth_clock_0_speed;
   assign eth_duplex_status[0]   = eth_duplex_0_status;
   assign rx_rgmii_clk_int[0]    = rx_rgmii_0_clk_int;

   // --- Mac 1
   assign gmii_1_txd_int         = gmii_txd_int[1];
   assign gmii_1_tx_en_int       = gmii_tx_en_int[1];
   assign gmii_1_tx_er_int       = gmii_tx_er_int[1];

   assign gmii_crs_int[1]        = gmii_1_crs_int;
   assign gmii_col_int[1]        = gmii_1_col_int;
   assign gmii_rxd_reg[1]        = gmii_1_rxd_reg;
   assign gmii_rx_dv_reg[1]      = gmii_1_rx_dv_reg;
   assign gmii_rx_er_reg[1]      = gmii_1_rx_er_reg;
   assign eth_link_status[1]     = eth_link_1_status;
   assign eth_clock_speed[1]     = eth_clock_1_speed;
   assign eth_duplex_status[1]   = eth_duplex_1_status;
   assign rx_rgmii_clk_int[1]    = rx_rgmii_1_clk_int;

   // --- Mac 2
   assign gmii_2_txd_int         = gmii_txd_int[2];
   assign gmii_2_tx_en_int       = gmii_tx_en_int[2];
   assign gmii_2_tx_er_int       = gmii_tx_er_int[2];

   assign gmii_crs_int[2]        = gmii_2_crs_int;
   assign gmii_col_int[2]        = gmii_2_col_int;
   assign gmii_rxd_reg[2]        = gmii_2_rxd_reg;
   assign gmii_rx_dv_reg[2]      = gmii_2_rx_dv_reg;
   assign gmii_rx_er_reg[2]      = gmii_2_rx_er_reg;
   assign eth_link_status[2]     = eth_link_2_status;
   assign eth_clock_speed[2]     = eth_clock_2_speed;
   assign eth_duplex_status[2]   = eth_duplex_2_status;
   assign rx_rgmii_clk_int[2]    = rx_rgmii_2_clk_int;

   // --- Mac 3
   assign gmii_3_txd_int         = gmii_txd_int[3];
   assign gmii_3_tx_en_int       = gmii_tx_en_int[3];
   assign gmii_3_tx_er_int       = gmii_tx_er_int[3];

   assign gmii_crs_int[3]        = gmii_3_crs_int;
   assign gmii_col_int[3]        = gmii_3_col_int;
   assign gmii_rxd_reg[3]        = gmii_3_rxd_reg;
   assign gmii_rx_dv_reg[3]      = gmii_3_rx_dv_reg;
   assign gmii_rx_er_reg[3]      = gmii_3_rx_er_reg;
   assign eth_link_status[3]     = eth_link_3_status;
   assign eth_clock_speed[3]     = eth_clock_3_speed;
   assign eth_duplex_status[3]   = eth_duplex_3_status;
   assign rx_rgmii_clk_int[3]    = rx_rgmii_3_clk_int;

endmodule // nf2_core
