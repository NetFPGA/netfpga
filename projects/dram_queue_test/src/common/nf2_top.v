//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_top.v 3827 2008-06-03 07:15:23Z grg $
//
// Module: nf2_top.v
// Project: NetFPGA
// Description: Top level module for a NetFPGA design.
//
// This is the top level module - it instantiates the I/Os and
// clocks, and then instantiates a 'core' which contains all other
// logic.
//
///////////////////////////////////////////////////////////////////////////////

module nf2_top (

    //-- RGMII interfaces for 4 MACs.

    output [3:0] rgmii_0_txd,
    output       rgmii_0_tx_ctl,
    output       rgmii_0_txc,
    input  [3:0] rgmii_0_rxd,
    input        rgmii_0_rx_ctl,
    input        rgmii_0_rxc,

    output [3:0] rgmii_1_txd,
    output       rgmii_1_tx_ctl,
    output       rgmii_1_txc,
    input  [3:0] rgmii_1_rxd,
    input        rgmii_1_rx_ctl,
    input        rgmii_1_rxc,

    output [3:0] rgmii_2_txd,
    output       rgmii_2_tx_ctl,
    output       rgmii_2_txc,
    input  [3:0] rgmii_2_rxd,
    input        rgmii_2_rx_ctl,
    input        rgmii_2_rxc,

    output [3:0] rgmii_3_txd,
    output       rgmii_3_tx_ctl,
    output       rgmii_3_txc,
    input  [3:0] rgmii_3_rxd,
    input        rgmii_3_rx_ctl,
    input        rgmii_3_rxc,

    input        gtx_clk,      // common TX clk reference 125MHz.


    // DDR signals

    input ddr_clk_200,
    input ddr_clk_200b,

    output        ddr2_odt0,
    output        ddr2_clk0,
    output        ddr2_clk0b,
    output        ddr2_clk1,
    output        ddr2_clk1b,
    output        ddr2_cke,
    output        ddr2_csb,
    output        ddr2_rasb,
    output        ddr2_casb,
    output        ddr2_web,
    output [3:0]  ddr2_dm,
    output [1:0]  ddr2_ba,
    output [12:0] ddr2_address,
    inout  [31:0] ddr2_dq,
    inout  [3:0]  ddr2_dqs,
    inout  [3:0]  ddr2_dqs_n,
    input         ddr2_rst_dqs_div_in,
    output        ddr2_rst_dqs_div_out,


    // CPCI interface and clock

    input                               cpci_clk,   // 62.5 MHz
    input                               cpci_rd_wr_L,
    input                               cpci_req,
    input   [`CPCI_NF2_ADDR_WIDTH-1:0]  cpci_addr,
    inout   [`CPCI_NF2_DATA_WIDTH-1:0]  cpci_data,
    output                              cpci_wr_rdy,
    output                              cpci_rd_rdy,
    output                              nf2_err,  // was cnet_err

    // synthesis attribute keep of nf2_err is "true";


    // ---- SRAM 1
    // Note: 1 extra address bit on sram
    output [19:0] sram1_addr,
    inout  [`SRAM_DATA_WIDTH - 1:0] sram1_data,
    output        sram1_we,
    output [3:0]  sram1_bw,
    output        sram1_zz,

    // ---- SRAM 2
    // Note: 1 extra address bit on sram
    output [19:0] sram2_addr,
    inout  [`SRAM_DATA_WIDTH - 1:0] sram2_data,
    output        sram2_we,
    output [3:0]  sram2_bw,
    output        sram2_zz,

    // --- CPCI DMA handshake signals
    input [1:0]   dma_op_code_req,
    input [3:0]   dma_op_queue_id,
    output [1:0]  dma_op_code_ack,

     // DMA data and flow control
    input         dma_vld_c2n,
    output        dma_vld_n2c,
    inout [`DMA_DATA_WIDTH-1:0] dma_data,
    input         dma_q_nearly_full_c2n,
    output        dma_q_nearly_full_n2c,

    // --- CPCI Debug Data

    input [`CPCI_DEBUG_DATA_WIDTH-1:0] cpci_debug_data,

    // ---  MDC/MDIO PHY control signals

    output  phy_mdc,
    inout   phy_mdio,

    //--- Debug bus (goes to LA connector)

    output            debug_led,
    output     [31:0] debug_data,
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

    output   cpci_rp_en,
    output   cpci_rp_prog_b,
    output   cpci_rp_din,

    // core clock - must also be same as sram clock

    input      core_clk,

    // Misc

    input        nf2_reset    // driven by CPCI

    );

   // CHANGE THIS
   //reg                 reset;
   wire        reset;
   wire        core_locked;

   // Disable the reset signal
   //
   // Be careful -- this is potentially dangerous as a badly behaved design
   // could lock itself and require reprogramming.
   //
   // Purpose: Spartan reprogramming designs
   //          Reset has to be disabled to prevent the Spartan from resetting
   //          the Virtex mid-programming when it's IOs come online.
   wire        disable_reset;


   //----------------------------------------------------------------------
   // gtx_clk Clock Management
   //
   // This is the input 125MHz Transmit reference clock for the MACs.
   // It is common to all four MACs and thus is instantiated here.
   //----------------------------------------------------------------------

   IBUF ibufg_gtx_clk (.I(gtx_clk),           .O(gtx_clk_ibufg));

   //-- Use a DCM to generate the 2ns set-up and hold time
   //-- at the transmitter output at 1000Mb/s.
   // NOTE: This is much simpler than the one in UG-138 because we do not
   //       support operation at 10 or 100Mbps

   DCM RGMII_TX_DCM (
                     .CLKIN(gtx_clk_ibufg),
                     .CLKFB(tx_rgmii_clk_int),
                     .DSSEN(1'b0),
                     .PSINCDEC(1'b0),
                     .PSEN(1'b0),
                     .PSCLK(1'b0),
                     .RST(reset),
                     .CLK0(tx_clk0),
                     .CLK90(tx_clk90),
                     .CLK180(),
                     .CLK270(),
                     .CLK2X(),
                     .CLK2X180(),
                     .CLKDV(),
                     .CLKFX(),
                     .CLKFX180(),
                     .PSDONE(),
                     .STATUS(),
                     .LOCKED());

   //-- Now we need to feed these to BUFGMUXes so that they are global.
   // We must feed both clocks to both BUFGMUXes even though the mux select
   // is fixed. This is due to a constraint on BUFGMUXES in the Virtex 2 Pro.

    BUFGMUX BUFGMUX_TXCLK (
                           .O(tx_rgmii_clk_int),
                           .I0(tx_clk0),
                           .I1(tx_clk90),  // not used
                           .S(1'b0)
                           );

   //-- To maintain the 2ns set-up and hold requirement we need to use the 90
   //-- degrees out of phase clock output to generate the rgmii_txc output.

   BUFGMUX BUFGMUX_TXCLK90 (
                            .O(tx_rgmii_clk90_int),
                            .I1(tx_clk0),  // not used
                            .I0(tx_clk90),
                            .S(1'b0)
                            );



   //----------------------------------------------------------------
   // Receive clocks.
   //
   // There are 4 receive clocks. Each has its own DCM.
   // We simply route the incoming rxc to a DCM via an IBUFG.
   //
   // They are defined here simply to make the constraints easier
   // to specify.
   //----------------------------------------------------------------

   IBUFG inst_rgmii_0_rxc_ibuf  (.I(rgmii_0_rxc),  .O(rgmii_0_rxc_ibuf));
   IBUFG inst_rgmii_1_rxc_ibuf  (.I(rgmii_1_rxc),  .O(rgmii_1_rxc_ibuf));
   IBUFG inst_rgmii_2_rxc_ibuf  (.I(rgmii_2_rxc),  .O(rgmii_2_rxc_ibuf));
   IBUFG inst_rgmii_3_rxc_ibuf  (.I(rgmii_3_rxc),  .O(rgmii_3_rxc_ibuf));

   DCM RGMII_0_RX_DCM (
                       .CLKIN(rgmii_0_rxc_ibuf),
                       .CLKFB(rx_rgmii_0_clk_int),  // feedback from BUFGMUX
                       .DSSEN(1'b0),
                       .PSINCDEC(1'b0),
                       .PSEN(1'b0),
                       .PSCLK(1'b0),
                       .RST(reset),
                       .CLK0(rgmii_0_clk0),
                       .CLK90(),
                       .CLK180(),
                       .CLK270(),
                       .CLK2X(),
                       .CLK2X180(),
                       .CLKDV(),
                       .CLKFX(),
                       .CLKFX180(),
                       .PSDONE(),
                       .STATUS(),
                       .LOCKED()
                       );

   BUFGMUX BUFGMUX_RGMII_0_RXCLK (
                                  .O(rx_rgmii_0_clk_int),
                                  .I0(rgmii_0_clk0),
                                  .I1(),
                                  .S(1'b0)
                                  );


   DCM RGMII_1_RX_DCM (
                       .CLKIN(rgmii_1_rxc_ibuf),
                       .CLKFB(rx_rgmii_1_clk_int),  // feedback from BUFGMUX
                       .DSSEN(1'b0),
                       .PSINCDEC(1'b0),
                       .PSEN(1'b0),
                       .PSCLK(1'b0),
                       .RST(reset),
                       .CLK0(rgmii_1_clk0),
                       .CLK90(),
                       .CLK180(),
                       .CLK270(),
                       .CLK2X(),
                       .CLK2X180(),
                       .CLKDV(),
                       .CLKFX(),
                       .CLKFX180(),
                       .PSDONE(),
                       .STATUS(),
                       .LOCKED()
                       );

   BUFGMUX BUFGMUX_RGMII_1_RXCLK (
                                  .O(rx_rgmii_1_clk_int),
                                  .I0(rgmii_1_clk0),
                                  .I1(),
                                  .S(1'b0)
                                  );


   DCM RGMII_2_RX_DCM (
                       .CLKIN(rgmii_2_rxc_ibuf),
                       .CLKFB(rx_rgmii_2_clk_int),  // feedback from BUFGMUX
                       .DSSEN(1'b0),
                       .PSINCDEC(1'b0),
                       .PSEN(1'b0),
                       .PSCLK(1'b0),
                       .RST(reset),
                       .CLK0(rgmii_2_clk0),
                       .CLK90(),
                       .CLK180(),
                       .CLK270(),
                       .CLK2X(),
                       .CLK2X180(),
                       .CLKDV(),
                       .CLKFX(),
                       .CLKFX180(),
                       .PSDONE(),
                       .STATUS(),
                       .LOCKED()
                       );

   BUFGMUX BUFGMUX_RGMII_2_RXCLK (
                                  .O(rx_rgmii_2_clk_int),
                                  .I0(rgmii_2_clk0),
                                  .I1(),
                                  .S(1'b0)
                                  );


   DCM RGMII_3_RX_DCM (
                       .CLKIN(rgmii_3_rxc_ibuf),
                       .CLKFB(rx_rgmii_3_clk_int),  // feedback from BUFGMUX
                       .DSSEN(1'b0),
                       .PSINCDEC(1'b0),
                       .PSEN(1'b0),
                       .PSCLK(1'b0),
                       .RST(reset),
                       .CLK0(rgmii_3_clk0),
                       .CLK90(),
                       .CLK180(),
                       .CLK270(),
                       .CLK2X(),
                       .CLK2X180(),
                       .CLKDV(),
                       .CLKFX(),
                       .CLKFX180(),
                       .PSDONE(),
                       .STATUS(),
                       .LOCKED()
                       );

   BUFGMUX BUFGMUX_RGMII_3_RXCLK (
                                  .O(rx_rgmii_3_clk_int),
                                  .I0(rgmii_3_clk0),
                                  .I1(),
                                  .S(1'b0)
                                  );

   //synthesis attribute keep of tx_rgmii_clk_int    is "true";
   //synthesis attribute keep of tx_rgmii_clk90_int    is "true";
   //synthesis attribute keep of rx_rgmii_0_clk_int    is "true";
   //synthesis attribute keep of rx_rgmii_1_clk_int    is "true";
   //synthesis attribute keep of rx_rgmii_2_clk_int    is "true";
   //synthesis attribute keep of rx_rgmii_3_clk_int    is "true";


   //----------------------------------------------------
   // Now we instantiate the various RGMII buffers for the
   // data and control signals and the outgoing TXC for
   // each channel.
   //----------------------------------------------------

   wire [7:0]    gmii_0_txd_int;
   wire [7:0]    gmii_0_rxd_reg;
   wire [1:0]    eth_clock_0_speed;

   rgmii_io rgmii_0_io (
                        .rgmii_txd             (rgmii_0_txd),
                        .rgmii_tx_ctl          (rgmii_0_tx_ctl),
                        .rgmii_txc             (rgmii_0_txc),
                        .rgmii_rxd             (rgmii_0_rxd),
                        .rgmii_rx_ctl          (rgmii_0_rx_ctl),
                        .gmii_txd_int          (gmii_0_txd_int),
                        .gmii_tx_en_int        (gmii_0_tx_en_int),
                        .gmii_tx_er_int        (gmii_0_tx_er_int),
                        .gmii_col_int          (gmii_0_col_int),
                        .gmii_crs_int          (gmii_0_crs_int),
                        .gmii_rxd_reg          (gmii_0_rxd_reg),
                        .gmii_rx_dv_reg        (gmii_0_rx_dv_reg),
                        .gmii_rx_er_reg        (gmii_0_rx_er_reg),
                        .eth_link_status       (eth_link_0_status),
                        .eth_clock_speed       (eth_clock_0_speed),
                        .eth_duplex_status     (eth_duplex_0_status),
                        .tx_rgmii_clk_int      (tx_rgmii_clk_int),
                        .tx_rgmii_clk90_int    (tx_rgmii_clk90_int),
                        .rx_rgmii_clk_int      (rx_rgmii_0_clk_int),
                        .reset                 (reset)
                        );

   // synthesis attribute keep_hierarchy of rgmii_0_io is false;


   wire [7:0]    gmii_1_txd_int;
   wire [7:0]    gmii_1_rxd_reg;
   wire [1:0]    eth_clock_1_speed;

   rgmii_io rgmii_1_io (
                        .rgmii_txd             (rgmii_1_txd),
                        .rgmii_tx_ctl          (rgmii_1_tx_ctl),
                        .rgmii_txc             (rgmii_1_txc),
                        .rgmii_rxd             (rgmii_1_rxd),
                        .rgmii_rx_ctl          (rgmii_1_rx_ctl),
                        .gmii_txd_int          (gmii_1_txd_int),
                        .gmii_tx_en_int        (gmii_1_tx_en_int),
                        .gmii_tx_er_int        (gmii_1_tx_er_int),
                        .gmii_col_int          (gmii_1_col_int),
                        .gmii_crs_int          (gmii_1_crs_int),
                        .gmii_rxd_reg          (gmii_1_rxd_reg),
                        .gmii_rx_dv_reg        (gmii_1_rx_dv_reg),
                        .gmii_rx_er_reg        (gmii_1_rx_er_reg),
                        .eth_link_status       (eth_link_1_status),
                        .eth_clock_speed       (eth_clock_1_speed),
                        .eth_duplex_status     (eth_duplex_1_status),
                        .tx_rgmii_clk_int      (tx_rgmii_clk_int),
                        .tx_rgmii_clk90_int    (tx_rgmii_clk90_int),
                        .rx_rgmii_clk_int      (rx_rgmii_1_clk_int),
                        .reset                 (reset)
                        );

   // synthesis attribute keep_hierarchy of rgmii_1_io is false;


   wire [7:0]    gmii_2_txd_int;
   wire [7:0]    gmii_2_rxd_reg;
   wire [1:0]    eth_clock_2_speed;

   rgmii_io rgmii_2_io (
                        .rgmii_txd             (rgmii_2_txd),
                        .rgmii_tx_ctl          (rgmii_2_tx_ctl),
                        .rgmii_txc             (rgmii_2_txc),
                        .rgmii_rxd             (rgmii_2_rxd),
                        .rgmii_rx_ctl          (rgmii_2_rx_ctl),
                        .gmii_txd_int          (gmii_2_txd_int),
                        .gmii_tx_en_int        (gmii_2_tx_en_int),
                        .gmii_tx_er_int        (gmii_2_tx_er_int),
                        .gmii_col_int          (gmii_2_col_int),
                        .gmii_crs_int          (gmii_2_crs_int),
                        .gmii_rxd_reg          (gmii_2_rxd_reg),
                        .gmii_rx_dv_reg        (gmii_2_rx_dv_reg),
                        .gmii_rx_er_reg        (gmii_2_rx_er_reg),
                        .eth_link_status       (eth_link_2_status),
                        .eth_clock_speed       (eth_clock_2_speed),
                        .eth_duplex_status     (eth_duplex_2_status),
                        .tx_rgmii_clk_int      (tx_rgmii_clk_int),
                        .tx_rgmii_clk90_int    (tx_rgmii_clk90_int),
                        .rx_rgmii_clk_int      (rx_rgmii_2_clk_int),
                        .reset                 (reset)
                        );

   // synthesis attribute keep_hierarchy of rgmii_2_io is false;


   wire [7:0]    gmii_3_txd_int;
   wire [7:0]    gmii_3_rxd_reg;
   wire [1:0]    eth_clock_3_speed;

   rgmii_io rgmii_3_io (
                        .rgmii_txd             (rgmii_3_txd),
                        .rgmii_tx_ctl          (rgmii_3_tx_ctl),
                        .rgmii_txc             (rgmii_3_txc),
                        .rgmii_rxd             (rgmii_3_rxd),
                        .rgmii_rx_ctl          (rgmii_3_rx_ctl),
                        .gmii_txd_int          (gmii_3_txd_int),
                        .gmii_tx_en_int        (gmii_3_tx_en_int),
                        .gmii_tx_er_int        (gmii_3_tx_er_int),
                        .gmii_col_int          (gmii_3_col_int),
                        .gmii_crs_int          (gmii_3_crs_int),
                        .gmii_rxd_reg          (gmii_3_rxd_reg),
                        .gmii_rx_dv_reg        (gmii_3_rx_dv_reg),
                        .gmii_rx_er_reg        (gmii_3_rx_er_reg),
                        .eth_link_status       (eth_link_3_status),
                        .eth_clock_speed       (eth_clock_3_speed),
                        .eth_duplex_status     (eth_duplex_3_status),
                        .tx_rgmii_clk_int      (tx_rgmii_clk_int),
                        .tx_rgmii_clk90_int    (tx_rgmii_clk90_int),
                        .rx_rgmii_clk_int      (rx_rgmii_3_clk_int),
                        .reset                 (reset)
                        );

   // synthesis attribute keep_hierarchy of rgmii_3_io is false;




   //--------------------------------------------------------------
   // DDR interface
   //--------------------------------------------------------------


   // outputs from DDR controller
   wire          ddr2_user_auto_ref_req;
   wire          ddr2_user_ar_done;
   wire          ddr2_user_cmd_ack;
   wire          ddr2_user_rd_data_valid;
   wire [63:0]   ddr2_user_rd_data;
   wire          ddr2_user_init_val;
   wire          ddr2_user_burst_done;

   // inputs to DDR controller
   wire [21: 0]  ddr2_user_addr;
   wire [1:0]    ddr2_user_bank_addr;
   wire [3:0]    ddr2_user_cmd;
   wire [63:0]   ddr2_user_wr_data;
   wire [7:0]    ddr2_user_wr_data_mask;
   wire [14:0]   ddr2_user_config1;
   wire [12:0]   ddr2_user_config2;

   // Clocks
   wire clk_ddr_200;
   wire clk90_ddr_200;

   // Resets
   wire ddr2_reset;
   wire ddr2_reset90;



   // Note:
   //   - dip1, dip2 and dip3 are not used
   //   - reset_in is active low
   mem_interface_top mem_interface_top (
                .dip1                         (),
                .dip2                         (),
                .reset_in                     (~reset),
                .dip3                         (),
                .SYS_CLK                      (ddr_clk_200),
                .SYS_CLKb                     (ddr_clk_200b),
                .clk_int                      (clk_ddr_200),
                .clk90_int                    (clk90_ddr_200),
                .clk180                       (),
                .clk270                       (),
                .sys_rst                      (ddr2_reset),
                .sys_rst90                    (ddr2_reset90),
                .sys_rst180                   (),
                .sys_rst270                   (),

                .cntrl0_rst_dqs_div_in        (ddr2_rst_dqs_div_in),
                .cntrl0_rst_dqs_div_out       (ddr2_rst_dqs_div_out),

                .cntrl0_ddr2_casb             (ddr2_casb),
                .cntrl0_ddr2_cke              (ddr2_cke),
                .cntrl0_ddr2_clk0             (ddr2_clk0),
                .cntrl0_ddr2_clk0b            (ddr2_clk0b),
                .cntrl0_ddr2_clk1             (ddr2_clk1),
                .cntrl0_ddr2_clk1b            (ddr2_clk1b),
                .cntrl0_ddr2_csb              (ddr2_csb),
                .cntrl0_ddr2_rasb             (ddr2_rasb),
                .cntrl0_ddr2_web              (ddr2_web),
                .cntrl0_ddr2_address          (ddr2_address),
                .cntrl0_ddr2_ODT0             (ddr2_odt0),
                .cntrl0_ddr2_dqs_n            (ddr2_dqs_n),
                .cntrl0_ddr2_dqs              (ddr2_dqs),
                .cntrl0_ddr2_ba               (ddr2_ba),
                .cntrl0_ddr2_dm               (ddr2_dm),
                .cntrl0_ddr2_dq               (ddr2_dq),

                .cntrl0_user_config_register1 (ddr2_user_config1),
                .cntrl0_user_config_register2 (ddr2_user_config2),

                .cntrl0_burst_done            (ddr2_user_burst_done),
                .cntrl0_user_input_address    (ddr2_user_addr),
                .cntrl0_user_bank_address     (ddr2_user_bank_addr),
                .cntrl0_user_command_register (ddr2_user_cmd),
                .cntrl0_user_input_data       (ddr2_user_wr_data),
                .cntrl0_user_data_mask        (ddr2_user_wr_data_mask),
                .cntrl0_ar_done               (ddr2_user_ar_done),
                .cntrl0_user_cmd_ack          (ddr2_user_cmd_ack),
                .cntrl0_auto_ref_req          (ddr2_user_auto_ref_req),
                .cntrl0_user_data_valid       (ddr2_user_rd_data_valid),
                .cntrl0_user_output_data      (ddr2_user_rd_data),
                .cntrl0_init_val              (ddr2_user_init_val)
        );


   // --- end of DDR


   // --- CPCI interface

   IBUFG inst_cpci_clk_ibuf  (.I(cpci_clk),  .O(cpci_clk_ibuf));

   BUFGMUX BUFGMUX_CPCI_CLK (
                              .O(cpci_clk_int),
                              .I0(cpci_clk_ibuf),
                              .I1(),  // not used
                              .S(1'b0)
                              );

   wire [`CPCI_NF2_DATA_WIDTH-1:0]   cpci_rd_data;
   wire          cpci_data_tri_en;
   assign        cpci_data = cpci_data_tri_en ? cpci_rd_data : 'hz;


   // --- end of CPCI interface


   // --- Tri-state driver logic for SRAM
   wire [`SRAM_DATA_WIDTH-1:0] sram1_wr_data;
   wire [`SRAM_DATA_WIDTH-1:0] sram2_wr_data;

   wire          sram1_tri_en;
   wire          sram2_tri_en;

   assign        sram1_data = sram1_tri_en ? sram1_wr_data : `SRAM_DATA_WIDTH'hz;
   assign        sram2_data = sram2_tri_en ? sram2_wr_data : `SRAM_DATA_WIDTH'hz;


   // --- tie off useless signals

   // junk -- currently 1 spare bit
   assign        sram1_addr[19] = reset ? 1'b0 : 1'b1;

   // junk
   assign        sram2_addr[19] = reset ? 1'b0 : 1'b1;

   // --- end of SRAM interfaces


   // --- PHY MDIO tri-state

   wire   phy_mdata_tri, phy_mdata_out;

   assign phy_mdio = phy_mdata_tri ? phy_mdata_out : 1'bz;
   assign phy_mdata_in = phy_mdio;

   // --- end of PHY MDIO tri-state


   // --- core clock logic.

   IBUFG inst_core_clk_ibuf  (.I(core_clk),  .O(core_clk_ibuf));

   DCM CORE_DCM_CLK (
                     .CLKIN(core_clk_ibuf),
                     .CLKFB(core_clk_int),  // feedback from BUFGMUX
                     .DSSEN(1'b0),
                     .PSINCDEC(1'b0),
                     .PSEN(1'b0),
                     .PSCLK(1'b0),
                     .RST(nf2_reset & ~disable_reset),
                     .CLK0(core_clk0),
                     .CLK90(),
                     .CLK180(),
                     .CLK270(),
                     .CLK2X(),
                     .CLK2X180(),
                     .CLKDV(),
                     .CLKFX(),
                     .CLKFX180(),
                     .PSDONE(),
                     .STATUS(),
                     .LOCKED(core_locked)
                     );

   BUFGMUX BUFGMUX_CORE_CLK (
                             .O(core_clk_int),
                             .I1(cpci_clk_ibuf),  // not used.
                             .I0(core_clk0),
                             .S(1'b0)
                             );

   // --- end of core clock logic.


   // --- DMA data tri-state

   wire   dma_data_tri_en;
   wire [`DMA_DATA_WIDTH-1:0] dma_data_n2c;

   assign dma_data = dma_data_tri_en ? dma_data_n2c : {`DMA_DATA_WIDTH {1'b z}};

   // --- end of DMA data tri-state


   nf2_core nf2_core (
              .gmii_0_txd_int     (gmii_0_txd_int),
              .gmii_0_tx_en_int   (gmii_0_tx_en_int),
              .gmii_0_tx_er_int   (gmii_0_tx_er_int),
              .gmii_0_crs_int     (gmii_0_crs_int),
              .gmii_0_col_int     (gmii_0_col_int),
              .gmii_0_rxd_reg     (gmii_0_rxd_reg),
              .gmii_0_rx_dv_reg   (gmii_0_rx_dv_reg),
              .gmii_0_rx_er_reg   (gmii_0_rx_er_reg),
              .eth_link_0_status  (eth_link_0_status),
              .eth_clock_0_speed  (eth_clock_0_speed),
              .eth_duplex_0_status(eth_duplex_0_status),
              .gmii_1_txd_int     (gmii_1_txd_int),
              .gmii_1_tx_en_int   (gmii_1_tx_en_int),
              .gmii_1_tx_er_int   (gmii_1_tx_er_int),
              .gmii_1_crs_int     (gmii_1_crs_int),
              .gmii_1_col_int     (gmii_1_col_int),
              .gmii_1_rxd_reg     (gmii_1_rxd_reg),
              .gmii_1_rx_dv_reg   (gmii_1_rx_dv_reg),
              .gmii_1_rx_er_reg   (gmii_1_rx_er_reg),
              .eth_link_1_status  (eth_link_1_status),
              .eth_clock_1_speed  (eth_clock_1_speed),
              .eth_duplex_1_status(eth_duplex_1_status),
              .gmii_2_txd_int     (gmii_2_txd_int),
              .gmii_2_tx_en_int   (gmii_2_tx_en_int),
              .gmii_2_tx_er_int   (gmii_2_tx_er_int),
              .gmii_2_crs_int     (gmii_2_crs_int),
              .gmii_2_col_int     (gmii_2_col_int),
              .gmii_2_rxd_reg     (gmii_2_rxd_reg),
              .gmii_2_rx_dv_reg   (gmii_2_rx_dv_reg),
              .gmii_2_rx_er_reg   (gmii_2_rx_er_reg),
              .eth_link_2_status  (eth_link_2_status),
              .eth_clock_2_speed  (eth_clock_2_speed),
              .eth_duplex_2_status(eth_duplex_2_status),
              .gmii_3_txd_int     (gmii_3_txd_int),
              .gmii_3_tx_en_int   (gmii_3_tx_en_int),
              .gmii_3_tx_er_int   (gmii_3_tx_er_int),
              .gmii_3_crs_int     (gmii_3_crs_int),
              .gmii_3_col_int     (gmii_3_col_int),
              .gmii_3_rxd_reg     (gmii_3_rxd_reg),
              .gmii_3_rx_dv_reg   (gmii_3_rx_dv_reg),
              .gmii_3_rx_er_reg   (gmii_3_rx_er_reg),
              .eth_link_3_status  (eth_link_3_status),
              .eth_clock_3_speed  (eth_clock_3_speed),
              .eth_duplex_3_status(eth_duplex_3_status),
              .tx_rgmii_clk_int   (tx_rgmii_clk_int),
              .rx_rgmii_0_clk_int (rx_rgmii_0_clk_int),
              .rx_rgmii_1_clk_int (rx_rgmii_1_clk_int),
              .rx_rgmii_2_clk_int (rx_rgmii_2_clk_int),
              .rx_rgmii_3_clk_int (rx_rgmii_3_clk_int),
              .cpci_clk_int       (cpci_clk_int),
              .cpci_rd_wr_L       (cpci_rd_wr_L),
              .cpci_req           (cpci_req),
              .cpci_addr          (cpci_addr),
              .cpci_wr_data       (cpci_data),
              .cpci_rd_data       (cpci_rd_data),
              .cpci_data_tri_en   (cpci_data_tri_en),
              .cpci_wr_rdy        (cpci_wr_rdy),
              .cpci_rd_rdy        (cpci_rd_rdy),
              .nf2_err            (nf2_err),
              .sram1_addr         (sram1_addr[`SRAM_ADDR_WIDTH-1:0]),
              .sram1_wr_data      (sram1_wr_data),
              .sram1_rd_data      (sram1_data),
              .sram1_tri_en       (sram1_tri_en),
              .sram1_we           (sram1_we),
              .sram1_bw           (sram1_bw),
              .sram1_zz           (sram1_zz),
              .sram2_addr         (sram2_addr[`SRAM_ADDR_WIDTH-1:0]),
              .sram2_wr_data      (sram2_wr_data),
              .sram2_rd_data      (sram2_data),
              .sram2_tri_en       (sram2_tri_en),
              .sram2_we           (sram2_we),
              .sram2_bw           (sram2_bw),
              .sram2_zz           (sram2_zz),
              .ddr2_cmd           (ddr2_user_cmd),
              .ddr2_cmd_ack       (ddr2_user_cmd_ack),
              .ddr2_addr          (ddr2_user_addr),
              .ddr2_bank_addr     (ddr2_user_bank_addr),
              .ddr2_burst_done    (ddr2_user_burst_done),
              .ddr2_rd_data       (ddr2_user_rd_data),
              .ddr2_rd_data_valid (ddr2_user_rd_data_valid),
              .ddr2_wr_data       (ddr2_user_wr_data),
              .ddr2_wr_data_mask  (ddr2_user_wr_data_mask),
              .ddr2_auto_ref_req  (ddr2_user_auto_ref_req),
              .ddr2_ar_done       (ddr2_user_ar_done),
              .ddr2_config1       (ddr2_user_config1),
              .ddr2_config2       (ddr2_user_config2),
              .ddr2_init_val      (ddr2_user_init_val),
              .ddr2_reset         (ddr2_reset),
              .ddr2_reset90       (ddr2_reset90),
              .clk_ddr_200        (clk_ddr_200),
              .clk90_ddr_200      (clk90_ddr_200),

              //DMA handshake signals
              .dma_op_code_req ( dma_op_code_req ),
              .dma_op_queue_id ( dma_op_queue_id ),
              .dma_op_code_ack ( dma_op_code_ack ),

              // DMA TX data and flow control
              .dma_vld_c2n ( dma_vld_c2n ),
              .dma_data_c2n ( dma_data ),
              .dma_q_nearly_full_n2c ( dma_q_nearly_full_n2c ),

              // DMA RX data and flow control
              .dma_vld_n2c ( dma_vld_n2c ),
              .dma_data_n2c ( dma_data_n2c ),
	      .dma_q_nearly_full_c2n ( dma_q_nearly_full_c2n ),

              // enable to drive tri-state bus
              .dma_data_tri_en ( dma_data_tri_en ),

              .cpci_debug_data     (cpci_debug_data),
              .phy_mdc             (phy_mdc),
              .phy_mdata_out       (phy_mdata_out),
              .phy_mdata_in        (phy_mdata_in),
              .phy_mdata_tri       (phy_mdata_tri),
              .debug_led           (debug_led),
              .debug_data          (debug_data),
              .debug_clk           (debug_clk),


/*** not used
              .serial_TXP_0        (serial_TXP_0),
              .serial_TXN_0        (serial_TXN_0),
              .serial_RXP_0        (serial_RXP_0),
              .serial_RXN_0        (serial_RXN_0),
              .serial_TXP_1        (serial_TXP_1),
              .serial_TXN_1        (serial_TXN_1),
              .serial_RXP_1        (serial_RXP_1),
              .serial_RXN_1        (serial_RXN_1),
***/

              // Spartan reprogramming signals
              .cpci_rp_done        (cpci_rp_done),
              .cpci_rp_init_b      (cpci_rp_init_b),
              .cpci_rp_cclk        (cpci_rp_cclk),

              .cpci_rp_en          (cpci_rp_en),
              .cpci_rp_prog_b      (cpci_rp_prog_b),
              .cpci_rp_din         (cpci_rp_din),


              .disable_reset       (disable_reset),


              .core_clk_int        (core_clk_int),
              .reset               (reset)
           );

   assign serial_TXP_0 = 1'bz;
   assign serial_TXP_1 = 1'bz;
   assign serial_TXN_0 = 1'bz;
   assign serial_TXN_1 = 1'bz;

   // synthesis attribute keep_hierarchy of nf2_core is false;

   // synthesis attribute iob of sram1_addr is true;
   // synthesis attribute iob of sram1_data is true;
   // synthesis attribute iob of sram1_tri_en is true;
   // synthesis attribute iob of sram1_we is true;
   // synthesis attribute iob of sram1_bw is true;
   // synthesis attribute iob of sram1_zz is true;
   // synthesis attribute iob of sram2_addr is true;
   // synthesis attribute iob of sram2_data is true;
   // synthesis attribute iob of sram2_tri_en is true;
   // synthesis attribute iob of sram2_we is true;
   // synthesis attribute iob of sram2_bw is true;
   // synthesis attribute iob of sram2_zz is true;

   // synthesis attribute iob of cpci_data_tri_en is true;
   // synthesis attribute iob of cpci_data is true;
   // synthesis attribute iob of cpci_rd_data is true;
   // synthesis attribute iob of cpci_data is true;
   // synthesis attribute iob of cpci_addr is true;
   // synthesis attribute iob of cpci_rd_rdy is true;
   // synthesis attribute iob of cpci_wr_rdy is true;
   // synthesis attribute iob of cpci_req is true;
   // synthesis attribute iob of cpci_tx_full is true;
   // synthesis attribute iob of cpci_rd_wr_L is true;

   // synthesis attribute iob of dma_op_code_req is true;
   // synthesis attribute iob of dma_op_queue_id is true;
   // synthesis attribute iob of dma_vld_c2n is true;
   // synthesis attribute iob of dma_data is true;
   // synthesis attribute iob of dma_q_nearly_full_c2n is true;

   // synthesis attribute iob of dma_op_code_ack is true;
   // synthesis attribute iob of dma_vld_n2c is true;
   // synthesis attribute iob of dma_data_n2c is true;
   // synthesis attribute iob of dma_data_tri_en is true;
   // synthesis attribute iob of dma_q_nearly_full_n2c is true;

   //always @(posedge core_clk_int) reset <= nf2_reset;
   assign reset = (nf2_reset && !disable_reset) || !core_locked;



endmodule // nf2_top
