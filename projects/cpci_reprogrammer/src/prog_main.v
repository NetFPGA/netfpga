///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: prog_main.v 2061 2007-07-31 18:38:57Z grg $
//
// Module: prog_main.v
// Project: NetFPGA
// Description: Spartan reprogramming module
//
///////////////////////////////////////////////////////////////////////////////

module prog_main
   #(
      parameter REG_ADDR_WIDTH = (`CORE_REG_ADDR_WIDTH - 2 - 4),
      parameter RAM_ADDR_WIDTH = 16,
      parameter CPCI_NF2_DATA_WIDTH = 32
   )
   (
      // Control register interface signals
      input                                     ctrl_reg_req,
      output                                    ctrl_reg_ack,
      input                                     ctrl_reg_rd_wr_L,

      input [REG_ADDR_WIDTH - 1:0]              ctrl_reg_addr,

      output [`CPCI_NF2_DATA_WIDTH - 1:0]       ctrl_reg_rd_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        ctrl_reg_wr_data,

      // RAM register interface signals
      input                                     ram_reg_req,
      output                                    ram_reg_ack,
      input                                     ram_reg_rd_wr_L,

      input [REG_ADDR_WIDTH - 1:0]              ram_reg_addr,

      output [`CPCI_NF2_DATA_WIDTH - 1:0]       ram_reg_rd_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        ram_reg_wr_data,


      output                                    disable_reset,

      // Reprogramming signals
      input                      cpci_rp_done,
      input                      cpci_rp_init_b,
      input                      cpci_rp_cclk,

      output                     cpci_rp_en,
      output                     cpci_rp_prog_b,
      output                     cpci_rp_din,

      //
      input             clk,
      input             reset
   );

// --- Local signals
wire [RAM_ADDR_WIDTH - 1:0]         ctrl_addr;
wire [RAM_ADDR_WIDTH - 1:0]         ram_addr;
wire [`CPCI_NF2_DATA_WIDTH - 1 : 0] ram_rd_data;
wire [`CPCI_NF2_DATA_WIDTH - 1 : 0] ram_wr_data;
wire start;
wire prog_ram_sel;
wire ram_we;


// ==============================================
// Instantiate the sub modules

prog_ctrl #(
      .REG_ADDR_WIDTH (REG_ADDR_WIDTH),
      .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH)
   ) prog_ctrl (
      // Programming ROM interface signals
      .ram_addr                  (ctrl_addr),
      .ram_data                  (ram_rd_data),

      // Reprogramming signals
      .cpci_rp_done              (cpci_rp_done),
      .cpci_rp_init_b            (cpci_rp_init_b),
      .cpci_rp_cclk              (cpci_rp_cclk),

      .cpci_rp_en                (cpci_rp_en),
      .cpci_rp_prog_b            (cpci_rp_prog_b),
      .cpci_rp_din               (cpci_rp_din),

      // Control signals
      .start                     (start),

      //
      .clk              (clk),
      .reset            (reset)
   );



prog_ctrl_reg #(
      .REG_ADDR_WIDTH (REG_ADDR_WIDTH)
   ) prog_ctrl_reg (
      // Register interface signals
      .reg_req                                  (ctrl_reg_req),
      .reg_ack                                  (ctrl_reg_ack),
      .reg_rd_wr_L                              (ctrl_reg_rd_wr_L),

      .reg_addr                                 (ctrl_reg_addr),

      .reg_rd_data                              (ctrl_reg_rd_data),
      .reg_wr_data                              (ctrl_reg_wr_data),

      // Reprogram control signals
      .start                                    (start),
      .disable_reset                            (disable_reset),
      .prog_ram_sel                             (prog_ram_sel),

      //
      .clk              (clk),
      .reset            (reset)
   );



prog_ram_reg prog_ram_reg (
      // Register interface signals
      .reg_req                                  (ram_reg_req),
      .reg_ack                                  (ram_reg_ack),
      .reg_rd_wr_L                              (ram_reg_rd_wr_L),

      .reg_addr                                 (ram_reg_addr),

      .reg_rd_data                              (ram_reg_rd_data),
      .reg_wr_data                              (ram_reg_wr_data),

      // RAM access signals
      .ram_addr                                 (ram_addr),
      .ram_we                                   (ram_we),
      .ram_wr_data                              (ram_wr_data),
      .ram_rd_data                              (ram_rd_data),

      //
      .clk              (clk),
      .reset            (reset)
   );

prog_ram prog_ram (
      .addr       ((prog_ram_sel == 0) ? ram_addr : ctrl_addr),

      .rd_data    (ram_rd_data),

      .wr_data    (ram_wr_data),
      .wr_en      (prog_ram_sel == 0 && ram_we),

      .clk        (clk),
      .reset      (reset)
   );

/*
prog_rom prog_rom (
      .addra      (rom_addr),
      .douta      (rom_data),
      .clka       (clk)
   );
*/


endmodule // prog_main
