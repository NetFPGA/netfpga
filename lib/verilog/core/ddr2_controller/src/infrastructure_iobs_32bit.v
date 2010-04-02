//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   infrastructure_iobs_32bit.v.v
//
//  Description :     This module instantiates DDR IOB output flip-flops, an
//                    output buffer with registered tri-state, and an input buffer
//                    for a single strobe/dqs bit. The DDR IOB output flip-flops
//                    are used to forward strobe to memory during a write. During
//                    a read, the output of the IBUF is routed to the internal
//                    delay module, dqs_delay.
//
//  Date - revision : 12/10/2003
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

module    infrastructure_iobs_32bit(
                            //inputs
                            clk0,
                            clk90,
       clk180,
       clk270,
                            //outputs
                            ddr2_clk0,
                            ddr2_clk0b,
                            ddr2_clk1,
                            ddr2_clk1b
                           );

//input/output declarations
input       clk0;
input       clk90;
   input    clk180;
   input    clk270;
output      ddr2_clk0;
output      ddr2_clk0b;
output      ddr2_clk1;
output      ddr2_clk1b;


//*******************************
//  Internal Wire declarations
//*******************************

wire   ddr2_clk0_q;
wire   ddr2_clk0b_q;
wire   ddr2_clk1_q;
wire   ddr2_clk1b_q;
wire   vcc;
wire   gnd;


assign  vcc    =  1'b1;
assign  gnd    =  1'b0;


//##### Component instantiations #####

//**************************************

// ***********************************************************
//     Output DDR generation
//     This includes instantiation of the output DDR flip flop
//     for ddr clk's
// ***********************************************************


  /*
FDDRRSE  U1 (
             .Q(ddr2_clk0_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U2 (
             .Q(ddr2_clk0b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U3 (
             .Q(ddr2_clk1_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U4 (
             .Q(ddr2_clk1b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U5 (
             .Q(ddr2_clk2_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U6 (
             .Q(ddr2_clk2b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U7 (
             .Q(ddr2_clk3_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U8 (
             .Q(ddr2_clk3b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U9 (
             .Q(ddr2_clk4_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );


FDDRRSE  U10 (
              .Q(ddr2_clk4b_q),
              .C0(clk0),
              .C1(clk180),
              .CE(vcc),
              .D0(vcc),
              .D1(gnd),
              .R(gnd),
              .S(gnd)
             );

*/
//original
FDDRRSE  U1 (
             .Q(ddr2_clk0_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );


FDDRRSE  U3 (
             .Q(ddr2_clk1_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(vcc),
             .D1(gnd),
             .R(gnd),
             .S(gnd)
            );



FDDRRSE  U2 (
             .Q(ddr2_clk0b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );

FDDRRSE  U4 (
             .Q(ddr2_clk1b_q),
             .C0(clk0),
             .C1(clk180),
             .CE(vcc),
             .D0(gnd),
             .D1(vcc),
             .R(gnd),
             .S(gnd)
            );


// ******************************
//   Ouput BUffers for ddr clk's
// ******************************
/*

OBUFDS_BLVDS_25 r1 (
                     .I(ddr2_clk0_q),
                     .O(ddr2_clk0),
                     .OB(ddr2_clk0b)
                   );

OBUFDS_BLVDS_25 r3 (
                     .I(ddr2_clk1_q),
                     .O(ddr2_clk1),
                     .OB(ddr2_clk1b)
                   );

OBUFDS_BLVDS_25 r5 (
                     .I(ddr2_clk2_q),
                     .O(ddr2_clk2),
                     .OB(ddr2_clk2b)
                   );

OBUFDS_BLVDS_25 r7 (
                     .I(ddr2_clk3_q),
                     .O(ddr2_clk3),
                     .OB(ddr2_clk3b)
                   );

OBUFDS_BLVDS_25 r9 (
                     .I(ddr2_clk4_q),
                     .O(ddr2_clk4),
                     .OB(ddr2_clk4b)
                   );
*/


OBUF r1 (
         .I(ddr2_clk0_q),
         .O(ddr2_clk0)
         );


OBUF r2 (
         .I(ddr2_clk0b_q),
         .O(ddr2_clk0b)
         );


OBUF r3 (
         .I(ddr2_clk1_q),
         .O(ddr2_clk1)
         );

OBUF r4 (
         .I(ddr2_clk1b_q),
         .O(ddr2_clk1b)
         );

 endmodule