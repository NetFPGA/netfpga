///////////////////////////////////////////////////////////////////////////////
// $Id: host32.v 5550 2009-05-11 20:09:59Z grg $
//
// Module: host32.v
// Project: CPCI (PCI Control FPGA)
// Description: Simulates a PCI host
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`include "defines.v"

module host32 (
                  inout  [31:0] AD,
                  inout   [3:0] CBE,
                  inout         PAR,
                  output        FRAME_N,
                  input         TRDY_N,
                  output        IRDY_N,
                  input         STOP_N,
                  input         DEVSEL_N,
                  input         INTR_A,
                  input         RST_N,
                  input         CLK
                );

// Include all of the base code that defines how do do various
// basic transactions
`include "host32_inc.v"

// Local variables
reg [31:0] random_data;
integer i;

// Begin the actual simulation sequence
initial
begin
   // wait for the system to reset
   RESET_WAIT;

   // set up the device as an os would
   DO_OS_SETUP;

   // Perform a read
   PCI_DW_RD({`CPCI_ID, 2'b0}, 4'h6, returned, success);

   // Write numbers to the control reg
   for (i = 1; i < 11; i = i + 1) begin
      PCI_DW_WR('h40_0000 + `CNET_Control_reg, 4'h7, i, success);
   end

   // Verify that we get back the last number read
   PCI_DW_RD_RETRY_EXPECT('h40_0000 + `CNET_Control_reg, 4'h6, 'd 10, 20, returned, success);

   // stop simulation
   $display(" ");
   $display($time, "   Simulation complete...");
   $display(" ");

   $finish;
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
