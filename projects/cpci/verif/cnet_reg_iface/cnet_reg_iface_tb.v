///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reg_iface_tb.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: cnet_reg_iface
// Project: CPCI (PCI Control FPGA)
// Description: Tests the cnet_reg_iface module
//
// Test bench simulates a series of reads and writes to the CNET
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module cnet_reg_iface_tb ( );

// ==================================================================
// Constants
// ==================================================================

`define RETRY     1'b1
`define NO_RETRY  1'b0

`define BUF_SIZE  4'h3

`define QUEUE_DEPTH 32
`define QUEUE_DEPTH_BITS 5



parameter Tpclk = 15;
parameter Tnclk = 8;


reg reset, pclk, nclk;



// CPCI->CNET
reg [`CPCI_CNET_DATA_WIDTH-1:0]  p2n_data;     // Data going from the CPCI to the CNET
reg [`CPCI_CNET_ADDR_WIDTH-1:0]  p2n_addr;     // Data going from the CPCI to the CNET
reg         p2n_we;       // Write enable signal
reg         p2n_req;      // Read/Write request signal

reg [`CPCI_CNET_DATA_WIDTH-1:0]  dma_data;     // DMA Data going from the CPCI to the CNET
reg [`CPCI_CNET_ADDR_WIDTH-1:0]  dma_addr;     // DMA Data going from the CPCI to the CNET
reg         dma_req;      // DMA request signal

wire         p2n_full;
wire         p2n_almost_full;

// CNET->CPCI
wire [`CPCI_CNET_DATA_WIDTH-1:0]  n2p_data;     // Data going from the CPCI to the CNET
wire         n2p_rd_rdy;   // Read enable signal

// External signals between CPCI and CNET
wire cpci_rd_wr_L;
wire cpci_req;
wire [`CPCI_CNET_ADDR_WIDTH-1:0] cpci_addr;
wire [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data_wr;
tri [`CPCI_CNET_DATA_WIDTH-1:0] cpci_data;
wire cpci_data_tri_en;
wire cpci_wr_rdy;
wire cpci_rd_rdy;



reg          cnet_reprog;   // Indicates that the CNET is
reg cnet_hit;

reg [31:0]  cnet_rd_time;  // Max amout of time for a read to complete
wire        cnet_rd_timeout;

integer 			    i;

wire [3:0] buf_size = `BUF_SIZE;


reg [`CPCI_CNET_ADDR_WIDTH + `CPCI_CNET_DATA_WIDTH + 1 - 1 : 0] req_queue [`QUEUE_DEPTH - 1 : 0];
reg [`CPCI_CNET_ADDR_WIDTH - 1: 0] reply_queue [`QUEUE_DEPTH - 1 : 0];

reg [`QUEUE_DEPTH_BITS-1 : 0] req_depth, reply_depth;
reg [`QUEUE_DEPTH_BITS-1 : 0] req_curr_rd, req_curr_wr, reply_curr_rd, reply_curr_wr;

reg cpci_req_d1;

