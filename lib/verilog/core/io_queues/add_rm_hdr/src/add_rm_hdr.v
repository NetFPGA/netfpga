///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: add_rm_hdr.v 2055 2007-07-30 22:44:59Z grg $
//
// Module: add_rm_hdr.v
// Project: NF2.1
// Description: Adds/removes length header to/from packets
//
// The format of this extra word is:
//
// Bits    Purpose
// 15:0    Packet length in bytes
// 31:16   Source port
// 47:32   Packet length in words
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module add_rm_hdr
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter STAGE_NUMBER = 'hff,
      parameter PORT_NUMBER = 0
   )
   (
      input [DATA_WIDTH-1:0]              rx_in_data,
      input [CTRL_WIDTH-1:0]              rx_in_ctrl,
      input                               rx_in_wr,
      output                              rx_in_rdy,

      output [DATA_WIDTH-1:0]             rx_out_data,
      output [CTRL_WIDTH-1:0]             rx_out_ctrl,
      output                              rx_out_wr,
      input                               rx_out_rdy,

      input [DATA_WIDTH-1:0]              tx_in_data,
      input [CTRL_WIDTH-1:0]              tx_in_ctrl,
      input                               tx_in_wr,
      output                              tx_in_rdy,

      output [DATA_WIDTH-1:0]             tx_out_data,
      output [CTRL_WIDTH-1:0]             tx_out_ctrl,
      output                              tx_out_wr,
      input                               tx_out_rdy,

      // --- Misc
      input                               reset,
      input                               clk
   );


add_hdr
   #(
      .DATA_WIDTH (DATA_WIDTH),
      .CTRL_WIDTH (CTRL_WIDTH),
      .STAGE_NUMBER (STAGE_NUMBER),
      .PORT_NUMBER (PORT_NUMBER)
   ) add_hdr (
      .in_data                            (rx_in_data),
      .in_ctrl                            (rx_in_ctrl),
      .in_wr                              (rx_in_wr),
      .in_rdy                             (rx_in_rdy),

      .out_data                           (rx_out_data),
      .out_ctrl                           (rx_out_ctrl),
      .out_wr                             (rx_out_wr),
      .out_rdy                            (rx_out_rdy),

      // --- Misc
      .reset                              (reset),
      .clk                                (clk)
   );


rm_hdr
   #(
      .DATA_WIDTH (DATA_WIDTH),
      .CTRL_WIDTH (CTRL_WIDTH)
   ) rm_hdr (
      .in_data                            (tx_in_data),
      .in_ctrl                            (tx_in_ctrl),
      .in_wr                              (tx_in_wr),
      .in_rdy                             (tx_in_rdy),

      .out_data                           (tx_out_data),
      .out_ctrl                           (tx_out_ctrl),
      .out_wr                             (tx_out_wr),
      .out_rdy                            (tx_out_rdy),

      // --- Misc
      .reset                              (reset),
      .clk                                (clk)
   );

endmodule // add_rm_hdr
