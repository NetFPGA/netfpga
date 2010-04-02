//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   data_read_32bit_rl.v.v
//
//  Description :     This module comprises the write and read data paths for the
//                    DDR1 memory interface. The read data is
//                    captured in CLB FFs and finally input to FIFOs.
//
//
//  Date - revision : 10/16/2003
//
//  Author :          Maria George (modified by Padmaja Sannala)
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
module    data_read_32bit_rl
   (
     //inputs
     clk,
     clk90,
     reset90_r,
     reset270_r,
     dq,
     read_valid_data_1,
     read_valid_data_2,
     transfer_done_0,
     transfer_done_1,
     transfer_done_2,
     transfer_done_3,
     fifo_00_wr_addr,
     fifo_01_wr_addr,
     fifo_02_wr_addr,
     fifo_03_wr_addr,
     fifo_10_wr_addr,
     fifo_11_wr_addr,
     fifo_12_wr_addr,
     fifo_13_wr_addr,
     fifo_20_wr_addr,
     fifo_21_wr_addr,
     fifo_22_wr_addr,
     fifo_23_wr_addr,
     fifo_30_wr_addr,
     fifo_31_wr_addr,
     fifo_32_wr_addr,
     fifo_33_wr_addr,
     dqs_delayed_col0,
     dqs_delayed_col1,
     dqs_div_col0,
     dqs_div_col1,
     fifo_00_rd_addr,
     fifo_01_rd_addr,
     fifo_02_rd_addr,
     fifo_03_rd_addr,
     fifo_10_rd_addr,
     fifo_11_rd_addr,
     fifo_12_rd_addr,
     fifo_13_rd_addr,
     fifo_20_rd_addr,
     fifo_21_rd_addr,
     fifo_22_rd_addr,
     fifo_23_rd_addr,
     fifo_30_rd_addr,
     fifo_31_rd_addr,
     fifo_32_rd_addr,
     fifo_33_rd_addr,
     //outputs
     next_state_val,
     user_output_data
     );

//input/output declarations
input           clk;
input           clk90;
input           reset90_r;
input           reset270_r;
input [31:0]    dq;
input           read_valid_data_1;
input           read_valid_data_2;
input [3:0]     transfer_done_0;
input [3:0]     transfer_done_1;
input [3:0]     transfer_done_2;
input [3:0]     transfer_done_3;
input [3:0]     fifo_00_wr_addr;
input [3:0]     fifo_01_wr_addr;
input [3:0]     fifo_02_wr_addr;
input [3:0]     fifo_03_wr_addr;
input [3:0]     fifo_10_wr_addr;
input [3:0]     fifo_11_wr_addr;
input [3:0]     fifo_12_wr_addr;
input [3:0]     fifo_13_wr_addr;
input [3:0]     fifo_20_wr_addr;
input [3:0]     fifo_21_wr_addr;
input [3:0]     fifo_22_wr_addr;
input [3:0]     fifo_23_wr_addr;
input [3:0]     fifo_30_wr_addr;
input [3:0]     fifo_31_wr_addr;
input [3:0]     fifo_32_wr_addr;
input [3:0]     fifo_33_wr_addr;
input [3:0]     dqs_delayed_col0;
input [3:0]     dqs_delayed_col1;
input [3:0]     dqs_div_col0;
input [3:0]     dqs_div_col1;
input [3:0]     fifo_00_rd_addr;
input [3:0]     fifo_01_rd_addr;
input [3:0]     fifo_02_rd_addr;
input [3:0]     fifo_03_rd_addr;
input [3:0]     fifo_10_rd_addr;
input [3:0]     fifo_11_rd_addr;
input [3:0]     fifo_12_rd_addr;
input [3:0]     fifo_13_rd_addr;
input [3:0]     fifo_20_rd_addr;
input [3:0]     fifo_21_rd_addr;
input [3:0]     fifo_22_rd_addr;
input [3:0]     fifo_23_rd_addr;
input [3:0]     fifo_30_rd_addr;
input [3:0]     fifo_31_rd_addr;
input [3:0]     fifo_32_rd_addr;
input [3:0]     fifo_33_rd_addr;

output [63:0]   user_output_data;
output          next_state_val;

reg [63:0]      user_output_data;




