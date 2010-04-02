///////////////////////////////////////////////////////////////////////////////
// $Id: target32.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: target32.v
// Project: CPCI (PCI Control FPGA)
// Description: Simulates a PCI target
//
//              Simulates a host that can do dword transactions and
//              initialize configuration space.
//
//              Based upon target32.v by Eric Crabill, Xilinx.
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`include "defines.v"


/*
 * Port declaration
 *
 * Put this in the module that includes this
 */


module target32 (
                AD,
                CBE,
                PAR,
                FRAME_N,
                TRDY_N,
                IRDY_N,
                STOP_N,
                DEVSEL_N,
                RST_N,
                CLK
                );


// Port Directions

inout   [31:0] AD;
input    [3:0] CBE;
inout          PAR;
input          FRAME_N;
output         TRDY_N;
input          IRDY_N;
output         STOP_N;
output         DEVSEL_N;
input          RST_N;
input          CLK;


// Global Declarations

reg     [31:0] cmd_mem [0:4095];
wire     [1:0] behavior;
reg      [3:0] chance;
integer        loop_var;
parameter      Tc2o = 2;


// Initialize Internal Memory
always @(posedge RST_N)
begin
   for (loop_var = 0; loop_var < 4096; loop_var = loop_var + 1)
   begin
      cmd_mem[loop_var] = {~loop_var[15:0], loop_var[15:0]};
   end
end


// Target Controlled Signals
reg     [31:0] reg_ad;
reg            ad_oe;
reg      [3:0] reg_cbe;
reg            cbe_oe;
reg            reg_par;
reg            par_oe;

reg            reg_frame_n;
reg            frame_oe;
reg            reg_irdy_n;
reg            irdy_oe;
reg            reg_trdy_n;
reg            trdy_oe;
reg            reg_stop_n;
reg            stop_oe;
reg            reg_devsel_n;
reg            devsel_oe;
wire           drive;


// Output Drivers

assign #Tc2o AD = ad_oe ? reg_ad : 32'bz;
assign #Tc2o CBE = cbe_oe ? reg_cbe : 4'bz;
assign #Tc2o PAR = par_oe ? reg_par : 1'bz;
assign #Tc2o FRAME_N = frame_oe ? reg_frame_n : 1'bz;
assign #Tc2o IRDY_N = irdy_oe ? reg_irdy_n : 1'bz;
assign #Tc2o TRDY_N = trdy_oe ? reg_trdy_n : 1'bz;
assign #Tc2o STOP_N = stop_oe ? reg_stop_n : 1'bz;
assign #Tc2o DEVSEL_N = devsel_oe ? reg_devsel_n : 1'bz;


// PCI Parity Generation

assign #Tc2o drive = ad_oe;

always @(posedge CLK)
begin
   reg_par <= (^ {AD, CBE});
   par_oe <= drive;
   chance <= $random;
end


// Pre-decode Information

reg      [31:0] counter;
reg                old_frame_n;
reg                cmd_write;
reg                cmd_read;
wire               valid_read;
wire               valid_write;
wire               valid_addr;

assign #Tc2o valid_write = (CBE == 4'b0111);
assign #Tc2o valid_read   = (CBE == 4'b0110)|(CBE == 4'b1100)|(CBE == 4'b1110);
assign #Tc2o valid_addr = (AD[31:30] == 2'b11);
assign #Tc2o behavior = 2'b00;


// Behavior Selection

always @(posedge CLK or negedge RST_N)
begin
   if (RST_N)
   begin
      casex (behavior)
         2'b00    : NORMAL;
         2'b01    : ABORT;
         2'b10    : RANDOM;
         2'b11    : NONE;
         default : NONE;
      endcase
   end
   else RESET;
end


// Reset Task

task RESET;
begin
   reg_ad = 32'h0;
   ad_oe = 1'b0;
   reg_cbe = 4'h0;
   cbe_oe = 1'b0;
   reg_frame_n = 1'b1;
   frame_oe = 1'b0;
   reg_irdy_n = 1'b1;
   irdy_oe = 1'b0;
   reg_trdy_n = 1'b1;
   trdy_oe = 1'b0;
   reg_stop_n = 1'b1;
   stop_oe = 1'b0;
   reg_devsel_n = 1'b1;
   devsel_oe = 1'b0;
   old_frame_n = 1'b1;
end
endtask


// Abort Task

task ABORT;
begin
   $display("Fatal Unimplemented Task Error TARGET32.ABORT.   Exiting");
   $finish;
end
endtask


// Random Task

task RANDOM;
begin
   if (old_frame_n & !FRAME_N & (valid_read | valid_write) & valid_addr)
   begin
      old_frame_n = 1'b0;
      devsel_oe = 1'b1;
      stop_oe = 1'b1;
      trdy_oe = 1'b1;
      cmd_write = valid_write;
      cmd_read = valid_read;
      counter = (AD >> 2) & 32'h00000fff;
      reg_ad = cmd_mem[counter];

      if (valid_write)
      begin
         reg_devsel_n = 1'b0;
         reg_stop_n = 1'b1;
         reg_trdy_n = 1'b0;
      end
      else
      begin
         reg_devsel_n = 1'b0;
         @(posedge CLK);
         reg_stop_n = 1'b1;
         reg_trdy_n = 1'b0;
         ad_oe = 1'b1;
      end

      while (!old_frame_n)
      begin
         @(posedge CLK);
         if (reg_stop_n == 1'b0) reg_trdy_n = 1'b1;
         while (IRDY_N) @(posedge CLK);
         old_frame_n = FRAME_N;
         if (cmd_write & !reg_trdy_n) cmd_mem[counter] = AD;
         counter = (counter + 1) & 32'h00000fff;
         reg_ad = cmd_mem[counter];
         if (chance == 4'b0000) reg_stop_n = 1'b0;
      end

      ad_oe = 1'b0;
      reg_devsel_n = 1'b1;
      reg_stop_n = 1'b1;
      reg_trdy_n = 1'b1;
      @(posedge CLK);
      devsel_oe = 1'b0;
      stop_oe = 1'b0;
      trdy_oe = 1'b0;
      old_frame_n = 1'b1;
   end
end
endtask


// None Task

task NONE;
begin
   #Tc2o;
end
endtask


// Normal Task

task NORMAL;
begin
   if (old_frame_n & !FRAME_N & (valid_read | valid_write) & valid_addr)
   begin
      old_frame_n = 1'b0;
      devsel_oe = 1'b1;
      stop_oe = 1'b1;
      trdy_oe = 1'b1;
      cmd_write = valid_write;
      cmd_read = valid_read;
      counter = (AD >> 2) & 32'h00000fff;
      reg_ad = cmd_mem[counter];

      if (valid_write)
      begin
         reg_devsel_n = 1'b0;
         reg_stop_n = 1'b1;
         reg_trdy_n = 1'b0;
      end
      else
      begin
         reg_devsel_n = 1'b0;
         @(posedge CLK);
         reg_stop_n = 1'b1;
         reg_trdy_n = 1'b0;
         ad_oe = 1'b1;
      end

      while (!old_frame_n)
      begin
         @(posedge CLK);
         while (IRDY_N) @(posedge CLK);
         old_frame_n = FRAME_N;
         if (cmd_write) begin
            cmd_mem[counter] = AD;
            $display($time, " Write to TARGET32 at 0x%h   Data: 0x%h   CBE: 0x%4b", 32'hc0000000 | (counter << 2), AD, CBE);
         end
         counter = (counter + 1) & 32'h00000fff;
         reg_ad = cmd_mem[counter];
      end

      ad_oe = 1'b0;
      reg_devsel_n = 1'b1;
      reg_stop_n = 1'b1;
      reg_trdy_n = 1'b1;
      @(posedge CLK);
      devsel_oe = 1'b0;
      stop_oe = 1'b0;
      trdy_oe = 1'b0;
      old_frame_n = 1'b1;
   end
end
endtask

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
