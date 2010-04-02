//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   data_path_iobs_32bit.v.v
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
`include  "ddr_defines.v"
`include "parameters_32bit_00.v"
module    data_path_iobs_32bit(
                      //inputs
                      clk,
  clk180,
  clk270,
                      dqs_reset,
                      dqs_enable,
                      ddr_dqs,
                      ddr_dq,
                      `ifdef DQS_n
                      ddr_dqs_n,
                      `endif
                      write_data_falling,
                      write_data_rising,
                      write_en_val,
                      clk90,
                      reset270_r,
                      data_mask_f,
                      data_mask_r,
                      //outputs
                      dqs_int_delay_in0,
                      dqs_int_delay_in1,
                      dqs_int_delay_in2,
                      dqs_int_delay_in3,
                      dq,
                      ddr_dm
                    );



// input/output port declarations
input         clk;
  input clk180;
  input clk270;
input    dqs_reset;
input    dqs_enable /* synthesis syn_keep = 1 */ ;
inout [3:0]   ddr_dqs;
`ifdef DQS_n
inout [3:0]   ddr_dqs_n;
`endif
inout [31:0]  ddr_dq;
input [31:0]  write_data_falling;
input [31:0]  write_data_rising;
input         write_en_val;
input         clk90;
input         reset270_r;
input [3:0]   data_mask_f;
input [3:0]   data_mask_r;
output        dqs_int_delay_in0;
output        dqs_int_delay_in1;
output        dqs_int_delay_in2;
output        dqs_int_delay_in3;
output [31:0] dq;
output [3:0]  ddr_dm;

`ifdef DQS_n
wire         dqs_enable_n;
wire [3:0]   ddr_dqs_n;
`endif

//***********************************************************************
// DQS IOB instantiations
//***********************************************************************


  ddr_dqs_iob ddr_dqs_iob0 (
                              .clk(clk),
      .clk180(clk180),
                              .ddr_dqs_reset(dqs_reset),
                              .ddr_dqs_enable(dqs_enable),
                              .ddr_dqs(ddr_dqs[0]),
                              `ifdef DQS_n
                              .ddr_dqs_n(ddr_dqs_n[0]),
                              `endif
                              .dqs(dqs_int_delay_in0)
                             );

  ddr_dqs_iob ddr_dqs_iob1  (
                              .clk(clk),
      .clk180(clk180),
                              .ddr_dqs_reset(dqs_reset),
                              .ddr_dqs_enable(dqs_enable),
                              .ddr_dqs(ddr_dqs[1]),
                              `ifdef DQS_n
                              .ddr_dqs_n(ddr_dqs_n[1]),
                              `endif
                              .dqs(dqs_int_delay_in1)
                             );

  ddr_dqs_iob ddr_dqs_iob2  (
                              .clk(clk),
                              .ddr_dqs_reset(dqs_reset),
      .clk180(clk180),
                              .ddr_dqs_enable(dqs_enable),
                              .ddr_dqs(ddr_dqs[2]),
                              `ifdef DQS_n
                              .ddr_dqs_n(ddr_dqs_n[2]),
                              `endif
                              .dqs(dqs_int_delay_in2)
                             );

  ddr_dqs_iob ddr_dqs_iob3  (
                              .clk(clk),
                              .ddr_dqs_reset(dqs_reset),
      .clk180(clk180),
                              .ddr_dqs_enable(dqs_enable),
                              .ddr_dqs(ddr_dqs[3]),
                              `ifdef DQS_n
                              .ddr_dqs_n(ddr_dqs_n[3]),
                              `endif
                              .dqs(dqs_int_delay_in3)
                             );


//***********************************************************************
// Dq IOB instantiations
//***********************************************************************                            );

