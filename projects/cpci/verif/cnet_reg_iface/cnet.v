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

`timescale 1 ns / 1 ns

module cnet(
            input cpci_rd_wr_L,
            input cpci_req,
            input [`CPCI_CNET_ADDR_WIDTH-1:0] cpci_addr,
            inout [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data,
            output reg cpci_wr_rdy,
            output reg cpci_rd_rdy,

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

reg [1:0] result_cnt;

// ==================================================================
// Work out how many clocks until the ready signal should be asserted
// ==================================================================

always @(posedge clk)
begin
   if (reset)
      result_cnt <= 'h0;
   else if (result_cnt == 0 || !cpci_req)
      result_cnt <= $random;
   else
      result_cnt <= result_cnt - 1'b1;
end


// ==================================================================
// Generate the ready signals
// ==================================================================

always @*
begin
   if (reset || result_cnt != 'h0 || !cpci_req) begin
      #1 cpci_rd_rdy = 1'b0;
      cpci_wr_rdy = 1'b0;
   end
   else begin
      #1 cpci_rd_rdy = cpci_rd_wr_L;
      cpci_wr_rdy = !cpci_rd_wr_L;
   end
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

//assign cpci_data = cpci_rd_rdy ? {(`CPCI_CNET_DATA_WIDTH - `CPCI_CNET_ADDR_WIDTH)'b0, cpci_addr} : 'bz;
assign cpci_data = cpci_rd_rdy ? cpci_addr : 'bz;

endmodule // cnet

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
