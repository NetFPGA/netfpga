///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: prog_ram.v 1912 2007-07-10 22:34:11Z grg $
//
// Module: prog_ram.v
// Project: NetFPGA
// Description: Block ram instantiation for the programming memory
//
// Note: 1-cycle delay between address in and data out
//
///////////////////////////////////////////////////////////////////////////////

module prog_ram (
      input [15:0] addr,

      input [`CPCI_NF2_DATA_WIDTH - 1:0] wr_data,
      input wr_en,

      output [`CPCI_NF2_DATA_WIDTH - 1:0] rd_data,

      input clk,
      input reset
   );

localparam NUM_BANKS = 3;


wire [`CPCI_NF2_DATA_WIDTH - 1:0] dout [0:2];
wire en[0:2];
wire we[0:2];

reg [1:0] bank_sel;

generate
   genvar i;
   genvar j;
   for (i=0; i < NUM_BANKS; i = i + 1) begin: bank
      for (j=0; j < `CPCI_NF2_DATA_WIDTH; j = j + 1) begin: bits
         RAMB16_S1 RAMB16_S1_inst (
            .ADDR    (addr[13:0]), // 14-bit Address Input
            .EN      (en[i]), // RAM Enable Input
            .WE      (we[i]), // Write Enable Input

            .DI      (wr_data[j]), // 1-bit Data Input
            .DO      (dout[i][j]), // 1-bit Data Output

            .CLK     (clk), // Clock
            .SSR     (reset) // Synchronous Set/Reset Input
         );
      end // bits

      assign en[i] = addr[15:14] == i;
      assign we[i] = addr[15:14] == i && wr_en;
   end // bank

endgenerate

// Register the bank and output the read data
always @(posedge clk)
begin
   bank_sel <= addr[15:14];
end

/*always @*
begin
   if (bank_sel < NUM_BANKS)
      rd_data <= dout[bank_sel];
   else
      rd_data <= 'h0;
end*/

assign rd_data = (bank_sel < NUM_BANKS) ? dout[bank_sel] : 'h0;

endmodule // prog_ram


