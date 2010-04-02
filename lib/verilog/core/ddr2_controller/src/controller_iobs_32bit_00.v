//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       v2p_dqs_iob.v
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

`include "parameters_32bit_00.v"
`timescale 1ns/100ps

module controller_iobs_32bit_00(
                       //inputs
                       clk0,
   clk180,
                       ddr_rasb_cntrl,
                       ddr_casb_cntrl,
                       ddr_web_cntrl,
                       ddr_cke_cntrl,
                       ddr_csb_cntrl,
                       ddr_ODT_cntrl,
                       ddr_address_cntrl,
                       ddr_ba_cntrl,
                       rst_dqs_div_int,
                       rst_dqs_div_in,
                       //outputs
                       ddr_rasb,
                       ddr_casb,
                       ddr_web,
                       ddr_ba,
                       ddr_address,
                       ddr_cke,
                       ddr_csb,
                       ddr_ODT0,
                       rst_dqs_div,
                       rst_dqs_div_out
                    );

//input/output declarations

input        clk0;
   input clk180;
input        ddr_rasb_cntrl;
input        ddr_casb_cntrl;
input        ddr_web_cntrl;
input        ddr_cke_cntrl;
input        ddr_csb_cntrl;
input        ddr_ODT_cntrl;
input [`row_address-1:0] ddr_address_cntrl;
input [`bank_address-1:0]  ddr_ba_cntrl;
input        rst_dqs_div_int;
input        rst_dqs_div_in;
output       ddr_rasb;
output       ddr_casb;
output       ddr_web;
output [`bank_address-1:0] ddr_ba;
output [`row_address-1:0]ddr_address;
output       ddr_cke;
output       ddr_csb;
output       ddr_ODT0;
output       rst_dqs_div;
output       rst_dqs_div_out;


// internal wire declarations
wire GND;
wire ddr_web_q;
wire ddr_rasb_q;
wire ddr_casb_q;
wire ddr_cke_q;

wire [`row_address-1:0] ddr_address_iob_reg;
wire [`bank_address-1:0] ddr_ba_reg;


assign GND    = 1'b0;


//********************************************************
//  Includes the instantiation of FD for cntrl signals
// *******************************************************

FD iob_web (
            .Q(ddr_web_q),
            .D(ddr_web_cntrl),
            .C(clk180)
           )/* synthesis xc_props = "IOB=1" */ ;

FD iob_rasb(
            .Q(ddr_rasb_q),
            .D(ddr_rasb_cntrl),
            .C(clk180)
           )/* synthesis xc_props= "IOB=1" */ ;