wire [31:0] fbit_0;
wire [31:0] fbit_1;
wire [31:0] fbit_2;
wire [31:0] fbit_3;
wire [7:0] fifo_00_data_out;
wire [7:0] fifo_01_data_out;
wire [7:0] fifo_02_data_out;
wire [7:0] fifo_03_data_out;
wire [7:0] fifo_10_data_out;
wire [7:0] fifo_11_data_out;
wire [7:0] fifo_12_data_out;
wire [7:0] fifo_13_data_out;
wire [7:0] fifo_20_data_out;
wire [7:0] fifo_21_data_out;
wire [7:0] fifo_22_data_out;
wire [7:0] fifo_23_data_out;
wire [7:0] fifo_30_data_out;
wire [7:0] fifo_31_data_out;
wire [7:0] fifo_32_data_out;
wire [7:0] fifo_33_data_out;

wire [3:0] fifo_00_rd_addr;
wire [3:0] fifo_02_rd_addr;
reg        next_state;


assign next_state_val      = next_state;

always @(posedge clk90)
begin
 if(reset90_r)
 begin
    next_state       <= 1'b0;
    user_output_data  <= 64'b0;
  end
  else
  begin
    case(next_state)
     1'b0:
          if(read_valid_data_1)
          begin
             next_state      <= 1'b1;
             user_output_data  <= {fifo_30_data_out,
                                  fifo_20_data_out,fifo_10_data_out,fifo_00_data_out,
             	                    fifo_31_data_out,
             	                    fifo_21_data_out,fifo_11_data_out,fifo_01_data_out};
           end
           else
               next_state      <= 1'b0;
     1'b1:
          if (read_valid_data_2)
          begin
             next_state       <= 1'b0;
             user_output_data <= {fifo_32_data_out,
                                 fifo_22_data_out,fifo_12_data_out,fifo_02_data_out,
                                 fifo_33_data_out,
                                 fifo_23_data_out,fifo_13_data_out,fifo_03_data_out};
         end
         else
            next_state <= 1'b1;
         default:begin
                    next_state      <= 1'b0;
                    user_output_data <= 64'b0;
                 end

     endcase
     end
end


//--******************************************************************************************************************************
// DDR Data bit instantiations (32-bits)
//--******************************************************************************************************************************


ddr2_dqbit ddr2_dqbit0
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[0]),
                       .fbit_0(fbit_0[0]),
                       .fbit_1(fbit_1[0]),
                       .fbit_2(fbit_2[0]),
                       .fbit_3(fbit_3[0])
                      );


ddr2_dqbit ddr2_dqbit1
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[1]),
                       .fbit_0(fbit_0[1]),
                       .fbit_1(fbit_1[1]),
                       .fbit_2(fbit_2[1]),
                       .fbit_3(fbit_3[1])
                      );

ddr2_dqbit ddr2_dqbit2
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[2]),
                       .fbit_0(fbit_0[2]),
                       .fbit_1(fbit_1[2]),
                       .fbit_2(fbit_2[2]),
                       .fbit_3(fbit_3[2])
                      );


ddr2_dqbit ddr2_dqbit3
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[3]),
                       .fbit_0(fbit_0[3]),
                       .fbit_1(fbit_1[3]),
                       .fbit_2(fbit_2[3]),
                       .fbit_3(fbit_3[3])
                      );

ddr2_dqbit ddr2_dqbit4
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[4]),
                       .fbit_0(fbit_0[4]),
                       .fbit_1(fbit_1[4]),
                       .fbit_2(fbit_2[4]),
                       .fbit_3(fbit_3[4])
                      );


ddr2_dqbit ddr2_dqbit5
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[5]),
                       .fbit_0(fbit_0[5]),
                       .fbit_1(fbit_1[5]),
                       .fbit_2(fbit_2[5]),
                       .fbit_3(fbit_3[5])
                      );


ddr2_dqbit ddr2_dqbit6
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[6]),
                       .fbit_0(fbit_0[6]),
                       .fbit_1(fbit_1[6]),
                       .fbit_2(fbit_2[6]),
                       .fbit_3(fbit_3[6])
                      );

ddr2_dqbit ddr2_dqbit7
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[0]),
                       .dqs1(dqs_delayed_col1[0]),
                       .dqs_div_1(dqs_div_col0[0]),
                       .dqs_div_2(dqs_div_col1[0]),
                       .dq(dq[7]),
                       .fbit_0(fbit_0[7]),
                       .fbit_1(fbit_1[7]),
                       .fbit_2(fbit_2[7]),
                       .fbit_3(fbit_3[7])
                      );

