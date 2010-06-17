///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: cpu_dma_queue_no_regs.v
// Project: NF2.1
// Description: Register module for the CPU DMA queue
//
// This module is a replacement of 'dma_queue_regs' module.
// It is based on dma_queue_regs.v file and the interface has
// a compatibility with the base module.
// This module contains only the tx_queue/rx_queue enable register.
// You should use this module only when you really want to reduce
// FPGA resource usage.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_queue_no_regs
   (
      // Register interface
      input                                  reg_req,
      input                                  reg_rd_wr_L,
      input  [`CPU_QUEUE_REG_ADDR_WIDTH-1:0] reg_addr,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_wr_data,

      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_rd_data,
      output reg                             reg_ack,

      // interface to rx queue
      output                                 rx_queue_en,
      input                                  rx_pkt_stored,
      input                                  rx_pkt_removed,
      input                                  rx_pkt_dropped,
      input                                  rx_q_overrun,
      input                                  rx_q_underrun,
      input  [11:0]                          rx_pkt_byte_cnt,
      input  [9:0]                           rx_pkt_word_cnt,


      // interface to tx queue
      output                                 tx_queue_en,
      input                                  tx_pkt_stored,
      input                                  tx_pkt_removed,
      input                                  tx_q_overrun,
      input                                  tx_q_underrun,
      input [11:0]                           tx_pkt_byte_cnt,
      input [9:0]                            tx_pkt_word_cnt,

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

   localparam NUM_REGS_USED         = 2; /* don't forget to update this when adding regs */
   localparam REG_FILE_ADDR_WIDTH   = log2(NUM_REGS_USED);

   // ------------- Wires/reg ------------------

   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg_nxt;

   wire [REG_FILE_ADDR_WIDTH-1:0]      addr;
   wire                                addr_good;

   reg [3:0]                           reset_long;

   reg                                 reg_req_d1;

   wire                                new_reg_req;

   // -------------- Logic --------------------

   /* extend the reset */
   always @(posedge clk) begin
      reset_long <= {reset_long[2:0], reset};
   end

   assign rx_queue_en         = !control_reg[`CPU_QUEUE_CONTROL_RX_QUEUE_DISABLE_POS];
   assign tx_queue_en         = !control_reg[`CPU_QUEUE_CONTROL_TX_QUEUE_DISABLE_POS];

   assign addr                = reg_addr[REG_FILE_ADDR_WIDTH-1:0];
   assign addr_good           = reg_addr[`CPU_QUEUE_REG_ADDR_WIDTH-1:REG_FILE_ADDR_WIDTH] == 'h0 &&
                                          addr < NUM_REGS_USED;

   assign new_reg_req         = reg_req && !reg_req_d1;

   always @*
   begin
      // Set the defaults
      control_reg_nxt = control_reg;

      if (reset) begin
         control_reg_nxt = 'h0;
      end
      else begin
         if((new_reg_req) && (addr == `CPU_QUEUE_CONTROL) && (!reg_rd_wr_L)) begin
            control_reg_nxt = reg_wr_data;
         end
      end
   end

   always @(posedge clk) begin
      reg_req_d1  <= reg_req;
      control_reg <= control_reg_nxt;

      if( reset ) begin
         reg_rd_data  <= 0;
         reg_ack      <= 0;
      end
      else begin
         // Register access logic
         if(new_reg_req) begin // read request
            if((addr_good) && (addr == `CPU_QUEUE_CONTROL)) begin
               reg_rd_data <= control_reg;
            end
            else begin
               reg_rd_data <= 32'hdead_beef;
            end
         end

         // requests complete after one cycle
         reg_ack <= new_reg_req;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // cpu_dma_queue_no_regs
