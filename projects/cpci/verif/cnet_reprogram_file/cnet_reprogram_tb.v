///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reprogram_tb.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: cnet_reprogram
// Project: CPCI (PCI Control FPGA)
// Description: Tests the cnet_reprogram module
//
// Test bench must simulate the reprgramming of the CNET
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module cnet_reprogram_tb ( );

// ==================================================================
// Constants
// ==================================================================

`define  BITSTREAM   "bitstream.hex"

parameter Tperiod = 15;

parameter BITSTREAM_LEN = 362185;

reg reset, clk;

reg [`PCI_DATA_WIDTH-1:0] prog_data;
reg          prog_data_vld;

wire [7:0]   rp_data;
reg          want_crc_error;

integer 			    i;
integer bs_pos;


reg [31:0] queue [15:0];
reg [3:0] rd_ptr, wr_ptr;
reg [4:0] depth;
reg [1:0] curr_byte;

reg [7:0] expected_byte;
wire [7:0] rp_data_reversed;

reg [31:0] bitstream [BITSTREAM_LEN - 1:0];

reg prog_reset;



// ==================================================================
// Generate a clock signal
// ==================================================================

always
begin
   clk <= 1'b1;
   #Tperiod;
   clk <= 1'b0;
   #Tperiod;
end



// ==================================================================
// Instantiate the module under test
// ==================================================================

cnet_reprogram cnet_reprogram(
            .prog_data (prog_data),
            .prog_data_vld (prog_data_vld),
            .prog_reset (prog_reset),
            .cnet_reprog (cnet_reprog),
            .overflow (overflow),
            .error (error),
            .init (init),
            .done (done),
            .rp_prog_b (rp_prog_b),
            .rp_init_b (rp_init_b),
            .rp_cclk (rp_cclk),
            .rp_cs_b (rp_cs_b),
            .rp_rdwr_b (rp_rdwr_b),
            .rp_data (rp_data),
            .rp_done (rp_done),
            .reset (reset),
            .clk (clk)
         );


// ==================================================================
// Test structures
// ==================================================================

cnet cnet(
            .rp_prog_b (rp_prog_b),
            .rp_init_b (rp_init_b),
            .rp_cs_b (rp_cs_b),
            .rp_rdwr_b (rp_rdwr_b),
            .rp_data (rp_data),
            .rp_done (rp_done),

            .want_crc_error (want_crc_error),

            .rp_cclk (rp_cclk)
         );

// Perform a write
task do_write;
   input [31:0] data;

   begin
      $display($time, " Writing programming data %x", data);

      @(negedge clk) begin
         prog_data <= data;
         prog_data_vld <= 1'b1;
      end

      // Add the data to the queue
      queue[wr_ptr] = data;
      wr_ptr = wr_ptr + 1;
      depth = depth + 1;

      // Check the overflow flag and reset the data
      @(negedge clk) begin
         if (overflow)
            $display($time, " ERROR: Writing programming data %x caused overflow", data);
         prog_data <= 32'hffff_ffff;
         prog_data_vld <= 1'b0;
      end
   end
endtask


// Wait for the write to memory to be done
task wait_for_done;
   integer count;
   integer prev_depth;

   reg ok;

   begin
      ok = done;
      prev_depth = depth;
      // Wait up to 20 clocks for the queue to deplete in depth
      count = 20;
      while (!ok) begin
         @(posedge clk) ;
         ok = (done || count == 0);
         count = count - 1;
         if (depth < prev_depth) begin
            count = 20;
            prev_depth = depth;
         end
      end
      if (depth != 0)
         $display($time, " ERROR: Not all programming data was sent to the CNET");
      else begin
         // Wait a few clock cycles for cnet_reprog to go low
         count = 20;
         ok = !cnet_reprog;
         while (!ok) begin
            @(posedge clk) ;
            ok = !cnet_reprog || count == 0;
            count = count - 1;
         end
         if (!done)
            $display($time, " ERROR: Did not see done signal");
      end
   end
endtask

always @(posedge rp_cclk)
begin
   if (want_crc_error && !rp_cs_b) begin
      $display($time, " Wanting a CRC error");
      rd_ptr = wr_ptr;
      depth = 'h0;
   end
   else if (!rp_cs_b) begin
      if (depth == 0)
         $display($time, " ERROR: Unexpected %s to CNET of %x", rp_rdwr_b ? "READ" : "WRITE", rp_data_reversed);
      else begin
         if (rp_data_reversed == expected_byte)
            $display($time, " Success: Saw %s to CNET of %x", rp_rdwr_b ? "READ" : "WRITE", rp_data_reversed);
         else
            $display($time, " ERROR: Saw %s to CNET of %x, expected %x", rp_rdwr_b ? "READ" : "WRITE", rp_data_reversed, expected_byte);
         curr_byte = curr_byte + 1;
         if (curr_byte == 'h0) begin
            rd_ptr = rd_ptr + 1;
            depth = depth - 1;
         end
      end
   end
end

always @*
begin
   $display($time, " Flags: REPRG: %b   OVERFLOW: %b   ERR: %b   INIT: %b   DONE: %b", cnet_reprog , overflow , error , init , done);
end


initial
begin
   prog_data = 32'hffff_ffff;
   prog_data_vld = 1'b0;
   prog_reset = 1'b0;

   want_crc_error = 1'b0;

   rd_ptr = 'h0;
   wr_ptr = 'h0;
   depth = 'h0;
   curr_byte = 'h0;

   clk = 0;
   reset = 1;

   // Read in the bin file
   for (i = 0; i < BITSTREAM_LEN; i = i + 1)
   begin
      bitstream[i] = 'h0;
   end
   $readmemh(`BITSTREAM, bitstream);
   bs_pos = 0;


   #1000  reset = 0;

   if (cnet_reprog || overflow || error || init || !done)
      $display($time, " ERROR: Flags: REPRG: %b   OVERFLOW: %b   ERR: %b   INIT: %b   DONE: %b", cnet_reprog , overflow , error , init , done);

   // Reset the programming process
   #100 prog_reset = 1'b1;
   #100 prog_reset = 1'b0;

   // Start programming
   for (i = 0; i < 50; i = i + 1)
   begin
      #200 do_write(bitstream[i]);
   end

   // Reset the programming process
   #200  prog_reset = 1;
   #200  prog_reset = 0;

   // Program properly
   for (i = 0; i < BITSTREAM_LEN; i = i + 1)
   begin
      #200 do_write(bitstream[i]);
   end

   /*
   #100 do_write($random);

   #100 do_write($random);

   #100 do_write($random);

   #100 do_write($random);

   #10 wait_for_done;


   #100 do_write($random);

   #100 do_write($random);

   #100 do_write($random);

   #100 do_write($random);

   want_crc_error = 1'b1;
   */
   #10 wait_for_done;

   #100
   $display($time," finishing...");
   $finish;

end

always @*
begin
   case (curr_byte)
      2'h0: expected_byte <= queue[rd_ptr][7:0];
      2'h1: expected_byte <= queue[rd_ptr][15:8];
      2'h2: expected_byte <= queue[rd_ptr][23:16];
      2'h3: expected_byte <= queue[rd_ptr][31:24];
   endcase
end

assign rp_data_reversed = {
            rp_data[0],
            rp_data[1],
            rp_data[2],
            rp_data[3],
            rp_data[4],
            rp_data[5],
            rp_data[6],
            rp_data[7]
            };

endmodule // cnet_reprogram_tb

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
