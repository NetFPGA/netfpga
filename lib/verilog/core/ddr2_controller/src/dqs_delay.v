//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       dqs_delay.v
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

module dqs_delay  (
	           clk_in,
	           sel_in,
	           clk_out
                  );

   input          clk_in;
   input [4:0]    sel_in;

   output         clk_out;

   wire           delay1;
   wire           delay2;
   wire           delay3;
   wire           delay4;
   wire           delay5;
   wire           high;

   assign high = 1'b1;

   LUT4 one( .I0(high), .I1(sel_in[4]), .I2(delay5), .I3(clk_in), .O(clk_out));
   defparam    one.INIT = 16'hf3c0;

   LUT4 two( .I0(clk_in), .I1(sel_in[2]), .I2(high), .I3(delay3), .O(delay4));
   defparam    two.INIT = 16'hee22;

   LUT4 three( .I0(clk_in), .I1(sel_in[0]), .I2(delay1), .I3(high), .O(delay2) );
   defparam    three.INIT = 16'he2e2;

   LUT4 four( .I0(high), .I1(high), .I2(high), .I3(clk_in), .O(delay1) );
   defparam    four.INIT = 16'hff00;

   LUT4 five( .I0(high), .I1(sel_in[3]), .I2(delay4), .I3(clk_in), .O(delay5) );
   defparam    five.INIT = 16'hf3c0;

   LUT4 six( .I0(clk_in), .I1(sel_in[1]), .I2(delay2), .I3(high), .O(delay3) );
   defparam    six.INIT = 16'he2e2;

endmodule