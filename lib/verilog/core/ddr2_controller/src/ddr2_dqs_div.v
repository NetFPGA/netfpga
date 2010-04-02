//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       ddr2_dqs_div.v
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

module ddr2_dqs_div  (
	              dqs,
	              dqs1,
			  reset,
		        rst_dqs_div_delayed,
	              dqs_divn,
	              dqs_divp
                     );

   input  dqs;
   input  dqs1;
   input  reset;
   input  rst_dqs_div_delayed;

   output dqs_divn;
   output dqs_divp;

   wire   dqs_div1_int;
   wire   dqs_div0_int;
   wire   dqs_div0n;
   wire   dqs_div1n;

   wire   dqs1_n;
   wire   dqs_n;
   wire   reset;
   wire   rst_dqs_div_delayed;

assign dqs_divn  = dqs_div1_int;
assign dqs_divp  = dqs_div0_int;
assign dqs_div0n = ~dqs_div0_int;
assign dqs_div1n = ~dqs_div1_int;

assign dqs1_n = (~dqs1);
assign dqs_n = (~dqs);


FDC  col1  (
             .Q(dqs_div0_int),
             .C(dqs1),
             .CLR(rst_dqs_div_delayed),
             .D(dqs_div0n)
            );

FDC  col0  (
             .Q(dqs_div1_int),
             .C(dqs_n),
             .CLR(reset),
             .D(dqs_div0_int)
            );

endmodule