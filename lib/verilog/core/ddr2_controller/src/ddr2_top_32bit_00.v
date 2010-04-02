//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//  XAPP 253 - Synthesizable DDR SDRAM Controller
//
//*******************************************************************************
//
//    File   name   :   ddr2_top_32bit_00.v
//
//  Description :
//                    Main DDR SDRAM controller block. This includes the following
//                    features:
//                    - The main controller state machine that controlls the
//                    initialization process upon power up, as well as the
//                    read, write, and refresh commands.
//                    - handles the data path during READ and WRITEs.
//                    - Generates control signals for other modules, including the
//                      data strobe(DQS) signal
//
//  Date - revision : 05/01/2002
//
//  Author :          Lakshmi Gopalakrishnan ( Modified by Sailaja)
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
`include "ddr_defines.v"

module    ddr2_top_32bit_00
   (
     dip1,
     dip3,
       clk_int,
       clk90_int,
  clk180,
  clk270,
       delay_sel_val,
       sys_rst90,
       sys_rst180,
       sys_rst270,
       rst_dqs_div_in,
     reset_in,
     user_input_data,
user_data_mask,
      user_input_address,
      user_bank_address,
     user_config_register1,
     user_config_register2,
     user_command_register,
     burst_done,
     ddr_dqs,
     `ifdef DQS_n
      ddr_dqs_n,
     `endif
     ddr_dq,
     rst_dqs_div_out,
     user_output_data,
     user_data_valid,
     user_cmd_ack,
     init_val,
     ar_done,
     ddr_cke,
     ddr_csb,
     ddr_rasb,
     ddr_casb,
     ddr_web,
        ddr_ODT0,
     ddr_dm,
     ddr_ba,
     ddr_address,
auto_ref_req,
wait_200us,
     ddr2_clk0,
     ddr2_clk0b,
     ddr2_clk1,
     ddr2_clk1b,
       sys_rst
     );



//Input/Output declarations
input         dip1;
 input         dip3;
  input clk180;
  input clk270;
 input         rst_dqs_div_in;
 input       clk_int;
input       clk90_int;
input       reset_in;
input  [4:0] delay_sel_val;
input       sys_rst;
input       sys_rst90;
input       sys_rst180;
input       sys_rst270;
input [63:0] user_input_data;
input [(`mask_width-1):0] user_data_mask;
 input [((`row_address + `column_address)-1):0]  user_input_address;
 input [`bank_address-1:0]   user_bank_address;
 input [14:0]  user_config_register1;
 input [12:0]  user_config_register2;
 input [3:0]   user_command_register;
 input         burst_done;

inout [3:0]    ddr_dqs;
`ifdef DQS_n
inout [3:0]   ddr_dqs_n;
`endif
inout [31:0]   ddr_dq;

output     rst_dqs_div_out;

output [63:0]user_output_data;

output     user_data_valid;
output     user_cmd_ack;

output     init_val;
output     ar_done;
output     ddr_cke;
output     ddr_csb;
output    auto_ref_req;
input    wait_200us;
output     ddr_rasb;
output     ddr_casb;
output     ddr_web;
output     ddr_ODT0;

output [((`mask_width/2)-1):0] ddr_dm;
output [`bank_address-1:0] ddr_ba;
output [`row_address-1:0]ddr_address;

output     ddr2_clk0;
output     ddr2_clk0b;
output     ddr2_clk1;
output     ddr2_clk1b;


//Internal Signal declarations
wire rst_calib;
wire [4:0] delay_sel;
wire sys_rst;
wire sys_rst90;
wire sys_rst180;
wire sys_rst270;
wire clk_int;
wire clk90_int;


wire write_enable;
wire dqs_div_rst;
wire dqs_enable;
wire  dqs_reset;
wire dqs_int_delay_in0;
wire dqs_int_delay_in1;
wire dqs_int_delay_in2;
wire dqs_int_delay_in3;
wire [31:0] dq;
wire u_data_val;
wire write_en_val;
wire reset270_r;
wire [((`mask_width/2)-1):0] data_mask_f;
wire [((`mask_width/2)-1):0] data_mask_r;
wire [31:0] write_data_falling;
wire [31:0] write_data_rising;

wire ddr_rasb_cntrl;
wire ddr_casb_cntrl;
wire ddr_web_cntrl;
wire [`bank_address-1:0] ddr_ba_cntrl;
wire [`row_address-1:0] ddr_address_cntrl;
wire ddr_cke_cntrl;
wire ddr_csb_cntrl;
wire ddr_ODT_cntrl;
wire rst_dqs_div_int;




infrastructure infrastructure0
(
                                         .sys_rst(sys_rst),
                                         .clk_int(clk_int),
                                         .rst_calib1(rst_calib),
                                         .delay_sel_val(delay_sel_val),
                                         .delay_sel_val1_val(delay_sel)
                                          );


