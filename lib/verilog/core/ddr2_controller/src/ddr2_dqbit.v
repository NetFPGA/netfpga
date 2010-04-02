//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       ddr2_dqbit.v
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

module ddr2_dqbit (
	           reset,
	           dqs,
	           dqs1,
	           dqs_div_1,
	           dqs_div_2,
	           dq,
	           fbit_0,
	           fbit_1,
	           fbit_2,
	           fbit_3
                  );

// input/output declarations
   input          reset;
   input          dqs;
   input          dqs1;
   input          dqs_div_1;
   input          dqs_div_2;
   input          dq;

   output         fbit_0;
   output         fbit_1;
   output         fbit_2;
   output         fbit_3;

   wire [3:0]     fbit;
   wire           async_clr;
   wire           dqsn;
   wire           dqs_div2n;
   wire           dqs_div1n;

assign async_clr  = reset;
assign dqsn       = ~dqs;
assign dqs_div2n  = ~dqs_div_2;
assign dqs_div1n  = ~dqs_div_1;
assign fbit_0     = fbit[0];
assign fbit_1     = fbit[1];
assign fbit_2     = fbit[2];
assign fbit_3     = fbit[3];

// Read data from memory is first registered in CLB ff using delayed strobe from memory
// A data bit from data words 0, 1, 2, and 3

FDCE  fbit0  (
               .Q(fbit[0]),
               .C(dqs1),
               .CE(dqs_div2n),
               .CLR(async_clr),
               .D(dq)
              );


FDCE  fbit1  (
               .Q(fbit[1]),
               .C(dqsn),
               .CE(dqs_div_2),
               .CLR(async_clr),
               .D(dq)
              );

FDCE  fbit2  (
               .Q(fbit[2]),
               .C(dqs1),
               .CE(dqs_div_2),
               .CLR(async_clr),
               .D(dq)
              );

FDCE  fbit3  (
               .Q(fbit[3]),
               .C(dqsn),
               .CE(dqs_div_1),
               .CLR(async_clr),
               .D(dq)
              );

endmodule