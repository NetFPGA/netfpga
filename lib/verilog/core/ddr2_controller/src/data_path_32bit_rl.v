//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   data_path_32bit_rl.v.v
//
//  Description :     This module comprises the write and read data paths for the
//                    DDR1 memory interface. The write data along with write enable
//                    signals are forwarded to the DDR IOB FFs. The read data is
//                    captured in CLB FFs and finally input to FIFOs.
//
//
//  Date - revision : 10/16/2003
//
//  Author :          Maria George (Modified by Padmaja Sannala)
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
module    data_path_32bit_rl
   (
     //inputs
     user_input_data,
user_data_mask,
     clk,
     clk90,
  clk180,
  clk270,
     reset,
     reset90,
     reset180,
     reset270,
     write_enable,
     rst_dqs_div,
     delay_sel,
     dqs_int_delay_in0,
     dqs_int_delay_in1,
     dqs_int_delay_in2,
     dqs_int_delay_in3,
     dq,
     //outputs
     u_data_val,
     user_output_data,
     write_en_val,
     reset270_r_val,
     data_mask_f,
     data_mask_r,
     write_data_falling,
     write_data_rising
     );

//Input/Output declarations
input [63:0]   user_input_data;
input [((`mask_width)-1):0] user_data_mask;
input          clk;
input          clk90;
  input clk180;
  input clk270;
input          reset;
input          reset90;
input          reset180;
input          reset270;
input          write_enable;
input          rst_dqs_div;
input [4:0]    delay_sel;
input          dqs_int_delay_in0;
input          dqs_int_delay_in1;
input          dqs_int_delay_in2;
input          dqs_int_delay_in3;
input [31:0]   dq;

output         u_data_val;
output [63:0]  user_output_data;
output         write_en_val;
output         reset270_r_val;
output [((`mask_width/2)-1):0]   data_mask_f;
output [((`mask_width/2)-1):0]   data_mask_r;
output [31:0]  write_data_falling;
output [31:0]  write_data_rising;


//Internal signals declarations
 wire       reset_r;
 wire       reset90_r;
 wire       reset180_r;
 wire       reset270_r;

 wire [3:0]     fifo_00_rd_addr;
 wire [3:0]     fifo_01_rd_addr;
 wire [3:0]     fifo_02_rd_addr;
 wire [3:0]     fifo_03_rd_addr;
 wire [3:0]     fifo_10_rd_addr;
 wire [3:0]     fifo_11_rd_addr;
 wire [3:0]     fifo_12_rd_addr;
 wire [3:0]     fifo_13_rd_addr;
 wire [3:0]     fifo_20_rd_addr;
 wire [3:0]     fifo_21_rd_addr;
 wire [3:0]     fifo_22_rd_addr;
 wire [3:0]     fifo_23_rd_addr;
 wire [3:0]     fifo_30_rd_addr;
 wire [3:0]     fifo_31_rd_addr;
 wire [3:0]     fifo_32_rd_addr;
 wire [3:0]     fifo_33_rd_addr;

 wire       read_valid_data_1;
 wire       read_valid_data_2;
 wire [3:0] transfer_done_0;
 wire [3:0] transfer_done_1;
 wire [3:0] transfer_done_2;
 wire [3:0] transfer_done_3;
 wire [3:0] fifo_00_wr_addr;
 wire [3:0] fifo_01_wr_addr;
 wire [3:0] fifo_02_wr_addr;
 wire [3:0] fifo_03_wr_addr;
 wire [3:0] fifo_10_wr_addr;
 wire [3:0] fifo_11_wr_addr;
 wire [3:0] fifo_12_wr_addr;
 wire [3:0] fifo_13_wr_addr;
 wire [3:0] fifo_20_wr_addr;
 wire [3:0] fifo_21_wr_addr;
 wire [3:0] fifo_22_wr_addr;
 wire [3:0] fifo_23_wr_addr;
 wire [3:0] fifo_30_wr_addr;
 wire [3:0] fifo_31_wr_addr;
 wire [3:0] fifo_32_wr_addr;
 wire [3:0] fifo_33_wr_addr;
 wire [3:0] dqs_delayed_col0;
 wire [3:0] dqs_delayed_col1;
 wire [3:0] dqs_div_col0;
 wire [3:0] dqs_div_col1;
 wire       next_state;



assign reset270_r_val = reset270_r;

data_read_32bit_rl	data_read0
       (
           .clk(clk),
           .clk90(clk90),
           .reset90_r(reset90_r),
           .reset270_r(reset270_r),
           .dq(dq),
           .read_valid_data_1(read_valid_data_1),
           .read_valid_data_2(read_valid_data_2),
           .transfer_done_0(transfer_done_0),
           .transfer_done_1(transfer_done_1),
           .transfer_done_2(transfer_done_2),
           .transfer_done_3(transfer_done_3),
           .fifo_00_wr_addr(fifo_00_wr_addr),
           .fifo_01_wr_addr(fifo_01_wr_addr),
           .fifo_02_wr_addr(fifo_02_wr_addr),
           .fifo_03_wr_addr(fifo_03_wr_addr),
           .fifo_10_wr_addr(fifo_10_wr_addr),
           .fifo_11_wr_addr(fifo_11_wr_addr),
           .fifo_12_wr_addr(fifo_12_wr_addr),
           .fifo_13_wr_addr(fifo_13_wr_addr),
           .fifo_20_wr_addr(fifo_20_wr_addr),
           .fifo_21_wr_addr(fifo_21_wr_addr),
           .fifo_22_wr_addr(fifo_22_wr_addr),
           .fifo_23_wr_addr(fifo_23_wr_addr),
           .fifo_30_wr_addr(fifo_30_wr_addr),
           .fifo_31_wr_addr(fifo_31_wr_addr),
           .fifo_32_wr_addr(fifo_32_wr_addr),
           .fifo_33_wr_addr(fifo_33_wr_addr),
           .dqs_delayed_col0(dqs_delayed_col0),
           .dqs_delayed_col1(dqs_delayed_col1),
           .dqs_div_col0(dqs_div_col0),
           .dqs_div_col1(dqs_div_col1),
           .fifo_00_rd_addr(fifo_00_rd_addr),
           .fifo_01_rd_addr(fifo_01_rd_addr),
           .fifo_02_rd_addr(fifo_02_rd_addr),
           .fifo_03_rd_addr(fifo_03_rd_addr),
           .fifo_10_rd_addr(fifo_10_rd_addr),
           .fifo_11_rd_addr(fifo_11_rd_addr),
           .fifo_12_rd_addr(fifo_12_rd_addr),
           .fifo_13_rd_addr(fifo_13_rd_addr),
           .fifo_20_rd_addr(fifo_20_rd_addr),
           .fifo_21_rd_addr(fifo_21_rd_addr),
           .fifo_22_rd_addr(fifo_22_rd_addr),
           .fifo_23_rd_addr(fifo_23_rd_addr),
           .fifo_30_rd_addr(fifo_30_rd_addr),
           .fifo_31_rd_addr(fifo_31_rd_addr),
           .fifo_32_rd_addr(fifo_32_rd_addr),
           .fifo_33_rd_addr(fifo_33_rd_addr),
           .next_state_val(next_state),
           .user_output_data(user_output_data)
         );


data_read_controller_32bit_rl	data_read_controller0
       (
            .clk(clk),
            .clk90(clk90),
  .clk180(clk180),
  .clk270(clk270),
            .reset_r(reset_r),
            .reset90_r(reset90_r),
            .reset180_r(reset180_r),
            .reset270_r(reset270_r),
            .rst_dqs_div(rst_dqs_div),
            .delay_sel(delay_sel),
            .dqs_int_delay_in0(dqs_int_delay_in0),
            .dqs_int_delay_in1(dqs_int_delay_in1),
            .dqs_int_delay_in2(dqs_int_delay_in2),
            .dqs_int_delay_in3(dqs_int_delay_in3),
            .next_state(next_state),
            .fifo_00_rd_addr(fifo_00_rd_addr),
            .fifo_01_rd_addr(fifo_01_rd_addr),
            .fifo_02_rd_addr(fifo_02_rd_addr),
            .fifo_03_rd_addr(fifo_03_rd_addr),
            .fifo_10_rd_addr(fifo_10_rd_addr),
            .fifo_11_rd_addr(fifo_11_rd_addr),
            .fifo_12_rd_addr(fifo_12_rd_addr),
            .fifo_13_rd_addr(fifo_13_rd_addr),
            .fifo_20_rd_addr(fifo_20_rd_addr),
            .fifo_21_rd_addr(fifo_21_rd_addr),
            .fifo_22_rd_addr(fifo_22_rd_addr),
            .fifo_23_rd_addr(fifo_23_rd_addr),
            .fifo_30_rd_addr(fifo_30_rd_addr),
            .fifo_31_rd_addr(fifo_31_rd_addr),
            .fifo_32_rd_addr(fifo_32_rd_addr),
            .fifo_33_rd_addr(fifo_33_rd_addr),
            .u_data_val     (u_data_val),
            .read_valid_data_1_val(read_valid_data_1),
            .read_valid_data_2_val(read_valid_data_2),
            .transfer_done_0_val(transfer_done_0),
            .transfer_done_1_val(transfer_done_1),
            .transfer_done_2_val(transfer_done_2),
            .transfer_done_3_val(transfer_done_3),
            .fifo_00_wr_addr_val(fifo_00_wr_addr),
            .fifo_01_wr_addr_val(fifo_01_wr_addr),
            .fifo_02_wr_addr_val(fifo_02_wr_addr),
            .fifo_03_wr_addr_val(fifo_03_wr_addr),
            .fifo_10_wr_addr_val(fifo_10_wr_addr),
            .fifo_11_wr_addr_val(fifo_11_wr_addr),
            .fifo_12_wr_addr_val(fifo_12_wr_addr),
            .fifo_13_wr_addr_val(fifo_13_wr_addr),
            .fifo_20_wr_addr_val(fifo_20_wr_addr),
            .fifo_21_wr_addr_val(fifo_21_wr_addr),
            .fifo_22_wr_addr_val(fifo_22_wr_addr),
            .fifo_23_wr_addr_val(fifo_23_wr_addr),
            .fifo_30_wr_addr_val(fifo_30_wr_addr),
            .fifo_31_wr_addr_val(fifo_31_wr_addr),
            .fifo_32_wr_addr_val(fifo_32_wr_addr),
            .fifo_33_wr_addr_val(fifo_33_wr_addr),
            .dqs_delayed_col0_val(dqs_delayed_col0),
            .dqs_delayed_col1_val(dqs_delayed_col1),
            .dqs_div_col0_val(dqs_div_col0),
            .dqs_div_col1_val(dqs_div_col1)
         );


data_write_32bit	data_write0
       (
          .user_input_data(user_input_data),
          .user_data_mask(user_data_mask),
          .clk90(clk90),
  .clk270(clk270),
          .reset90_r(reset90_r),
          .reset270_r(reset270_r),
          .write_enable(write_enable),
          .write_en_val(write_en_val),
          .write_data_falling(write_data_falling),
          .write_data_rising(write_data_rising),
          .data_mask_f(data_mask_f),
          .data_mask_r(data_mask_r)
         );

data_path_rst    data_path_rst0
       (
          .clk(clk),
          .clk90(clk90),
  .clk180(clk180),
  .clk270(clk270),
          .reset(reset),
          .reset90(reset90),
          .reset180(reset180),
          .reset270(reset270),
          .reset_r(reset_r),
          .reset90_r(reset90_r),
          .reset180_r(reset180_r),
          .reset270_r(reset270_r)
         );


endmodule

























































































































































































































































































































































































































































































































































































































































































































































