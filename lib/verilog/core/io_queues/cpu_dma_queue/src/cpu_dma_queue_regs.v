///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_regs.v 2265 2007-09-17 22:02:57Z grg $
//
// Module: cpu_dma_queue_regs.v
// Project: NF2.1
// Description: Register module for the CPU DMA queue
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_queue_regs
   #(
      parameter TX_WATCHDOG_TIMEOUT = 125000
   )
   (
      // Interface to "main" module
      input                                  tx_timeout,

      // Register interface
      input                                  reg_req,
      input                                  reg_rd_wr_L,
      input  [`MAC_GRP_REG_ADDR_WIDTH-1:0]   reg_addr,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_wr_data,

      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_rd_data,
      output reg                             reg_ack,

      // --- Misc
      input                                  reset,
      input                                  clk
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

   // -------- Internal parameters --------------

   localparam NUM_REGS_USED         = 'h2; /* don't forget to update this when adding regs */
   localparam REG_FILE_ADDR_WIDTH   = log2(NUM_REGS_USED);


   // ------------- Wires/reg ------------------

   wire [REG_FILE_ADDR_WIDTH-1:0]      addr;

   wire                                addr_good;

   wire                                new_reg_req;
   reg                                 reg_req_d1;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_rd_data_nxt;

   reg [31:0]                          tx_timeout_cnt;



   // ---------- Logic ----------

   assign addr = reg_addr[REG_FILE_ADDR_WIDTH-1:0];
   assign addr_good = reg_addr[`CPU_QUEUE_REG_ADDR_WIDTH-1:REG_FILE_ADDR_WIDTH] == 'h0 &&
      addr < NUM_REGS_USED;

   assign new_reg_req = reg_req && !reg_req_d1;


   // Update the tx timeout counter
   always @(posedge clk) begin
      if (reset) begin
         tx_timeout_cnt <= 'h0;
      end
      else begin
         if (tx_timeout)
            tx_timeout_cnt <= tx_timeout_cnt + 'h1;
      end
   end


   // Work out the data to return from a register request
   always @*
   begin
      case (addr)
         'h0:     reg_rd_data_nxt = tx_timeout_cnt;
         default: reg_rd_data_nxt = 'h dead_beef;
      endcase
   end


   // Handle register requests
   always @(posedge clk) begin
      reg_req_d1 <= reg_req;

      if( reset ) begin
         reg_rd_data  <= 0;
         reg_ack      <= 0;
      end
      else begin
         // Register access logic
         if(new_reg_req) begin // read request
            if(addr_good) begin
               reg_rd_data <= reg_rd_data_nxt;
            end
            else begin
               reg_rd_data <= 32'hdead_beef;
            end
         end

         // requests complete after one cycle
         reg_ack <= new_reg_req;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // cpu_dma_queue_regs
