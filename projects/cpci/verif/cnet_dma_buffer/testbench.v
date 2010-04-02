///////////////////////////////////////////////////////////////////////////////
// $Id: testbench.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: cnet_dma_buffer
// Project: CPCI (PCI Control FPGA)
// Description: Tests the cnet_dma_buffer module
//
// Test bench must simulate a series of DMA transfers.
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module testbench ( );

// ==================================================================
// Constants
// ==================================================================

`define RETRY     1'b1
`define NO_RETRY  1'b0

`define BUF_SIZE  4'h6




parameter Tpclk = 15;
parameter Tnclk = 8;

// Buffer size (buffer requires some extra space for housekeeping)
parameter bufsize = 512 - 1;


reg reset, nclk, pclk;



wire [3:0]  dma_pkt_avail; // Packets available in which buffers in CNET
reg  [3:0]  dma_request;   // Request packet from buffer X

wire [31:0] dma_data;      // DMA data to be transfered
reg         dma_rd_en;     // Read a word from the buffer

wire [3:0]  dma_tx_full; // Buffer full in the CNET

// CNET interface signals
reg  [3:0]  cpci_dma_pkt_avail;  // Which buffers have packets available
wire [3:0]  cpci_dma_send;     // Initiate a transfer from a buffer
reg         cpci_dma_wr_en;      // Valid data on data bus
reg  [31:0] cpci_dma_data;       // DMA data

reg  [3:0]  cpci_tx_full;        // Is there room for a full-sized packet in the
// corresponding tx buffer?



integer                             i;

wire [3:0] buf_size = `BUF_SIZE;




// ==================================================================
// Generate a clock signal
// ==================================================================

always
begin
   pclk <= 1'b1;
   #Tpclk;
   pclk <= 1'b0;
   #Tpclk;
end

always
begin
   nclk <= 1'b1;
   #Tnclk;
   nclk <= 1'b0;
   #Tnclk;
end


// ==================================================================
// Instantiate the module under test
// ==================================================================

cnet_dma_buffer cnet_dma_buffer (
            .dma_pkt_avail (dma_pkt_avail),
            .dma_request (dma_request),
            .dma_data (dma_data),
            .dma_rd_en (dma_rd_en),
            .dma_tx_full (dma_tx_full),
            .dma_nearly_empty (dma_nearly_empty),
            .dma_empty (dma_empty),
            .dma_all_in_buf (dma_all_in_buf),
            .cpci_dma_pkt_avail (cpci_dma_pkt_avail),
            .cpci_dma_send (cpci_dma_send),
            .cpci_dma_nearly_full (cpci_dma_nearly_full),
            .cpci_dma_wr_en (cpci_dma_wr_en),
            .cpci_dma_data (cpci_dma_data),
            .cpci_tx_full (cpci_tx_full),
            .reset (reset),
            .pclk (pclk),
            .nclk (nclk)
         );


// ==================================================================
// Test structures
// ==================================================================

// Test the dma_pkt_avail signals
task test_dma_pkt_avail;
   integer pkt_avail;
   integer timer;

   reg success;

   parameter wait_time = 10;

   begin
      success = 1;
      $write("pkt_avail passes:");
      for (pkt_avail = 0; pkt_avail < 16; pkt_avail = pkt_avail + 1) begin
         timer = wait_time;

         @(negedge nclk) begin
            cpci_dma_pkt_avail <= pkt_avail;
         end

         while (timer > 0 && dma_pkt_avail != pkt_avail) begin
            @(posedge pclk);
            timer = timer - 1;
         end

         if (dma_pkt_avail == pkt_avail)
            $write(" %1d", pkt_avail);
         else
            success = 0;
      end
      $display();

      if (!success)
         $display($time, " ERROR: pkt_avail tests failed");
      else
         $display($time, " Success: pkt_avail tests passed");
   end
endtask

// Test the dma_tx_full signals
task test_dma_tx_full;
   integer tx_full;
   integer timer;

   reg success;

   parameter wait_time = 10;

   begin
      success = 1;
      $write("tx_full passes:");
      for (tx_full = 0; tx_full < 16; tx_full = tx_full + 1) begin
         timer = wait_time;

         @(negedge nclk) begin
            cpci_tx_full <= tx_full;
         end

         while (timer > 0 && dma_tx_full != tx_full) begin
            @(posedge pclk);
            timer = timer - 1;
         end

         if (dma_tx_full == tx_full)
            $write(" %1d", tx_full);
         else
            success = 0;
      end
      $display();

      if (!success)
         $display($time, " ERROR: tx_full tests failed");
      else
         $display($time, " Success: tx_full tests passed");
   end
endtask

// Test the cpci_dma_send signals
task test_cpci_dma_send;
   integer request;
   integer timer;

   reg success;

   parameter wait_time = 10;

   begin
      success = 1;
      $write("request passes:");
      for (request = 0; request < 16; request = request + 1) begin
         timer = wait_time;

         @(negedge pclk) begin
            dma_request <= request;
         end

         @(negedge pclk) begin
            dma_request <= 'h0;
         end

         while (timer > 0 && cpci_dma_send != request) begin
            @(posedge nclk);
            timer = timer - 1;
         end

         if (cpci_dma_send == request)
            $write(" %1d", request);
         else
            success = 0;

         // Reset the dma_send signal
         @(negedge pclk) begin
            reset <= 1;
         end
         for (timer = 0; timer < 2; timer = timer + 1) begin
            @(posedge pclk);
         end
         @(negedge pclk) begin
            reset <= 0;
         end
         @(posedge pclk);
      end
      $display();

      if (!success)
         $display($time, " ERROR: request tests failed");
      else
         $display($time, " Success: request tests passed");

   end
endtask

