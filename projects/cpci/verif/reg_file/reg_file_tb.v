///////////////////////////////////////////////////////////////////////////////
// $Id: reg_file_tb.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: reg_file
// Project: CPCI (PCI Control FPGA)
// Description: Tests the reg_file module
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module reg_file_tb ( );

// ==================================================================
// Constants
// ==================================================================

`define CPCI_VERSION_ID   24'h0
`define CPCI_REVISION_ID  8'h0

parameter Tperiod = 15;


   reg pci_reset, clk;

   reg [31:0] pci_addr;
   reg [3:0] pci_be;
   reg [31:0] pci_data;
   reg reg_we;
   wire [31:0] reg_data;

   integer 			    i;



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

reg_file reg_file(
            .pci_addr (pci_addr),//
            .reg_hit (reg_hit),
            .reg_we (reg_we),//
            .pci_be (pci_be),//
            .pci_data (pci_data),//
            .pci_data_vld (pci_data_vld),
            .reg_data (reg_data),//
            .reg_vld (reg_vld),
            .reg_reset (reg_reset),
            .prog_data (prog_data),
            .prog_data_vld (prog_data_vld),
            .prog_reset (prog_reset),
            .intr_req (intr_req),
            .cnet_hit (cnet_hit),
            .cnet_we (cnet_we),
	    .empty (empty),
            .prog_init (prog_init),
            .prog_done (prog_done),
            .cnet_reprog (cnet_reprog),
            .dma_rd_addr (dma_rd_addr),
            .dma_wr_addr (dma_wr_addr),
            .dma_rd_mac (dma_rd_mac),
            .dma_wr_mac (dma_wr_mac),
            .dma_rd_size (dma_rd_size),
            .dma_wr_size (dma_wr_size),
            .dma_rd_owner (dma_rd_owner),
            .dma_wr_owner (dma_wr_owner),
            .dma_rd_done (dma_rd_done),
            .dma_wr_done (dma_wr_done),
            .dma_in_progress (dma_in_progress),
            .dma_time (dma_time),
            .dma_retries (dma_retries),
            .cnet_rd_time (cnet_rd_time),
            .cpci_jmpr (cpci_jmpr),
            .cpci_id (cpci_id),
            .prog_overflow (prog_overflow),
            .prog_error (prog_error),
            .dma_buf_overflow (dma_buf_overflow),
            .dma_rd_size_err (dma_rd_size_err),
            .dma_wr_size_err (dma_wr_size_err),
            .dma_rd_addr_err (dma_rd_addr_err),
            .dma_wr_addr_err (dma_wr_addr_err),
            .dma_rd_mac_err (dma_rd_mac_err),
            .dma_wr_mac_err (dma_wr_mac_err),
            .dma_timeout (dma_timeout),
            .dma_retry_expire (dma_retry_expire),
            .dma_fatal_err (dma_fatal_err),
            .cnet_rd_timeout (cnet_rd_timeout),
            .cnet_err (cnet_err),
            .dma_rd_intr (dma_rd_intr),
            .dma_wr_intr (dma_wr_intr),
            .phy_intr (phy_intr),
            .cpci_dma_pkt_avail (cpci_dma_pkt_avail),
            .cpci_led (cpci_led),
            .try_cnet_reset (try_cnet_reset),
            .host_is_le (host_is_le),
            .pci_reset (pci_reset),
            .clk (clk)//
         );


   task do_read_w_result;
      input [31:0] addr;
      input [31:0] data;

      reg done;
      time terminate_on_error;
      `define MAX_WR_WAIT_TIME 30000

      begin
	 $display($time, " Reading data from address %x", addr);

	 @(negedge clk) begin
	    pci_addr <= addr;
	    reg_we <= 1'b0;
	    pci_be <= 4'b1111;
	    pci_data <= 32'b0;
	 end

	 // Wait for the positive edge of the clock

	 @(posedge clk) begin
            if (data != reg_data) begin
	       $display($time, " ERROR: Read from %x: expected %x, actual %x", addr, data, reg_data);
            end
            else begin
	       $display($time, " Success: Read from %x: %x", addr, reg_data);
            end
	 end

	 // OK, clean up.
	 #1 begin
	    pci_addr = 32'hffff_ffff;
	    reg_we = 'h0;
	    pci_be <= 4'b0000;
	 end
      end
   endtask
/*
   task do_write;
      input [`CPCI_CNET_ADDR_WIDTH-1:0] addr;
      input [`CPCI_CNET_DATA_WIDTH-1:0] data;

      reg done;
      time terminate_on_error;
      `define MAX_WR_WAIT_TIME 30000

      begin
	 $display("%t Writing data %x to address %x", $time, data, addr);

	 @(negedge clk33) begin
	    cpci_addr <= addr;
	    cpci_wr_data <= data;
	    cpci_rd_wr_L <= 0;
	    cpci_bus_req <= 1;
	    done = 0;
	 end

	 // Wait for wr_rdy to be asserted.

	 terminate_on_error = $time + `MAX_WR_WAIT_TIME;

	 while (done == 0) begin
	   @(posedge clk33) done <= cpci_wr_rdy;
	   #1 if ($time > terminate_on_error) begin
	      $display($time,"ERROR: Write cycle didnt terminate within %t", `MAX_WR_WAIT_TIME);
	      done = 1;
	   end
	 end

	 // OK, write was accepted, clean up.
	 #1 begin
	    cpci_addr = 'h0;
	    cpci_wr_data = 'h0;
	    cpci_rd_wr_L = 1;
	    cpci_bus_req = 0;
	 end
      end
   endtask
*/


initial
begin
   pci_addr = 32'hffff_ffff;
   reg_we = 'h0;
   pci_be = 4'b0000;
   pci_data = 'h0;
   clk = 0;
   pci_reset = 1;

   #1000  pci_reset = 0;

   #100 begin end

   do_read_w_result('h0, {`CPCI_REVISION_ID, `CPCI_VERSION_ID} );

   #100 begin end

   #100
   $display($time," finishing...");
   $finish;

end

endmodule // reg_file_tb

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
