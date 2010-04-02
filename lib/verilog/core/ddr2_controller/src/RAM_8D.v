//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//  XAPP 678 - Data Capture Technique Using CLB Flip-Flops
//
//*******************************************************************************
//
//  File name :       RAM_8D.v
//
//  Description :      This block is used to build the asynchronous FIFOs from the
//                     LUT RAMs. This is specific for data clocked at the rising edge
//                     of the clock
//
//  Date - revision : 05/01/2002
//
//  Author :          Converted to Verilog by Maria George
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
//****************************************************************************************

`timescale 1ns/100ps

module RAM_8D (
	         DPO,
	         A0,
	         A1,
	         A2,
	         A3,
	         D,
	         DPRA0,
	         DPRA1,
	         DPRA2,
	         DPRA3,
	         WCLK,
	         WE
                 );

   input          A0;
   input          A1;
   input          A2;
   input 	  A3;
   input 	  DPRA0;
   input 	  DPRA1;
   input 	  DPRA2;
   input 	  DPRA3;
   input 	  WCLK;
   input          WE;
   input [7:0]   D;

   output [7:0]  DPO;


RAM16X1D  B0 ( .D(D[0]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[0]));

RAM16X1D  B1 ( .D(D[1]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[1]));

RAM16X1D  B2 ( .D(D[2]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[2]));

RAM16X1D  B3 ( .D(D[3]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[3]));

RAM16X1D  B4 ( .D(D[4]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[4]));

RAM16X1D  B5 ( .D(D[5]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[5]));

RAM16X1D  B6 ( .D(D[6]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[6]));

RAM16X1D  B7 ( .D(D[7]),
               .WE(WE),
               .WCLK(WCLK),
               .A0(A0),
               .A1(A1),
               .A2(A2),
               .A3(A3),
               .DPRA0(DPRA0),
               .DPRA1(DPRA1),
               .DPRA2(DPRA2),
               .DPRA3(DPRA3),
               .SPO(),
               .DPO(DPO[7]));

endmodule