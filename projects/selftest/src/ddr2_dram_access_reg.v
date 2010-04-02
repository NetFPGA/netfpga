//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: ddr2_dram_access_reg.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: ddr2_dram_access_reg.v
// Project: NetFPGA
// Description: Provide random access to the DRAM
//
///////////////////////////////////////////////////////////////////////////////

module ddr2_dram_access_reg
   #(
      parameter DRAM_ADDR_WIDTH = 24, // 2 - BA  +  22 - Addr
      parameter DRAM_DATA_WIDTH = 64
    )
    (
      // Register interface
      input reg_req,
      input reg_rd_wr_L,
      input [DRAM_ADDR_WIDTH - 1:0] reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0] reg_wr_data,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data,
      output reg reg_ack,

      // Self-test interface
      output reg [DRAM_ADDR_WIDTH - 1 : 0] dram_addr,
      output reg [`CPCI_NF2_DATA_WIDTH - 1 : 0] dram_wr_data,
      output reg dram_rd_wr_L,
      output reg dram_req,
      input [`CPCI_NF2_DATA_WIDTH - 1 : 0] dram_rd_data,
      input dram_vld,

      input dram_ready,

      // Clock/reset
      input clk_core_125,
      input clk_ddr_200,
      input reset_ddr,
      input reset_core
   );

   // ====================================
   // Local variables
   // ====================================


   reg dram_vld_tgl_200;
   reg dram_vld_tgl_125;
   reg dram_vld_tgl_125_d1;
   reg dram_vld_tgl_125_d2;
   reg [`CPCI_NF2_DATA_WIDTH -1:0] dram_rd_data_200_d1;

   reg dram_req_tgl_125;
   reg [DRAM_ADDR_WIDTH - 1 : 0] dram_addr_125;
   reg dram_rd_wr_L_125;
   reg [`CPCI_NF2_DATA_WIDTH - 1 : 0] dram_wr_data_125;

   reg reg_req_d1;

   reg dram_req_tgl_200;
   reg dram_req_tgl_200_d1;
   reg dram_req_tgl_200_d2;

   reg dram_ready_125_p1;
   reg dram_ready_125;


   // ===================================================
   // Clock domain crossing for reads/writes
   // ===================================================

   // DDR -> Core
   // DDR Clk, dram response signals
   always @(posedge clk_ddr_200)
   begin
      if (reset_ddr) begin
         dram_vld_tgl_200 <= 1'b0;
         dram_rd_data_200_d1 <= 'h0;
      end
      else if (dram_vld) begin
         dram_vld_tgl_200 <= !dram_vld_tgl_200;
         dram_rd_data_200_d1 <= dram_rd_data;
      end
   end

   // DDR -> Core
   // Core Clk, dram response signals + dram ready
   always @(posedge clk_core_125)
   begin
      dram_vld_tgl_125 <= dram_vld_tgl_200;
      dram_vld_tgl_125_d1 <= dram_vld_tgl_125;
      dram_vld_tgl_125_d2 <= dram_vld_tgl_125_d1;

      // Bring the 200 MHZ buses across to the 125 MHz domain
      //
      // Note: The bus signals have been stable for at least
      // a 125 MHz clock period
      if (dram_vld_tgl_125_d2 != dram_vld_tgl_125_d1) begin
         reg_rd_data <= dram_rd_data_200_d1;

         reg_ack <= reg_req;
      end
      else if (reg_req && !reg_ack && !reg_rd_wr_L)
         reg_ack <= 1'b1;
      else
         reg_ack <= 1'b0;

      dram_ready_125_p1 <= dram_ready;
      dram_ready_125 <= dram_ready_125_p1;
   end

   // Core -> DDR
   // Core Clk, dram req signals
   always @(posedge clk_core_125)
   begin
      if (reset_core) begin
         dram_req_tgl_125 <= 1'b0;

         dram_addr_125 <= 'h0;
      end
      else if (reg_req && !reg_req_d1 && dram_ready_125) begin
         dram_req_tgl_125 <= !dram_req_tgl_125;

         dram_addr_125 <= reg_addr;
         dram_rd_wr_L_125 <= reg_rd_wr_L;
         dram_wr_data_125 <= reg_wr_data;
      end

      reg_req_d1 <= reg_req && dram_ready_125;
   end

   // Core -> DDR
   // DDR clk, dram req signals
   always @(posedge clk_ddr_200)
   begin
      dram_req_tgl_200 <= dram_req_tgl_125;
      dram_req_tgl_200_d1 <= dram_req_tgl_200;
      dram_req_tgl_200_d2 <= dram_req_tgl_200_d1;

      if (reset_ddr || dram_req_tgl_200_d2 == dram_req_tgl_200_d1)
         dram_req <= 1'b0;
      else
         dram_req <= 1'b1;

      // Bring the 125 MHZ buses across to the 200 MHz domain
      //
      // Note: The bus signals have been stable for at least
      // a 200 MHz clock period
      if (dram_req_tgl_200_d2 != dram_req_tgl_200_d1) begin
         dram_addr <= dram_addr_125;
         dram_wr_data <= dram_wr_data_125;
         dram_rd_wr_L <= dram_rd_wr_L_125;
      end
   end
endmodule // ddr2_dram_access_reg
