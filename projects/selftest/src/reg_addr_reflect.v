///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: reg_addr_reflect.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: reg_addr_reflect.v
// Project: NetFPGA
// Description: Reflects the address back as the read data
//
///////////////////////////////////////////////////////////////////////////////

module reg_addr_reflect
   (
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [`REG_REFLECT_TEST_REG_ADDR_WIDTH - 1:0] reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0]         reg_wr_data,

      output reg                                reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0]    reg_rd_data,

      input                                     clk,
      input                                     reset
   );

   always @(posedge clk)
   begin
      reg_ack <= reg_req && !reg_ack;
      reg_rd_data = reg_addr;
   end

endmodule // reg_addr_reflect