ddr_dq_iob  ddr_dq_iob0 (
                            .ddr_dq_inout(ddr_dq[0]),
                            .write_data_rising(write_data_rising[0]),
                            .write_data_falling(write_data_falling[0]),
                            .read_data_in(dq[0]),
                            .clk90(clk90),
      .clk270(clk270),
                           .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob1 (
                            .ddr_dq_inout(ddr_dq[1]),
                            .write_data_rising(write_data_rising[1]),
                            .write_data_falling(write_data_falling[1]),
                            .read_data_in(dq[1]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob2 (
                            .ddr_dq_inout(ddr_dq[2]),
                            .write_data_rising(write_data_rising[2]),
                            .write_data_falling(write_data_falling[2]),
                            .read_data_in(dq[2]),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
      .clk270(clk270),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob3 (
                            .ddr_dq_inout(ddr_dq[3]),
                            .write_data_rising(write_data_rising[3]),
                            .write_data_falling(write_data_falling[3]),
                            .read_data_in(dq[3]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob4 (
                            .ddr_dq_inout(ddr_dq[4]),
                            .write_data_rising(write_data_rising[4]),
                            .write_data_falling(write_data_falling[4]),
                            .read_data_in(dq[4]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob5 (
                            .ddr_dq_inout(ddr_dq[5]),
                            .write_data_rising(write_data_rising[5]),
                            .write_data_falling(write_data_falling[5]),
                            .read_data_in(dq[5]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob6 (
                            .ddr_dq_inout(ddr_dq[6]),
                            .write_data_rising(write_data_rising[6]),
                            .write_data_falling(write_data_falling[6]),
                            .read_data_in(dq[6]),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
      .clk270(clk270),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob7 (
                            .ddr_dq_inout(ddr_dq[7]),
                            .write_data_rising(write_data_rising[7]),
                            .write_data_falling(write_data_falling[7]),
                            .read_data_in(dq[7]),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
      .clk270(clk270),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob8 (
                            .ddr_dq_inout(ddr_dq[8]),
                            .write_data_rising(write_data_rising[8]),
                            .write_data_falling(write_data_falling[8]),
                            .read_data_in(dq[8]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob9 (
                            .ddr_dq_inout(ddr_dq[9]),
                            .write_data_rising(write_data_rising[9]),
                            .write_data_falling(write_data_falling[9]),
                            .read_data_in(dq[9]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob10(
                            .ddr_dq_inout(ddr_dq[10]),
                            .write_data_rising(write_data_rising[10]),
                            .write_data_falling(write_data_falling[10]),
                            .read_data_in(dq[10]),
      .clk270(clk270),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob11(
                            .ddr_dq_inout(ddr_dq[11]),
                            .write_data_rising(write_data_rising[11]),
                            .write_data_falling(write_data_falling[11]),
                            .read_data_in(dq[11]),
      .clk270(clk270),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob12(
                            .ddr_dq_inout(ddr_dq[12]),
                            .write_data_rising(write_data_rising[12]),
                            .write_data_falling(write_data_falling[12]),
                            .read_data_in(dq[12]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob13(
                            .ddr_dq_inout(ddr_dq[13]),
                            .write_data_rising(write_data_rising[13]),
                            .write_data_falling(write_data_falling[13]),
                            .read_data_in(dq[13]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob14(
                            .ddr_dq_inout(ddr_dq[14]),
                            .write_data_rising(write_data_rising[14]),
                            .write_data_falling(write_data_falling[14]),
                            .read_data_in(dq[14]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob15(
                            .ddr_dq_inout(ddr_dq[15]),
                            .write_data_rising(write_data_rising[15]),
                            .write_data_falling(write_data_falling[15]),
                            .read_data_in(dq[15]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob16(
                            .ddr_dq_inout(ddr_dq[16]),
                            .write_data_rising(write_data_rising[16]),
                            .write_data_falling(write_data_falling[16]),
                            .read_data_in(dq[16]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob17(
                            .ddr_dq_inout(ddr_dq[17]),
                            .write_data_rising(write_data_rising[17]),
                            .write_data_falling(write_data_falling[17]),
                            .read_data_in(dq[17]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob18(
                            .ddr_dq_inout(ddr_dq[18]),
                            .write_data_rising(write_data_rising[18]),
                            .write_data_falling(write_data_falling[18]),
                            .read_data_in(dq[18]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob19(
                            .ddr_dq_inout(ddr_dq[19]),
                            .write_data_rising(write_data_rising[19]),
                            .write_data_falling(write_data_falling[19]),
                            .read_data_in(dq[19]),
                            .clk90(clk90),
       .clk270(clk270),
                           .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob20(
                            .ddr_dq_inout(ddr_dq[20]),
                            .write_data_rising(write_data_rising[20]),
                            .write_data_falling(write_data_falling[20]),
                            .read_data_in(dq[20]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );


ddr_dq_iob  ddr_dq_iob21(
                            .ddr_dq_inout(ddr_dq[21]),
                            .write_data_rising(write_data_rising[21]),
                            .write_data_falling(write_data_falling[21]),
                            .read_data_in(dq[21]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob22(
                            .ddr_dq_inout(ddr_dq[22]),
                            .write_data_rising(write_data_rising[22]),
                            .write_data_falling(write_data_falling[22]),
                            .read_data_in(dq[22]),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
      .clk270(clk270),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob23(
                            .ddr_dq_inout(ddr_dq[23]),
                            .write_data_rising(write_data_rising[23]),
                            .write_data_falling(write_data_falling[23]),
                            .read_data_in(dq[23]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob24(
                            .ddr_dq_inout(ddr_dq[24]),
                            .write_data_rising(write_data_rising[24]),
                            .write_data_falling(write_data_falling[24]),
                            .read_data_in(dq[24]),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
      .clk270(clk270),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob25(
                            .ddr_dq_inout(ddr_dq[25]),
                            .write_data_rising(write_data_rising[25]),
                            .write_data_falling(write_data_falling[25]),
                            .read_data_in(dq[25]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );


ddr_dq_iob  ddr_dq_iob26(
                            .ddr_dq_inout(ddr_dq[26]),
                            .write_data_rising(write_data_rising[26]),
                            .write_data_falling(write_data_falling[26]),
                            .read_data_in(dq[26]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob27(
                            .ddr_dq_inout(ddr_dq[27]),
                            .write_data_rising(write_data_rising[27]),
                            .write_data_falling(write_data_falling[27]),
                            .read_data_in(dq[27]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob28(
                            .ddr_dq_inout(ddr_dq[28]),
                            .write_data_rising(write_data_rising[28]),
                            .write_data_falling(write_data_falling[28]),
                            .read_data_in(dq[28]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob29(
                            .ddr_dq_inout(ddr_dq[29]),
                            .write_data_rising(write_data_rising[29]),
                            .write_data_falling(write_data_falling[29]),
                            .read_data_in(dq[29]),
      .clk270(clk270),
                            .clk90(clk90),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob30(
                            .ddr_dq_inout(ddr_dq[30]),
                            .write_data_rising(write_data_rising[30]),
                            .write_data_falling(write_data_falling[30]),
                            .read_data_in(dq[30]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );

ddr_dq_iob  ddr_dq_iob31(
                            .ddr_dq_inout(ddr_dq[31]),
                            .write_data_rising(write_data_rising[31]),
                            .write_data_falling(write_data_falling[31]),
                            .read_data_in(dq[31]),
                            .clk90(clk90),
      .clk270(clk270),
                            .write_en_val(write_en_val),
                            .reset(reset270_r)
                           );



//***********************************************************************
//  DM IOB instantiations
//***********************************************************************


ddr2_dm_32bit	ddr2_dm0	(
                    .ddr_dm(ddr_dm),
                    .mask_falling(data_mask_f),
                    .mask_rising(data_mask_r),
      .clk270(clk270),
                    .clk90(clk90)
                   );





endmodule
