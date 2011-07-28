///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: host32.v
// Project: CPCI (PCI Control FPGA)
// Description: Simulates a PCI host.
//
//              Provides read and write operations to a testbench.
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ns

//`include "defines.v"

module host32 (
	       // PCI side signals
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
               input         CLK,

	       // testbench side signals
               output reg req,
               input      grant,
	       output reg host32_is_active,  // tell TB when we are ready for requests

               output reg done,

               output reg activity,

               output reg barrier_req,
               input      barrier_proceed
               );

// Include all of the base code that defines how do do various
// basic transactions
`include "host32_inc.v"

`define PCI_FILE_NAME "packet_data/pci_sim_data"

`define NUM_DMA_PORTS   4

   reg dma_in_progress;
   reg [`PCI_DATA_WIDTH - 1:0] dma_q_status;
   wire [`PCI_DATA_WIDTH/2 - 1:0] dma_pkt_avail;
   wire [`PCI_DATA_WIDTH/2 - 1:0] dma_can_wr_pkt;
   localparam MAX_TRIES = 30;

   assign dma_pkt_avail = dma_q_status[`PCI_DATA_WIDTH/2 +: `PCI_DATA_WIDTH/2];
   assign dma_can_wr_pkt = dma_q_status[`PCI_DATA_WIDTH/2 - 1:0];

   integer dma_rx_pkts[0 : `NUM_DMA_PORTS - 1];
   integer dma_rx_pkts_i;

   integer exp_pkts [0: `NUM_DMA_PORTS - 1];
   reg all_exp_pkts_seen;

   reg delay_done;
   time delay_end;



// Begin the actual simulation sequence
   initial
   begin

      host32_is_active = 0;
      dma_in_progress = 0;
      dma_q_status = 'h0;
      barrier_req = 0;
      activity = 0;
      done = 0;
      for (dma_rx_pkts_i = 0; dma_rx_pkts_i < `NUM_DMA_PORTS;
         dma_rx_pkts_i = dma_rx_pkts_i + 1) begin
            dma_rx_pkts[dma_rx_pkts_i] = 0;
            exp_pkts[dma_rx_pkts_i] = 0;
         end
      all_exp_pkts_seen = 0;
      delay_end = 0;
      delay_done = 1;

      // wait for the system to reset
      RESET_WAIT;

      // set up the device as an os would
      DO_OS_SETUP;

      host32_is_active = 1;

      process_PCI_requests;

   end


   // ================================================================
   // Read the file containing the list of PCI accesses (reads/writes)
   // Then step through and perform them.

