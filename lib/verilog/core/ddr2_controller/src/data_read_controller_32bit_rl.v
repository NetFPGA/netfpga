//--******************************************************************************
//--
//--  Xilinx, Inc. 2002                 www.xilinx.com
//--
//--
//--*******************************************************************************
//--
//--    File   name   :   data_read_controller_32bit_rl.v.v
//--
//--  Description :     This module generates all the control signals  for the
//--                     read data path.
//--
//--
//--  Date - revision : 10/16/2003
//--
//--  Author :          Maria George ( Modified by SAilaja)
//--
//--  Contact : e-mail  hotline@xilinx.com
//--            phone   + 1 800 255 7778
//--
//--  Disclaimer: LIMITED WARRANTY AND DISCLAMER. These designs are
//--              provided to you "as is". Xilinx and its licensors make and you
//--              receive no warranties or conditions, express, implied,
//--              statutory or otherwise, and Xilinx specifically disclaims any
//--              implied warranties of merchantability, non-infringement, or
//--              fitness for a particular purpose. Xilinx does not warrant that
//--              the functions contained in these designs will meet your
//--              requirements, or that the operation of these designs will be
//--              uninterrupted or error free, or that defects in the Designs
//--              will be corrected. Furthermore, Xilinx does not warrant or
//--              make any representations regarding use or the results of the
//--              use of the designs in terms of correctness, accuracy,
//--              reliability, or otherwise.
//--
//--              LIMITATION OF LIABILITY. In no event will Xilinx or its
//--              licensors be liable for any loss of data, lost profits, cost
//--              or procurement of substitute goods or services, or for any
//--              special, incidental, consequential, or indirect damages
//--              arising from the use or operation of the designs or
//--              accompanying documentation, however caused and on any theory
//--              of liability. This limitation will apply even if Xilinx
//--              has been advised of the possibility of such damage. This
//--              limitation shall apply not-withstanding the failure of the
//--              essential purpose of any limited remedies herein.
//--
//--  Copyright © 2002 Xilinx, Inc.
//--  All rights reserved
//--
//--*****************************************************************************
`timescale 1ns/100ps
module    data_read_controller_32bit_rl
   (
     //inputs
     clk,
     clk90,
  clk180,
  clk270,
     reset_r,
     reset90_r,
     reset180_r,
     reset270_r,
     rst_dqs_div,
     delay_sel,
     dqs_int_delay_in0,
     dqs_int_delay_in1,
     dqs_int_delay_in2,
     dqs_int_delay_in3,
     next_state,
     //outputs
     u_data_val,
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
     read_valid_data_1_val,
     read_valid_data_2_val,
     transfer_done_0_val,
     transfer_done_1_val,
     transfer_done_2_val,
     transfer_done_3_val,
     fifo_00_wr_addr_val,
     fifo_01_wr_addr_val,
     fifo_02_wr_addr_val,
     fifo_03_wr_addr_val,
     fifo_10_wr_addr_val,
     fifo_11_wr_addr_val,
     fifo_12_wr_addr_val,
     fifo_13_wr_addr_val,
     fifo_20_wr_addr_val,
     fifo_21_wr_addr_val,
     fifo_22_wr_addr_val,
     fifo_23_wr_addr_val,
     fifo_30_wr_addr_val,
     fifo_31_wr_addr_val,
     fifo_32_wr_addr_val,
     fifo_33_wr_addr_val,
     dqs_delayed_col0_val,
     dqs_delayed_col1_val,
     dqs_div_col0_val,
     dqs_div_col1_val
    );

 //input/output declarations
input            clk;
input            clk90;
  input clk180;
  input clk270;
input            reset_r;
input            reset90_r;
input            reset180_r;
input            reset270_r;
input            rst_dqs_div;
input [4:0]      delay_sel;
input            dqs_int_delay_in0;
input            dqs_int_delay_in1;
input            dqs_int_delay_in2;
input            dqs_int_delay_in3;
input            next_state;

output           u_data_val;
output [3:0]     fifo_00_rd_addr;
output [3:0]     fifo_01_rd_addr;
output [3:0]     fifo_02_rd_addr;
output [3:0]     fifo_03_rd_addr;
output [3:0]     fifo_10_rd_addr;
output [3:0]     fifo_11_rd_addr;
output [3:0]     fifo_12_rd_addr;
output [3:0]     fifo_13_rd_addr;
output [3:0]     fifo_20_rd_addr;
output [3:0]     fifo_21_rd_addr;
output [3:0]     fifo_22_rd_addr;
output [3:0]     fifo_23_rd_addr;
output [3:0]     fifo_30_rd_addr;
output [3:0]     fifo_31_rd_addr;
output [3:0]     fifo_32_rd_addr;
output [3:0]     fifo_33_rd_addr;
output           read_valid_data_1_val;
output           read_valid_data_2_val;
output [3:0]     transfer_done_0_val;
output [3:0]     transfer_done_1_val;
output [3:0]     transfer_done_2_val;
output [3:0]     transfer_done_3_val;
output [3:0]     fifo_00_wr_addr_val;
output [3:0]     fifo_01_wr_addr_val;
output [3:0]     fifo_02_wr_addr_val;
output [3:0]     fifo_03_wr_addr_val;
output [3:0]     fifo_10_wr_addr_val;
output [3:0]     fifo_11_wr_addr_val;
output [3:0]     fifo_12_wr_addr_val;
output [3:0]     fifo_13_wr_addr_val;
output [3:0]     fifo_20_wr_addr_val;
output [3:0]     fifo_21_wr_addr_val;
output [3:0]     fifo_22_wr_addr_val;
output [3:0]     fifo_23_wr_addr_val;
output [3:0]     fifo_30_wr_addr_val;
output [3:0]     fifo_31_wr_addr_val;
output [3:0]     fifo_32_wr_addr_val;
output [3:0]     fifo_33_wr_addr_val;
output [3:0]     dqs_delayed_col0_val;
output [3:0]     dqs_delayed_col1_val;
output [3:0]     dqs_div_col0_val;
output [3:0]     dqs_div_col1_val;


//Internal signals declarations
 reg           fifo_01_not_empty_r;
 reg           fifo_03_not_empty_r;
 reg           fifo_01_not_empty_r1;
 reg           fifo_03_not_empty_r1;
 reg           rd_data_valid;

 wire [3:0]     transfer_done_0;
 wire [3:0]     transfer_done_1;
 wire [3:0]     transfer_done_2;
 wire [3:0]     transfer_done_3;
 wire [3:0]     transfer_done_4;
 reg [3:0]     fifo_00_wr_addr;
 reg [3:0]     fifo_01_wr_addr;
 reg [3:0]     fifo_02_wr_addr;
 reg [3:0]     fifo_03_wr_addr;
 reg [3:0]     fifo_10_wr_addr;
 reg [3:0]     fifo_11_wr_addr;
 reg [3:0]     fifo_12_wr_addr;
 reg [3:0]     fifo_13_wr_addr;
 reg [3:0]     fifo_20_wr_addr;
 reg [3:0]     fifo_21_wr_addr;
 reg [3:0]     fifo_22_wr_addr;
 reg [3:0]     fifo_23_wr_addr;
 reg [3:0]     fifo_30_wr_addr;
 reg [3:0]     fifo_31_wr_addr;
 reg [3:0]     fifo_32_wr_addr;
 reg [3:0]     fifo_33_wr_addr;

 wire [3:0]    dqs_div_col0;
 wire [3:0]    dqs_div_col1;
 wire [3:0]    dqs_delayed_col0;
 wire [3:0]    dqs_delayed_col1;

 wire           rst_dqs_div_int;
 wire           fifo_01_not_empty;
 wire           fifo_03_not_empty;
 wire           read_valid_data_1;
 wire           read_valid_data_2;
 wire           read_valid_data;
 wire           rst_dqs_div_delayed;

 reg [3:0]     fifo_00_rd_addr;
 reg [3:0]     fifo_01_rd_addr;
 reg [3:0]     fifo_02_rd_addr;
 reg [3:0]     fifo_03_rd_addr;
 reg [3:0]     fifo_10_rd_addr;
 reg [3:0]     fifo_11_rd_addr;
 reg [3:0]     fifo_12_rd_addr;
 reg [3:0]     fifo_13_rd_addr;
 reg [3:0]     fifo_20_rd_addr;
 reg [3:0]     fifo_21_rd_addr;
 reg [3:0]     fifo_22_rd_addr;
 reg [3:0]     fifo_23_rd_addr;
 reg [3:0]     fifo_30_rd_addr;
 reg [3:0]     fifo_31_rd_addr;
 reg [3:0]     fifo_32_rd_addr;
 reg [3:0]     fifo_33_rd_addr;
 reg           rd_data_valid_reg;
 reg           rd_data_valid_1;
 reg           rd_data_valid_2;


 assign transfer_done_0_val = transfer_done_0;
 assign transfer_done_1_val = transfer_done_1;
 assign transfer_done_2_val = transfer_done_2;
 assign transfer_done_3_val = transfer_done_3;
// assign transfer_done_4_val = transfer_done_4;

 assign fifo_00_wr_addr_val = fifo_00_wr_addr;
 assign fifo_01_wr_addr_val = fifo_01_wr_addr;
 assign fifo_02_wr_addr_val = fifo_02_wr_addr;
 assign fifo_03_wr_addr_val = fifo_03_wr_addr;
 assign fifo_10_wr_addr_val = fifo_10_wr_addr;
 assign fifo_11_wr_addr_val = fifo_11_wr_addr;
 assign fifo_12_wr_addr_val = fifo_12_wr_addr;
 assign fifo_13_wr_addr_val = fifo_13_wr_addr;
 assign fifo_20_wr_addr_val = fifo_20_wr_addr;
 assign fifo_21_wr_addr_val = fifo_21_wr_addr;
 assign fifo_22_wr_addr_val = fifo_22_wr_addr;
 assign fifo_23_wr_addr_val = fifo_23_wr_addr;
 assign fifo_30_wr_addr_val = fifo_30_wr_addr;
 assign fifo_31_wr_addr_val = fifo_31_wr_addr;
 assign fifo_32_wr_addr_val = fifo_32_wr_addr;
 assign fifo_33_wr_addr_val = fifo_33_wr_addr;

 assign dqs_delayed_col0_val = dqs_delayed_col0;
 assign dqs_delayed_col1_val = dqs_delayed_col1;
 assign dqs_div_col0_val     = dqs_div_col0;
 assign dqs_div_col1_val     = dqs_div_col1;



assign read_valid_data_1_val = rd_data_valid_1;
assign read_valid_data_2_val = rd_data_valid_2;

assign rst_dqs_div_int       = ~ rst_dqs_div;

assign read_valid_data_1 = (fifo_01_not_empty_r1 && fifo_01_not_empty)?1'b1:1'b0;
assign read_valid_data_2 = (fifo_03_not_empty_r1 && fifo_03_not_empty)?1'b1:1'b0;
assign read_valid_data   =  read_valid_data_1 || read_valid_data_2;
assign u_data_val        =  rd_data_valid;
assign fifo_01_not_empty = (fifo_00_rd_addr[3:0]== fifo_01_wr_addr[3:0])?1'b0:1'b1;
assign fifo_03_not_empty = (fifo_02_rd_addr[3:0]== fifo_03_wr_addr[3:0])?1'b0:1'b1;


always @(posedge clk90)
begin
   if (reset90_r)
   begin
      fifo_01_not_empty_r   <= 1'b0;
      fifo_03_not_empty_r   <= 1'b0;
      fifo_01_not_empty_r1  <= 1'b0;
      fifo_03_not_empty_r1  <= 1'b0;
      rd_data_valid         <= 1'b0;
      rd_data_valid_1       <= 1'b0;
      rd_data_valid_2       <= 1'b0;
   end
   else
   begin
      fifo_01_not_empty_r   <= fifo_01_not_empty;
      fifo_03_not_empty_r   <= fifo_03_not_empty;
      fifo_01_not_empty_r1  <= fifo_01_not_empty_r;
      fifo_03_not_empty_r1  <= fifo_03_not_empty_r;
      rd_data_valid_reg     <= read_valid_data;
      rd_data_valid         <= rd_data_valid_reg && read_valid_data;
      rd_data_valid_1       <=  read_valid_data_1;
      rd_data_valid_2       <=  read_valid_data_2;
   end
end


always @(posedge clk90)
begin
 if(reset90_r)
 begin
   fifo_00_rd_addr <= 4'b0000;
   fifo_01_rd_addr <= 4'b0000;
   fifo_10_rd_addr <= 4'b0000;
   fifo_11_rd_addr <= 4'b0000;
   fifo_20_rd_addr <= 4'b0000;
   fifo_21_rd_addr <= 4'b0000;
   fifo_30_rd_addr <= 4'b0000;
   fifo_31_rd_addr <= 4'b0000;
   fifo_02_rd_addr <= 4'b0000;
   fifo_03_rd_addr <= 4'b0000;
   fifo_12_rd_addr <= 4'b0000;
   fifo_13_rd_addr <= 4'b0000;
   fifo_22_rd_addr <= 4'b0000;
   fifo_23_rd_addr <= 4'b0000;
   fifo_32_rd_addr <= 4'b0000;
   fifo_33_rd_addr <= 4'b0000;
  end
  else
  begin
    case(next_state)
     1'b0:
          if(rd_data_valid_1)
          begin
             fifo_00_rd_addr <= fifo_00_rd_addr + 4'b0001;
             fifo_01_rd_addr <= fifo_01_rd_addr + 4'b0001;
             fifo_10_rd_addr <= fifo_10_rd_addr + 4'b0001;
             fifo_11_rd_addr <= fifo_11_rd_addr + 4'b0001;
             fifo_20_rd_addr <= fifo_20_rd_addr + 4'b0001;
             fifo_21_rd_addr <= fifo_21_rd_addr + 4'b0001;
             fifo_30_rd_addr <= fifo_30_rd_addr + 4'b0001;
             fifo_31_rd_addr <= fifo_31_rd_addr + 4'b0001;
          end
          else
          begin
             fifo_00_rd_addr <= fifo_00_rd_addr;
             fifo_01_rd_addr <= fifo_01_rd_addr;
             fifo_10_rd_addr <= fifo_10_rd_addr;
             fifo_11_rd_addr <= fifo_11_rd_addr;
             fifo_20_rd_addr <= fifo_20_rd_addr;
             fifo_21_rd_addr <= fifo_21_rd_addr;
             fifo_30_rd_addr <= fifo_30_rd_addr;
             fifo_31_rd_addr <= fifo_31_rd_addr;
          end

     1'b1:
          if (rd_data_valid_2)
          begin
             fifo_02_rd_addr  <= fifo_02_rd_addr + 4'b0001;
             fifo_03_rd_addr  <= fifo_03_rd_addr + 4'b0001;
             fifo_12_rd_addr  <= fifo_12_rd_addr + 4'b0001;
             fifo_13_rd_addr  <= fifo_13_rd_addr + 4'b0001;
             fifo_22_rd_addr  <= fifo_22_rd_addr + 4'b0001;
             fifo_23_rd_addr  <= fifo_23_rd_addr + 4'b0001;
             fifo_32_rd_addr  <= fifo_32_rd_addr + 4'b0001;
             fifo_33_rd_addr  <= fifo_33_rd_addr + 4'b0001;
          end
         else
         begin
             fifo_02_rd_addr  <= fifo_02_rd_addr;
             fifo_03_rd_addr  <= fifo_03_rd_addr;
             fifo_12_rd_addr  <= fifo_12_rd_addr;
             fifo_13_rd_addr  <= fifo_13_rd_addr;
             fifo_22_rd_addr  <= fifo_22_rd_addr;
             fifo_23_rd_addr  <= fifo_23_rd_addr;
             fifo_32_rd_addr  <= fifo_32_rd_addr;
             fifo_33_rd_addr  <= fifo_33_rd_addr;
        end
         default:begin
                    fifo_00_rd_addr <= 4'b0000;
                    fifo_01_rd_addr <= 4'b0000;
                    fifo_10_rd_addr <= 4'b0000;
                    fifo_11_rd_addr <= 4'b0000;
                    fifo_20_rd_addr <= 4'b0000;
                    fifo_21_rd_addr <= 4'b0000;
                    fifo_30_rd_addr <= 4'b0000;
                    fifo_31_rd_addr <= 4'b0000;
                    fifo_02_rd_addr <= 4'b0000;
                    fifo_03_rd_addr <= 4'b0000;
                    fifo_12_rd_addr <= 4'b0000;
                    fifo_13_rd_addr <= 4'b0000;
                    fifo_22_rd_addr <= 4'b0000;
                    fifo_23_rd_addr <= 4'b0000;
                    fifo_32_rd_addr <= 4'b0000;
                    fifo_33_rd_addr <= 4'b0000;
                 end

     endcase
     end
end


always @(posedge clk90)
begin
   if(reset90_r)
      fifo_00_wr_addr <= 4'b0000;
   else if (transfer_done_0[0])
           fifo_00_wr_addr <= fifo_00_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_01_wr_addr <= 4'b0000;
    else if (transfer_done_0[1])
             fifo_01_wr_addr <= fifo_01_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_02_wr_addr <= 4'b0000;
    else if (transfer_done_0[2])
            fifo_02_wr_addr <= fifo_02_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_03_wr_addr <= 4'b0000;
    else if (transfer_done_0[3])
            fifo_03_wr_addr <= fifo_03_wr_addr + 4'b0001;
end

//----------------------------------------------------------

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_10_wr_addr <= 4'b0000;
    else if (transfer_done_1[0])
            fifo_10_wr_addr <= fifo_10_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_11_wr_addr <= 4'b0000;
    else if (transfer_done_1[1])
            fifo_11_wr_addr <= fifo_11_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_12_wr_addr <= 4'b0000;
    else if (transfer_done_1[2])
            fifo_12_wr_addr <= fifo_12_wr_addr + 4'b0001;
end

always @ (posedge clk90)
begin
    if (reset90_r == 1'b1)
      fifo_13_wr_addr <= 4'h0;
    else if (transfer_done_1[3] == 1'b1)
      fifo_13_wr_addr <= fifo_13_wr_addr + 1'b1;
end

//----------------------------------------------------------
always @(posedge clk90)
begin
    if (reset90_r)
       fifo_20_wr_addr <= 4'b0000;
    else if (transfer_done_2[0])
            fifo_20_wr_addr <= fifo_20_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_21_wr_addr <= 4'b0000;
    else if (transfer_done_2[1])
            fifo_21_wr_addr <= fifo_21_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_22_wr_addr <= 4'b0000;
    else if (transfer_done_2[2])
            fifo_22_wr_addr <= fifo_22_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
       fifo_23_wr_addr <= 4'b0000;
    else if (transfer_done_2[3])
            fifo_23_wr_addr <= fifo_23_wr_addr + 4'b0001;
end

//----------------------------------------------------------
always @(posedge clk90)
begin
    if (reset90_r)
        fifo_30_wr_addr <= 4'b0000;
    else if (transfer_done_3[0])
            fifo_30_wr_addr <= fifo_30_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
        fifo_31_wr_addr <= 4'b0000;
    else if (transfer_done_3[1])
            fifo_31_wr_addr <= fifo_31_wr_addr + 4'b0001;
end


always @(posedge clk90)
begin
    if (reset90_r)
        fifo_32_wr_addr <= 4'b0000;
    else if (transfer_done_3[2])
            fifo_32_wr_addr <= fifo_32_wr_addr + 4'b0001;
end

always @(posedge clk90)
begin
    if (reset90_r)
        fifo_33_wr_addr <= 4'b0000;
    else if (transfer_done_3[3])
            fifo_33_wr_addr <= fifo_33_wr_addr + 4'b0001;
end



//--***********************************************************************
//--    Read Data Capture Module Instantiations
//-------------------------------------------------------------------------------------------------------------------------------------------------

//**************************************************************************************************
// rst_dqs_div internal delay to match dqs internal delay
//**************************************************************************************************

dqs_delay  rst_dqs_div_delay0 (
	                       .clk_in(rst_dqs_div_int),  // rst_dqs_div,
	                       .sel_in(delay_sel),
	                       .clk_out(rst_dqs_div_delayed)
	                       );



//**************************************************************************************************
// DQS Internal Delay Circuit implemented in LUTs
//**************************************************************************************************

// Internal Clock Delay circuit placed in the first column (for falling edge data) adjacent to IOBs
dqs_delay  dqs_delay0_col0  (
	                      .clk_in (dqs_int_delay_in0),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col0[0])
	                     );

// Internal Clock Delay circuit placed in the second column (for rising edge data) adjacent to IOBs
dqs_delay  dqs_delay0_col1  (
	                      .clk_in (dqs_int_delay_in0),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col1[0])
	                     );

// Internal Clock Delay circuit placed in the first column (for falling edge data) adjacent to IOBs
dqs_delay  dqs_delay1_col0  (
	                      .clk_in (dqs_int_delay_in1),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col0[1])
	                     );

// Internal Clock Delay circuit placed in the second column (for rising edge data) adjacent to IOBs
dqs_delay  dqs_delay1_col1  (
	                       .clk_in (dqs_int_delay_in1),
	                       .sel_in (delay_sel),
	                       .clk_out(dqs_delayed_col1[1])
	                      );

// Internal Clock Delay circuit placed in the first column (for falling edge data) adjacent to IOBs
dqs_delay  dqs_delay2_col0  (
	                      .clk_in (dqs_int_delay_in2),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col0[2])
	                     );

// Internal Clock Delay circuit placed in the second column (for rising edge data) adjacent to IOBs
dqs_delay  dqs_delay2_col1  (
	                      .clk_in (dqs_int_delay_in2),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col1[2])
	                     );

// Internal Clock Delay circuit placed in the first column (for falling edge data) adjacent to IOBs
dqs_delay  dqs_delay3_col0  (
	                      .clk_in (dqs_int_delay_in3),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col0[3])
	                     );

// Internal Clock Delay circuit placed in the second column (for rising edge data) adjacent to IOBs
dqs_delay  dqs_delay3_col1  (
	                      .clk_in (dqs_int_delay_in3),
	                      .sel_in (delay_sel),
	                      .clk_out(dqs_delayed_col1[3])
	                     );

//------------------------------------------------------------------------------------------------------------------------------------------------
//***************************************************************************************************
// DQS Divide by 2 instantiations
//***************************************************************************************************

ddr2_dqs_div  ddr2_dqs_div0   (
                               .dqs(dqs_delayed_col0[0]),
                               .dqs1(dqs_delayed_col1[0]),
          					   .reset(reset_r),
                               .rst_dqs_div_delayed(rst_dqs_div_delayed),
                               .dqs_divn(dqs_div_col0[0]),
                               .dqs_divp(dqs_div_col1[0])
                              );

ddr2_dqs_div  ddr2_dqs_div1   (
                               .dqs(dqs_delayed_col0[1]),
                               .dqs1(dqs_delayed_col1[1]),
							   .reset(reset_r),
                               .rst_dqs_div_delayed(rst_dqs_div_delayed),
                               .dqs_divn(dqs_div_col0[1]),
                               .dqs_divp(dqs_div_col1[1])
                              );

ddr2_dqs_div  ddr2_dqs_div2   (
                               .dqs(dqs_delayed_col0[2]),
                               .dqs1(dqs_delayed_col1[2]),
							   .reset(reset_r),
                               .rst_dqs_div_delayed(rst_dqs_div_delayed),
                               .dqs_divn(dqs_div_col0[2]),
                               .dqs_divp(dqs_div_col1[2])
                              );

ddr2_dqs_div  ddr2_dqs_div3   (
                               .dqs(dqs_delayed_col0[3]),
                               .dqs1(dqs_delayed_col1[3]),
							   .reset(reset_r),
                               .rst_dqs_div_delayed(rst_dqs_div_delayed),
                               .dqs_divn(dqs_div_col0[3]),
                               .dqs_divp(dqs_div_col1[3])
                              );
      //------------------------------------------------------------------------------------------------------------------------------------------
//****************************************************************************************************************
// Transfer done instantiations (One instantiation peer strobe)
//****************************************************************************************************************

ddr2_transfer_done  ddr2_transfer_done0 (
                                         .clk0(clk),
                                         .clk90(clk90),
                 	  .clk180(clk180),
			  .clk270(clk270),
                                         .reset(reset_r),
                                         .reset90(reset90_r),
                                         .reset180(reset180_r),
                                         .reset270(reset270_r),
                                         .dqs_div(dqs_div_col1[0]),
                                         .transfer_done0(transfer_done_0[0]),
                                         .transfer_done1(transfer_done_0[1]),
                                         .transfer_done2(transfer_done_0[2]),
                                         .transfer_done3(transfer_done_0[3])
                                         );

ddr2_transfer_done  ddr2_transfer_done1 (
                                         .clk0(clk),
                                         .clk90(clk90),
                 	  .clk180(clk180),
			  .clk270(clk270),
                                         .reset(reset_r),
                                         .reset90(reset90_r),
                                         .reset180(reset180_r),
                                         .reset270(reset270_r),
                                         .dqs_div(dqs_div_col1[1]),
                                         .transfer_done0(transfer_done_1[0]),
                                         .transfer_done1(transfer_done_1[1]),
                                         .transfer_done2(transfer_done_1[2]),
                                         .transfer_done3(transfer_done_1[3])
                                         );

ddr2_transfer_done  ddr2_transfer_done2 (
                                         .clk0(clk),
                                         .clk90(clk90),
                 	  .clk180(clk180),
			  .clk270(clk270),
                                         .reset(reset_r),
                                         .reset90(reset90_r),
                                         .reset180(reset180_r),
                                         .reset270(reset270_r),
                                         .dqs_div(dqs_div_col1[2]),
                                         .transfer_done0(transfer_done_2[0]),
                                         .transfer_done1(transfer_done_2[1]),
                                         .transfer_done2(transfer_done_2[2]),
                                         .transfer_done3(transfer_done_2[3])
                                         );

ddr2_transfer_done  ddr2_transfer_done3 (
                                         .clk0(clk),
                                         .clk90(clk90),
                 	  .clk180(clk180),
			  .clk270(clk270),
                                         .reset(reset_r),
                                         .reset90(reset90_r),
                                         .reset180(reset180_r),
                                         .reset270(reset270_r),
                                         .dqs_div(dqs_div_col1[3]),
                                         .transfer_done0(transfer_done_3[0]),
                                         .transfer_done1(transfer_done_3[1]),
                                         .transfer_done2(transfer_done_3[2]),
                                         .transfer_done3(transfer_done_3[3])
                                         );
endmodule