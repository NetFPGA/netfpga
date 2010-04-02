///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: rate_limiter_regs.v 5606 2009-05-29 18:54:40Z g9coving $
//
// Module: rate_limiter_regs.v
// Project: rate limiter
// Description: Demultiplexes, stores and serves register requests
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module rate_limiter_regs
  #(
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter RATE_LIMIT_BLOCK_TAG = `RATE_LIMIT_0_BLOCK_ADDR
   )
   (
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


      output [3:0]                           thruput_shift,
      output                                 enable_rate_limit,

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

   // ------------- Internal parameters --------------
   parameter NUM_REGS_USED = 2; /* don't forget to update this when adding regs */
   parameter ADDR_WIDTH = log2(NUM_REGS_USED);

   // ------------- Wires/reg ------------------

   reg [`CPCI_NF2_DATA_WIDTH-1:0]       reg_file [0:NUM_REGS_USED-1];

   wire [ADDR_WIDTH-1:0]                              addr;
   wire [`RATE_LIMIT_REG_ADDR_WIDTH - 1:0]            reg_addr;
   wire [`UDP_REG_ADDR_WIDTH-`RATE_LIMIT_REG_ADDR_WIDTH - 1:0] tag_addr;

   wire                                               addr_good;
   wire                                               tag_hit;

   // -------------- Logic --------------------

   assign enable_rate_limit = reg_file[`RATE_LIMIT_ENABLE];
   assign thruput_shift = reg_file[`RATE_LIMIT_SHIFT];

   assign addr = reg_addr_in[ADDR_WIDTH-1:0];
   assign reg_addr = reg_addr_in[`RATE_LIMIT_REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`RATE_LIMIT_REG_ADDR_WIDTH];

   assign addr_good = (reg_addr<NUM_REGS_USED);
   assign tag_hit = tag_addr == RATE_LIMIT_BLOCK_TAG;

   always @(posedge clk) begin
      // Never modify the address/src
      reg_rd_wr_L_out <= reg_rd_wr_L_in;
      reg_addr_out <= reg_addr_in;
      reg_src_out <= reg_src_in;

      if( reset ) begin
         reg_req_out                     <= 1'b0;
         reg_ack_out                     <= 1'b0;
         reg_data_out                    <= 'h0;

         reg_file[`RATE_LIMIT_ENABLE]    <= 0;
         reg_file[`RATE_LIMIT_SHIFT]     <= 0;

      end
      else begin
         if(reg_req_in && tag_hit) begin
            if(addr_good) begin
               reg_data_out <= reg_file[addr];

               if (!reg_rd_wr_L_in)
                  reg_file[addr] <= reg_data_in;
            end
            else begin
               reg_data_out <= 32'hdead_beef;
            end

            // requests complete after one cycle
            reg_ack_out <= 1'b1;
         end
         else begin
            reg_ack_out <= reg_ack_in;
            reg_data_out <= reg_data_in;
         end
         reg_req_out <= reg_req_in;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // rate_lim_regs


