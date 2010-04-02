//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   ddr2_dm_32bit.v.v
//
//  Description :     This module instantiates DDR IOB output flip-flops, and an
//                    output buffer for the data mask bits.
//
//  Date - revision : 12/22/2003
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

`timescale 1ns/100ps

//`include "parameters_32bit.v"
module    ddr2_dm_32bit   (
	           ddr_dm,
	           mask_falling,
	           mask_rising,
  clk270,
	           clk90
                  );

   input [3:0]    mask_falling;
   input [3:0]    mask_rising;
   input          clk90;
  input clk270;
   output [3:0]   ddr_dm;

   wire [3:0]     mask_o;  // Mask output intermediate signal
   wire           gnd;
   wire           vcc;

assign gnd    = 1'b0;
assign vcc    = 1'b1;

// Data Mask Output during a write command

FDDRRSE  DDR_DM0_OUT (
                       .Q (mask_o[0]),
                       .C0(clk270),
                       .C1(clk90),
                       .CE(vcc),
                       .D0(mask_rising[0]),
                       .D1(mask_falling[0]),
                       .R (gnd),
                       .S (gnd)
                      );

FDDRRSE  DDR_DM1_OUT (
                       .Q (mask_o[1]),
                       .C0(clk270),
                       .C1(clk90),
                       .CE(vcc),
                       .D0(mask_rising[1]),
                       .D1(mask_falling[1]),
                       .R (gnd),
                       .S (gnd)
                      );

FDDRRSE  DDR_DM2_OUT (
                       .Q (mask_o[2]),
                       .C0(clk270),
                       .C1(clk90),
                       .CE(vcc),
                       .D0(mask_rising[2]),
                       .D1(mask_falling[2]),
                       .R (gnd),
                       .S (gnd)
                      );

FDDRRSE  DDR_DM3_OUT (
                       .Q (mask_o[3]),
                       .C0(clk270),
                       .C1(clk90),
                       .CE(vcc),
                       .D0(mask_rising[3]),
                       .D1(mask_falling[3]),
                       .R (gnd),
                       .S (gnd)
                      );


OBUF  DM0_OBUF (
                 .I(mask_o[0]),
                 .O(ddr_dm[0])
                );

OBUF  DM1_OBUF (
                 .I(mask_o[1]),
                 .O(ddr_dm[1])
                );

OBUF  DM2_OBUF (
                 .I(mask_o[2]),
                 .O(ddr_dm[2])
                );

OBUF  DM3_OBUF (
                 .I(mask_o[3]),
                 .O(ddr_dm[3])
                );

endmodule