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
module infrastructure_top
    (
       //inputs
	       reset_in,
		             sys_clk_ibuf,
	       //outputs
       delay_sel_val1_val,
       sys_rst_val,
       sys_rst90_val,
     clk_int_val,
     clk90_int_val,
       sys_rst180_val,
       sys_rst270_val,
	 wait_200us
    );
//Input/Output declarations
input         reset_in;
		            input         sys_clk_ibuf;

output        wait_200us;
output [4:0] delay_sel_val1_val;
output       sys_rst_val;
output       sys_rst90_val;
output       sys_rst180_val;
output       sys_rst270_val;
  output       clk_int_val;
  output       clk90_int_val;

//---- Signal declarations used on the diagram ----

wire user_rst;
  wire clk_int;
  wire clk90_int;
  wire dcm_lock;

reg sys_rst_o;
reg sys_rst_1;//: std_logic := '1';
reg sys_rst;
reg sys_rst90_o;
reg sys_rst90_1;//             : std_logic := '1';
reg sys_rst90;
reg sys_rst180_o;
reg sys_rst180_1;//            : std_logic := '1';
reg sys_rst180;
reg sys_rst270_o ;
reg sys_rst270_1;//            : std_logic := '1';
reg sys_rst270;
wire vcc;

wire [4:0] delay_sel_val;

//200us reg
reg [15:0] Counter200;
reg      wait_200us;//added
reg      wait_clk90;//added

  assign clk_int_val        = clk_int;
  assign clk90_int_val      = clk90_int;

assign sys_rst_val        = sys_rst;
assign sys_rst90_val      = sys_rst90;
assign sys_rst180_val     = sys_rst180;
assign sys_rst270_val     = sys_rst270;
assign delay_sel_val1_val = delay_sel_val;


assign vcc      = 1'b1;
assign user_rst = ~ reset_in;


always @(posedge clk_int)
begin
   if(user_rst == 1'b1 || dcm_lock == 1'b0)
   begin
     wait_200us <= 1'b1;
     Counter200     <= 16'b0;
// synthesis translate_off
     // Artificially bump the counter to reduce the waiting time during
     // simulations
     Counter200     <= 16'b1101_1111_1111_0000;
// synthesis translate_on
   end
   else
   begin
      if( Counter200[15] & Counter200[14] & Counter200[13] & wait_200us)
         wait_200us <=1'b0;
      else if (wait_200us)
         Counter200 <= Counter200 + 1;
      else
         Counter200 <= Counter200;
   end
end


always @(posedge clk90_int)
begin
   if(user_rst == 1'b1 || dcm_lock == 1'b0)
      wait_clk90 <= 1'b1;
   else
      wait_clk90 <= wait_200us;
end



always @(posedge clk_int)
begin
  if(user_rst || !dcm_lock || wait_200us )
  begin
      sys_rst_o <= 1'b1;
      sys_rst_1 <= 1'b1;
      sys_rst   <= 1'b1;
  end
  else
  begin
      sys_rst_o <= 1'b0;
      sys_rst_1 <= sys_rst_o;
      sys_rst   <= sys_rst_1;
  end
end

always @(posedge clk90_int)
begin
   if(user_rst || !dcm_lock || wait_clk90 )
   begin
      sys_rst90_o <= 1'b1;
      sys_rst90_1 <= 1'b1;
      sys_rst90   <= 1'b1;
  end
  else
  begin
      sys_rst90_o <= 1'b0;
      sys_rst90_1 <= sys_rst90_o;
      sys_rst90   <= sys_rst90_1;
  end
end

always @(negedge clk_int)
begin
  if(user_rst || !dcm_lock || wait_200us )
  begin
      sys_rst180_o <= 1'b1;
      sys_rst180_1 <= 1'b1;
      sys_rst180   <= 1'b1;
  end
  else
  begin
      sys_rst180_o <= 1'b0;
      sys_rst180_1 <= sys_rst180_o;
      sys_rst180   <= sys_rst180_1;
  end
end

always @(negedge clk90_int)
begin
   if(user_rst || !dcm_lock || wait_clk90 )
   begin
      sys_rst270_o <= 1'b1;
      sys_rst270_1 <= 1'b1;
      sys_rst270   <= 1'b1;
   end
   else
   begin
      sys_rst270_o <= 1'b0;
      sys_rst270_1 <= sys_rst270_o;
      sys_rst270   <= sys_rst270_1;
  end
end

//----  Component instantiations  ----


  clk_dcm clk_dcm0 (
                    .input_clk(sys_clk_ibuf),
                    .rst(user_rst),
                    .clk(clk_int),
                    .clk90(clk90_int),
                    .dcm_lock(dcm_lock)
                   );

cal_top cal_top0 (
                  .clk(sys_clk_ibuf),
                  .clk0(clk_int),
                  .clk0dcmlock(dcm_lock),
                  .reset(reset_in),
                  .okToSelTap(vcc),
                  .tapForDqs(delay_sel_val)
                );


endmodule