controller_32bit_00  controller0        (
.auto_ref_req      (auto_ref_req),
.wait_200us(wait_200us),
                                   .dip1(dip1),
                                   .dip3(dip3),
                                   .clk(clk_int),
			  .clk180(clk180),
                                   .rst0(sys_rst),
                                   .rst180(sys_rst180),
                                   .address(user_input_address),
                                    .bank_address(user_bank_address),
                                   .config_register1(user_config_register1),
                                   .config_register2(user_config_register2),
                                   .command_register(user_command_register),
                                   .burst_done(burst_done),
                                   .ddr_rasb_cntrl(ddr_rasb_cntrl),
                                   .ddr_casb_cntrl(ddr_casb_cntrl),
                                   .ddr_web_cntrl (ddr_web_cntrl),
                                   .ddr_ba_cntrl(ddr_ba_cntrl),
                                   .ddr_address_cntrl(ddr_address_cntrl),
                                   .ddr_cke_cntrl(ddr_cke_cntrl),
                                   .ddr_csb_cntrl(ddr_csb_cntrl),
                                   .ddr_ODT_cntrl(ddr_ODT_cntrl),
                                   .dqs_enable(dqs_enable),
                                   .dqs_reset(dqs_reset),
                                   .write_enable(write_enable),
                                   .rst_calib(rst_calib),
                                   .rst_dqs_div_int(rst_dqs_div_int),
                                   .cmd_ack(user_cmd_ack),
                                   .init(init_val),
                                   .ar_done(ar_done)
                                  );

data_path_32bit_rl	data_path0	(
                                 .user_input_data (user_input_data),
                                 .user_data_mask(user_data_mask),
                                  .clk(clk_int),
                                 .clk90(clk90_int),
			  .clk180(clk180),
			  .clk270(clk270),                                 .reset(sys_rst),
                                 .reset90(sys_rst90),
                                 .reset180(sys_rst180),
                                 .reset270(sys_rst270),
                                 .write_enable (write_enable),
                                 .rst_dqs_div(dqs_div_rst),
                                 .delay_sel(delay_sel),
                                 .dqs_int_delay_in0(dqs_int_delay_in0),
                                 .dqs_int_delay_in1(dqs_int_delay_in1),
                                 .dqs_int_delay_in2(dqs_int_delay_in2),
                                 .dqs_int_delay_in3(dqs_int_delay_in3),
                                 .dq(dq),
                                 .u_data_val(user_data_valid),
                                 .user_output_data(user_output_data),
                                 .write_en_val (write_en_val),
                                 .reset270_r_val(reset270_r),
                                 .data_mask_f(data_mask_f),
                                 .data_mask_r(data_mask_r),
                                 .write_data_falling(write_data_falling),
                                 .write_data_rising(write_data_rising)
                                );


iobs_32bit_00	iobs0
                   (
                     .clk(clk_int),
                     .clk90(clk90_int),
			  .clk180(clk180),
			  .clk270(clk270),
                     .ddr_rasb_cntrl(ddr_rasb_cntrl),
                     .ddr_casb_cntrl(ddr_casb_cntrl),
                     .ddr_web_cntrl(ddr_web_cntrl),
                     .ddr_cke_cntrl(ddr_cke_cntrl),
                     .ddr_csb_cntrl(ddr_csb_cntrl),
                     .ddr_ODT_cntrl(ddr_ODT_cntrl),
                     .ddr_address_cntrl(ddr_address_cntrl),
                     .ddr_ba_cntrl(ddr_ba_cntrl),
                     .rst_dqs_div_int( rst_dqs_div_int),
                     .dqs_reset(dqs_reset),
                     .dqs_enable(dqs_enable),
                     .ddr_dqs(ddr_dqs),
                     `ifdef DQS_n
                     .ddr_dqs_n(ddr_dqs_n),
                     `endif
                     .ddr_dq(ddr_dq),
                     .write_data_falling(write_data_falling),
                     .write_data_rising(write_data_rising),
                     .write_en_val(write_en_val),
                     .reset270_r(reset270_r),
                     .data_mask_f(data_mask_f),
                     .data_mask_r(data_mask_r),
                     .ddr2_clk0(ddr2_clk0),
                     .ddr2_clk0b(ddr2_clk0b),
                     .ddr2_clk1(ddr2_clk1),
                     .ddr2_clk1b(ddr2_clk1b),
                     .ddr_rasb(ddr_rasb),
                     .ddr_casb(ddr_casb),
                     .ddr_web(ddr_web),
                     .ddr_ba(ddr_ba),
                     .ddr_address (ddr_address),
                     .ddr_cke(ddr_cke),
                     .ddr_csb(ddr_csb),
        .ddr_ODT0 (ddr_ODT0),
                     .rst_dqs_div(dqs_div_rst),
                     .rst_dqs_div_in(rst_dqs_div_in),
       		     .rst_dqs_div_out(rst_dqs_div_out),
                     .dqs_int_delay_in0(dqs_int_delay_in0),
                     .dqs_int_delay_in1(dqs_int_delay_in1),
                     .dqs_int_delay_in2(dqs_int_delay_in2),
                     .dqs_int_delay_in3(dqs_int_delay_in3),
                     .dq(dq),
                     .ddr_dm(ddr_dm)
                    );

endmodule