ddr2_dqbit ddr2_dqbit8
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[8]),
                       .fbit_0(fbit_0[8]),
                       .fbit_1(fbit_1[8]),
                       .fbit_2(fbit_2[8]),
                       .fbit_3(fbit_3[8])
                      );


ddr2_dqbit ddr2_dqbit9
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[9]),
                       .fbit_0(fbit_0[9]),
                       .fbit_1(fbit_1[9]),
                       .fbit_2(fbit_2[9]),
                       .fbit_3(fbit_3[9])
                      );


ddr2_dqbit ddr2_dqbit10
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[10]),
                       .fbit_0(fbit_0[10]),
                       .fbit_1(fbit_1[10]),
                       .fbit_2(fbit_2[10]),
                       .fbit_3(fbit_3[10])
                      );


ddr2_dqbit ddr2_dqbit11
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[11]),
                       .fbit_0(fbit_0[11]),
                       .fbit_1(fbit_1[11]),
                       .fbit_2(fbit_2[11]),
                       .fbit_3(fbit_3[11])
                      );


ddr2_dqbit ddr2_dqbit12
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[12]),
                       .fbit_0(fbit_0[12]),
                       .fbit_1(fbit_1[12]),
                       .fbit_2(fbit_2[12]),
                       .fbit_3(fbit_3[12])
                      );

ddr2_dqbit ddr2_dqbit13
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[13]),
                       .fbit_0(fbit_0[13]),
                       .fbit_1(fbit_1[13]),
                       .fbit_2(fbit_2[13]),
                       .fbit_3(fbit_3[13])
                      );

ddr2_dqbit ddr2_dqbit14
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[14]),
                       .fbit_0(fbit_0[14]),
                       .fbit_1(fbit_1[14]),
                       .fbit_2(fbit_2[14]),
                       .fbit_3(fbit_3[14])
                      );

ddr2_dqbit ddr2_dqbit15
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[1]),
                       .dqs1(dqs_delayed_col1[1]),
                       .dqs_div_1(dqs_div_col0[1]),
                       .dqs_div_2(dqs_div_col1[1]),
                       .dq(dq[15]),
                       .fbit_0(fbit_0[15]),
                       .fbit_1(fbit_1[15]),
                       .fbit_2(fbit_2[15]),
                       .fbit_3(fbit_3[15])
                      );

ddr2_dqbit ddr2_dqbit16
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[16]),
                       .fbit_0(fbit_0[16]),
                       .fbit_1(fbit_1[16]),
                       .fbit_2(fbit_2[16]),
                       .fbit_3(fbit_3[16])
                      );

ddr2_dqbit ddr2_dqbit17
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[17]),
                       .fbit_0(fbit_0[17]),
                       .fbit_1(fbit_1[17]),
                       .fbit_2(fbit_2[17]),
                       .fbit_3(fbit_3[17])
                      );

ddr2_dqbit ddr2_dqbit18
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[18]),
                       .fbit_0(fbit_0[18]),
                       .fbit_1(fbit_1[18]),
                       .fbit_2(fbit_2[18]),
                       .fbit_3(fbit_3[18])
                      );

ddr2_dqbit ddr2_dqbit19
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[19]),
                       .fbit_0(fbit_0[19]),
                       .fbit_1(fbit_1[19]),
                       .fbit_2(fbit_2[19]),
                       .fbit_3(fbit_3[19])
                      );

ddr2_dqbit ddr2_dqbit20
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[20]),
                       .fbit_0(fbit_0[20]),
                       .fbit_1(fbit_1[20]),
                       .fbit_2(fbit_2[20]),
                       .fbit_3(fbit_3[20])
                      );


ddr2_dqbit ddr2_dqbit21
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[21]),
                       .fbit_0(fbit_0[21]),
                       .fbit_1(fbit_1[21]),
                       .fbit_2(fbit_2[21]),
                       .fbit_3(fbit_3[21])
                      );



ddr2_dqbit ddr2_dqbit22
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[22]),
                       .fbit_0(fbit_0[22]),
                       .fbit_1(fbit_1[22]),
                       .fbit_2(fbit_2[22]),
                       .fbit_3(fbit_3[22])
                      );

