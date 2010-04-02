///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: add_hdr.v 2119 2007-08-14 19:06:03Z jnaous $
//
// Module: add_hdr.v
// Project: NF2.1
// Description: Adds a length header to packets
//
// The format of this extra word is:
//
// Bits    Purpose
// 15:0    Packet length in bytes
// 31:16   Source port (binary encoding)
// 47:32   Packet length in words
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module add_hdr
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter STAGE_NUMBER = 'hff,
      parameter PORT_NUMBER = 0
   )
   (
      input [DATA_WIDTH-1:0]              in_data,
      input [CTRL_WIDTH-1:0]              in_ctrl,
      input                               in_wr,
      output reg                          in_rdy,

      output reg [DATA_WIDTH-1:0]         out_data,
      output reg [CTRL_WIDTH-1:0]         out_ctrl,
      output reg                          out_wr,
      input                               out_rdy,

      // --- Misc
      input                               reset,
      input                               clk
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

   // ------------ Internal Params --------
   localparam WRITE              = 0;
   localparam READ_HDR           = 1;
   localparam READ               = 2;

   localparam LAST_WORD_BYTE_CNT_WIDTH = log2(CTRL_WIDTH);
   localparam PKT_BYTE_CNT_WIDTH       = log2(2048);
   localparam PKT_WORD_CNT_WIDTH       = PKT_BYTE_CNT_WIDTH - LAST_WORD_BYTE_CNT_WIDTH;

   // ------------- Regs/ wires -----------

   wire [CTRL_WIDTH-1:0]            out_ctrl_local;
   wire [DATA_WIDTH-1:0]            out_data_local;

   reg [1:0]                        state_nxt;
   reg [1:0]                        state;

   reg [PKT_BYTE_CNT_WIDTH-1:0]     byte_cnt_rd;
   reg [PKT_BYTE_CNT_WIDTH-1:0]     byte_cnt_rd_nxt;
   reg [PKT_WORD_CNT_WIDTH-1:0]     word_cnt_rd;
   reg [PKT_WORD_CNT_WIDTH-1:0]     word_cnt_rd_nxt;

   reg [PKT_BYTE_CNT_WIDTH-1:0]     byte_cnt;
   reg [PKT_BYTE_CNT_WIDTH-1:0]     byte_cnt_nxt;
   reg [PKT_WORD_CNT_WIDTH-1:0]     word_cnt;
   reg [PKT_WORD_CNT_WIDTH-1:0]     word_cnt_nxt;

   reg                              fifo_rd;

   wire [`IOQ_WORD_LEN_POS - `IOQ_SRC_PORT_POS-1:0] port_number = PORT_NUMBER;

   // ------------ Modules -------------

   hdr_fifo add_hdr_fifo (
      .din({in_ctrl, in_data}),
      .wr_en(in_wr),

      .dout({out_ctrl_local, out_data_local}),
      .rd_en(fifo_rd),

      .empty(),
      .full(),
      .almost_full(),

      .rst(reset),
      .clk(clk)
   );


   // ------------- Logic ------------

   always @(posedge clk)
   begin
      state <= state_nxt;

      byte_cnt <= byte_cnt_nxt;
      word_cnt <= word_cnt_nxt;

      byte_cnt_rd <= byte_cnt_rd_nxt;
      word_cnt_rd <= word_cnt_rd_nxt;
   end

   always @*
   begin
      // Restore to previous state
      state_nxt = state;
      byte_cnt_nxt = byte_cnt;
      word_cnt_nxt = word_cnt;
      byte_cnt_rd_nxt = byte_cnt_rd;
      word_cnt_rd_nxt = word_cnt_rd;

      out_data = out_data_local;
      out_ctrl = out_ctrl_local;

      in_rdy = 1'b0;
      out_wr = 1'b0;

      fifo_rd = 1'b0;

      if (reset) begin
         state_nxt = WRITE;

         byte_cnt_nxt = 'h0;
         word_cnt_nxt = 'h0;

         byte_cnt_rd_nxt = 'h0;
         word_cnt_rd_nxt = 'h0;
      end
      else begin
         if (in_wr) begin
            if (|in_ctrl) begin
               word_cnt_rd_nxt = word_cnt + 'h1;
               word_cnt_nxt = 'h0;

               case (in_ctrl)
                  'h01: byte_cnt_rd_nxt = byte_cnt + 8;
                  'h02: byte_cnt_rd_nxt = byte_cnt + 7;
                  'h04: byte_cnt_rd_nxt = byte_cnt + 6;
                  'h08: byte_cnt_rd_nxt = byte_cnt + 5;
                  'h10: byte_cnt_rd_nxt = byte_cnt + 4;
                  'h20: byte_cnt_rd_nxt = byte_cnt + 3;
                  'h40: byte_cnt_rd_nxt = byte_cnt + 2;
                  'h80: byte_cnt_rd_nxt = byte_cnt + 1;
               endcase
               byte_cnt_nxt = 'h0;
            end
            else begin
               word_cnt_nxt = word_cnt + 'h1;
               byte_cnt_nxt = byte_cnt + 'h8;
            end
         end

         case (state)
            WRITE : begin
               in_rdy = 1'b1;

               if (in_wr && |in_ctrl)
                  state_nxt = READ_HDR;
            end

            READ_HDR : begin
               out_data = {word_cnt_rd,
                           port_number,
                           {(`IOQ_SRC_PORT_POS - PKT_BYTE_CNT_WIDTH){1'b0}}, byte_cnt_rd};
               out_ctrl = STAGE_NUMBER;
               out_wr = out_rdy;

               fifo_rd = out_rdy;

               if (out_rdy)
                  state_nxt = READ;
            end

            READ : begin
               out_data = out_data_local;
               out_ctrl = out_ctrl_local;
               out_wr = out_rdy;

               fifo_rd = out_rdy && !(|out_ctrl_local);

               if (out_rdy && |out_ctrl_local)
                  state_nxt = WRITE;
            end
         endcase
      end
   end

endmodule // add_hdr