reg [`QUEUE_DEPTH_BITS-1 : 0] q_depth;
reg q_done;
integer retries;

reg in_req;

reg expect_timeout;


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

cnet_reg_iface cnet_reg_iface (
            .p2n_data (p2n_data),
            .p2n_addr (p2n_addr),
            .p2n_we (p2n_we),
            .p2n_req (p2n_req),
            .dma_data (dma_data),
            .dma_addr (dma_addr),
            .dma_req (dma_req),
            .p2n_full (p2n_full),
            .p2n_almost_full (p2n_almost_full),
            .n2p_data (n2p_data),
            .n2p_rd_rdy (n2p_rd_rdy),
            .cnet_reprog (cnet_reprog),
            .cnet_hit (cnet_hit),
            .cnet_rd_time (cnet_rd_time),
            .cnet_rd_timeout (cnet_rd_timeout),
            .cpci_rd_wr_L (cpci_rd_wr_L),
            .cpci_req (cpci_req),
            .cpci_addr (cpci_addr),
            .cpci_data_wr (cpci_data_wr),
            .cpci_data_rd (cpci_data),
            .cpci_data_tri_en (cpci_data_tri_en),
            .cpci_wr_rdy (cpci_wr_rdy),
            .cpci_rd_rdy (cpci_rd_rdy),
            .reset (reset),
            .pclk (pclk),
            .nclk (nclk)
         );
assign cpci_data = cpci_data_tri_en ? cpci_data_wr : 'bz;


// ==================================================================
// Test structures
// ==================================================================

cnet cnet(
            .cpci_rd_wr_L (cpci_rd_wr_L),
            .cpci_req (cpci_req),
            .cpci_addr (cpci_addr),
            .cpci_data (cpci_data),
            .cpci_wr_rdy (cpci_wr_rdy),
            .cpci_rd_rdy (cpci_rd_rdy),
            .reset (reset),
            .clk (nclk)
         );

// Perform a write
task do_reg_write;
   input [`CPCI_CNET_ADDR_WIDTH - 1:0] addr;
   input [`CPCI_CNET_DATA_WIDTH - 1:0] data;

   begin
      $display($time, " Reg Write to address %x  Data: %x  P2N_Full: %b", addr, data, p2n_full);

      wait (!p2n_full);

      @(negedge pclk) begin
	 p2n_addr <= addr;
         p2n_data <= data;
         p2n_we <= 1'b1;
         p2n_req <= 1'b1;
         cnet_hit <= 1'b1;
      end

      // Pop the request on the request_queue
      req_queue[req_curr_wr] = {1'b0, addr, data};
      req_curr_wr = req_curr_wr + 1;
      req_depth = req_depth + 1;

      @(negedge pclk) begin
	 p2n_addr <= 'h0;
         p2n_data <= 'h0;
         p2n_we <= 1'b0;
         p2n_req <= 1'b0;
         cnet_hit <= 1'b0;
      end

   end
endtask


// Perform a write
task do_dma_write;
   input [`CPCI_CNET_ADDR_WIDTH - 1:0] addr;
   input [`CPCI_CNET_DATA_WIDTH - 1:0] data;

   begin
      $display($time, " DMA Write to address %x  Data: %x  P2N_Full: %b", addr, data, p2n_full);

      wait (!p2n_full);

      @(negedge pclk) begin
	 dma_addr <= addr;
         dma_data <= data;
         dma_req <= 1'b1;
      end

      // Pop the request on the request_queue
      req_queue[req_curr_wr] = {1'b0, addr, data};
      req_curr_wr = req_curr_wr + 1;
      req_depth = req_depth + 1;

      @(negedge pclk) begin
	 dma_addr <= 'h0;
         dma_data <= 'h0;
         dma_req <= 1'b0;
      end
   end
endtask

// Perform a read
task do_reg_read;
   input [`CPCI_CNET_ADDR_WIDTH - 1:0] addr;

   begin
      $display($time, " Reg Read from address %x  P2N_Full: %b", addr, p2n_full);

      wait (!p2n_full);

      @(negedge pclk) begin
	 p2n_addr <= addr;
         p2n_we <= 1'b0;
         p2n_req <= 1'b1;
         cnet_hit <= 1'b1;
      end

      // Pop the request on the request queue
      req_queue[req_curr_wr] = {1'b1, addr, `CPCI_CNET_DATA_WIDTH'b0};
      req_curr_wr = req_curr_wr + 1;
      req_depth = req_depth + 1;

      // Pop the request on the reply queue
      reply_queue[reply_curr_wr] = {addr};
      reply_curr_wr = reply_curr_wr + 1;
      reply_depth = reply_depth + 1;

      @(negedge pclk) begin
	 p2n_addr <= 'h0;
         p2n_we <= 1'b0;
         p2n_req <= 1'b0;
         cnet_hit <= 1'b0;
      end
   end
endtask

always @(posedge nclk)
begin
   if (!cpci_req || (!cpci_rd_wr_L && cpci_wr_rdy) || (cpci_rd_wr_L && cpci_rd_rdy))
      in_req <= 1'b0;
   else
      in_req <= 1'b1;
end

always @(posedge nclk)
begin
   if (cpci_req && !in_req) begin
      if (req_depth > 0) begin
         if (cpci_rd_wr_L == req_queue[req_curr_rd][`CPCI_CNET_ADDR_WIDTH + `CPCI_CNET_DATA_WIDTH + 1 - 1] &&
             cpci_addr == req_queue[req_curr_rd][`CPCI_CNET_ADDR_WIDTH + `CPCI_CNET_DATA_WIDTH - 1 : `CPCI_CNET_DATA_WIDTH] &&
             (cpci_rd_wr_L || cpci_data == req_queue[req_curr_rd][`CPCI_CNET_DATA_WIDTH - 1 : 0]))
             $display($time, " Success: Saw %s at address %x on bus. Data: %x", cpci_rd_wr_L ? "READ" : "WRITE", cpci_addr, cpci_data);
         else begin
	    $display($time, " ERROR: An unexpected request has appeared on the bus: Type: %s  Addr: %x  Data: %x",
                  cpci_rd_wr_L ? "READ" : "WRITE", cpci_addr, cpci_data);
	    $display($time, " ERROR: Expected: Type: %s  Addr: %x  Data: %x",
                  req_queue[req_curr_rd][`CPCI_CNET_ADDR_WIDTH + `CPCI_CNET_DATA_WIDTH + 1 - 1] ? "READ" : "WRITE",
                  req_queue[req_curr_rd][`CPCI_CNET_ADDR_WIDTH + `CPCI_CNET_DATA_WIDTH - 1 : `CPCI_CNET_DATA_WIDTH],
                  req_queue[req_curr_rd][`CPCI_CNET_DATA_WIDTH - 1 : 0]);
         end
         req_depth = req_depth - 1;
         req_curr_rd = req_curr_rd + 1;
      end
      else
	 $display($time, " ERROR: An unexpected request has appeared on the bus: Type: %s  Addr: %x  Data: %x",
                  cpci_rd_wr_L ? "READ" : "WRITE", cpci_addr, cpci_data);
   end
   cpci_req_d1 = cpci_req;
