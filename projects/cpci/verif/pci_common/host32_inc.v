///////////////////////////////////////////////////////////////////////////////
// $Id: host32_inc.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: host32.v
// Project: CPCI (PCI Control FPGA)
// Description: Simulates a PCI host
//
//              Simulates a host that can do dword transactions and
//              initialize configuration space.
//
//              Based upon host32.v by Eric Crabill, Xilinx.
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`define         SKIP_PEEK       1
`define         SKIP_PROM       1
`define         T32_NORMAL      2'b00
`define         T32_ABORT       2'b01
`define         T32_RANDOM      2'b10
`define         T32_NONE        2'b11


/*
 * Port declaration
 *
 * Put this in the module that includes this
 */

/*
module host32 (
                  inout  [`PCI_DATA_WIDTH - 1:0] AD,
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
*/

// Define Timing Parameters
parameter Tc2o = 2;


// Define Internal Registers

reg [`PCI_DATA_WIDTH - 1:0] returned;
reg [`PCI_DATA_WIDTH - 1:0] regfile_base;
reg         success;

reg [`PCI_DATA_WIDTH - 1:0]  reg_ad;
reg         ad_oe;
reg  [3:0]  reg_cbe;
reg         cbe_oe;
reg         reg_par;
reg         par_oe;
reg         reg_frame_n;
reg         frame_oe;
reg         reg_irdy_n;
reg         irdy_oe;


// Define port hookup

assign #Tc2o AD = ad_oe ? reg_ad : 32'bz;
assign #Tc2o CBE = cbe_oe ? reg_cbe : 4'bz;
assign #Tc2o PAR = par_oe ? reg_par : 1'bz;
assign #Tc2o FRAME_N = frame_oe ? reg_frame_n : 1'bz;
assign #Tc2o IRDY_N = irdy_oe ? reg_irdy_n : 1'bz;


// PCI Parity Generation

wire drive;
assign #Tc2o drive = ad_oe;

always @(posedge CLK)
begin
   // Always computed, selectively enabled
   reg_par <= (^ {AD, CBE});
   par_oe <= drive;
end


// Read Task

task PCI_DW_RD;
   input [`PCI_DATA_WIDTH - 1:0]   addr;
   input [3:0]    cmd;
   output [`PCI_DATA_WIDTH - 1:0]  data;
   output         okay;
begin
   @(posedge CLK);
      reg_frame_n <= 0;
      reg_irdy_n <= 1;
      reg_ad <= addr;
      reg_cbe <= cmd;
      frame_oe <= 1;
      irdy_oe <= 1;
      ad_oe <= 1;
      cbe_oe <= 1;
   @(posedge CLK);
      reg_frame_n <= 1;
      reg_irdy_n <= 0;
      reg_cbe <= 4'b0000;
      frame_oe <= 1;
      irdy_oe <= 1;
      ad_oe <= 0;
      cbe_oe <= 1;
   while(TRDY_N & STOP_N) @(posedge CLK);
   $write($time, "   Host read  0x%h with cmd 0x%h:  ", addr, cmd);
   case ({TRDY_N,STOP_N})
      2'b00: begin
         $write("Disconnect with Data, ");
         data = AD;
         okay = 1'b1;
         $display("0x%h.",data);
      end
      2'b01: begin
         $write("Data Transfer, ");
         data = AD;
         okay = 1'b1;
         $display("0x%h.",data);
      end
      2'b10: begin
         $display("Retry, no data.");
         data = 32'bx;
         okay = 1'b0;
      end
      2'b11: begin
         $display("ERROR: Fatal Error in PCI_DW_RD.  Exiting");
         data = 32'bx;
         okay = 1'b0;
         $finish;
      end
      default: begin
         $display("ERROR: Fatal Error in PCI_DW_RD. Unknown response: %2b  Exiting", {TRDY_N,STOP_N});
         data = 32'bx;
         okay = 1'b0;
         $finish;
      end
   endcase
      reg_irdy_n <= 1;
      frame_oe <= 0;
      irdy_oe <= 1;
      ad_oe <= 0;
      cbe_oe <= 0;
   @(posedge CLK);
      frame_oe <= 0;
      irdy_oe <= 0;
   @(posedge CLK);
end
endtask


// Read Task with expected result
task PCI_DW_RD_EXPECT;
   input [`PCI_DATA_WIDTH - 1:0]   addr;
   input [3:0]    cmd;
   input [`PCI_DATA_WIDTH - 1:0]   expect;
   output [`PCI_DATA_WIDTH - 1:0]  data;
   output         okay;
