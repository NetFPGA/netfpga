///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: strip_headers.v 2158 2007-08-18 02:34:53Z grg $
//
// Module: strip_headers.v
// Project: NF2.1
// Description: Strips all headers except the length/src/dst port header.
//  Sets the header length field in the header
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module strip_headers
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter IOQ_STAGE_NUM = `IO_QUEUE_STAGE_NUM
   )

   (// --- data path interface
      output reg [DATA_WIDTH-1:0]        out_data,
      output reg [CTRL_WIDTH-1:0]        out_ctrl,
      output reg                         out_wr,
      input                              out_rdy,

      input  [DATA_WIDTH-1:0]            in_data,
      input  [CTRL_WIDTH-1:0]            in_ctrl,
      input                              in_wr,
      output                             in_rdy,

      // --- Register interface
      input                              reg_req_in,
      input                              reg_ack_in,
      input                              reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

      output                             reg_req_out,
      output                             reg_ack_out,
      output                             reg_rd_wr_L_out,
      output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
      output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

      // --- Misc
      input                              clk,
      input                              reset
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

   //---------------------- Wires/Regs -------------------------------
   reg   in_pkt;
   reg   full;

   wire  keep_data;

   //----------------------- Modules ---------------------------------

   // Work out whether we should forward the data
   //
   // We should only keep data if we're already in a packet, if the packet
   // is just beginning or we're in the IOQ STAGE NUM header
   assign keep_data = in_pkt || in_ctrl == 'h0 || in_ctrl == IOQ_STAGE_NUM;

   always @(posedge clk)
   begin
      if (reset) begin
         in_pkt <= 1'b0;
         full <= 1'b0;

         out_wr <= 1'b0;
      end
      else begin
         if (full) begin
            // If the output is ready and we have an item of data, sent it to
            // the output
            out_wr <= out_rdy;
            full <= !out_rdy;
         end
         else if (in_wr) begin
            // Store the data if there's a write on the input
            out_ctrl <= in_ctrl;
            out_data <= in_data;

            // If the output is ready then send the data there, otherwise`
            if (out_rdy) begin
               out_wr <= keep_data;
               full <= 1'b0;
            end
            else begin
               out_wr <= 1'b0;
               full <= keep_data;
            end

            // Work out whether we're in a packet
            if (!in_pkt && in_ctrl == 'h0)
               in_pkt <= 1'b1;
            else if (in_pkt && |in_ctrl)
               in_pkt <= 1'b0;
         end
         else begin
            out_wr <= 1'b0;
         end
      end
   end

   // Only accept data if the output is ready and we're not full
   // (If we're full we've got to wait a cycle to give the data to the output)
   assign in_rdy = out_rdy && !full;

   assign reg_req_out = reg_req_in;
   assign reg_ack_out = reg_ack_in;
   assign reg_rd_wr_L_out = reg_rd_wr_L_in;
   assign reg_addr_out = reg_addr_in;
   assign reg_data_out = reg_data_in;
   assign reg_src_out = reg_src_in;


endmodule // strip_headers