end

always @(posedge pclk)
begin
   if (n2p_rd_rdy) begin
      if (reply_depth > 0) begin
         //if (n2p_data == {(`CPCI_CNET_DATA_WIDTH - `CPCI_CNET_ADDR_WIDTH)'b0, reply_queue[reply_curr_rd]})
         if (n2p_data == reply_queue[reply_curr_rd])
             $display($time, " Success: Saw reply at address %x on bus. Data: %x", reply_queue[reply_curr_rd], n2p_data);
         else if (cnet_rd_timeout && expect_timeout) begin
	    $display($time, " Warning: Saw a timeout when reading from %x. (Probably ok)", reply_queue[reply_curr_rd]);
         end
         else if (cnet_rd_timeout && !expect_timeout) begin
	    $display($time, " ERROR: Saw a timeout when reading from %x. (Not expecting one.)", reply_queue[reply_curr_rd]);
         end
         else begin
	    $display($time, " ERROR: An unexpected reply has appeared on the bus: Data: %x", n2p_data);
	    $display($time, " ERROR: Expected: Data: %x",
                  reply_queue[reply_curr_rd]);
         end
         reply_depth = reply_depth - 1;
         reply_curr_rd = reply_curr_rd + 1;
      end
      else
	 $display($time, " ERROR: An unexpected reply has appeared on the bus: Data: %x", n2p_data);
   end
end

task wait_for_queues;
   begin
      // Waits up to 10 clocks for a queue to drop by 1 item
      q_depth = req_depth;
      q_done = req_depth == 0;
      retries = 10;
      while (!q_done && retries != 0) begin
         @(posedge nclk) q_done = req_depth == 0;

         #1 retries = retries - 1;
         if (retries == 0) begin
            if (q_depth != req_depth) begin
               q_depth = req_depth;
               retries = 10;
            end
         end
      end

      if (q_done) begin
         q_depth = reply_depth;
         q_done = reply_depth == 0;
         retries = 10;
         while (!q_done && retries != 0) begin
            @(posedge pclk) q_done = reply_depth == 0;

            #1 retries = retries - 1;
            if (retries == 0) begin
               if (q_depth != reply_depth) begin
                  q_depth = reply_depth;
                  retries = 10;
               end
            end
         end
      end
   end
endtask


integer rand, wait_time;

initial
begin
   req_depth = 'h0;
   reply_depth = 'h0;
   req_curr_rd = 'h0;
   req_curr_wr = 'h0;
   reply_curr_rd = 'h0;
   reply_curr_wr = 'h0;

   p2n_addr = 32'hffff_ffff;
   p2n_data = 'h0;
   p2n_we = 1'b0;
   p2n_req = 1'b0;
   cnet_hit = 1'b0;

   dma_addr = 32'hffff_ffff;
   dma_data = 'h0;
   dma_req = 1'b0;

   cnet_reprog = 1'b0;
   cnet_rd_time = -'h1;

   pclk = 0;
   nclk = 0;
   reset = 1;

   in_req = 1'b0;

   #1000 reset = 0;

   expect_timeout = 1'b0;

   for (i = 0; i < 30; i = i + 1) begin

      // Work out what we're doing
      rand = ($random % 2);
      wait_time = {$random} % 100 + Tpclk;

      #wait_time if (rand == 1)
         do_reg_write($random, $random);
      else if (rand == 1)
         do_dma_write($random, $random);
      else
         do_reg_read($random);
   end

   // Wait for the two queues to trickle down...
   wait_for_queues;

   // Perform more random operations (this time expecting timeouts)
   cnet_rd_time = 'h1;

   $display($time, " Expecting timeouts now");
   expect_timeout = 1'b1;

   for (i = 0; i < 20; i = i + 1) begin

      // Work out what we're doing
      rand = ($random % 2);
      wait_time = {$random} % 100 + Tpclk;

      #wait_time if (rand == 1)
         do_reg_write($random, $random);
      else if (rand == 1)
         do_dma_write($random, $random);
      else
         do_reg_read($random);
   end

   // Wait for the two queues to trickle down...
   wait_for_queues;

   $display($time," finishing...");

   if (req_depth > 0 || reply_depth > 0) begin
      $display($time, " ERROR: Non-empty request or reply queue: Request depth: %d  Reply depth: %d", req_depth, reply_depth);
   end
   $finish;

end

endmodule // cnet_reg_iface_tb

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
