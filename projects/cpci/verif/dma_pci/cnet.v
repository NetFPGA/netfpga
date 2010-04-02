///////////////////////////////////////////////////////////////////////////////
// $Id: cnet.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: cnet.v
// Project: CPCI (PCI Control FPGA)
// Description: Simulates the CNET as seen from the CPCI
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`include "defines.v"

`timescale 1 ns/1 ns

module cnet(
            // Register interface
            input          cpci_rd_wr_L,
            input          cpci_req,
            input [`CPCI_CNET_ADDR_WIDTH-1:0] cpci_addr,
            inout [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data,
            output reg     cpci_wr_rdy,
            output reg     cpci_rd_rdy,

            // DMA interface
            output  [3:0]  cpci_dma_pkt_avail, // Packets waiting from MACs
            input [3:0]    cpci_dma_send, // Request next packet from MACs
            output reg     cpci_dma_wr_en, // Write stobe
            output reg [`CPCI_CNET_DATA_WIDTH-1:0] cpci_dma_data,
            input          cpci_dma_nearly_full,

            // Programming interface to the CNET
            input          rp_prog_b,
            output         rp_init_b,
            input          rp_cs_b,
            input          rp_rdwr_b,
            input [7:0]    rp_data,
            output         rp_done,

            input          rp_cclk,

            // Error output
            output         cnet_err,      // Error signal from CNET

            // Misc signals
            input          want_crc_error,

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

reg [`CPCI_CNET_DATA_WIDTH-1:0] cpci_rd_data;
reg cpci_data_tri_en;


// ==================================================================
// Simulate the registers
// ==================================================================

reg [31:0] ctrl_reg;

always @(posedge clk)
begin
   if (reset) begin
      ctrl_reg <= 'h0;

      cpci_rd_data <= - 'h1;
      cpci_rd_rdy <= 1'b0;
      cpci_data_tri_en <= 1'b0;
      cpci_wr_rdy <= 1'b0;
   end
   else if (cpci_req) begin
      if (cpci_addr[23:20] == `CNET_Regs_select) begin
         case (cpci_addr[11:0])
            `CNET_ID_reg : begin
               cpci_rd_data <= 32'h abcd_0123;
            end

            `CNET_Control_reg : begin
               if (~cpci_rd_wr_L)
                  ctrl_reg <= cpci_data;
               cpci_rd_data <= ctrl_reg;
            end

            default : begin
               cpci_rd_data <= 32'h dead_beef;
            end
         endcase
      end
      else if (cpci_addr[23:20] == `CNET_Tx_FIFO_select) begin
         if (cpci_rd_wr_L)
            $display($time, " ERROR: Attempt to read from one of the MAC FIFOs");
         else begin
            $write($time, " DMA write to MAC %1d: 0x%h", cpci_addr[5:4], cpci_data);
            if (cpci_addr[7])
               $display("  Last Word. Size: %1d", cpci_addr[3:2] + 1);
            else
               $display("");
         end
      end
   end

   // Work out the other signals
   cpci_rd_rdy <= cpci_rd_wr_L;
   cpci_data_tri_en <= cpci_rd_wr_L;
   cpci_wr_rdy <= ~cpci_rd_wr_L;
end


// ==================================================================
// DMA transfer
// ==================================================================

assign cpci_dma_pkt_avail = 4'b1111;

reg [31:0] dma_pkt_size;

always @(posedge clk)
begin
   if (reset) begin
      dma_pkt_size <= 32'd128;

      cpci_dma_wr_en <= 1'b0;
      cpci_dma_data <= - 'h1;
   end
   else if (|(cpci_dma_send))
      dma_pkt_transfer;
end

task dma_pkt_transfer;
   integer words;
   integer i;
   reg [7:0] byte;
begin
   words = dma_pkt_size / 4;
   if (dma_pkt_size[1:0] != 0)
      words = words + 1;
   $display($time, " Commencing packet transfer from MAC %1d to CPCI",
               cpci_dma_send[0] * 1 +
               cpci_dma_send[1] * 2 +
               cpci_dma_send[2] * 3 +
               cpci_dma_send[3] * 4);

   for (i = -1; i < words ; i = i + 1) begin
      @(negedge clk) begin
         byte = i[5:0] << 2;
         if (i == -1)
            cpci_dma_data <= dma_pkt_size;
         else
            cpci_dma_data <= {byte + 8'd3, byte + 8'd2, byte + 8'd1, byte + 8'd0};
         cpci_dma_wr_en <= 1'b1;
      end
   end

   @(negedge clk) begin
      cpci_dma_wr_en <= 1'b0;
   end
end
endtask


assign cpci_data = cpci_data_tri_en ? cpci_rd_data : 'bz;

assign rp_init_b = 1'b1;
assign rp_done = 1'b1;

endmodule // cnet

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