ddr2_dqbit ddr2_dqbit23
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[2]),
                       .dqs1(dqs_delayed_col1[2]),
                       .dqs_div_1(dqs_div_col0[2]),
                       .dqs_div_2(dqs_div_col1[2]),
                       .dq(dq[23]),
                       .fbit_0(fbit_0[23]),
                       .fbit_1(fbit_1[23]),
                       .fbit_2(fbit_2[23]),
                       .fbit_3(fbit_3[23])
                      );

ddr2_dqbit ddr2_dqbit24
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[24]),
                       .fbit_0(fbit_0[24]),
                       .fbit_1(fbit_1[24]),
                       .fbit_2(fbit_2[24]),
                       .fbit_3(fbit_3[24])
                      );

ddr2_dqbit ddr2_dqbit25
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[25]),
                       .fbit_0(fbit_0[25]),
                       .fbit_1(fbit_1[25]),
                       .fbit_2(fbit_2[25]),
                       .fbit_3(fbit_3[25])
                      );

ddr2_dqbit ddr2_dqbit26
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[26]),
                       .fbit_0(fbit_0[26]),
                       .fbit_1(fbit_1[26]),
                       .fbit_2(fbit_2[26]),
                       .fbit_3(fbit_3[26])
                      );

ddr2_dqbit ddr2_dqbit27
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[27]),
                       .fbit_0(fbit_0[27]),
                       .fbit_1(fbit_1[27]),
                       .fbit_2(fbit_2[27]),
                       .fbit_3(fbit_3[27])
                      );

ddr2_dqbit ddr2_dqbit28
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[28]),
                       .fbit_0(fbit_0[28]),
                       .fbit_1(fbit_1[28]),
                       .fbit_2(fbit_2[28]),
                       .fbit_3(fbit_3[28])
                      );

ddr2_dqbit ddr2_dqbit29
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[29]),
                       .fbit_0(fbit_0[29]),
                       .fbit_1(fbit_1[29]),
                       .fbit_2(fbit_2[29]),
                       .fbit_3(fbit_3[29])
                      );

ddr2_dqbit ddr2_dqbit30
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[30]),
                       .fbit_0(fbit_0[30]),
                       .fbit_1(fbit_1[30]),
                       .fbit_2(fbit_2[30]),
                       .fbit_3(fbit_3[30])
                      );

ddr2_dqbit ddr2_dqbit31
                     (
                       .reset(reset270_r),
                       .dqs(dqs_delayed_col0[3]),
                       .dqs1(dqs_delayed_col1[3]),
                       .dqs_div_1(dqs_div_col0[3]),
                       .dqs_div_2(dqs_div_col1[3]),
                       .dq(dq[31]),
                       .fbit_0(fbit_0[31]),
                       .fbit_1(fbit_1[31]),
                       .fbit_2(fbit_2[31]),
                       .fbit_3(fbit_3[31])
                      );



//--*************************************************************************************************************************
//- Distributed RAM 8 bit wide FIFO instantiations (4 FIFOs per strobe, 1 for each fbit0 through 3)
//--*************************************************************************************************************************
//-- FIFOs associated with ddr2_dqs(0)

RAM_8D  ram_8d_dqs0_fbit0
        (
          .DPO(fifo_00_data_out),
          .A0(fifo_00_wr_addr[0]),
          .A1(fifo_00_wr_addr[1]),
          .A2(fifo_00_wr_addr[2]),
          .A3(fifo_00_wr_addr[3]),
          .D(fbit_0[7:0]),
          .DPRA0(fifo_00_rd_addr[0]),
          .DPRA1(fifo_00_rd_addr[1]),
          .DPRA2(fifo_00_rd_addr[2]),
          .DPRA3(fifo_00_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_0[0])
         );

RAM_8D  ram_8d_dqs0_fbit1
        (
          .DPO(fifo_01_data_out),
          .A0(fifo_01_wr_addr[0]),
          .A1(fifo_01_wr_addr[1]),
          .A2(fifo_01_wr_addr[2]),
          .A3(fifo_01_wr_addr[3]),
          .D(fbit_1[7:0]),
          .DPRA0(fifo_01_rd_addr[0]),
          .DPRA1(fifo_01_rd_addr[1]),
          .DPRA2(fifo_01_rd_addr[2]),
          .DPRA3(fifo_01_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_0[1])
         );

