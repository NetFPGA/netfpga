///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: generic_table_regs.v 5464 2009-05-05 22:17:44Z grg $
//
// Module: generic_table_regs.v
// Project: NF2.1
// Author: Glen Gibb
// Description: Implement a generic register block that interfaces with
//              a table.
//
// WARNING: This module does *not* implement the table.
//
// This module is an interface between the register system and a table. The
// table needs to be implemented externally.
//
// To use this block you should specify a number of parameters at
// instantiation:
//   TAG -- specifies the major block's tag. This should be specified as a macro
//          somewhere like (udp_defines.v)
//   REG_ADDR_WIDTH -- width of the address block allocated to this register
//                     group. It is important that this is specified correctly
//                     as this width is used to enable tag matching
//   TABLE_ENTRY_WIDTH -- width of each entry in the table in bits
//   REG_START_ADDR -- start address of the registers
//
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module generic_table_regs
   #(
      parameter UDP_REG_SRC_WIDTH     = 2,                       // identifies which module started this request
      parameter TAG                   = 0,                       // Tag to match against
      parameter REG_ADDR_WIDTH        = 5,                       // Width of block addresses
      parameter TABLE_ENTRY_WIDTH     = 8,                       // Width of a table entry in bits
      parameter TABLE_ADDR_WIDTH      = 8,                       // Width of a table entry in bits
      parameter REG_START_ADDR        = 0                        // First address
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

      // --- Table interface
      output reg                             table_rd_req,       // Request a read
      input                                  table_rd_ack,       // Pulses hi on ACK
      output reg  [TABLE_ADDR_WIDTH-1:0]     table_rd_addr,      // Address in table to read
      input [TABLE_ENTRY_WIDTH-1:0]          table_rd_data,      // Value in table
      output reg                             table_wr_req,       // Request a write
      input                                  table_wr_ack,       // Pulses hi on ACK
      output reg [TABLE_ADDR_WIDTH-1:0]      table_wr_addr,      // Address in table to write
      output [TABLE_ENTRY_WIDTH-1:0]         table_wr_data,      // Value to write to table

      input                                  clk,
      input                                  reset
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   // ------------- Internal parameters --------------
   localparam NUM_ENTRY_REGS = ceildiv(TABLE_ENTRY_WIDTH, `CPCI_NF2_DATA_WIDTH);
   localparam TABLE_ENTRY_WIDTH_CEIL = NUM_ENTRY_REGS * `CPCI_NF2_DATA_WIDTH;

   // End addr = start addr + # entry regs + rd addr reg + wr addr reg
   localparam REG_END_ADDR = REG_START_ADDR + NUM_ENTRY_REGS + 2;

   // Read/write addresses are immediately after the entry
   localparam TABLE_RD_ADDR = REG_START_ADDR + NUM_ENTRY_REGS;
   localparam TABLE_WR_ADDR = REG_START_ADDR + NUM_ENTRY_REGS + 1;

   localparam WAIT_FOR_REQ             = 1;
   localparam WRITE_TO_TABLE           = 2;
   localparam READ_FROM_TABLE          = 4;
   localparam DONE                     = 8;

   // ------------- Wires/reg ------------------

   wire [REG_ADDR_WIDTH-1:0]              addr;
   wire [`UDP_REG_ADDR_WIDTH-REG_ADDR_WIDTH-1:0] tag_addr;

   wire                                   addr_good;
   wire                                   tag_hit;

   reg [`CPCI_NF2_DATA_WIDTH-1:0]         entry [0:NUM_ENTRY_REGS-1];
   wire [TABLE_ENTRY_WIDTH_CEIL-1:0]      table_rd_data_padded;
   wire [TABLE_ENTRY_WIDTH_CEIL-1:0]      table_wr_data_padded;

   reg [3:0]                              state;

   reg                                    reg_rd_wr_L_held;
   reg  [`UDP_REG_ADDR_WIDTH-1:0]         reg_addr_held;
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]        reg_data_held;
   reg  [UDP_REG_SRC_WIDTH-1:0]           reg_src_held;

   integer i;
   genvar j;

   // -------------- Logic --------------------
   assign addr = reg_addr_in;
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:REG_ADDR_WIDTH];

   assign addr_good = addr < REG_END_ADDR && addr >= REG_START_ADDR;
   assign tag_hit = tag_addr == TAG;

   // Read data handling
   generate
      if (TABLE_ENTRY_WIDTH_CEIL != TABLE_ENTRY_WIDTH)
         assign table_rd_data_padded = table_rd_data;
      else
         assign table_rd_data_padded = {{(TABLE_ENTRY_WIDTH_CEIL - TABLE_ENTRY_WIDTH){1'b0}}, table_rd_data};
   endgenerate

   // Write data handling
   assign table_wr_data = table_wr_data_padded[TABLE_ENTRY_WIDTH-1:0];
   generate
      for (j = 0; j < NUM_ENTRY_REGS; j = j + 1) begin : gen_wr_data_padded
         assign table_wr_data_padded[(NUM_ENTRY_REGS - 1 - j) * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = entry[j];
      end
   endgenerate

   always @(posedge clk)
   begin
      if(reset) begin
         for (i = 0; i < NUM_ENTRY_REGS; i = i + 1) begin
            entry[i]       <= 0;
         end
         state             <= WAIT_FOR_REQ;

         reg_req_out       <= 0;
         reg_ack_out       <= 0;
         reg_rd_wr_L_out   <= 0;
         reg_addr_out      <= 0;
         reg_src_out       <= 0;
         reg_data_out      <= 0;
      end
      else begin
         case(state)
            WAIT_FOR_REQ: begin
               if (reg_req_in && tag_hit) begin
                  if (!reg_rd_wr_L_in && addr_good) begin // Write
                     // Update the appropriate register
                     case (addr)
                        TABLE_RD_ADDR: table_rd_addr <= reg_data_in;
                        TABLE_WR_ADDR: table_wr_addr <= reg_data_in;
                        default:       entry[addr - REG_START_ADDR] <= reg_data_in;
                     endcase

                     // Perform the correct post processing
                     case(addr)
                        TABLE_RD_ADDR: state <= READ_FROM_TABLE;
                        TABLE_WR_ADDR: state <= WRITE_TO_TABLE;
                        default:       state <= DONE;
                     endcase

                     reg_req_out       <= 0;
                     reg_ack_out       <= 0;
                     reg_rd_wr_L_out   <= 0;
                     reg_addr_out      <= 0;
                     reg_data_out      <= 0;
                     reg_src_out       <= 0;

                     reg_rd_wr_L_held  <= reg_rd_wr_L_in;
                     reg_addr_held     <= reg_addr_in;
                     reg_data_held     <= reg_data_in;
                     reg_src_held      <= reg_src_in;
                  end
                  else begin
                     reg_req_out       <= 1'b 1;
                     reg_rd_wr_L_out   <= reg_rd_wr_L_in;
                     reg_addr_out      <= reg_addr_in;
                     if (addr_good) begin
                        reg_ack_out       <= 1'b 1;
                        case (addr)
                           TABLE_RD_ADDR: reg_data_out <= table_rd_addr;
                           TABLE_WR_ADDR: reg_data_out <= table_wr_addr;
                           default:       reg_data_out <= entry[addr - REG_START_ADDR];
                        endcase
                     end
                     else
                     begin
                        reg_ack_out    <= reg_ack_in;
                        reg_data_out   <= reg_data_in;
                     end
                     reg_src_out       <= reg_src_in;
                  end
               end
               else begin
                  reg_req_out       <= reg_req_in;
                  reg_ack_out       <= reg_ack_in;
                  reg_rd_wr_L_out   <= reg_rd_wr_L_in;
                  reg_addr_out      <= reg_addr_in;
                  reg_data_out      <= reg_data_in;
                  reg_src_out       <= reg_src_in;
               end
            end // case: WAIT_FOR_REQ

            WRITE_TO_TABLE: begin
               if(table_wr_ack) begin
                  state <= DONE;
                  table_wr_req <= 0;
               end
               else begin
                  table_wr_req <= 1;
               end
            end // case: WRITE_TO_TABLE

            READ_FROM_TABLE: begin
               if(table_rd_ack) begin
                  for (i = 0; i < NUM_ENTRY_REGS; i = i + 1) begin
                     entry[i] <= table_rd_data_padded[(NUM_ENTRY_REGS - 1 - i) * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];
                  end
                  state <= DONE;
                  table_rd_req <= 0;
               end
               else begin
                  table_rd_req <= 1;
               end
            end // case: READ_TO_TABLE

            DONE: begin
               state <= WAIT_FOR_REQ;

               reg_req_out      <= 1'b 1;
               reg_ack_out      <= 1'b 1;
               reg_rd_wr_L_out  <= reg_rd_wr_L_held;
               reg_addr_out     <= reg_addr_held;
               reg_data_out     <= reg_data_held;
               reg_src_out      <= reg_src_held;
            end // case: DONE
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)
endmodule // generic_table_regs
