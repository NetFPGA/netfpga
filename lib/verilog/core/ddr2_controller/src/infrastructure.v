//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//  XAPP 253 - Synthesizable DDR SDRAM Controller
//
//*******************************************************************************
//
//  File name :       infrastructure.v
//
//  Description :
//                    Main fucntions of this module
//                       - generation of FPGA clocks.
//                       - generation of reset signals
//                       - implements calibration mechanism
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
module infrastructure
    (
       //inputs
       sys_rst,
       clk_int,
       rst_calib1,
       delay_sel_val,
       //output
       delay_sel_val1_val
    );

//Input/Output declarations
input         sys_rst;
input         clk_int;
input         rst_calib1;
input [4:0] delay_sel_val;

output [4:0] delay_sel_val1_val;

//---- Signal declarations used on the diagram ----

wire user_rst;
wire clk_int;
wire clk90_int;
wire dcm_lock;

reg sys_rst_o;
reg sys_rst_1;//: std_logic := '1';
reg sys_rst90_o;
reg sys_rst90_1;//             : std_logic := '1';
reg sys_rst90;
reg sys_rst180_o;
reg sys_rst180_1;//            : std_logic := '1';
reg sys_rst180;
reg sys_rst270_o ;
reg sys_rst270_1;//            : std_logic := '1';
reg sys_rst270;
reg rst_calib1_r1;
reg rst_calib1_r2;
wire stuck_at1;
wire vcc;

wire [4:0] delay_sel_val;
wire [4:0] delay_sel_val1;

reg  [4:0] delay_sel_val1_r;

assign delay_sel_val1_val = delay_sel_val1;
assign delay_sel_val1 = (!rst_calib1 && !rst_calib1_r2)? delay_sel_val:delay_sel_val1_r;

always @(posedge clk_int)
begin
   if(sys_rst)
   begin
     delay_sel_val1_r <= 5'b0000;
     rst_calib1_r1    <= 1'b0;
     rst_calib1_r2    <= 1'b0;
   end
   else
   begin
     delay_sel_val1_r <= delay_sel_val1;
     rst_calib1_r1    <= rst_calib1;
     rst_calib1_r2    <= rst_calib1_r1;
   end
end

endmodule