FD iob_casb(
            .Q(ddr_casb_q),
            .D(ddr_casb_cntrl),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;


// *************************************
//  Output buffers for address signals
// *************************************

FD iob_addr0 (
            .Q(ddr_address_iob_reg[0]),
            .D(ddr_address_cntrl[0]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr1 (
            .Q(ddr_address_iob_reg[1]),
            .D(ddr_address_cntrl[1]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr2 (
            .Q(ddr_address_iob_reg[2]),
            .D(ddr_address_cntrl[2]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr3 (
            .Q(ddr_address_iob_reg[3]),
            .D(ddr_address_cntrl[3]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr4(
            .Q(ddr_address_iob_reg[4]),
            .D(ddr_address_cntrl[4]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr5(
            .Q(ddr_address_iob_reg[5]),
            .D(ddr_address_cntrl[5]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr6(
            .Q(ddr_address_iob_reg[6]),
            .D(ddr_address_cntrl[6]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr7(
            .Q(ddr_address_iob_reg[7]),
            .D(ddr_address_cntrl[7]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr8(
            .Q(ddr_address_iob_reg[8]),
            .D(ddr_address_cntrl[8]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr9(
            .Q(ddr_address_iob_reg[9]),
            .D(ddr_address_cntrl[9]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr10(
            .Q(ddr_address_iob_reg[10]),
            .D(ddr_address_cntrl[10]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_addr11(
            .Q(ddr_address_iob_reg[11]),
            .D(ddr_address_cntrl[11]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;


FD iob_addr12(
            .Q(ddr_address_iob_reg[12]),
            .D(ddr_address_cntrl[12]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;



OBUF r0(
        .I(ddr_address_iob_reg[0]),
        .O(ddr_address[0])
       );

OBUF r1(
        .I(ddr_address_iob_reg[1]),
        .O(ddr_address[1])
       );

OBUF r2(
        .I(ddr_address_iob_reg[2]),
        .O(ddr_address[2])
       );

OBUF r3(
        .I(ddr_address_iob_reg[3]),
        .O(ddr_address[3])
       );

OBUF r4(
        .I(ddr_address_iob_reg[4]),
        .O(ddr_address[4])
       );

OBUF r5(
         .I(ddr_address_iob_reg[5]),
         .O(ddr_address[5])
        );

OBUF r6(
         .I(ddr_address_iob_reg[6]),
         .O(ddr_address[6])
        );

OBUF r7(
         .I(ddr_address_iob_reg[7]),
         .O(ddr_address[7])
        );

OBUF r8(
         .I(ddr_address_iob_reg[8]),
         .O(ddr_address[8])
        );

OBUF r9(
         .I(ddr_address_iob_reg[9]),
         .O(ddr_address[9])
        );

OBUF r10(
         .I(ddr_address_iob_reg[10]),
         .O(ddr_address[10])
        );

OBUF r11(
         .I(ddr_address_iob_reg[11]),
         .O(ddr_address[11])
        );

OBUF r12(
         .I(ddr_address_iob_reg[12]),
         .O(ddr_address[12])
        );

`ifdef row_address_14

FD iob_addr13(
            .Q(ddr_address_iob_reg[13]),
            .D(ddr_address_cntrl[13]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;



OBUF r13(
         .I(ddr_address_iob_reg[13]),
         .O(ddr_address[13])
        );

`endif

FD iob_ba0(
            .Q(ddr_ba_reg[0]),
            .D(ddr_ba_cntrl[0]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;

FD iob_ba1(
            .Q(ddr_ba_reg[1]),
            .D(ddr_ba_cntrl[1]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;


OBUF r14(
         .I(ddr_ba_reg[0]),
         .O(ddr_ba[0])
        );

OBUF r15(
         .I(ddr_ba_reg[1]),
         .O(ddr_ba[1])
        );

`ifdef bank_address_3

FD iob_ba2(
            .Q(ddr_ba_reg[2]),
            .D(ddr_ba_cntrl[2]),
            .C(clk180)
            ) /* synthesis xc_props = "IOB=1" */ ;


OBUF r16(
         .I(ddr_ba_reg[2]),
         .O(ddr_ba[2])
        );
`endif


//***************************************
//  Output buffers for control signals
//***************************************

OBUF r17(
        .I(ddr_web_q),
        .O(ddr_web)
       );

OBUF r18(
        .I(ddr_rasb_q),
        .O(ddr_rasb)
       );

OBUF r19(
        .I(ddr_casb_q),
        .O(ddr_casb)
       );

FD iob_cke (
            .Q(ddr_cke_q),
            .D(ddr_cke_cntrl),
            .C(clk180)
           )/* synthesis xc_props = "IOB=1" */ ;


OBUF r20(
        .I(ddr_cke_q),
        .O(ddr_cke)
       );


//OBUF r20(
//        .I(ddr_cke_cntrl),
//        .O(ddr_cke)
//       );

OBUF r21 (
        .I(ddr_csb_cntrl),
        .O(ddr_csb)
       );

OBUF r22(
         .I(ddr_ODT_cntrl),
         .O(ddr_ODT0)
        );


//************************************** Copied from board test logic ****************************************


IBUF rst_iob_inbuf (
                       .I(rst_dqs_div_in),
                       .O(rst_dqs_div)
                   );

OBUF rst_iob_outbuf (
                      .I(rst_dqs_div_int),
                      .O(rst_dqs_div_out)
                    );

//************************************** Copied from board test logic ****************************************
  endmodule
