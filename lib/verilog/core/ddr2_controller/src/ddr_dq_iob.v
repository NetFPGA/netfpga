//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       ddr_dq_iob.v
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

module ddr_dq_iob(
	           clk90,
  clk270,
	           ddr_dq_inout,
	           write_data_falling,
	           write_data_rising,
	           read_data_in,
	           write_en_val,
	           reset
                   );

   input          clk90;
  input clk270;
   input 	        write_data_falling;
   input 	        write_data_rising;
   input          write_en_val;
   input          reset;

   inout          ddr_dq_inout;

   output         read_data_in;

   wire           ddr_en;   // Tri-state enable signal
   wire           ddr_dq_q; // Data output intermediate signal
   wire           ddr_dq_o; // Data output intermediate signal
   wire           GND;
   wire           clock_en;
   wire           enable_b;

   assign clock_en = 1'b1;
   assign GND      = 1'b0;
   assign enable_b = ~write_en_val;

// Transmission data path

 wire write_data_rising1;
 wire write_data_falling1;

assign #1 write_data_rising1 = write_data_rising;
assign #1 write_data_falling1 = write_data_falling;

FDDRRSE DDR_OUT  (
                  .Q(ddr_dq_q),
                  .C0(clk270),
                  .C1(clk90),
                  .CE(clock_en),
                  .D0(write_data_rising1),
                  .D1(write_data_falling1),
                  .R(GND),
                  .S(GND)
                 );

FDCE  DQ_T  (
             .D(enable_b),
             .CLR(reset),
             .C(clk270),
             .Q(ddr_en),
             .CE(clock_en)
            );


OBUFT  DQ_OBUFT  (
                  .I(ddr_dq_q),
                  .T(ddr_en),
                  .O(ddr_dq_inout)
                 );

// Receive data path

IBUF  DQ_IBUF  (
                .I(ddr_dq_inout),
                .O(read_data_in)
               );


 endmodule