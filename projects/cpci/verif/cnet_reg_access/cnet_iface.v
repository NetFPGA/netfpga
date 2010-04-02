///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_iface.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: cnet_iface.v
// Project: CPCI (PCI Control FPGA)
// Description: Emulates the interface to the CNET as seen from the
//              cnet_reg_access module.
//              Note: doesn't empty the buffer during operation
//
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////


module cnet_iface(

            // CNET interface signals
            // CPCI->CNET
            input [31:0]   p2n_data,      // Data going from the CPCI to the CNET
            input [31:0]   p2n_addr,      // Data going from the CPCI to the CNET
            input          p2n_we,        // Write enable signal
            input          p2n_req,       // Read/Write request signal

            output         p2n_full,      // Full signal for FIFO from CPCI to CNET

            // CNET->CPCI
            output reg [31:0] n2p_data,   // Data going from the CPCI to the CNET
            output reg     n2p_rd_rdy,    // Read enable signal

            input [3:0] buf_size,         // How deep should the buffer be?


            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

reg [3:0] curr_count, curr_count_nxt;

reg [31:0] n2p_data_nxt;
reg n2p_rd_rdy_nxt;

reg [31:0] addr;


// ==================================================================
// Increment the depth when a request is made
//
// Simulate the buffer filling up
// ==================================================================

always @(posedge clk)
begin
   curr_count <= curr_count_nxt;
   if (curr_count != curr_count_nxt)
      $display($time, " CNET Interface: Currently %d entries", curr_count_nxt);
end

always @*
begin
   curr_count_nxt = curr_count;

   if (reset)
      curr_count_nxt = 'h0;
   else if (p2n_req && curr_count != buf_size)
      curr_count_nxt = curr_count + 1;
end

// ==================================================================
// Simulate a read
// ==================================================================

integer i;

always @(posedge clk)
begin
   if (reset) begin
      n2p_data = 'h0;
      n2p_rd_rdy = 1'b0;
   end
   // Check that a request can be made
   else if (p2n_req && curr_count != buf_size)
   begin

      // Check if it is a read
      if (!p2n_we)
      begin
         // Latch the address
         addr = p2n_addr;

         // Wait 20 clocks
         i = 0;
         while (i < 20)
            @(posedge clk) i = i + 1;

         // Return a result
         #1;
         n2p_data = addr;
         n2p_rd_rdy = 1'b1;
         @(posedge clk) begin
            n2p_data = 'h0;
            n2p_rd_rdy = 1'b0;
         end
      end
   end
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

assign #1 p2n_full = curr_count == buf_size;

endmodule // cnet_iface

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
