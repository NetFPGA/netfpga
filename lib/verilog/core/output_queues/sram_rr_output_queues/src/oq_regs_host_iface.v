///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_regs_host_iface.v 5424 2009-05-01 00:17:23Z grg $
//
// Module: oq_regs_host_iface.v
// Project: NF2.1
// Description: Handles the host interface accesses (ie. accesses from the
// host CPU). Most of the work is actually off-loaded to oq_regs_host_ctrl.
// This module provides the basic logic for interfacing to the register bus.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module oq_regs_host_iface
   #(
      parameter SRAM_ADDR_WIDTH     = 19,
      parameter CTRL_WIDTH          = 8,
      parameter UDP_REG_SRC_WIDTH   = 2,
      parameter NUM_OUTPUT_QUEUES   = 8,
      parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
      parameter NUM_REGS_USED       = 17,
      parameter ADDR_WIDTH          = log2(NUM_REGS_USED)
   )

   (
      // --- interface to udp_reg_grp
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output reg                             reg_req_out,
      output reg                             reg_ack_out,
      output reg                             reg_rd_wr_L_out,
      output reg [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output reg [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // --- interface to oq_regs_process_sm
      output reg                             req_in_progress,
      output reg                             reg_rd_wr_L_held,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_held,

      output [ADDR_WIDTH-1:0]                addr,
      output [NUM_OQ_WIDTH-1:0]              q_addr,

      input                                  result_ready,
      input [`CPCI_NF2_DATA_WIDTH-1:0]       reg_result,

      // --- Misc
      input                                  clk,
      input                                  reset
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


   // ------------- Wires/reg ------------------

   // Register hit/processing signals
   wire [`OQ_QUEUE_INST_REG_ADDR_WIDTH - 1:0] local_reg_addr;   // Register number
   wire [`OQ_REG_ADDR_WIDTH -
         `OQ_QUEUE_INST_REG_ADDR_WIDTH - 1:0] local_q_addr;     // Queue address/number
   wire [`UDP_REG_ADDR_WIDTH -
         `OQ_REG_ADDR_WIDTH - 1:0]     tag_addr;

   wire                                addr_good;
   wire                                tag_hit;

   reg                                 reg_req_held;
   reg [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_held;
   reg [UDP_REG_SRC_WIDTH-1:0]         reg_src_held;



   // -------------- Logic ----------------------

   assign local_reg_addr = reg_addr_in[`OQ_QUEUE_INST_REG_ADDR_WIDTH-1:0];
   assign local_q_addr = reg_addr_in[`OQ_REG_ADDR_WIDTH - 1:`OQ_QUEUE_INST_REG_ADDR_WIDTH];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`OQ_REG_ADDR_WIDTH];

   assign addr_good = (local_reg_addr<NUM_REGS_USED) && (local_q_addr < NUM_OUTPUT_QUEUES);
   assign tag_hit = tag_addr == `OQ_BLOCK_ADDR;

   assign addr = reg_addr_held[ADDR_WIDTH-1:0];
   assign q_addr = reg_addr_held[`OQ_QUEUE_INST_REG_ADDR_WIDTH + NUM_OQ_WIDTH - 1:`OQ_QUEUE_INST_REG_ADDR_WIDTH];


   // Handle register accesses
   always @(posedge clk) begin
      if (reset) begin
         reg_req_out <= 1'b0;
         reg_ack_out <= 1'b0;
         reg_rd_wr_L_out <= 'h0;
         reg_addr_out <= 'h0;
         reg_src_out <= 'h0;

         reg_req_held <= 1'b0;
         reg_rd_wr_L_held <= 'h0;
         reg_addr_held <= 'h0;
         reg_data_held <= 'h0;
         reg_src_held <= 'h0;

         req_in_progress <= 1'b0;
      end
      else begin
         if (req_in_progress) begin
            if (result_ready) begin
               req_in_progress <= 1'b0;

               reg_req_out <= reg_req_held;
               reg_ack_out <= reg_req_held;
               reg_rd_wr_L_out <= reg_rd_wr_L_held;
               reg_addr_out <= reg_addr_held;
               reg_data_out <= reg_result;
               reg_src_out <= reg_src_held;
            end
         end
         else if (reg_req_in && tag_hit && addr_good) begin
            req_in_progress <= 1'b1;

            reg_req_held <= reg_req_in;
            reg_rd_wr_L_held <= reg_rd_wr_L_in;
            reg_addr_held <= reg_addr_in;
            reg_data_held <= reg_data_in;
            reg_src_held <= reg_src_in;

            reg_req_out <= 1'b0;
            reg_ack_out <= 1'b0;
            reg_rd_wr_L_out <= 'h0;
            reg_addr_out <= 'h0;
            reg_data_out <= 'h0;
            reg_src_out <= 'h0;
         end
         else begin
            reg_req_out <= reg_req_in;
            reg_ack_out <= reg_ack_in || reg_req_in && tag_hit;
            reg_rd_wr_L_out <= reg_rd_wr_L_in;
            reg_addr_out <= reg_addr_in;
            reg_data_out <= (reg_req_in && tag_hit) ? 32'h dead_beef : reg_data_in;
            reg_src_out <= reg_src_in;
         end
      end
   end

endmodule // oq_regs_host_iface