RAM_8D  ram_8d_dqs0_fbit2
        (
          .DPO(fifo_02_data_out),
          .A0(fifo_02_wr_addr[0]),
          .A1(fifo_02_wr_addr[1]),
          .A2(fifo_02_wr_addr[2]),
          .A3(fifo_02_wr_addr[3]),
          .D(fbit_2[7:0]),
          .DPRA0(fifo_02_rd_addr[0]),
          .DPRA1(fifo_02_rd_addr[1]),
          .DPRA2(fifo_02_rd_addr[2]),
          .DPRA3(fifo_02_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_0[2])
         );

RAM_8D  ram_8d_dqs0_fbit3
        (
          .DPO(fifo_03_data_out),
          .A0(fifo_03_wr_addr[0]),
          .A1(fifo_03_wr_addr[1]),
          .A2(fifo_03_wr_addr[2]),
          .A3(fifo_03_wr_addr[3]),
          .D(fbit_3[7:0]),
          .DPRA0(fifo_03_rd_addr[0]),
          .DPRA1(fifo_03_rd_addr[1]),
          .DPRA2(fifo_03_rd_addr[2]),
          .DPRA3(fifo_03_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_0[3])
         );

//-- FIFOs associated with ddr2_dqs(1)
RAM_8D  ram_8d_dqs1_fbit0
        (
          .DPO(fifo_10_data_out),
          .A0(fifo_10_wr_addr[0]),
          .A1(fifo_10_wr_addr[1]),
          .A2(fifo_10_wr_addr[2]),
          .A3(fifo_10_wr_addr[3]),
          .D(fbit_0[15:8]),
          .DPRA0(fifo_10_rd_addr[0]),
          .DPRA1(fifo_10_rd_addr[1]),
          .DPRA2(fifo_10_rd_addr[2]),
          .DPRA3(fifo_10_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_1[0])
         );

RAM_8D  ram_8d_dqs1_fbit1
        (
          .DPO(fifo_11_data_out),
          .A0(fifo_11_wr_addr[0]),
          .A1(fifo_11_wr_addr[1]),
          .A2(fifo_11_wr_addr[2]),
          .A3(fifo_11_wr_addr[3]),
          .D(fbit_1[15:8]),
          .DPRA0(fifo_11_rd_addr[0]),
          .DPRA1(fifo_11_rd_addr[1]),
          .DPRA2(fifo_11_rd_addr[2]),
          .DPRA3(fifo_11_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_1[1])
         );

RAM_8D  ram_8d_dqs1_fbit2
        (
          .DPO(fifo_12_data_out),
          .A0(fifo_12_wr_addr[0]),
          .A1(fifo_12_wr_addr[1]),
          .A2(fifo_12_wr_addr[2]),
          .A3(fifo_12_wr_addr[3]),
          .D(fbit_2[15:8]),
          .DPRA0(fifo_12_rd_addr[0]),
          .DPRA1(fifo_12_rd_addr[1]),
          .DPRA2(fifo_12_rd_addr[2]),
          .DPRA3(fifo_12_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_1[2])
         );


RAM_8D  ram_8d_dqs1_fbit3
        (
          .DPO(fifo_13_data_out),
          .A0(fifo_13_wr_addr[0]),
          .A1(fifo_13_wr_addr[1]),
          .A2(fifo_13_wr_addr[2]),
          .A3(fifo_13_wr_addr[3]),
          .D(fbit_3[15:8]),
          .DPRA0(fifo_13_rd_addr[0]),
          .DPRA1(fifo_13_rd_addr[1]),
          .DPRA2(fifo_13_rd_addr[2]),
          .DPRA3(fifo_13_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_1[3])
         );

//-- FIFOs associated with ddr2_dqs(2)

RAM_8D  ram_8d_dqs2_fbit0
        (
          .DPO(fifo_20_data_out),
          .A0(fifo_20_wr_addr[0]),
          .A1(fifo_20_wr_addr[1]),
          .A2(fifo_20_wr_addr[2]),
          .A3(fifo_20_wr_addr[3]),
          .D(fbit_0[23:16]),
          .DPRA0(fifo_20_rd_addr[0]),
          .DPRA1(fifo_20_rd_addr[1]),
          .DPRA2(fifo_20_rd_addr[2]),
          .DPRA3(fifo_20_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_2[0])
         );


