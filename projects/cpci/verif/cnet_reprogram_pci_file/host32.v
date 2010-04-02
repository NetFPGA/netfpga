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

`define  BITSTREAM   "bitstream.hex"

parameter BITSTREAM_LEN = 362185;

// Local variables
reg [31:0] random_data;
integer i;

reg [31:0] bitstream [BITSTREAM_LEN - 1:0];


// Begin the actual simulation sequence
initial
begin
   // Read in the bin file
   for (i = 0; i < BITSTREAM_LEN; i = i + 1)
   begin
      bitstream[i] = 'h0;
   end
   $readmemh(`BITSTREAM, bitstream);

   // wait for the system to reset
   RESET_WAIT;

   // set up the device as an os would
   DO_OS_SETUP;

   // Perform a read
   PCI_DW_RD({`CPCI_ID, 2'b0}, 4'h6, returned, success);

   // Reset the programming process
   $display($time, " Resetting programming interface");
   PCI_DW_WR({`CPCI_REPROG_CTRL, 2'b0}, 4'h7, 1'h1, success);

   // Program first 20 words
   //for (i = 0; i < BITSTREAM_LEN; i = i + 1)
   for (i = 0; i < 20; i = i + 1)
   begin
      PCI_DW_WR({`CPCI_REPROG_DATA, 2'b0}, 4'h7, bitstream[i], success);
   end

   // Reset the programming process
   $display($time, " Resetting programming interface");
   PCI_DW_WR({`CPCI_REPROG_CTRL, 2'b0}, 4'h7, 1'h1, success);

   // Program properly
   for (i = 0; i < BITSTREAM_LEN; i = i + 1)
   //for (i = 0; i < 1000; i = i + 1)
   begin
      PCI_DW_WR({`CPCI_REPROG_DATA, 2'b0}, 4'h7, bitstream[i], success);
   end

   // stop simulation
   $display(" ");
   $display($time, "   Simulation complete...");
   $display(" ");
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