`define PCI_SZ 1000000
`define PCI_READ     1
`define PCI_WRITE    2
`define PCI_DMA      3
`define PCI_BARRIER  4
`define PCI_DELAY    5

   reg pkts_good;

   always @(posedge CLK)
   begin
      pkts_good = 1;
      for (dma_rx_pkts_i = 0; dma_rx_pkts_i < `NUM_DMA_PORTS;
         dma_rx_pkts_i = dma_rx_pkts_i + 1) begin
            pkts_good = pkts_good &
               (dma_rx_pkts[dma_rx_pkts_i] >= exp_pkts[dma_rx_pkts_i]);
         end
      all_exp_pkts_seen = pkts_good;
   end

   always @(posedge CLK)
   begin
      delay_done = $time >= delay_end;
   end

   task process_PCI_requests;

      reg [31:0] pci_cmds [0:`PCI_SZ];
      integer pci_ptr;
      reg [31:0] pci_cmd;
      reg [31:0] pci_addr, pci_data, pci_mask;
      integer i;
      reg [31:0] rd_data;
      reg ok;
      reg ok2, ok3;

      reg [`PCI_DATA_WIDTH - 1:0]   interrupt_mask;
      reg rx_good;

      time delay;

      begin
	 for (i=0;i <= `PCI_SZ; i=i+1) pci_cmds[i] = 'h0;

	 // Read the cmds into local memory
	 $readmemh(`PCI_FILE_NAME, pci_cmds);

	 pci_ptr = 0 ;

	 // Iterate through the command memory until we get to a null command or end of mem.
	 while ((pci_ptr < `PCI_SZ) && (pci_cmds[pci_ptr] != 0)) begin
	    pci_cmd = pci_cmds[pci_ptr];
	    pci_addr = pci_cmds[pci_ptr+1];
	    pci_data = pci_cmds[pci_ptr+2];
	    pci_mask = pci_cmds[pci_ptr+3];
            if (pci_cmd == `PCI_BARRIER)
               for (i = 0; i < `NUM_DMA_PORTS; i = i + 1)
                  exp_pkts[i] = pci_cmds[pci_ptr + 1 + i];
            delay = {pci_cmds[pci_ptr+1], pci_cmds[pci_ptr+2]};

            // Service any pending interrupts
            while (~INTR_A)
               service_interrupt;

            // Wait appropriately if the command is a PCI transaction
            if (pci_cmd != `PCI_BARRIER && pci_cmd != `PCI_DELAY) begin
                while (dma_in_progress ||
                   (pci_cmd == `PCI_DMA && !dma_can_wr_pkt[pci_addr - 1])) begin

                   // Wait until either an interrupt occurs
                   // or the there's no DMA transfer in progress and we can
                   // proceed with the next command
                   wait (~INTR_A || !dma_in_progress &&
                      !(pci_cmd == `PCI_DMA && !dma_can_wr_pkt[pci_addr - 1]));

                   // Service any interrupts
                   if (~INTR_A)
                      service_interrupt;
                end
             end

	    // tell user what we're doing

            case (pci_cmd)
               `PCI_READ: begin
                  $display("%t %m: Info: Starting PCI Read of address 0x%08x expect result 0x%08x",
                           $time, pci_addr, (pci_data & pci_mask));
               end

               `PCI_WRITE: begin
	          $display("%t %m: Info: Starting PCI Write data 0x%08x to address 0x%08x",
		           $time, pci_data, pci_addr);
               end

               `PCI_DMA: begin
	          $display("%t %m: Info: Starting PCI DMA transfer of length %0d to DMA queue %0d",
		           $time, pci_data, pci_addr);
               end

               `PCI_BARRIER: begin
	          $display("%t %m: Info: PCI barrier", $time);
                  for (i = 0; i < `NUM_DMA_PORTS; i = i + 1)
	             $display("%t %m: Info:   DMA port %1d: expecting %1d pkts, seen %1d pkts",
                        $time, i, exp_pkts[i], dma_rx_pkts[i]);
               end

               `PCI_DELAY: begin
	          $display("%t %m: Info: PCI delay %t ns", $time, delay);
               end

               default: begin
	          $display("%t %m: Error: Unknown PCI transaction: 0x%08x", $time, pci_cmd);
               end
            endcase


	    // do it.
            case (pci_cmd)
               `PCI_READ: begin
                  activity = 1;
                  PCI_DW_RD_RETRY( pci_addr[26:0],  4'h6, MAX_TRIES, rd_data, ok);
                  activity = 0;

                  if (ok !== 1)
                    $display("%t %m: Error: PCI Read of address 0x%08x failed.",
                             $time, pci_addr);
                  else begin
                     // check expected value against actual
                     if ((rd_data & pci_mask) !== (pci_data & pci_mask)) begin
                        $display("%t %m: Error: PCI read of addr 0x%06x returned data 0x%08x but expected 0x%08x (mask is 0x%08x)",
                                 $time, pci_addr, (rd_data & pci_mask), (pci_data & pci_mask), pci_mask);
                     end
                     else
                        $display("%t %m: Good: PCI read of addr 0x%06x returned data 0x%08x as expected.",
                                 $time, pci_addr, (rd_data & pci_mask));
                  end

	          pci_ptr = pci_ptr + 4;
               end  // PCI READ


               `PCI_WRITE: begin
                  activity = 1;
                  PCI_DW_WR_RETRY( pci_addr[26:0],  4'h7, pci_data, MAX_TRIES, ok);
                  activity = 0;

                  if (ok !== 1)
                    $display("%t %m: Error: PCI Write to address 0x%08x with data 0x%08x failed.",
                             $time, pci_addr, pci_data);

	          pci_ptr = pci_ptr + 4;
               end  // PCI WRITE


               `PCI_DMA: begin
                  $display("%t %m: Info: Starting DMA transfer", $time);

                  dma_in_progress = 1;

                  // Prepare the DMA data in memory
                  testbench.target32.next_ingress;

                  // Mask off the packet available interrupts (don't start a new
                  // transfer while we're waiting for this transfer to begin)
                  activity = 1;
                  PCI_DW_RD({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h6, interrupt_mask, success);
                  interrupt_mask = interrupt_mask | 32'h00000100;
                  PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, interrupt_mask, success);

                  // Set up the write address and size
                  PCI_DW_WR({`CPCI_DMA_ADDR_E, 2'b0}, 4'h7, 32'hc0000000, ok);
                  PCI_DW_WR({`CPCI_DMA_SIZE_E, 2'b0}, 4'h7, pci_data, ok2);

                  // Start the DMA transfer
                  PCI_DW_WR({`CPCI_DMA_CTRL_E, 2'b0}, 4'h7,
                     (32'h00000f00 & ((pci_addr-1) << 8)) | 32'h00000001, ok3);

                  if (ok !== 1 || ok2 !== 1 || ok3 != 1)
                    $display("%t %m: Error: Problem starting DMA transfer", $time);

	          pci_ptr = pci_ptr + 4;
               end // PCI_DMA

               `PCI_BARRIER: begin
                  $display($time," %m Info: barrier request");

                  // Wait to ensure that all expected packets have been seen
                  // (ensure that interrupts are serviced)
                  @(posedge CLK);
                  #1; //all_exp_pkts_seen = 0;
                  while (!all_exp_pkts_seen) begin
                     wait (all_exp_pkts_seen || ~INTR_A);

                     // Service any interrupts
                     if (~INTR_A)
                        service_interrupt;
                  end
                  barrier_req = 1;

                  // Wait for the barrier proceed signals, but ensure that
                  // interrupts are serviced
                  while (!barrier_proceed) begin
                     wait (barrier_proceed || ~INTR_A);

                     // Service any interrupts
                     if (~INTR_A)
                        service_interrupt;
                  end

                  #1;
                  barrier_req = 0;
                  wait (!barrier_proceed);
                  $display($time," %m Info: barrier complete");
                  for (i = 0; i < `NUM_DMA_PORTS; i = i + 1)
                     dma_rx_pkts[i]=0;

	          pci_ptr = pci_ptr + 1 + `NUM_DMA_PORTS;
               end

               `PCI_DELAY: begin
	          $display("%t %m: Info: delaying %0d ns", $time, delay);
                  activity = 1;
                  delay_end = $time + delay;
                  @(posedge CLK);
                  #1;
                  while (!delay_done) begin
                     wait (delay_done || ~INTR_A);

                     // Service any interrupts
                     if (~INTR_A)
                        service_interrupt;
                  end
                  activity = 0;
	          pci_ptr = pci_ptr + 3;
               end

               default: begin
	          $finish;
               end
            endcase

	 end // while ((pci_ptr < `PCI_SZ) && (pci_cmds[pci_ptr] != 0))

         // Indicate that we are done
         done = 1;

         // Finished processing all PCI simulation data.
         //
         // Sit and process an interrupts
         while (1) begin

            // Wait until an interrupt occurs
            wait (~INTR_A);
            if (~INTR_A)
               service_interrupt;
         end

      end
   endtask // process_PCI_requests



   //=============================================================

   reg [15:0]  expected_dma_ingress_seq_num [3:0];

   reg [31:0]  ingress_rcvd [0:3];  // number received

   reg 	       ingress_dma_done;
   reg 	       egress_dma_done;
   reg         phy_int;
   reg         pkt_avail;
   reg         q_status_change;
   reg         cnet_err;
   reg         cnet_rd_timeout;
   reg         cnet_prog_err;
   reg         dma_xfer_timeout;
   reg         dma_xfer_error;
   reg         dma_fatal_error;



   //=============================================================
   // Service an interrupt
   //=============================================================
   task service_interrupt;
      reg [`PCI_DATA_WIDTH - 1:0]   returned;

      reg [`PCI_DATA_WIDTH - 1:0]   interrupt_mask;

      reg [`PCI_DATA_WIDTH - 1:0]   dma_size;
      reg [`PCI_DATA_WIDTH - 1:0]   dma_ctrl;

      reg [3:0]                     dma_src;

      reg 			    success;
      begin

	 ingress_dma_done  = 0;
	 egress_dma_done   = 0;
         phy_int           = 0;
         pkt_avail         = 0;
         q_status_change   = 0;
         cnet_err          = 0;
         cnet_rd_timeout   = 0;
         cnet_prog_err     = 0;
         dma_xfer_timeout  = 0;
         dma_xfer_error    = 0;
         dma_fatal_error   = 0;

         $display("%t %m: Info: Interrupt signaled", $time);
         host32.PCI_DW_RD({`CPCI_INTERRUPT_STATUS, 2'b0}, 4'h6, returned, success);
         host32.DECODE_INTR(returned);

	 #1;

         // Work out what sort of interrupt we saw
         ingress_dma_done  = returned[31];
         egress_dma_done   = returned[30];
         phy_int           = returned[29];
         pkt_avail         = returned[08];
         q_status_change   = returned[09];
         cnet_err          = returned[05];
         cnet_rd_timeout   = returned[04];
         cnet_prog_err     = returned[03];
         dma_xfer_timeout  = returned[02];
         dma_xfer_error    = returned[01];
         dma_fatal_error   = returned[00];

         #1;

         // Handle queue status changes
         if (q_status_change) begin
            $display("%t %m: DMA queue status change", $time);

            // Read the queue status
            activity = 1;
            PCI_DW_RD({`CPCI_DMA_QUEUE_STATUS, 2'b0}, 4'h6, dma_q_status, success);
            activity = 0;
         end

         // Handle ingress DMA completion
         if (ingress_dma_done) begin
            PCI_DW_RD({`CPCI_DMA_SIZE_I, 2'b0}, 4'h6, dma_size, success);
            PCI_DW_RD({`CPCI_DMA_CTRL_I, 2'b0}, 4'h6, dma_ctrl, success);

            dma_src = dma_ctrl[11:8];

            // Make sure the host is the owner
            if (dma_ctrl[0]) begin
               $display("%t %m: Error: DMA complete yet owner set to NetFPGA", $time);
               $finish;
            end

            $display("%t %m: Info: DMA ingress transfer complete. Size: %d   Source: %d", $time, dma_size, dma_src);

            testbench.target32.handle_egress_packet(dma_src, dma_size);
            dma_in_progress = 0;

            if (dma_src < `NUM_DMA_PORTS)
               dma_rx_pkts[dma_src] = dma_rx_pkts[dma_src] + 1;

            // Re-enable the pkt avail interrupt
            PCI_DW_RD({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h6, interrupt_mask, success);
            interrupt_mask = interrupt_mask & ~(32'h00000100);
            PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, interrupt_mask, success);

            activity = 0;
         end

         // Handle egress DMA completion
         if (egress_dma_done) begin

            // Re-enable the pkt avail interrupt
            PCI_DW_RD({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h6, interrupt_mask, success);
            interrupt_mask = interrupt_mask & ~(32'h00000100);
            PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, interrupt_mask, success);

            $display("%t %m: Info: DMA egress transfer complete.", $time);

            // Clear the DMA in progress flag
            dma_in_progress = 0;
            activity = 0;
         end

         // Handle PHY interrupts
         if (phy_int) begin
            $display("%t %m: Warning: Seen Phy Interrupt. Ignoring...", $time);

            // Mask off the interrupt
            PCI_DW_RD({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h6, interrupt_mask, success);
            interrupt_mask = interrupt_mask | 32'h20000000;
            PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, interrupt_mask, success);
         end

         // Handle packets available
         if (pkt_avail && !dma_in_progress) begin
            $display("%t %m: Packet available. Starting DMA ingress transfer", $time);

            dma_in_progress = 1;
            activity = 1;

            // Begin by masking off the interrupt
            PCI_DW_RD({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h6, interrupt_mask, success);
            interrupt_mask = interrupt_mask | 32'h00000100;
            PCI_DW_WR({`CPCI_INTERRUPT_MASK, 2'b0}, 4'h7, interrupt_mask, success);

            // Set up the write address
            PCI_DW_WR({`CPCI_DMA_ADDR_I, 2'b0}, 4'h7, 32'hc0000000, success);

            // Start the transfer
            PCI_DW_WR({`CPCI_DMA_CTRL_I, 2'b0}, 4'h7, 32'h00000001, success);
         end
         else if (pkt_avail && dma_in_progress) begin
            $display("%t %m: Packet available. Ignoring as DMA transaction already in progress...", $time);
         end

         // Handle CNET read timeouts
         if (cnet_rd_timeout) begin
            $display("%t %m: Warning: Seen CNET Read Timeout Interrupt. Ignoring...", $time);
         end

         // Handle the various errors
         if (cnet_err || cnet_prog_err ||
             dma_xfer_timeout || dma_xfer_error || dma_fatal_error) begin
            $display("%t %m: Error: Interrupt signalled error. Exiting...", $time);
            $finish;
         end

         // Wait a clock cycle to prevent us triggering on the same interrupt
         // again in case we didn't issue any additional reads/writes
         @(posedge CLK);
         #1;
      end
   endtask // do_interrupt_handler


endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
