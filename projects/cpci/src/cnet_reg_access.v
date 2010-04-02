///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reg_access.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: cnet_reg_access.v
// Project: CPCI (PCI Control FPGA)
// Description: Register interface to the CNET - both the CNET and SRAM are
//              accessed via this module. (SRAM access is via the CNET.)
//
// Note: Don't need to worry about read timeouts here. The cnet_reg_iface
// module will ALWAYS return a value, even on timeout.
//
// Reading from an address different from that which is currently available
// will result in a retry.
//
// Change history:
//    9/23/04 - Added timer to time-out reads (moved to cnet_reg_iface)
//    9/23/04 - Implemented logic to detect when a read arrives for an address
//              different to the address we are currently waiting for
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

//`include "defines.v"

module cnet_reg_access(
            // PCI Signals
            input [`PCI_ADDR_WIDTH-1:0] pci_addr,      // PCI Address
            input [`PCI_BE_WIDTH-1:0]   pci_be,        // Byte Enable
            input [`PCI_DATA_WIDTH-1:0] pci_data,      // Data being written from the PCI interface
            input          pci_data_vld,  // Data on pci_data is valid

            input          cnet_we,       // Write Enable
            input          cnet_hit,      // Is the CNET the target of the transaction

            output reg [`PCI_DATA_WIDTH-1:0]  cnet_data, // Data being read by the PCI interface
            output         cnet_vld,      // Data on the cnet_data bus is valid

            output         cnet_retry,    // Force a retry

            // CNET interface signals
            // CPCI->CNET
            output reg [`CPCI_CNET_DATA_WIDTH-1:0]  p2n_data,  // Data going from the CPCI to the CNET
            output reg [`CPCI_CNET_ADDR_WIDTH-1:0]  p2n_addr,  // Data going from the CPCI to the CNET
            output reg     p2n_we,        // Write enable signal
            output reg     p2n_req,       // Read/Write request signal

            input          p2n_full,      // Full signal for FIFO from CPCI to CNET
            // Don't need to worry about the almost full signal as we are
            // never doing burst register reads/writes.
            //input          p2n_almost_full,  // Almost full signal

            // CNET->CPCI
            input [`CPCI_CNET_DATA_WIDTH-1:0]   n2p_data,      // Data going from the CPCI to the CNET
            input          n2p_rd_rdy,    // Read enable signal

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

reg [`PCI_DATA_WIDTH-1:0] cnet_data_nxt;

reg [`CPCI_CNET_DATA_WIDTH-1:0] p2n_data_nxt;
reg [`CPCI_CNET_ADDR_WIDTH-1:0] p2n_addr_nxt;
reg p2n_req_nxt;
reg p2n_we_nxt;

// Track whether a CNET transaction has just completed
wire cnet_trans_done;
wire cnet_trans_start;
reg cnet_hit_d1;

// Remember which address is being read - to avoid returning the wrong
// result if some how the next request is NOT for the address we have
// the result for
reg [`CPCI_CNET_ADDR_WIDTH-1:0] rd_addr, rd_addr_nxt;


// ==================================================================
// Main state machine
// ==================================================================

/* The state machine has the following states:
 *   CR_Idle         - When either idling or doing a write to the CNET
 *   CR_Wait_CNET    - Waiting for the CNET to return the result
 *   CR_Wait_PCI     - Waiting for the next PCI transaction to fetch the
 *                     result
 *   CR_Read_Result  - Read result is being returned
 */

reg [1:0]   rd_state, rd_state_nxt;

`define CR_Idle         2'h0
`define CR_Wait_CNET    2'h1
`define CR_Wait_PCI     2'h2
`define CR_Read_Result  2'h3

always @(posedge clk)
begin
   rd_state <= rd_state_nxt;
   p2n_data <= p2n_data_nxt;
   p2n_addr <= p2n_addr_nxt;
   p2n_req <= p2n_req_nxt;
   p2n_we <= p2n_we_nxt;
   rd_addr <= rd_addr_nxt;
end

always @*
begin
   // Set defaults
   rd_state_nxt = rd_state;
   p2n_data_nxt = 'h0;
   p2n_addr_nxt = 'h0;
   p2n_req_nxt = 1'b0;
   p2n_we_nxt = 1'b0;
   rd_addr_nxt = rd_addr;

   // On either reset or the CNET being reprogrammed, go to the idle state
   if (reset || cnet_reprog) begin
      rd_state_nxt = `CR_Idle;
      rd_addr_nxt = 'h0;
   end
   else
      case (rd_state)
         `CR_Idle : begin
            // Only do something if there has been a hit on the CNET
            // address range and there is space in the buffer to the
            // CNET device.
            //
            // Note: Don't care about p2n_almost_full as there are no
            // back to back writes from this module
            if (cnet_hit && !p2n_full) begin

               // The data on the pci_data bus must be valid
               // or it must be the first cycle of a read
               if (pci_data_vld || (!cnet_we && cnet_trans_start)) begin
                  // Update the address and data signals
                  p2n_data_nxt = pci_data;
                  p2n_addr_nxt = pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0];
                  p2n_req_nxt = 1'b1;
                  p2n_we_nxt = cnet_we;

                  if (!cnet_we) begin
                     rd_state_nxt = `CR_Wait_CNET;
                     rd_addr_nxt = pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0];
                  end
               end
            end
         end

         `CR_Wait_CNET : begin
            // Wait for the response
            if (n2p_rd_rdy)
               rd_state_nxt = `CR_Wait_PCI;
         end

         `CR_Wait_PCI : begin
            // Wait for the next read transaction
            if (cnet_trans_start && !cnet_we)
               rd_state_nxt = `CR_Read_Result;
         end

         `CR_Read_Result : begin
            // Transition back to idle when the transaction finishes
            if (cnet_trans_done)
               rd_state_nxt = `CR_Idle;
         end

         default : begin
            rd_state_nxt = `CR_Idle;
         end
      endcase
end

// ==================================================================
// Latch the data coming back from n2p_data into cnet_data
// ==================================================================

always @(posedge clk)
begin
   cnet_data <= cnet_data_nxt;
end

always @*
begin
   // Default to previous value
   cnet_data_nxt = cnet_data;

   if (reset)
      cnet_data_nxt = 'h0;
   // Latch the result when waiting and the signal is ready
   else if (rd_state == `CR_Wait_CNET && n2p_rd_rdy)
      cnet_data_nxt = n2p_data;
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

