///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: target32.v 3454 2008-03-25 05:00:58Z grg $
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

//`include "defines.v"

// default filenames
`define DMA_INGRESS_FILE_NAME "packet_data/ingress_dma"
`define INGRESS_SEPARATOR 32'heeeeffff

`define DMA_EGRESS_FILE_FMT "packet_data/egress_dma_X"
`define DMA_EGRESS_FILE_LEN 24
`define DMA_EGRESS_FILE_BITS 8*`DMA_EGRESS_FILE_LEN

`define DEFAULT_FINISH_TIME 1000000

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
                CLK,

                sim_end
                );


// How many ports?
localparam NUM_PORTS = 4;


// Set size of memory (in words)
//
// Note: 1024 words is approx the size of a page
localparam MEM_SIZE = 1024;
localparam MEM_MASK = MEM_SIZE - 1;

// Max size of DMA ingress file
localparam DMA_SZ = 1000000;

// Port Directions

inout   [31:0] AD;
inout    [3:0] CBE;
inout          PAR;
inout          FRAME_N;
output         TRDY_N;
inout          IRDY_N;
output         STOP_N;
output         DEVSEL_N;
input          RST_N;
input          CLK;

input          sim_end;


// Global Declarations

reg     [31:0] cmd_mem [0:MEM_SIZE - 1];
wire     [1:0] behavior;
reg      [3:0] chance;
integer        loop_var;
parameter      Tc2o = 2;

// DMA Ingress registers
reg [31:0] dma_ingress_data [0:DMA_SZ - 1];
integer dma_size;
integer egress_count [NUM_PORTS-1:0];

// Egress file descriptor
integer fd_e [NUM_PORTS-1:0];

// Pointer to current word in ingress memory
integer dma_iptr;


// ================================================================
// Initialization code to open files
// ================================================================

initial
begin
   // get info such as finish time from the config.txt file
   read_DMA_ingress;
   initialize_egress;
   clear_memory;

   dma_iptr = 0;

   fork
      handle_finish;
   join
end


// Initialize Internal Memory
always @(posedge RST_N)
begin
   for (loop_var = 0; loop_var < MEM_SIZE; loop_var = loop_var + 1)
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
reg      [31:0] num_words;
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
      counter = (AD >> 2) & MEM_MASK;
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
         counter = (counter + 1) & MEM_MASK;
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

      reg verbose;

begin

   verbose = 0;

   if (old_frame_n & !FRAME_N & (valid_read | valid_write) & valid_addr)
   begin
      old_frame_n = 1'b0;
      devsel_oe = 1'b1;
      stop_oe = 1'b1;
      trdy_oe = 1'b1;
      cmd_write = valid_write;
      cmd_read = valid_read;
      counter = (AD >> 2) & MEM_MASK;
      num_words = 0;
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
            num_words = num_words + 1;
            if(verbose) $display($time, " Write to TARGET32 at 0x%h   Data: 0x%h", 32'hc0000000 | (counter << 2), AD);
         end
         counter = (counter + 1) & MEM_MASK;
         reg_ad = cmd_mem[counter];
         if (cmd_read) begin
            num_words = num_words + 1;
            if(verbose) $display($time, " Read from TARGET32 at 0x%h   Data: 0x%h", 32'hc0000000 | (counter << 2), reg_ad);
         end
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



// ================================================================
// Clear the memory
// ================================================================

task clear_memory;

   integer i;

   begin
      for (i = 0; i < MEM_SIZE; i = i + 1) begin
         cmd_mem[i] = {32{1'bx}};
      end
   end
endtask // clear_memory


// ================================================================
// Read the file containing the list of DMA writes
// ================================================================

task read_DMA_ingress;

   integer i;

   begin
      // Read the cmds into local memory
      $readmemh(`DMA_INGRESS_FILE_NAME, dma_ingress_data);
   end
endtask // read_DMA_ingress


// ================================================================
// Process the ingress DMA data (ingress into the NetFPGA)
// ================================================================

