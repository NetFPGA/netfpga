///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: generic_sw_regs.v
// Project: NF2.1
// Author: Jad Naous
// Description: Implements a generic register block that is written by the
//              CPU and read by the hardware.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module generic_sw_regs
   #(
      parameter UDP_REG_SRC_WIDTH     = 2,                       // identifies which module started this request
      parameter TAG                   = 0,                       // Tag to match against
      parameter REG_ADDR_WIDTH        = 5,                       // Width of block addresses
      parameter NUM_REGS_USED         = 8,                       // How many sw regs
      parameter REG_START_ADDR        = 0,                       // First address

      // Don't modify the parameters below. They are used to calculate the
      // widths of the various register inputs/outputs.
      parameter REG_END_ADDR = REG_START_ADDR + NUM_REGS_USED,   // address of last register + 1
      parameter INPUT_START  = REG_START_ADDR * `CPCI_NF2_DATA_WIDTH,    // first bit of the input vector
      parameter INPUT_END    = REG_END_ADDR * `CPCI_NF2_DATA_WIDTH       // bit after last bit of the input vector
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

      // --- SW regs interface
      output [INPUT_END - 1 : INPUT_START]   software_regs, // signals from the software

      input                                clk,
      input                                reset
    );

   `LOG2_FUNC
   `CEILDIV_FUNC

   // ------------- Internal parameters --------------

   // ------------- Wires/reg ------------------

   wire [REG_ADDR_WIDTH-1:0]              addr;
   wire [`UDP_REG_ADDR_WIDTH-REG_ADDR_WIDTH-1:0] tag_addr;

   wire                                   addr_good;
   wire                                   tag_hit;

   reg [`CPCI_NF2_DATA_WIDTH-1:0]         reg_file[REG_START_ADDR:REG_END_ADDR - 1];

   integer                                ii;

   // -------------- Logic --------------------
   assign addr = reg_addr_in;
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:REG_ADDR_WIDTH];

   assign addr_good = addr < REG_END_ADDR && addr >= REG_START_ADDR;
   assign tag_hit = tag_addr == TAG;

   generate
   genvar i;
   for (i=REG_START_ADDR; i<REG_END_ADDR; i=i+1) begin:reg_file_assigns
      assign software_regs[`CPCI_NF2_DATA_WIDTH*(i+1)-1:`CPCI_NF2_DATA_WIDTH*i]
                                       = reg_file[i];
   end
   endgenerate

   always @(posedge clk) begin
      if(reset) begin
         for(ii=REG_START_ADDR; ii<REG_END_ADDR; ii=ii+1) begin
            reg_file[ii] <= 0;
         end
         reg_req_out        <= 0;
         reg_ack_out        <= 0;
         reg_rd_wr_L_out    <= 0;
         reg_addr_out       <= 0;
         reg_src_out        <= 0;
         reg_data_out       <= 0;
      end
      else begin
         /* check if we should respond to this address */
         if(addr_good && tag_hit && reg_req_in) begin
            reg_req_out        <= reg_req_in;
            reg_ack_out        <= 1'b1;
            reg_rd_wr_L_out    <= reg_rd_wr_L_in;
            reg_addr_out       <= reg_addr_in;
            reg_src_out        <= reg_src_in;
            /* if read */
            if(reg_rd_wr_L_in) begin
               reg_data_out       <= reg_file[addr];
            end
            /* if write */
            else begin
               reg_data_out       <= reg_data_in;
               reg_file[addr]     <= reg_data_in;
            end
         end // if (addr_good && tag_hit && reg_req_in && !reg_ack_in)
         else begin
            reg_req_out        <= reg_req_in;
            reg_ack_out        <= reg_ack_in;
            reg_rd_wr_L_out    <= reg_rd_wr_L_in;
            reg_addr_out       <= reg_addr_in;
            reg_src_out        <= reg_src_in;
            reg_data_out       <= reg_data_in;
         end // else: !if(addr_good && tag_hit && reg_req_in && !reg_ack_in)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // generic_sw_regs







