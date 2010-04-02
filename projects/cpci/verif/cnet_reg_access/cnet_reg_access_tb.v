///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reg_access_tb.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: cnet_reg_access
// Project: CPCI (PCI Control FPGA)
// Description: Tests the cnet_reg_access module
//
// Test bench must simulate a series of reads and writes to the CNET
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module reg_file_tb ( );

// ==================================================================
// Constants
// ==================================================================

`define RETRY     1'b1
`define NO_RETRY  1'b0

`define BUF_SIZE  4'h6




parameter Tperiod = 15;


reg reset, clk;

reg [31:0]  pci_addr;
reg [3:0]   pci_be;
reg [31:0]  pci_data;
reg         pci_data_vld;

reg cnet_hit;
reg cnet_we;

wire [31:0]  cnet_data;    // Data being read by the PCI interface
wire         cnet_vld;     // Data on the cnet_data bus is valid

wire         cnet_retry;   // Force a retry

// CPCI->CNET
wire [31:0]  p2n_data;     // Data going from the CPCI to the CNET
wire [31:0]  p2n_addr;     // Data going from the CPCI to the CNET
wire         p2n_we;       // Write enable signal
wire         p2n_req;      // Read/Write request signal

wire         p2n_full;     // Full signal for FIFO from CPCI to CNET

// CNET->CPCI
wire [31:0]  n2p_data;     // Data going from the CPCI to the CNET
wire         n2p_rd_rdy;   // Read enable signal


reg          cnet_reprog;   // Indicates that the CNET is

integer 			    i;

wire [3:0] buf_size = `BUF_SIZE;

reg expect_timeout;


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

cnet_reg_access cnet_reg_access(
            .pci_addr (pci_addr),
            .pci_be (pci_be),
            .pci_data (pci_data),
            .pci_data_vld (pci_data_vld),
            .cnet_we (cnet_we),
            .cnet_hit (cnet_hit),
            .cnet_data (cnet_data),
            .cnet_vld (cnet_vld),
            .cnet_retry (cnet_retry),
            .p2n_data (p2n_data),
            .p2n_addr (p2n_addr),
            .p2n_we (p2n_we),
            .p2n_req (p2n_req),
            .p2n_full (p2n_full),
            .n2p_data (n2p_data),
            .n2p_rd_rdy (n2p_rd_rdy),
            .cnet_reprog (cnet_reprog),
            .reset (reset),
            .clk (clk)
         );


// ==================================================================
// Test structures
// ==================================================================

cnet_iface cnet_iface(
            .p2n_data (p2n_data),
            .p2n_addr (p2n_addr),
            .p2n_we (p2n_we),
            .p2n_req (p2n_req),
            .p2n_full (p2n_full),
            .n2p_data (n2p_data),
            .n2p_rd_rdy (n2p_rd_rdy),
            .buf_size (buf_size),
            .reset (reset),
            .clk (clk)
         );

   // Perform a write
   task do_write;
      input [31:0] addr;
      input [31:0] data;
      input expect_retry;

      begin
	 $display($time, " Writing data to address %x", addr);

	 @(negedge clk) begin
	    pci_addr <= addr;
	    pci_be <= 4'b1111;
	    pci_data <= 'h0;
	    pci_data_vld <= 1'b0;

            cnet_hit <= 1'b1;
            cnet_we <= 1'b1;
	 end

	 // Wait for the positive edge of the clock

	 @(posedge clk) begin
            // Check for a retry if we are expecting one
            if (expect_retry) begin
               if (cnet_retry)
	          $display($time, " Success: Read from %x produced a retry", addr);
               else
	          $display($time, " ERROR: Read from %x failed to produce a retry", addr);
            end
            else begin
               // Assert the data_vld signal on the next negative edge
               @(negedge clk) begin
	          pci_data <= data;
	          pci_data_vld <= 1'b1;
               end

               // De-assert the data_vld signal on the next negative edge
               @(negedge clk) begin
	          pci_data <= data;
	          pci_data_vld <= 1'b0;
               end
            end
	 end


	 // OK, clean up.
         i = 0;
         while (i < 2)
            @(negedge clk) i = i + 1;

	 #1 begin
	    pci_addr = 32'hffff_ffff;
	    pci_be <= 4'b0000;

	    cnet_we = 'h0;
            cnet_hit = 'h0;
	 end
      end
   endtask


   // Perform a read
   task do_read;
      input [31:0] addr;
      input expect_retry;

      reg done;
      time terminate_on_error;
      `define MAX_RD_WAIT_TIME 30000

      begin
	 $display($time, " Reading data from address %x", addr);

	 @(negedge clk) begin
	    pci_addr <= addr;
	    pci_be <= 4'b1111;
	    pci_data <= 'h0;
	    pci_data_vld <= 1'b0;

            cnet_hit <= 1'b1;
            cnet_we <= 1'b0;
	 end

	 // Wait for the positive edge of the clock
	 @(posedge clk) begin
            // Check for a retry if we are expecting one
            if (expect_retry) begin
               if (cnet_retry)
	          $display($time, " Success: Read from %x produced a retry", addr);
               else
	          $display($time, " ERROR: Read from %x failed to produce a retry", addr);
            end
            else begin
	       // Wait for up to 5 reads for n2p_rd_rdy to be asserted
               done = 1'b0;
               i = 0;
               while (!done && i < 5) begin
                  i = i + 1;
                  @(negedge clk) begin
                     cnet_hit <= 1'b0;
                     cnet_we <= 1'b0;
                  end

                  #(Tperiod * 10)
                  @(negedge clk) begin
                     cnet_hit <= 1'b1;
                     cnet_we <= 1'b0;
                  end

                  #1 done = !cnet_retry;
               end

               // Fetch the read result
               #1 if (!done) begin
	             $display($time, " ERROR: Read cycle didnt terminate within 5 transactions");
               end
               else begin
                  if (cnet_data == addr[23:0])
	             $display($time, " Success: Read from %x returned %x", addr, cnet_data);
                  else if (expect_timeout && cnet_data == 'h ffff_ffff)
	             $display($time, " Success: Read from %x returned timeout value %x", addr, cnet_data);
                  else
	             $display($time, " ERROR: Read from %x returned %x", addr, cnet_data);
               end
            end
	 end


	 // OK, clean up.
         i = 0;
         while (i < 2)
            @(negedge clk) i = i + 1;

	 #1 begin
	    pci_addr = 32'hffff_ffff;
	    pci_be <= 4'b0000;

	    cnet_we = 'h0;
            cnet_hit = 'h0;
	 end
      end
   endtask

initial
begin
   pci_addr = 32'hffff_ffff;
   pci_be = 4'b0000;
   pci_data = 'h0;
   pci_data_vld = 1'b0;

   cnet_we = 'h0;
   cnet_hit = 'h0;

   cnet_reprog = 1'b0;

   expect_timeout = 1'b0;

   clk = 0;
   reset = 1;

   #1000  reset = 0;

   #100  do_write($random, $random, `NO_RETRY);
   #50   do_read($random, `NO_RETRY);
   #50   do_write($random, $random, `NO_RETRY);

   #100
   $display($time," finishing...");
   $finish;

end

endmodule // reg_file_tb

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
