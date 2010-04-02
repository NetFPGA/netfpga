//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//    File   name   :   data_write_32bit.v.v
//
//  Description :     This module comprises the write data paths for the
//                    DDR1 memory interface.
//
//
//  Date - revision : 10/16/2003
//
//  Author :          Maria George (Modifed by Sailaja)
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
//`include "parameters_32bit.v"
module    data_write_32bit(
     //inputs
     user_input_data,
      user_data_mask,
     clk90,
  clk270,
    reset90_r,
     reset270_r,
     write_enable,
     //outputs
     write_en_val,
     write_data_falling,
     write_data_rising,
     data_mask_f,
     data_mask_r
 );

 //inputs
input [63:0]     user_input_data;
input [7:0]  user_data_mask;
input             clk90;
input             reset90_r;
input             reset270_r;
input             write_enable;
  input clk270;
output            write_en_val;
output [31:0]     write_data_falling;
output [31:0]     write_data_rising;
output [3:0]      data_mask_f;
output [3:0]      data_mask_r;


//Internal registers declarations
reg         write_en_P1;
reg         write_en_P2;
reg         write_en_P3;
reg         write_en_int;
reg [63:0] write_data;
reg [63:0] write_data1;
reg [63:0] write_data2;
reg [63:0] write_data3;
wire [63:0] write_data4;
reg [63:0] write_data5;
reg [63:0] write_data6;
reg [63:0] write_data7;

reg [63:0]  write_data_int;
reg [31:0]  write_data270_1;
reg [31:0]  write_data270_2;
reg [31:0]  write_data270_3;
reg         write_en_val;
reg         write_en_val_1;

reg  [7:0] write_data_m;
reg  [7:0] write_data_m1;
reg  [7:0] write_data_m2;
reg  [7:0] write_data_m3;
wire  [7:0] write_data_m4;
reg  [7:0] write_data_m5;
reg  [7:0] write_data_m6;
reg  [7:0] write_data_m7;
reg  [7:0] write_data_mask;

reg [3:0] write_data_m270_1;
reg [3:0] write_data_m270_2;
reg [3:0] write_data_m270_3;




//assign data_mask_f        = 5'b0;
//assign data_mask_r        = 5'b0;
//assign write_data_rising  = write_data270_2;
assign write_data_rising  = write_data270_3;
assign write_data_falling = write_data[31:0];

assign data_mask_f     = write_data_mask[3:0];
assign data_mask_r     = write_data_m270_3;




// Write or Transmit side


   always@(posedge clk90)
                         begin
        write_data_int    <=  user_input_data;
                                write_data_m    <= user_data_mask;
        write_data1 <= write_data_int;
                                               write_data_m1 <= write_data_m;
        write_data2 <= write_data1;
                                            write_data_m2 <= write_data_m1;
        write_data3 <= write_data2;
                                      write_data_m3 <= write_data_m2;
end
        FD write_data_mo [63:0]  (
                .Q( write_data4),
                .D( write_data3 ),
                .C( clk90)
        );

FD write_data_mas [7:0]  (
                .Q( write_data_m4),
                .D( write_data_m3 ),
                .C( clk90)
              );

  always@(posedge clk90)
                         begin
         write_data5    <=   write_data4 ;
                          write_data_m5    <=   write_data_m4 ;

        write_data   <=   write_data5;
        write_data_mask <= write_data_m5;
        end   // pipeline varables


always @ (posedge clk270)
begin
write_data270_1  <= write_data3 [63 : 32] ;
write_data_m270_1 <= write_data_m3 [7:4];
write_data270_2 <= write_data270_1;
write_data_m270_2 <= write_data_m270_1;
write_data270_3 <= write_data270_2;
write_data_m270_3 <= write_data_m270_2;
       // varable_in

end

//-- data path for write enable

always @ (posedge clk90)
begin
  if (reset90_r == 1'b1)
    begin
      write_en_P1 <= 1'b0;
      write_en_P2 <= 1'b0;
      write_en_P3 <= 1'b0;
    end
  else
    begin
     write_en_P1 <= write_enable;
     write_en_P2 <= write_en_P1;
     write_en_P3 <= write_en_P2;
    end
end

always @ (negedge clk90)
begin
  if (reset90_r == 1'b1)
    begin
      write_en_int    <= 1'b0;
      write_en_val    <= 1'b0;
      write_en_val_1  <= 1'b0;
    end
  else
    begin
      write_en_int   <= write_en_P2; // P2
      write_en_val   <= write_en_P1; // int;
      write_en_val_1 <= write_en_val;
    end
end

endmodule