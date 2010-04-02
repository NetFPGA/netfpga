///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: prog_ram_reg.v 1912 2007-07-10 22:34:11Z grg $
//
// Module: prog_ram_reg.v
// Project: NetFPGA
// Description: Reprogramming RAM access registers
//
// Allows reading/writing to ram via registers
//
///////////////////////////////////////////////////////////////////////////////

module prog_ram_reg #(
      parameter RAM_ADDR_BITS   = 'd16
   )
   (
      // Register interface signals
      input                                     reg_req,
      output reg                                reg_ack,
      input                                     reg_rd_wr_L,

      input [(`CORE_REG_ADDR_WIDTH - 2 - 4) - 1:0] reg_addr,

      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]   reg_rd_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        reg_wr_data,

      // RAM access signals
      output reg [RAM_ADDR_BITS - 1:0]          ram_addr,
      output reg                                ram_we,
      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]   ram_wr_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        ram_rd_data,

      //
      input             clk,
      input             reset
   );


localparam RAM_TURNAROUND  = 'd1;
localparam RAM_MAX = 1 << RAM_ADDR_BITS;

reg req_acked;
reg req_active;
reg [1:0] count;


// ==============================================
// Main state machine

always @(posedge clk)
begin
   if (reset) begin
      reg_ack <= 1'b0;
      reg_rd_data <= 'h 0;

      req_acked <= 1'b0;
      req_active <= 1'b0;

      ram_addr <= 'h0;
      ram_we <= 1'b0;
      ram_wr_data <= 'h0;
   end
   else begin
      if (reg_req) begin
         // Only process the request if it's new
         if (!req_active) begin
            req_active <= 1'b1;

            // Verify that the address actually corresponds to the RAM
            //if (reg_addr < ('d2 << RAM_ADDR_BITS)) begin
            if (reg_addr < RAM_MAX) begin
               ram_addr <= reg_addr[RAM_ADDR_BITS - 1 : 0];
               ram_we <= ~reg_rd_wr_L;
               ram_wr_data <= reg_wr_data;

               count <= RAM_TURNAROUND;

               reg_ack <= ~reg_rd_wr_L;
               req_acked <= ~reg_rd_wr_L;
            end
            else begin
               reg_ack <= 1'b1;
               req_acked <= 1'b1;

               reg_rd_data <= 'h dead_beef;
            end
         end
         else begin
            if (count != 'h0) begin
               count <= count - 'h1;
               reg_ack <= 1'b0;
            end
            else if (!req_acked) begin
               reg_ack <= 1'b1;
               req_acked <= 1'b1;

               reg_rd_data <= ram_rd_data;
            end
            else begin
               reg_ack <= 1'b0;
            end

            ram_we <= 1'b0;
         end
      end // if (reg_req)
      else begin
         reg_ack <= 1'b0;
         req_acked <= 1'b0;
         req_active <= 1'b0;

         ram_we <= 1'b0;
      end // if (reg_req) else
   end
end

endmodule // prog_ram_reg
