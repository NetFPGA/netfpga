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

   wire 			      enable_dma;

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
   //
   //--------------------------------------------------
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
