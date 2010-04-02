///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: oq_regs_dual_port_ram
// Project: NF2.1
// Description: Small RAM for oq_regs
//
// Stats:
//    - sync read
//    - sync write
//    - read-before-write
//
//
///////////////////////////////////////////////////////////////////////////////

module oq_regs_dual_port_ram
   #(
      parameter REG_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter REG_FILE_ADDR_WIDTH = log2(NUM_OUTPUT_QUEUES)
   )
   (
      input [REG_FILE_ADDR_WIDTH-1:0]     addr_a,
      input                               we_a,
      input [REG_WIDTH-1:0]               din_a,
      output reg [REG_WIDTH-1:0]          dout_a,
      input                               clk_a,

      input [REG_FILE_ADDR_WIDTH-1:0]     addr_b,
      input                               we_b,
      input [REG_WIDTH-1:0]               din_b,
      output reg [REG_WIDTH-1:0]          dout_b,
      input                               clk_b
   );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   // Uncomment the following synthesis attribute to force the memory into
   // Block RAM.
   //
   // Note: The attribute must appear immediately above the RAM register
   // declaraion.
   //
   (* ram_style = "block" *)
   reg [REG_WIDTH-1:0]      ram[0:NUM_OUTPUT_QUEUES-1];

   always @(posedge clk_a) begin
      if (we_a)
         ram[addr_a] <= din_a;

      dout_a <= ram[addr_a];
   end

   always @(posedge clk_b) begin
      if (we_b)
         ram[addr_b] <= din_b;

      dout_b <= ram[addr_b];
   end

endmodule // oq_dual_port_num
