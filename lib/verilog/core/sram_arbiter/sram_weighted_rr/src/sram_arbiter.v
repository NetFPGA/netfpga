///////////////////////////////////////////////////////////////////////////////
// $Id: sram_arbiter.v 3614 2008-04-16 01:22:09Z grg $
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: sram_arbiter.v
// Project: NF2.1 reference design
// Description: SRAM controller wrapper
//
// Wrapper around cnet_sram_sm to provide reg access
//
///////////////////////////////////////////////////////////////////////////////

`timescale  1ns /  10ps
module sram_arbiter  #(parameter SRAM_ADDR_WIDTH = 19,
                       parameter SRAM_DATA_WIDTH = 36,
                       parameter SRAM_REG_ADDR_WIDTH = 21)

   (// register interface
    input                            sram_reg_req,
    input                            sram_reg_rd_wr_L,    // 1 = read, 0 = write
    input [`SRAM_REG_ADDR_WIDTH-1:0] sram_reg_addr,
    input [`CPCI_NF2_DATA_WIDTH-1:0] sram_reg_wr_data,

    output                           sram_reg_ack,
    output [`CPCI_NF2_DATA_WIDTH -1:0] sram_reg_rd_data,

    // --- Requesters (read and/or write)
    input                            wr_0_req,
    input      [SRAM_ADDR_WIDTH-1:0] wr_0_addr,
    input      [SRAM_DATA_WIDTH-1:0] wr_0_data,
    output                           wr_0_ack,

    input                            rd_0_req,
    input      [SRAM_ADDR_WIDTH-1:0] rd_0_addr,
    output     [SRAM_DATA_WIDTH-1:0] rd_0_data,
    output                           rd_0_ack,
    output                           rd_0_vld,

    // --- SRAM signals (pins and control)
   output     [SRAM_ADDR_WIDTH-1:0] sram_addr,
   output                           sram_we,
   output   [SRAM_DATA_WIDTH/9-1:0] sram_bw,
   output     [SRAM_DATA_WIDTH-1:0] sram_wr_data,
   input      [SRAM_DATA_WIDTH-1:0] sram_rd_data,
   output                           sram_tri_en,

    // --- Misc

    input reset,
    input clk

    );

wire                       wr_1_req;
wire [SRAM_ADDR_WIDTH-1:0] wr_1_addr;
wire [SRAM_DATA_WIDTH-1:0] wr_1_data;
wire                       wr_1_ack;

wire                       rd_1_req;
wire [SRAM_ADDR_WIDTH-1:0] rd_1_addr;
wire [SRAM_DATA_WIDTH-1:0] rd_1_data;
wire                       rd_1_ack;
wire                       rd_1_vld;

   //-------- wires/regs -----------
   cnet_sram_sm
     #(.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
       .SRAM_DATA_WIDTH(SRAM_DATA_WIDTH))
   cnet_sram_sm
     (// --- Requesters     (read and/or write)
      .wr_0_req             (wr_0_req),
      .wr_0_addr            (wr_0_addr),
      .wr_0_data            (wr_0_data),
      .wr_0_ack             (wr_0_ack),

      .wr_1_req             (wr_1_req),
      .wr_1_addr            (wr_1_addr),
      .wr_1_data            (wr_1_data),
      .wr_1_ack             (wr_1_ack),

      .rd_0_req             (rd_0_req),
      .rd_0_addr            (rd_0_addr),
      .rd_0_data            (rd_0_data),
      .rd_0_ack             (rd_0_ack),
      .rd_0_vld             (rd_0_vld),

      .rd_1_req             (rd_1_req),
      .rd_1_addr            (rd_1_addr),
      .rd_1_data            (rd_1_data),
      .rd_1_ack             (rd_1_ack),
      .rd_1_vld             (rd_1_vld),

      // --- SRAM signals   (pins and control)
      .sram_addr            (sram_addr),
      .sram_wr_data         (sram_wr_data),
      .sram_rd_data         (sram_rd_data),
      .sram_we              (sram_we),
      .sram_bw              (sram_bw),
      .sram_tri_en          (sram_tri_en),

      // --- Misc
      .reset                (reset),
      .clk                  (clk)
   );

   // synthesis attribute keep_hierarchy of cnet_sram_sm is false;

   sram_reg_access #(
      .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
      .SRAM_DATA_WIDTH(SRAM_DATA_WIDTH),
      .SRAM_REG_ADDR_WIDTH(SRAM_REG_ADDR_WIDTH)
   ) sram_reg_access (
      // register interface
      .sram_reg_req        (sram_reg_req),
      .sram_reg_rd_wr_L    (sram_reg_rd_wr_L),    // 1 = read, 0 = write
      .sram_reg_addr       (sram_reg_addr),
      .sram_reg_wr_data    (sram_reg_wr_data),

      .sram_reg_ack        (sram_reg_ack),
      .sram_reg_rd_data    (sram_reg_rd_data),

      // --- Requesters (read and/or write)
      .wr_req              (wr_1_req),
      .wr_addr             (wr_1_addr),
      .wr_data             (wr_1_data),
      .wr_ack              (wr_1_ack),

      .rd_req              (rd_1_req),
      .rd_addr             (rd_1_addr),
      .rd_data             (rd_1_data),
      .rd_ack              (rd_1_ack),
      .rd_vld              (rd_1_vld),

      // --- Misc

      .reset               (reset),
      .clk                 (clk)

   );

   // synthesis attribute keep_hierarchy of sram_reg_access is false;

   /* stub for unimplemented register interface */
   //reg    sram_reg_req_d1;
   //always @(posedge clk) begin
   //   sram_reg_ack    <= sram_reg_req && !sram_reg_req_d1;
   //   sram_reg_req_d1 <= sram_reg_req;
   //end

   //assign sram_reg_rd_data = 32'hDEADBEEF;

endmodule // sram_arbiter


