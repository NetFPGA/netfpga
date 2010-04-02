//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       v2p_ddr_iob.v
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

`include "parameters_32bit_00.v"

`include  "ddr_defines.v"

module    iobs_32bit_00(
                    //inputs
                    clk,
                    clk90,
  clk180,
  clk270,
                    ddr_rasb_cntrl,
                    ddr_casb_cntrl,
                    ddr_ODT_cntrl,
                    ddr_web_cntrl,
                    ddr_cke_cntrl,
                    ddr_csb_cntrl,
                    ddr_address_cntrl,
                    ddr_ba_cntrl,
                    rst_dqs_div_int,
                    dqs_reset,
                    dqs_enable,
                    ddr_dqs,
                    `ifdef DQS_n
                    ddr_dqs_n,
                    `endif
                    ddr_dq,
                    write_data_falling,
                    write_data_rising,
                    write_en_val,
                    reset270_r,
                    data_mask_f,
                    data_mask_r,
                    //outputs
                    ddr2_clk0,
                    ddr2_clk0b,
                    ddr2_clk1,
                    ddr2_clk1b,
                    ddr_rasb,
                    ddr_casb,
                    ddr_web,
                    ddr_ba,
                    ddr_address,
                    ddr_cke,
                    ddr_csb,
             ddr_ODT0,
                    rst_dqs_div,
                    rst_dqs_div_in,
                    rst_dqs_div_out,
                    dqs_int_delay_in0,
                    dqs_int_delay_in1,
                    dqs_int_delay_in2,
                    dqs_int_delay_in3,
                    dq,
                    ddr_dm
                   );



//input/output declarations

input        clk;
input        clk90;
  input clk180;
  input clk270;
input        ddr_rasb_cntrl;
input        ddr_casb_cntrl;
input        ddr_web_cntrl;
input        ddr_cke_cntrl;
input        ddr_csb_cntrl;
input        ddr_ODT_cntrl;
input [`row_address-1:0] ddr_address_cntrl;
input [`bank_address-1:0]  ddr_ba_cntrl;
input        rst_dqs_div_int;
input   dqs_reset;
input   dqs_enable;
inout [3:0]  ddr_dqs;
`ifdef DQS_n
inout [3:0]   ddr_dqs_n;
`endif
inout [31:0] ddr_dq;
input [31:0] write_data_falling;
input [31:0] write_data_rising;
input        write_en_val;
input        reset270_r;
input [3:0]  data_mask_f;
input [3:0]  data_mask_r;
output       ddr2_clk0;
output       ddr2_clk0b;
output       ddr2_clk1;
output       ddr2_clk1b;
output       ddr_rasb;
output       ddr_casb;
output       ddr_web;
output [`bank_address-1:0] ddr_ba;
output [`row_address-1:0]ddr_address;
output       ddr_cke;
output       ddr_csb;
output             ddr_ODT0;
output       rst_dqs_div;
input        rst_dqs_div_in;
output       rst_dqs_div_out;
output       dqs_int_delay_in0;
output       dqs_int_delay_in1;
output       dqs_int_delay_in2;
output       dqs_int_delay_in3;
output[31:0] dq;
output[3:0]  ddr_dm;

// modules instantiations

infrastructure_iobs_32bit    infrastructure_iobs0   (
                                           .clk0(clk),
                                           .clk90(clk90),
			  .clk180(clk180),
			  .clk270(clk270),
                                           .ddr2_clk0(ddr2_clk0),
                                           .ddr2_clk0b(ddr2_clk0b),
                                           .ddr2_clk1(ddr2_clk1),
                                           .ddr2_clk1b(ddr2_clk1b)
                                         );

controller_iobs_32bit_00   controller_iobs0   (
                                  .clk0(clk),
			  .clk180(clk180),
                                  .ddr_rasb_cntrl(ddr_rasb_cntrl),
                                  .ddr_casb_cntrl(ddr_casb_cntrl),
                                  .ddr_web_cntrl(ddr_web_cntrl),
                                  .ddr_cke_cntrl(ddr_cke_cntrl),
                                  .ddr_csb_cntrl(ddr_csb_cntrl),
                                  .ddr_ODT_cntrl(ddr_ODT_cntrl),
                                  .ddr_address_cntrl(ddr_address_cntrl[`row_address-1:0]),
                                  .ddr_ba_cntrl(ddr_ba_cntrl[`bank_address-1:0]),
                                  .rst_dqs_div_int(rst_dqs_div_int),
                                  .ddr_rasb(ddr_rasb),
                                  .ddr_casb(ddr_casb),
                                  .ddr_web(ddr_web),
                                  .ddr_ba(ddr_ba[`bank_address-1:0]),
                                  .ddr_address(ddr_address[`row_address-1:0]),
                                  .ddr_cke(ddr_cke),
                                  .ddr_csb(ddr_csb),
             .ddr_ODT0 (ddr_ODT0),
                                  .rst_dqs_div(rst_dqs_div),
                                  .rst_dqs_div_in(rst_dqs_div_in),
    	   			  .rst_dqs_div_out(rst_dqs_div_out)
                                 );

data_path_iobs_32bit    data_path_iobs0   (
                              .clk(clk),
			  .clk180(clk180),
			  .clk270(clk270),
                              .dqs_reset(dqs_reset),
                              .dqs_enable(dqs_enable),
                              .ddr_dqs(ddr_dqs),
                              `ifdef DQS_n
                              .ddr_dqs_n(ddr_dqs_n),
                               `endif
                              .ddr_dq(ddr_dq),
                              .write_data_falling(write_data_falling[31:0]),
                              .write_data_rising(write_data_rising[31:0]),
                              .write_en_val(write_en_val),
                              .clk90(clk90),
                              .reset270_r(reset270_r),
                              .data_mask_f(data_mask_f[3:0]),
                              .data_mask_r(data_mask_r[3:0]),
                              .dqs_int_delay_in0(dqs_int_delay_in0),
                              .dqs_int_delay_in1(dqs_int_delay_in1),
                              .dqs_int_delay_in2(dqs_int_delay_in2),
                              .dqs_int_delay_in3(dqs_int_delay_in3),
                              .dq(dq[31:0]),
                              .ddr_dm(ddr_dm[3:0])
                          );





 endmodule