task next_ingress;

  integer words, i;
  reg [31:0] len;
  time time2send;

   begin
      // Prepare the next packet for transmission into the NetFPGA
      if ((dma_iptr < DMA_SZ) && (dma_ingress_data[dma_iptr] !== 32'hxxxxxxxx)) begin
         // get next packet and put in rx_packet_buffer
         len = dma_ingress_data[dma_iptr];

         $display("%t %m Setting up memory for DMA transfer (len %0d bytes) to NF2.", $time, len);

         // Copy the data into memory
         dma_iptr = dma_iptr + 1;
         words = ((len-1)>>2)+1;                 // number of 32 bit words in pkt
         for (i = 0; i < words; i = i + 1) begin
            cmd_mem[i] = dma_ingress_data[dma_iptr];
            dma_iptr = dma_iptr + 1;
         end

         if (dma_ingress_data[dma_iptr] !== `INGRESS_SEPARATOR) begin
            $display($time," %m Error: expected to point at packet separator %x but saw %x",
                     `INGRESS_SEPARATOR, dma_ingress_data[dma_iptr]);
            $fflush;
            $finish;
         end

         dma_iptr = dma_iptr + 1;
     end
   end
endtask // next_ingress



// ================================================================
// Initialize the egress file
// ================================================================

task initialize_egress;

   reg [`DMA_EGRESS_FILE_BITS-1:0]     egress_file_name;

   integer i;

begin
   for (i = 0; i < NUM_PORTS; i = i + 1) begin
      // Previously used sformat but this isn't supported by ISIM 10.1
      egress_file_name = `DMA_EGRESS_FILE_FMT;
      egress_file_name[7:0] = "0" + i + 1;

      fd_e[i] = $fopen(egress_file_name, "w");

      if (fd_e[i] == 0) begin
	 $display("Error: unable to open filename %s for writing.", egress_file_name );
	 $finish;
      end

      // Write out XML header info
      $fwrite(fd_e[i], "<?xml version=\"1.0\" standalone=\"yes\" ?>\n");
      $fwrite(fd_e[i], "<!-- DMA egress packet data. Port %0d -->\n", i + 1);
      $fwrite(fd_e[i], "<DMA_PACKET_STREAM>\n");

      egress_count[i] = 0;
   end // for
end
endtask // initialize_egress



// ================================================================
// Host just received a packet - we need to write it out to the file.
// Egress packet is in cmd_mem
// ================================================================

task handle_egress_packet;
      input integer port;
      input integer byte_len;

      integer i;
      integer word_len;

      begin
	 egress_count[port] = egress_count[port] + 1;

         // Calculate the word length
         word_len = ((byte_len-1)>>2)+1;                 // number of 32 bit words in pkt

         // Record the packet receival
	 $fwrite(fd_e[port],"\n<!-- Time %t Packet # %0d Full length = %0d (bytes). -->\n",
		 $time, egress_count[port], byte_len);

	 // OK write the packet out.
	 $fwrite(fd_e[port],"<DMA_PACKET Length=\"%0d\" Port=\"%0d\" Delay=\"%0d\">\n",
		 byte_len, port + 1, $time );

	 for (i = 0; i < word_len - 1; i = i + 1) begin
	    $fwrite(fd_e[port], "%02x %02x %02x %02x ",
               cmd_mem[i][31:24],
               cmd_mem[i][23:16],
               cmd_mem[i][15:8],
               cmd_mem[i][7:0]);
	    if ((i % 4 == 3)) $fwrite(fd_e[port],"\n");
	 end
         case (byte_len % 4)
	    0: $fwrite(fd_e[port], "%02x %02x %02x %02x ",
                  cmd_mem[word_len-1][31:24], cmd_mem[word_len-1][23:16],
                  cmd_mem[word_len-1][15:8], cmd_mem[word_len-1][7:0]);
	    1: $fwrite(fd_e[port], "%02x ",
                  cmd_mem[word_len-1][31:24]);
	    2: $fwrite(fd_e[port], "%02x %02x ",
                  cmd_mem[word_len-1][31:24], cmd_mem[word_len-1][23:16]);
	    3: $fwrite(fd_e[port], "%02x %02x %02x ",
                  cmd_mem[word_len-1][31:24], cmd_mem[word_len-1][23:16],
                  cmd_mem[word_len-1][15:8]);
         endcase
	 if (word_len % 4 != 0) $fwrite(fd_e[port],"\n");
	 $fwrite(fd_e[port],"</DMA_PACKET>\n");
	 $fflush;

      end
endtask // handle_egress_packet


// ========================================================
// Decide when to finish the simulation and clean up
// egress files.
// ========================================================

task handle_finish;
   integer i;
   begin
      wait (sim_end === 1'b1);

      // OK, now it's time to finish so clean up
      for (i = 0; i < NUM_PORTS; i = i + 1) begin
         $fwrite(fd_e[i],"\n<!-- Simulation terminating at time %0t -->\n",$time);
         $fwrite(fd_e[i],"</DMA_PACKET_STREAM>\n");
         $fclose(fd_e[i]);
      end

      // leave a bit of time for other processes to close
      #100 $display($time," Simulation has reached finish time - ending.");
      $finish;

   end
endtask // handle_finish

endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