// Generate a retry if the device is not being reprogrammed and either:
// - the current transaction is a read and the state machine is still waiting
//   for the result to be returned from the CNET.
// - the FIFO is full (although this really shouldn't occur)
assign cnet_retry = !cnet_reprog && cnet_hit &&
                    (!cnet_we && rd_state != `CR_Wait_PCI) ||
                    (rd_state != `CR_Idle && rd_addr != pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0]) ||
                    (rd_state != `CR_Wait_PCI && p2n_full);

// Generate the CNET Transaction Start and Done signals
always @(posedge clk)
   cnet_hit_d1 <= cnet_hit;

assign cnet_trans_start = ~cnet_hit_d1 & cnet_hit;
assign cnet_trans_done = cnet_hit_d1 & ~cnet_hit;

// Generate the cnet_vld signal
assign cnet_vld = (rd_state == `CR_Wait_PCI && cnet_trans_start ||
                   rd_state == `CR_Read_Result) &&
                  rd_addr == pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0];

// synthesis translate_off
always @*
begin
   if (rd_state != `CR_Idle && cnet_hit && !cnet_reprog && rd_addr != pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0])
      $display($time, " Warning: Requested access to CNET register %x while there is an outstanding request to %x", pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0], rd_addr);
   if (rd_state != `CR_Idle && cnet_hit && cnet_we)
      $display($time, " Warning: Write request to CNET register %x during outstanding read request to %x", pci_addr[`CPCI_CNET_ADDR_WIDTH-1:0], rd_addr);
end
// synthesis translate_on

endmodule // cnet_reg_access

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
