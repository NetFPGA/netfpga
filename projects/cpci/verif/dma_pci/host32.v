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

// Begin the actual simulation sequence
initial
begin
   // wait for the system to reset
   RESET_WAIT;

   // set up the device as an os would
   DO_OS_SETUP;

   $display(" ");
   $display($time, "   Testing reading and writing some registers...");
   $display(" ");

   // Perform a read
   PCI_DW_RD({`CPCI_ID, 2'b0}, 4'h6, returned, success);

   // Modify the "test" register
   PCI_DW_RD_EXPECT({`CPCI_DUMMY, 2'b0}, 4'h6, 'h0, returned, success);
   random_data = $random;
   PCI_DW_WR({`CPCI_DUMMY, 2'b0}, 4'h7, random_data, success);
   PCI_DW_RD_EXPECT({`CPCI_DUMMY, 2'b0}, 4'h6, random_data, returned, success);

   PCI_DW_WR({`CPCI_CONTROL, 2'b0}, 4'h7, 32'h0, success);


   // Unmask all interrupts and clear the interrupt status
   $display(" ");
   $display($time, "   Clearing the interrupt status and masks...");
   $display(" ");
   PCI_DW_WR({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h7, 32'h00000000, success);
   PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, 32'h00000000, success);

   // Try to write a block to the CPCI
   $display(" ");
   $display($time, "   Starting a DMA Write transfer...");
   $display($time, "   ================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000100, success);
   $display($time, "   Setting up transfer size.");
   PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, 32'h00000042, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);


   // Try to write a block to the CPCI
   $display(" ");
   $display($time, "   Starting an identical DMA Write transfer...");
   $display($time, "   ===========================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000100, success);
   $display($time, "   Setting up transfer size.");
   PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, 32'h00000042, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);


   // Try to write a block to the CPCI (off word boundary start)
   $display(" ");
   $display($time, "   Starting an off word boundary DMA Write transfer...");
   $display($time, "   ===================================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000101, success);
   $display($time, "   Setting up transfer size.");
   PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, 32'h00000042, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);


   // Try to write a block to the CPCI (off word boundary start)
   $display(" ");
   $display($time, "   Starting an off word boundary DMA Write transfer...");
   $display($time, "   ===================================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000102, success);
   $display($time, "   Setting up transfer size.");
   PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, 32'h00000042, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);


   // Try to write a block to the CPCI (off word boundary start)
   $display(" ");
   $display($time, "   Starting an off word boundary DMA Write transfer...");
   $display($time, "   ===================================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000103, success);
   $display($time, "   Setting up transfer size.");
   PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, 32'h00000042, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);


   // Try to read a block from the CPCI
   PCI_DW_WR({`CPCI_CONTROL, 2'b0}, 4'h7, 32'h10000, success);
   $display(" ");
   $display($time, "   Starting a DMA Read transfer...");
   $display($time, "   ===============================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   force testbench.cnet.dma_pkt_size = 32'd128;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_I, 2'b0}, 4'h7, 32'hc0002000, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_I, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);

   $display($time, "   Reading transfer size.");
   PCI_DW_RD_EXPECT({`CPCI_DMA_SIZE_I, 2'b0}, 4'h6, 32'd128, returned, success);
   $display($time, "   Transferred %1d bytes", returned);

   $display($time, "   Reading MAC.");
   PCI_DW_RD_EXPECT({`CPCI_DMA_CTRL_I, 2'b0}, 4'h6, 32'd0, returned, success);
   $display($time, "   Transferred from MAC %1d", returned[9:8]);


   // Perform an off-word boundary transfer
   $display(" ");
   $display($time, "   Starting an off word boundary DMA Read transfer...");
   $display($time, "   ==================================================");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   force testbench.cnet.dma_pkt_size = 32'd128;
   $display($time, "   Writing DMA Host Buffer Address.");
   PCI_DW_WR({`CPCI_DMA_ADDR_I, 2'b0}, 4'h7, 32'hc0002001, success);
   $display($time, "   Setting memory owner and starting transfer.");
   PCI_DW_WR({`CPCI_DMA_CTRL_I, 2'b0}, 4'h7, 32'h00000301, success);

   wait(~INTR_A);
   $display($time, "   Interrupt asserted.");
   PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
   DECODE_INTR(returned);

   $display($time, "   Reading transfer size.");
   PCI_DW_RD_EXPECT({`CPCI_DMA_SIZE_I, 2'b0}, 4'h6, 32'd128, returned, success);
   $display($time, "   Transferred %1d bytes", returned);

   $display($time, "   Reading MAC.");
   PCI_DW_RD_EXPECT({`CPCI_DMA_CTRL_I, 2'b0}, 4'h6, 32'h100, returned, success);
   $display($time, "   Transferred from MAC %1d", returned[9:8]);

   /*PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");*/

/*
   // peek at registers in cfg space and mem space
   if (`SKIP_PEEK != 1'b1)
   begin
     $display(" ");
     $display("Peeking Device Control Registers...");
     $display(" ");
     PCI_DW_RD(32'h00010080, 4'ha, returned, success);
     PCI_DW_RD(32'h00000000, 4'h6, returned, success);
     PCI_DW_RD(32'h00010084, 4'ha, returned, success);
     PCI_DW_RD(32'h00000004, 4'h6, returned, success);
     PCI_DW_RD(32'h00010088, 4'ha, returned, success);
     PCI_DW_RD(32'h00000008, 4'h6, returned, success);
     PCI_DW_RD(32'h0001008c, 4'ha, returned, success);
     PCI_DW_RD(32'h0000000c, 4'h6, returned, success);
     PCI_DW_RD(32'h00010090, 4'ha, returned, success);
     PCI_DW_RD(32'h00000010, 4'h6, returned, success);
     PCI_DW_RD(32'h00010094, 4'ha, returned, success);
     PCI_DW_RD(32'h00000014, 4'h6, returned, success);
     PCI_DW_RD(32'h00010098, 4'ha, returned, success);
     PCI_DW_RD(32'h00000018, 4'h6, returned, success);
     PCI_DW_RD(32'h0001009c, 4'ha, returned, success);
     PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   end

   // check out the serial prom behavior
   // the driver would read much more data
   // in order to set up the sdram controller
   // but we will skip this process for the
   // sake of simulation time once we can
   // see that it works
   if (`SKIP_PROM != 1'b1)
   begin
     $display(" ");
     $display("Starting Interrupt Driven SPD Access...");
     $display(" ");
     PCI_DW_RD(32'h00000000, 4'h6, returned, success);
     if (returned[16])
     begin
       $display("     SPD machine unexpectedly busy.");
       $display("     Exiting.");
       $display(" ");
       $display("Simulation complete...");
       $display(" ");
       $finish;
     end
     PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0004, success);
     PCI_DW_WR(32'h00000000, 4'h7, 32'hfff00040, success);
     @(negedge INTR_A);
     $display("     Interrupt asserted.");
     PCI_DW_RD(32'h00000000, 4'h6, returned, success);
     if (returned[15:8] != 8'h2c)
     begin
       $display("     Error:  Not a Micron Module.");
       $display("     Exiting.");
       $display(" ");
       $display("Simulation complete...");
       $display(" ");
       $finish;
     end
     PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
     @(posedge INTR_A);
     $display("     Interrupt deasserted.");
   end

   // now setup the sdram controller by
   // programming all the parameters then
   // releasing it from reset and enabling
   // the clock
   $display(" ");
   $display("Initializing SDRAM Controller...");
   $display(" ");
   $display("     Turn on SDRAM clock, set LED for DMA activity.");
   PCI_DW_WR(32'h00000000, 4'h7, 32'hfffa0040, success);
   $display("     Set module configuration for Micron 4LSDT464.");
   PCI_DW_WR(32'h00000004, 4'h7, 32'h35000000, success);
   $display("     Set other module paramters.");
   PCI_DW_WR(32'h00000008, 4'h7, 32'h171700ff, success);
   $display("     Release SDRAM domain reset.");
   PCI_DW_WR(32'h00000008, 4'h7, 32'h071700ff, success);
   $display("     Entering polling loop waiting for DLL lock.");
   returned = 32'h00000000;
   while(returned[31:30] != 2'b11)
   begin
     PCI_DW_RD(32'h00000008, 4'h6, returned, success);
   end
   $display("     SDRAM domain DLLs have locked.");
   $display("     Assert SDRAM clock enable signal.");
   PCI_DW_WR(32'h00000008, 4'h7, 32'h0f1700ff, success);
   $display("     Entering polling loop waiting for DMA ready.");
   returned = 32'h80000000;
   while(returned[31])
   begin
     PCI_DW_RD(32'h00000018, 4'h6, returned, success);
   end
   $display("     Enable auto refresh.");
   PCI_DW_WR(32'h00000008, 4'h7, 32'h2f1700ff, success);
   $display("     DMA ready after SDRAM initialization.");

   // try an interrupt driven sector read
   // from the target32 which is located
   // at absolute address 0xc0000000
   $display(" ");
   $display("Starting Interrupt Driven Single Pass Sector Read...");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000100, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h01000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");

   // try an interrupt driven sector write
   // to the target32 which is located
   // at absolute address 0xc0000000
   $display(" ");
   $display("Starting Interrupt Driven Single Pass Sector Write...");
   $display(" ");
   force testbench.TRG.behavior = `T32_NORMAL;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000500, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h41000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");

   // try an interrupt driven sector read
   // from the target32 which is located
   // at absolute address 0xc0000000 but
   // this time cause a master abort
   $display(" ");
   $display("Starting Interrupt Driven Master Aborted Sector Read...");
   $display(" ");
   force testbench.TRG.behavior = `T32_NONE;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000100, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h01000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");

   // try an interrupt driven sector write
   // to the target32 which is located
   // at absolute address 0xc0000000 but
   // this time cause a master abort
   $display(" ");
   $display("Starting Interrupt Driven Master Aborted Sector Write...");
   $display(" ");
   force testbench.TRG.behavior = `T32_NONE;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000500, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h41000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");

   // try an interrupt driven sector read
   // from the target32 which is located
   // at absolute address 0xc0000000 but
   // this time mix it up a bit...
   $display(" ");
   $display("Starting Interrupt Driven Fragmented Sector Read...");
   $display(" ");
   force testbench.TRG.behavior = `T32_RANDOM;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000100, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h01000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");

   // try an interrupt driven sector write
   // to the target32 which is located
   // at absolute address 0xc0000000 but
   // this time mix it up a bit...
   $display(" ");
   $display("Starting Interrupt Driven Fragmented Sector Write...");
   $display(" ");
   force testbench.TRG.behavior = `T32_RANDOM;
   $display("     Writing DMA Host Buffer Address.");
   PCI_DW_WR(32'h00000010, 4'h7, 32'hc0000500, success);
   PCI_DW_WR(32'h00000014, 4'h7, 32'h00000000, success);
   $display("     Setting up interrupt behavior.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0003, success);
   $display("     Setting up direction and Local Sector Address.");
   PCI_DW_WR(32'h00000018, 4'h7, 32'h41000000, success);
   @(negedge INTR_A);
   $display("     Interrupt asserted.");
   PCI_DW_RD(32'h0000001c, 4'h6, returned, success);
   if (returned[29]) $display("     A DMA Error occurred.");
   PCI_DW_WR(32'h0000001c, 4'h7, 32'hffff0000, success);
   @(posedge INTR_A);
   $display("     Interrupt deasserted.");
   // stop simulation
   $display(" ");
   $display("Simulation complete...");
   $display(" ");
   */

   $finish;
end

initial
begin
   #22000 $finish;
end

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
