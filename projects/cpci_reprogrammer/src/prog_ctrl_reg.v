///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: prog_ctrl_reg.v 1912 2007-07-10 22:34:11Z grg $
//
// Module: prog_ctrl_reg.v
// Project: NetFPGA
// Description: Reprogramming control registers
//
///////////////////////////////////////////////////////////////////////////////

module prog_ctrl_reg
   #(
      parameter REG_ADDR_WIDTH = 5
   )
   (
      // Register interface signals
      input                                     reg_req,
      output reg                                reg_ack,
      input                                     reg_rd_wr_L,

      input [REG_ADDR_WIDTH - 1:0]              reg_addr,

      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]    reg_rd_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]         reg_wr_data,

      // Reprogram control signals
      output reg                                start,
      output reg                                disable_reset,
      output reg                                prog_ram_sel,

      //
      input             clk,
      input             reset
   );


localparam CTRL_reg     = 'd0;

reg req_acked;


// ==============================================
// Main state machine

initial
begin
   disable_reset <= 1'b0;
   prog_ram_sel <= 1'b0;
end

always @(posedge clk)
begin
   if (reset) begin
      reg_ack <= 1'b0;
      reg_rd_data <= 'h0;

      req_acked <= 1'b0;

      start <= 1'b0;
      disable_reset <= 1'b0;
      prog_ram_sel <= 1'b0;
   end
   else begin
      if (reg_req) begin
         // Only process the request if it's new
         if (!req_acked) begin
            reg_ack <= 1'b1;
            req_acked <= 1'b1;

            case (reg_addr)
               CTRL_reg : begin
                  reg_rd_data <= 'h0;

                  // Handle the write if appropriate
                  if (!reg_rd_wr_L) begin
                     start <= reg_wr_data[0];
                     prog_ram_sel <= reg_wr_data[0];
                     disable_reset <= reg_wr_data[8];
                  end
               end

               default : begin
                  reg_rd_data <= 'h dead_beef;
               end
            endcase
         end
         else begin
            reg_ack <= 1'b0;
            start <= 1'b0;
         end
      end // if (reg_req)
      else begin
         reg_ack <= 1'b0;
         req_acked <= 1'b0;

         start <= 1'b0;
      end // if (reg_req) else
   end
end

endmodule // prog_ctrl_reg