RAM_8D  ram_8d_dqs2_fbit1
        (
          .DPO(fifo_21_data_out),
          .A0(fifo_21_wr_addr[0]),
          .A1(fifo_21_wr_addr[1]),
          .A2(fifo_21_wr_addr[2]),
          .A3(fifo_21_wr_addr[3]),
          .D(fbit_1[23:16]),
          .DPRA0(fifo_21_rd_addr[0]),
          .DPRA1(fifo_21_rd_addr[1]),
          .DPRA2(fifo_21_rd_addr[2]),
          .DPRA3(fifo_21_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_2[1])
         );


RAM_8D  ram_8d_dqs2_fbit2
        (
          .DPO(fifo_22_data_out),
          .A0(fifo_22_wr_addr[0]),
          .A1(fifo_22_wr_addr[1]),
          .A2(fifo_22_wr_addr[2]),
          .A3(fifo_22_wr_addr[3]),
          .D(fbit_2[23:16]),
          .DPRA0(fifo_22_rd_addr[0]),
          .DPRA1(fifo_22_rd_addr[1]),
          .DPRA2(fifo_22_rd_addr[2]),
          .DPRA3(fifo_22_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_2[2])
         );

RAM_8D  ram_8d_dqs2_fbit3
        (
          .DPO(fifo_23_data_out),
          .A0(fifo_23_wr_addr[0]),
          .A1(fifo_23_wr_addr[1]),
          .A2(fifo_23_wr_addr[2]),
          .A3(fifo_23_wr_addr[3]),
          .D(fbit_3[23:16]),
          .DPRA0(fifo_23_rd_addr[0]),
          .DPRA1(fifo_23_rd_addr[1]),
          .DPRA2(fifo_23_rd_addr[2]),
          .DPRA3(fifo_23_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_2[3])
         );


//-- FIFOs associated with ddr2_dqs(3)

RAM_8D  ram_8d_dqs3_fbit0
        (
          .DPO(fifo_30_data_out),
          .A0(fifo_30_wr_addr[0]),
          .A1(fifo_30_wr_addr[1]),
          .A2(fifo_30_wr_addr[2]),
          .A3(fifo_30_wr_addr[3]),
          .D(fbit_0[31:24]),
          .DPRA0(fifo_30_rd_addr[0]),
          .DPRA1(fifo_30_rd_addr[1]),
          .DPRA2(fifo_30_rd_addr[2]),
          .DPRA3(fifo_30_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_3[0])
         );


RAM_8D  ram_8d_dqs3_fbit1
        (
          .DPO(fifo_31_data_out),
          .A0(fifo_31_wr_addr[0]),
          .A1(fifo_31_wr_addr[1]),
          .A2(fifo_31_wr_addr[2]),
          .A3(fifo_31_wr_addr[3]),
          .D(fbit_1[31:24]),
          .DPRA0(fifo_31_rd_addr[0]),
          .DPRA1(fifo_31_rd_addr[1]),
          .DPRA2(fifo_31_rd_addr[2]),
          .DPRA3(fifo_31_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_3[1])
         );


RAM_8D  ram_8d_dqs3_fbit2
        (
          .DPO(fifo_32_data_out),
          .A0(fifo_32_wr_addr[0]),
          .A1(fifo_32_wr_addr[1]),
          .A2(fifo_32_wr_addr[2]),
          .A3(fifo_32_wr_addr[3]),
          .D(fbit_2[31:24]),
          .DPRA0(fifo_32_rd_addr[0]),
          .DPRA1(fifo_32_rd_addr[1]),
          .DPRA2(fifo_32_rd_addr[2]),
          .DPRA3(fifo_32_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_3[2])
         );

RAM_8D  ram_8d_dqs3_fbit3
        (
          .DPO(fifo_33_data_out),
          .A0(fifo_33_wr_addr[0]),
          .A1(fifo_33_wr_addr[1]),
          .A2(fifo_33_wr_addr[2]),
          .A3(fifo_33_wr_addr[3]),
          .D(fbit_3[31:24]),
          .DPRA0(fifo_33_rd_addr[0]),
          .DPRA1(fifo_33_rd_addr[1]),
          .DPRA2(fifo_33_rd_addr[2]),
          .DPRA3(fifo_33_rd_addr[3]),
          .WCLK(clk90),
          .WE(transfer_done_3[3])
         );




endmodule

























































































































































































































































































































































































































































































































































































































































































































