// Test the actual buffer
task test_p_flags;
   input nearly_empty;
   input empty;
   input all_in_buf;

   begin
      if (dma_nearly_empty != nearly_empty)
         $display($time, " ERROR: dma_nearly_empty -- Expected: %b  Saw: %b", nearly_empty, dma_nearly_empty);
      if (dma_empty != empty)
         $display($time, " ERROR: dma_empty -- Expected: %b  Saw: %b", empty, dma_empty);
      if (dma_all_in_buf != all_in_buf)
         $display($time, " ERROR: dma_all_in_buf -- Expected: %b  Saw: %b", all_in_buf, dma_all_in_buf);
   end
endtask

task test_n_flags;
   input dma_nearly_full;

   begin
      if (cpci_dma_nearly_full != dma_nearly_full)
         $display($time, " ERROR: cpci_dma_nearly_full -- Expected: %b  Saw: %b", dma_nearly_full, cpci_dma_nearly_full);
   end
endtask

task test_buffer;
   integer timer;

   parameter wait_time = 10;

   begin
      // Check to make sure the flags are at the correct values
      test_p_flags(1, 1, 0);
      test_n_flags(0);

      // Generate a request
      @(negedge pclk) begin
         dma_request <= 4'b0001;
      end

      @(negedge pclk) begin
         dma_request <= 4'b0000;
      end

      // Check to make sure we see the send request
      timer = wait_time;
      while (timer > 0 && ~|(cpci_dma_send)) begin
         @(posedge nclk);
      end

      if (~|(cpci_dma_send)) begin
         $display($time, " ERROR: Didn't see send request");
         $finish;
      end

      // Send a reply
      @(negedge nclk) begin
         cpci_dma_wr_en <= 1'b1;
         // Should be equal to the size of the buffer
         cpci_dma_data <= (bufsize - 1) * 4;
      end

      // Make sure the send flag has been reset
      @(posedge nclk);

      #1 if (|(cpci_dma_send)) begin
         $display($time, " ERROR: Send flag was not reset");
         $finish;
      end

      @(negedge nclk) begin
         cpci_dma_wr_en <= 1'b0;
      end

      @(posedge nclk);

      // Check to make sure the PCI side sees it
      timer = wait_time;
      while (timer > 0 && dma_empty) begin
         @(posedge pclk);
      end

      if (dma_empty) begin
         $display($time, " ERROR: Empty flag on PCI side of buffer is still set");
         $finish;
      end

      test_p_flags(1, 0, 0);

      // Send in a stream of data
      for (i = 0; i < bufsize - 1; i = i + 1) begin
         @(negedge nclk) begin
            cpci_dma_wr_en <= 1'b1;
            cpci_dma_data <= i;
         end
      end

      @(negedge nclk) begin
         cpci_dma_wr_en <= 1'b0;
      end

      test_n_flags(1);

      // Check to make sure the PCI side sees it
      for (i = 0; i < 5; i = i + 1) begin
         @(posedge pclk);
      end

      test_p_flags(0, 0, 1);

      // Suck a word out
      @(negedge pclk) begin
         dma_rd_en <= 1'b1;
      end

      @(posedge pclk);

      #1 if (dma_data != (bufsize - 1) * 4) begin
         $display($time, " ERROR: Unexpected output from buffer: 0x%h  Expected 0x%h", dma_data, (bufsize - 1) * 4);
         $finish;
      end

      @(negedge pclk) begin
         dma_rd_en <= 1'b0;
      end

      /*// Send in a final word
      @(negedge nclk) begin
         cpci_dma_wr_en <= 1'b1;
         cpci_dma_data <= bufsize;
      end

      @(negedge nclk) begin
         cpci_dma_wr_en <= 1'b0;
      end

      // Check to make sure the PCI side sees it
      timer = wait_time;
      while (timer > 0 && !dma_all_in_buf) begin
         @(posedge pclk);
      end

      if (!dma_all_in_buf) begin
         $display($time, " ERROR: all_in_buf flag on PCI side of buffer is not set");
         $finish;
      end

      test_p_flags(0, 0, 1);*/

      // Suck out the data
      for (i = 0; i < bufsize - 1; i = i + 1) begin
         @(negedge pclk) begin
            dma_rd_en <= 1'b1;
         end

         @(posedge pclk);

         #1 if (dma_data != i) begin
            $display($time, " ERROR: Unexpected output from buffer: 0x%h  Expected 0x%h", dma_data, i);
            $finish;
         end
         if (bufsize - i - 1 < 5) begin
            if (!dma_nearly_empty) begin
               $display($time, " ERROR: dma_nearly_empty not set");
               //$finish;
            end
         end
      end

      @(negedge pclk) begin
         dma_rd_en <= 1'b0;
      end

      test_p_flags(1, 1, 1);
   end
endtask

reg cpci_dma_nearly_full_d1;
reg reset_d1;

always @(posedge nclk) begin
   cpci_dma_nearly_full_d1 <= cpci_dma_nearly_full;
   reset_d1 <= reset;
end

always @(posedge nclk)
begin
   if (cpci_dma_nearly_full && !cpci_dma_nearly_full_d1 && !reset && !reset_d1)
      $display($time, " Nearly Full");
end

initial
begin
   dma_request = 'h0;
   dma_rd_en = 1'b0;
   cpci_dma_pkt_avail = 'h0;
   cpci_dma_wr_en = 1'b0;
   cpci_dma_data = 'h0;
   cpci_tx_full = 'h0;

   reset = 1'b1;

   #1000  reset = 1'b0;

   #100 test_dma_pkt_avail;
   #100 test_dma_tx_full;
   #100 test_cpci_dma_send;
   #100 test_buffer;

   #100
   $display($time," finishing...");
   $finish;

end

initial
begin
   #50000 $finish;
end

endmodule // testbench

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
