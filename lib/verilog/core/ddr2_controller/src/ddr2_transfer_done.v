//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       ddr2_transfer_done.v
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

module ddr2_transfer_done (
	                   clk0,
	                   clk90,
   clk180,
   clk270,
	                   reset,
	                   reset90,
	                   reset180,
	                   reset270,
	                   dqs_div,
	                   transfer_done0,
	                   transfer_done1,
	                   transfer_done2,
	                   transfer_done3
                           );

//input/output declarations
   input          clk0;
   input          clk90;
   input clk180;
   input clk270;
   input          reset;
   input          reset90;
   input          reset180;
   input          reset270;
   input 	        dqs_div;

   output         transfer_done0;
   output         transfer_done1;
   output         transfer_done2;
   output         transfer_done3;

   //internal signals declarations
   wire [3:0]     transfer_done_int;
   wire           transfer_done0_clk0;
   wire           transfer_done0_clk90;
   wire           transfer_done0_clk180;
   wire           transfer_done0_clk270;
   wire           transfer_done1_clk90;
   wire           transfer_done1_clk270;
   wire           transfer_done2_clk90;
   wire           transfer_done2_clk270;
   wire           transfer_done3_clk90;
   wire           transfer_done3_clk270;
   wire           sync_rst_xdone0_ck0;
   wire           sync_rst_xdone0_ck180;
   wire           sync_rst_clk90;
   wire           sync_rst_clk270;


assign sync_rst_xdone0_ck0   = reset || transfer_done0_clk0;
assign sync_rst_xdone0_ck180 = reset180 || transfer_done0_clk180;

assign transfer_done0        = transfer_done_int[0];
assign transfer_done1        = transfer_done_int[1];
assign transfer_done2        = transfer_done_int[2];
assign transfer_done3        = transfer_done_int[3];

LUT2  xdone0  (
               .O(transfer_done_int[0]),
               .I0(transfer_done0_clk90),
               .I1(transfer_done0_clk270)
              );
defparam    xdone0.INIT = 4'he;

LUT2  xdone1  (
               .O(transfer_done_int[1]),
               .I0(transfer_done1_clk90),
               .I1(transfer_done1_clk270)
              );
defparam    xdone1.INIT = 4'he;

LUT2  xdone2  (
               .O(transfer_done_int[2]),
               .I0(transfer_done2_clk90),
               .I1(transfer_done2_clk270)
              );
defparam    xdone2.INIT = 4'he;

LUT2  xdone3  (
               .O(transfer_done_int[3]),
               .I0(transfer_done3_clk90),
               .I1(transfer_done3_clk270)
              );
defparam    xdone3.INIT = 4'he;

FDR  xdone0_clk0  (
                    .Q(transfer_done0_clk0),
                    .C(clk0),
                    .R(sync_rst_xdone0_ck0),
                    .D(dqs_div)
                   );

FDR  xdone0_clk90  (
                     .Q(transfer_done0_clk90),
                     .C(clk90),
                     .R(sync_rst_clk90),
                     .D(transfer_done0_clk0)
                    );

FDR  xdone0_clk180  (
                      .Q(transfer_done0_clk180),
                      .C(clk180),
                      .R(sync_rst_xdone0_ck180),
                      .D(dqs_div)
                     );

FDR  xdone0_clk270  (
                      .Q(transfer_done0_clk270),
                      .C(clk270),
                      .R(sync_rst_clk270),
                      .D(transfer_done0_clk180)
                     );

LUT3  xdone0_rst90  (
                      .O(sync_rst_clk90),
                      .I0(reset90),
                      .I1(transfer_done0_clk270),
                      .I2(transfer_done0_clk90)
                     );
defparam    xdone0_rst90.INIT = 8'hfe;

LUT3  xdone0_rst270  (
                       .O(sync_rst_clk270),
                       .I0(reset270),
                       .I1(transfer_done0_clk270),
                       .I2(transfer_done0_clk90)
                      );
defparam    xdone0_rst270.INIT = 8'hfe;

FD  xdone1_clk90  (
                    .Q (transfer_done1_clk90),
                    .C (clk90),
                    .D (transfer_done0_clk270)
                   );

FD  xdone1_clk270  (
                     .Q(transfer_done1_clk270),
                     .C(clk270),
                     .D(transfer_done0_clk90)
                    );

FD  xdone2_clk90  (
                    .Q(transfer_done2_clk90),
                    .C(clk90),
                    .D(transfer_done1_clk270)
                   );

FD  xdone2_clk270  (
                     .Q(transfer_done2_clk270),
                     .C(clk270),
                     .D(transfer_done1_clk90)
                    );

FD  xdone3_clk90  (
                    .Q(transfer_done3_clk90),
                    .C(clk90),
                    .D(transfer_done2_clk270)
                   );

FD  xdone3_clk270  (
                     .Q(transfer_done3_clk270),
                     .C(clk270),
                     .D(transfer_done2_clk90)
                    );

endmodule