begin
   PCI_DW_RD(addr, cmd, data, okay);
   if (data != expect)
      $display($time, "   ERROR: Unexpected data from read. Expecting: 0x%h  Saw: 0x%h", expect, data);
end
endtask

// Read Task with auto retry
task PCI_DW_RD_RETRY;
   input [`PCI_DATA_WIDTH - 1:0]   addr;
   input [3:0]    cmd;
   input [`PCI_DATA_WIDTH - 1:0]   max_tries;
   output [`PCI_DATA_WIDTH - 1:0]  data;
   output         okay;
   integer        retry_count;
begin
   retry_count = max_tries;
   if (retry_count < 1)
      retry_count = 1;
   okay = 1'b0;
   while (retry_count > 0 && !okay) begin
      PCI_DW_RD(addr, cmd, data, okay);
      retry_count = retry_count - 1;
   end
   if (!okay)
      $display($time, "   ERROR: Retry on read to 0x%h failed to produce a result after retries", addr);
end
endtask

// Read Task with auto retry and an expected result
task PCI_DW_RD_RETRY_EXPECT;
   input [`PCI_DATA_WIDTH - 1:0]   addr;
   input [3:0]    cmd;
   input [`PCI_DATA_WIDTH - 1:0]   expect;
   input [`PCI_DATA_WIDTH - 1:0]   max_tries;
   output [`PCI_DATA_WIDTH - 1:0]  data;
   output         okay;
begin
   PCI_DW_RD_RETRY(addr, cmd, max_tries, data, okay);
   if (okay)
      if (data != expect)
         $display($time, "   ERROR: Unexpected data from read. Expecting: 0x%h  Saw: 0x%h", expect, data);
end
endtask


// Write Task

task PCI_DW_WR;
   input [`PCI_DATA_WIDTH - 1:0] addr;
   input [3:0] cmd;
   input [`PCI_DATA_WIDTH - 1:0] data;
   output      okay;
begin
   @(posedge CLK);
      reg_frame_n <= 0;
      reg_irdy_n <= 1;
      reg_ad <= addr;
      reg_cbe <= cmd;
      frame_oe <= 1;
      irdy_oe <= 1;
      ad_oe <= 1;
      cbe_oe <= 1;
   @(posedge CLK);
      reg_frame_n <= 1;
      reg_irdy_n <= 0;
      reg_ad <= data;
      reg_cbe <= 4'b0000;
      frame_oe <= 1;
      irdy_oe <= 1;
      ad_oe <= 1;
      cbe_oe <= 1;
   while(TRDY_N & STOP_N) @(posedge CLK);
   $write($time, "   Host wrote 0x%h with cmd 0x%h:  ", addr, cmd);
   case ({TRDY_N,STOP_N})
      2'b00: begin
         $write("Disconnect with Data, ");
         $display("0x%h.",data);
         okay = 1'b1;
      end
      2'b01: begin
         $write("Data Transfer, ");
         $display("0x%h.",data);
         okay = 1'b1;
      end
      2'b10: begin
         $display("Retry, no data.");
         okay = 1'b0;
      end
      2'b11: begin
         $display("ERROR: Fatal Error in PCI_DW_WR.  Exiting");
         okay = 1'b0;
         $finish;
      end
      default: begin
         $display("ERROR: Fatal Error in PCI_DW_WR. Unknown response: %2b  Exiting", {TRDY_N,STOP_N});
         okay = 1'b0;
         $finish;
      end
   endcase
      reg_irdy_n <= 1;
      frame_oe <= 0;
      irdy_oe <= 1;
      ad_oe <= 0;
      cbe_oe <= 0;
   @(posedge CLK);
      frame_oe <= 0;
      irdy_oe <= 0;
   @(posedge CLK);
end
endtask


// Reset Task

task RESET_WAIT;
begin
   reg_ad <= 32'h0;
   ad_oe <= 0;
   reg_cbe <= 4'h0;
   cbe_oe <= 0;
   reg_frame_n <= 1;
   frame_oe <= 0;
   reg_irdy_n <= 1;
   irdy_oe <= 0;
   @(posedge RST_N)
   $display(" ");
   $display($time, "   System Reset Complete...");
   @(posedge CLK);
   @(posedge CLK);
   @(posedge CLK);
   @(posedge CLK);
   @(posedge CLK);
   @(posedge CLK);
end
endtask

task DO_OS_SETUP;
integer i;
reg expect_bar;
begin
   $display(" ");
   $display($time, "   Operating System Configuring Device...");
   $display(" ");

   // Check the device type
   $display($time, "   Searching for device.");
   PCI_DW_RD(32'h00010000, 4'ha, returned, success);
   if (returned != 32'h0001feed) $display($time, "   Error:  Unexpected device.");
   else $display($time, "   NetFPGA-1G Device Found.");

   // Check the BARs
   regfile_base = 32'h00000000;
   for (i = 0; i < 3; i = i + 1)
   begin
      $display($time, "   BAR%1d:", i);
      PCI_DW_RD(32'h00010010 + i * 4, 4'ha, returned, success);
      if (returned[3:0] != 4'b0000) $display($time, "   Error:  Unexpected BAR type.");
      else $display($time, "   BAR%1d of expected type exists.", i);
      $display($time, "   Checking size of BAR%1d.", i);
      PCI_DW_WR(32'h00010010 + i * 4, 4'hb, 32'hffffffff, success);
      PCI_DW_RD(32'h00010010 + i * 4, 4'ha, returned, success);
      returned = ~returned + 1;
      $display($time, "   Device requests 0x%h bytes.", returned);

      // Work out if we expect a request
      case (i)
         0 : expect_bar = 1'b1;
         default : expect_bar = 1'b0;
      endcase

      // Work out if the expected and requested are identical
      if (expect_bar && returned != 0) begin
         $display($time, "   Locating device at 0x%h.",regfile_base);
         PCI_DW_WR(32'h00010010 + i * 4, 4'hb, regfile_base, success);
         regfile_base = regfile_base + returned;
      end
      else if ((!expect_bar && returned != 0) ||
               (expect_bar && returned == 0)) begin
         if (expect_bar)
            $display($time, "   ERROR: Expected BAR%1d to request address space. Exiting", i);
         else
            $display($time, "   ERROR: Unexpected request for address space by BAR%1d. Exiting", i);
         $finish;
      end
   end

   $display($time, "   Setting Latency Timer to 0xff.");
   PCI_DW_WR(32'h0001000c, 4'hb, 32'h0000ff00, success);
   $display($time, "   Enabling Mem Space and Bus Master.");
   PCI_DW_WR(32'h00010004, 4'hb, 32'hffff0147, success);
   PCI_DW_RD(32'h00010004, 4'ha, returned, success);

   $display($time, "   Operating System Configuring Done");
   $display(" ");
   $display(" ");
end
endtask


// Decode the interrupt register
task DECODE_INTR;
   input [`PCI_DATA_WIDTH - 1:0] intr_flags;
begin
   if (|(intr_flags)) begin
      $write($time, "   CPCI Interrupt:");
      if (intr_flags[31])
         $write("  DMA xfer complete");
      if (intr_flags[30])
         $write("  PHY");
      if (intr_flags[8])
         $write("  DMA pkts avail");
      if (intr_flags[5])
         $write("  CNET error");
      if (intr_flags[4])
         $write("  CNET read timeout");
      if (intr_flags[3])
         $write("  Prog error");
      if (intr_flags[2])
         $write("  DMA xfer timeout");
      if (intr_flags[1])
         $write("  DMA xfer error");
      if (intr_flags[0])
         $write("  DMA fatal error");

      $display("");
   end
   else begin
      $display($time, "   No interrupt flags asserted");
   end
end
endtask

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
