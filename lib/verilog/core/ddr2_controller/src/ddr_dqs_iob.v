//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       ddr_dqs_iob.v
//
//  Description :     This module instantiates DDR IOB output flip-flops, an
//                    output buffer with registered tri-state, and an input buffer
//                    for a single strobe/dqs bit. The DDR IOB output flip-flops
//                    are used to forward strobe to memory during a write. During
//                    a read, the output of the IBUF is routed to the internal
//                    delay module, dqs_delay.
//
//  Date - revision : 12/9/2003
//
//  Author :          Maria George
//
//  Contact : e-mail  hotline@xilinx.com
//            phone   + 1 800 255 7778
//
//  Disclaimer: LIMITED WARRANTY AND DISCLAMER. These designs are
//              provided to you "as is". Xilinx and its licensors make and you
//              receive no warranties or conditions, express, implied,
//              statutory or otherwise, and Xilinx specifically disclaims any
//              implied warranties of merchantability, non-infringement, or
//              fitness for a particular purpose. Xilinx does not warrant that
//              the functions contained in these designs will meet your
//              requirements, or that the operation of these designs will be
//              uninterrupted or error free, or that defects in the Designs
//              will be corrected. Furthermore, Xilinx does not warrant or
//              make any representations regarding use or the results of the
//              use of the designs in terms of correctness, accuracy,
//              reliability, or otherwise.
//
//              LIMITATION OF LIABILITY. In no event will Xilinx or its
//              licensors be liable for any loss of data, lost profits, cost
//              or procurement of substitute goods or services, or for any
//              special, incidental, consequential, or indirect damages
//              arising from the use or operation of the designs or
//              accompanying documentation, however caused and on any theory
//              of liability. This limitation will apply even if Xilinx
//              has been advised of the possibility of such damage. This
//              limitation shall apply not-withstanding the failure of the
//              essential purpose of any limited remedies herein.
//
//  Copyright © 2002 Xilinx, Inc.
//  All rights reserved
//
//*****************************************************************************
//`define DQS_n

`timescale 1ns/100ps
`include  "ddr_defines.v"

module ddr_dqs_iob(
	           clk,
  clk180,
                 ddr_dqs_reset,
	           ddr_dqs_enable,
	           ddr_dqs,
                   `ifdef DQS_n
	           ddr_dqs_n,
	           `endif
	           dqs
                   );


   input          clk;
  input clk180;
   input       	  ddr_dqs_reset;
   input 	        ddr_dqs_enable;

   inout          ddr_dqs;
  `ifdef DQS_n
   inout          ddr_dqs_n;
   `endif
   output         dqs;

   wire           dqs_q;
   wire           ddr_dqs_enable1;
   wire           vcc;
   wire           gnd;
   wire           ddr_dqs_enable_b;
   wire           data1;
   `ifdef DQS_n
   wire           dqs_q_n;
   wire           ddr_dqs_n;
   wire          dqs_n;

   `endif


assign vcc              = 1'b1;
assign gnd              = 1'b0;
assign ddr_dqs_enable_b = ~ddr_dqs_enable;
assign data1            = (ddr_dqs_reset == 1'b1) ? 1'b0 : 1'b1;


FD  U1 (
         .D(ddr_dqs_enable_b),
         .Q(ddr_dqs_enable1),
         .C(clk)
         );

//change as per infrastructure_iobs????
FDDRRSE U2 (
             .Q(dqs_q),
             .C0(clk180),
             .C1(clk),
             .CE(vcc),
             .D0(gnd),
             .D1(data1),
             .R(gnd),
             .S(gnd)
             );


//***********************************************************************
//    IO buffer for dqs signal. Allows for distribution of dqs
//     to the data (DQ) loads.
//***********************************************************************


`ifdef DQS_n

IOBUFDS U7 (
                    .I(dqs_q),
                    .O(dqs),
                    .IO(ddr_dqs),
                    .IOB(ddr_dqs_n),
                    .T(ddr_dqs_enable1)
                    );


`else

OBUFT  U3  (
            .I(dqs_q),
            .T(ddr_dqs_enable1),
            .O(ddr_dqs)
            );

IBUF_SSTL18_II  U4 (
                   .I(ddr_dqs),
                   .O(dqs)
                   );


`endif

endmodule
