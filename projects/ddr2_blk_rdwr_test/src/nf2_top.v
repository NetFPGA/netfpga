//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: nf2_top.v
// Project: NetFPGA
// Description: Top level module of a test circuit for the
// DDR2 block read/write module
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
    input         ddr_clk_200,
    input         ddr_clk_200b,

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


   // ----------------------------  TIE OFF -----------------------------
   // SRAM
   assign 	 sram1_addr = 20'h 0;
   assign 	 sram1_we = 1'b 1; //active low
   assign 	 sram1_bw = 4'b 0;
   assign 	 sram1_zz = 1'b 0;

   assign 	 sram2_addr = 20'h 0;
   assign 	 sram2_we = 1'b 1; //active low
   assign 	 sram2_bw = 4'b 0;
   assign 	 sram2_zz = 1'b 0;

   // --- Tri-state driver logic for SRAM
   wire [`SRAM_DATA_WIDTH-1:0] sram1_wr_data = 'h 0;
   wire [`SRAM_DATA_WIDTH-1:0] sram2_wr_data = 'h 0;
   wire          sram1_tri_en = 1'b 0;
   wire          sram2_tri_en = 1'b 0;
   assign        sram1_data = sram1_tri_en ? sram1_wr_data : `SRAM_DATA_WIDTH'h z;
   assign        sram2_data = sram2_tri_en ? sram2_wr_data : `SRAM_DATA_WIDTH'h z;

   // CPCI
   assign nf2_err = 1'b 0;

   // RGMII
   assign rgmii_0_txd = 4'b 0;
   assign rgmii_0_tx_ctl = 1'b 0;
   assign rgmii_0_txc = 1'b 0;

   assign rgmii_1_txd = 4'b 0;
   assign rgmii_1_tx_ctl = 1'b 0;
   assign rgmii_1_txc = 1'b 0;

   assign rgmii_2_txd = 4'b 0;
   assign rgmii_2_tx_ctl = 1'b 0;
   assign rgmii_2_txc = 1'b 0;

   assign rgmii_3_txd = 4'b 0;
   assign rgmii_3_tx_ctl = 1'b 0;
   assign rgmii_3_txc = 1'b 0;

   // DMA
   assign dma_op_code_ack = 1'b 0;
   assign dma_vld_n2c = 1'b 0;
   assign dma_q_nearly_full_n2c = 1'b 0;
   wire   dma_data_tri_en = 1'b 0;
   wire [`DMA_DATA_WIDTH-1:0] dma_data_n2c = 'h 0;
   assign dma_data = dma_data_tri_en ? dma_data_n2c : {`DMA_DATA_WIDTH {1'b z}};

   // --- end of DMA data tri-state

   // MDC/MDIO
   assign phy_mdc = 1'b 0;

   wire phy_mdata_tri = 1'b 0;
   wire phy_mdata_out = 1'b 0;

   assign phy_mdio = phy_mdata_tri ? phy_mdata_out : 1'bz;
   assign phy_mdata_in = phy_mdio;

   // --- end of PHY MDIO tri-state

   // Debug bus
   assign debug_led = 1'b 0;
   assign debug_data = 4'b 0;
   assign debug_clk = 2'b 0;

   // Serial bus
   assign serial_TXP_0 = 1'b 1;
   assign serial_TXN_0 = 1'b 0;

   assign serial_TXP_1 = 1'b 1;
   assign serial_TXN_1 = 1'b 0;

   // Spartan config
   assign cpci_rp_en = 1'b 0;
   assign cpci_rp_prog_b = 1'b 0;
   assign cpci_rp_din = 1'b 0;

   // ------------------------- END OF TIE OFF

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
   wire        disable_reset = 1'b 0;

   //--------------------------------------------------------------
   // DDR2 interface
   //--------------------------------------------------------------

   // outputs from DDR2 controller
   wire          ddr2_user_auto_ref_req;
   wire          ddr2_user_ar_done;
   wire          ddr2_user_cmd_ack;
   wire          ddr2_user_rd_data_valid;
   wire [63:0]   ddr2_user_rd_data;
   wire          ddr2_user_init_val;

   // inputs to DDR2 controller
   wire [21: 0]  ddr2_user_addr;
   wire [1:0]    ddr2_user_bank_addr;
   wire [3:0]    ddr2_user_cmd;
   wire [63:0]   ddr2_user_wr_data;
   wire [7:0]    ddr2_user_wr_data_mask;
   wire [14:0]   ddr2_user_config1;
   wire [12:0]   ddr2_user_config2;
   wire          ddr2_user_burst_done;

   // Clocks
   wire clk_ddr_200;
   wire clk90_ddr_200;

   // Resets
   wire ddr2_reset;
   wire ddr2_reset90;


   // ------------ DDR2 memory interface
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


   // --- end of DDR2 memory interface


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
   assign        cpci_data = cpci_data_tri_en ? cpci_rd_data : 'h z;

   // --- end of CPCI interface



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
                             .I1(),  // not used.
                             .I0(core_clk0),
                             .S(1'b0)
                             );

   // --- end of core clock logic.

   nf2_core nf2_core_u
     (
      // CPCI interface and clock
      //input:
      .cpci_clk_int ( cpci_clk_int ), // 62.5 MHz
      .cpci_rd_wr_L ( cpci_rd_wr_L ),
      .cpci_req     ( cpci_req ),
      .cpci_addr    ( cpci_addr ),//[`CPCI_NF2_ADDR_WIDTH-1:0]
      .cpci_wr_data ( cpci_data ),//[`CPCI_NF2_DATA_WIDTH-1:0]

      //output:
      .cpci_rd_data (  cpci_rd_data),//[`CPCI_NF2_DATA_WIDTH-1:0]
      .cpci_data_tri_en ( cpci_data_tri_en ),
      .cpci_wr_rdy      ( cpci_wr_rdy ),
      .cpci_rd_rdy      ( cpci_rd_rdy ),

      // --- DDR2 interface
      //output:
      .ddr2_cmd          ( ddr2_user_cmd ),//[3:0]
      .ddr2_addr         ( ddr2_user_addr ),//[21:0]
      .ddr2_bank_addr    ( ddr2_user_bank_addr ),//[1:0]
      .ddr2_burst_done   ( ddr2_user_burst_done ),
      .ddr2_wr_data      ( ddr2_user_wr_data ),//[63:0]
      .ddr2_wr_data_mask ( ddr2_user_wr_data_mask ),//[7:0]
      .ddr2_config1      ( ddr2_user_config1 ),//[14:0]
      .ddr2_config2      ( ddr2_user_config2 ),//[12:0]

      //input:
      .ddr2_cmd_ack       ( ddr2_user_cmd_ack ),
      .ddr2_rd_data       ( ddr2_user_rd_data ),//[63:0]
      .ddr2_rd_data_valid ( ddr2_user_rd_data_valid ),
      .ddr2_auto_ref_req  ( ddr2_user_auto_ref_req ),
      .ddr2_ar_done       ( ddr2_user_ar_done ),
      .ddr2_init_val      ( ddr2_user_init_val ),
      .ddr2_reset         ( ddr2_reset ),
      .ddr2_reset90       ( ddr2_reset90 ),

      // DDR2 clock
      .clk_ddr_200        ( clk_ddr_200 ),
      .clk90_ddr_200      ( clk90_ddr_200 ),

      // core clock
      .core_clk_int       ( core_clk_int ),

      // misc
      .reset              ( reset )
      );

   assign reset = (nf2_reset && !disable_reset) || !core_locked;

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

endmodule // nf2_top
