//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: reg_file_test.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: reg_file_test.v
// Project: NetFPGA
// Description: Implements a simple register file for test purposes
//
///////////////////////////////////////////////////////////////////////////////

module reg_file_test
   (
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [`REG_FILE_REG_ADDR_WIDTH - 1:0]    reg_addr,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        reg_wr_data,

      output reg                                reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]   reg_rd_data,

      input                                     clk,
      input                                     reset
   );

   // ------ Local parameters ------
   localparam NUM_REGS = 64;
   localparam ADDR_WIDTH = 6;


   // ------ Local signals ------

   // Register bank
   reg [`CPCI_NF2_DATA_WIDTH -1:0] registers [0 :  NUM_REGS-1];

   reg reg_acked;
   wire [ADDR_WIDTH -1:0] addr;


   // ------ Logic ------
   assign addr = reg_addr[ADDR_WIDTH - 1 : 0];

   always @(posedge clk) begin
      if (reset) begin
         reg_ack  <= 1'b0;
         reg_acked <= 1'b0;
      end
      else begin
         if (reg_req) begin
            if (!reg_acked) begin
               reg_ack <= 1'b1;
               reg_acked <= 1'b1;

               // Perform the write
               if (reg_rd_wr_L == 1'b0) begin
                  registers[addr] <= reg_wr_data;
               end
            end
            else begin
               reg_ack <= 1'b0;
            end
         end
         else begin
            reg_ack <= 1'b0;
            reg_acked <= 1'b0;
         end
      end
      reg_rd_data <= registers[reg_addr[ADDR_WIDTH - 1 : 0]];
   end

endmodule // reg_file_test
