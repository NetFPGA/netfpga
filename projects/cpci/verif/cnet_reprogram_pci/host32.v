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

   // Reset the programming process
   PCI_DW_WR({`CPCI_REPROG_CTRL, 2'b0}, 4'h7, 'h1, success);

   // Write four words to the programming register
   for (i = 0; i < 4; i = i + 1)
      PCI_DW_WR({`CPCI_REPROG_DATA, 2'b0}, 4'h7, $random, success);

   // stop simulation
   $display(" ");
   $display($time, "   Simulation complete...");
   $display(" ");
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
