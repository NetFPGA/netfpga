//******************************************************************************
//
//  Xilinx, Inc. 2002                 www.xilinx.com
//
//
//*******************************************************************************
//
//  File name :       controller.v
//
//  Description :
//                    Main DDR SDRAM controller block. This includes the following
//                    features:
//                    - The controller state machine that controls the
//                    initialization process upon power up, as well as the
//                    read, write, and refresh commands.
//                    - Accepts and decodes the user commands.
//                    - Generates the address and Bank address signals
//                    - Generates control signals for other modules, including
//                    the control signals for the dqs_en block.
//
//
//  Date - revision : 12/9/2003
//
//  Author :          Maria George (verilog conversion)
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
/*
June 9 2005
Write recovery implemntation corrected
Latency Reduced by 1 clock
Sailaja
*/

`timescale 1ns/100ps

`include "parameters_32bit_00.v"
`include  "ddr_defines.v"

module controller_32bit_00(
                 //ouputs
                 dip1,
                 dip3,
	         clk,
  clk180,
	         rst0,
	         rst180,
	         address,
	         bank_address,
	         config_register1,
	         config_register2,
	         command_register,
	         burst_done,
	         //ouputs
	         ddr_rasb_cntrl,
	         ddr_casb_cntrl,
	         ddr_web_cntrl,
	         ddr_ba_cntrl,
	         ddr_address_cntrl,
	         ddr_cke_cntrl,
	         ddr_csb_cntrl,
	         ddr_ODT_cntrl,
	         dqs_enable,
	         dqs_reset,
	         write_enable,
	         rst_calib,
	         rst_dqs_div_int,
	         cmd_ack,
	         init,
	         ar_done,
                 wait_200us,
               auto_ref_req
                 );
//Inout/Ouput declarations
   input         dip1;
   input         dip3;
   input         clk;    /* synthesis syn_keep = 1 */
   input clk180;
   input         rst0;
   input 	       rst180;
   input[((`row_address + `column_address)-1):0]   address;
   input[`bank_address-1:0]    bank_address;
   input[14:0]   config_register1;
   input[12:0]   config_register2;
   input[3:0]    command_register;
   input         burst_done;

   output         ddr_rasb_cntrl;
   output         ddr_casb_cntrl;
   output         ddr_web_cntrl;
   output[`bank_address-1:0]    ddr_ba_cntrl;
   output[`row_address-1:0]   ddr_address_cntrl;
   output         ddr_cke_cntrl;
   output         ddr_csb_cntrl;
   output         ddr_ODT_cntrl;
   output         dqs_enable;
   output         dqs_reset /* synthesis syn_keep = 1 */;
   output         write_enable;
   output         rst_calib;
   output         rst_dqs_div_int;
   output         cmd_ack;
   output         init;
   output         ar_done;
   input          wait_200us;
   output         auto_ref_req;


  // reg[`bank_address-1:0]    ddr_ba_cntrl;
 //  reg[`row_address-1:0]   ddr_address_cntrl;
   reg           ddr_ODT_cntrl;

   parameter [3:0] IDLE = 0,
                   PRECHARGE = 1,
                   LOAD_MODE_REG = 2,
                   AUTO_REFRESH =3,
                   ACTIVE = 4,
                   FIRST_WRITE =5,
                   WRITE_WAIT = 6,
                   BURST_WRITE = 7,
                   READ_AFTER_WRITE = 8,
                   PRECHARGE_AFTER_WRITE = 9,
                   PRECHARGE_AFTER_WRITE_2 = 10,//A
                   READ_WAIT =11,//B
                   BURST_READ = 12,//C
                   ODT_TURN_ON = 14, //E
                   ACTIVE_WAIT = 15; //'h12


   reg 		   ar_done;
   reg 		   write_enable;
   reg [3:0] 	   next_state;
   reg [3:0] 	   next_state1;

   wire 	   ack_reg;
   wire 	   ack_o;
   reg [((`row_address + `column_address)-1):0] address_reg;
   wire [`row_address-1:0] 			address_config;
   reg 						auto_ref;
   wire 					auto_ref1;
   wire 					AUTOREF_value;
   reg 						AUTO_REF_detect;
   reg 						AUTO_REF_detect1;
   reg 						AUTO_REF_pulse_end;
   reg [11:0] 					AUTOREF_COUNT;
   wire [11:0] 					AUTOREF_CNT_val;
   reg 						Auto_Ref_issued;
   wire 					Auto_Ref_issued_p;
   wire 					AR_done_p;
   reg [`bank_address-1:0] 			BA_address_active;
   reg 						BA_address_conflict;
   reg [`bank_address-1:0] 			BA_address_reg;
   reg [2:0] 					burst_length;
   wire [2:0] 					burst_cnt_max;
   reg [1:0] 					CAS_COUNT;
   wire [1:0] 					cas_count_value;
   reg [2:0] 					cas_latency /* synthesis syn_preserve = 1 */;



   reg [`column_address-1:0] 			column_address_reg;
   reg [`column_address-1:0] 			column_address_reg1;
   reg [`column_address-1:0] 			column_address_reg2;
   reg [`column_address-1:0] 			column_address_reg3;
   reg [`column_address-1:0] 			column_address_reg4;
   reg [`column_address-1:0] 			column_address_reg5;
   reg [`column_address-1:0] 			column_address_reg6;
   wire [`column_address-1:0] 			column_address;

   reg [3:0] 					command_reg;
   reg [14:0] 					config_reg1;
   reg [12:0] 					config_reg2;
   reg [2:0] 					WR;
   reg 						CONFLICT;
   wire 					CONFLICT_value;
   wire 					ddr_rasb1;
   wire 					ddr_casb1;
   wire 					ddr_web1;
   reg 						ddr_rasb2;
   reg 						ddr_casb2;
   reg 						ddr_web2;
   reg 						ddr_rasb3;
   reg 						ddr_casb3;
   reg 						ddr_web3;
   reg 						ddr_rasb4;
   reg 						ddr_casb4;
   reg 						ddr_web4;
   reg 						ddr_rst_dqs_rasb4;
   reg 						ddr_rst_dqs_casb4;
   reg 						ddr_rst_dqs_web4;

   wire [`bank_address-1:0] 			ddr_ba1;
   reg [`bank_address-1:0] 			ddr_ba2;
   reg [`bank_address-1:0] 			ddr_ba3;
//   reg [`bank_address-1:0] 			ddr_ba4;
//   reg [`bank_address-1:0] 			ddr_ba5;

   wire [`row_address-1:0] 			ddr_address1;
   reg [`row_address-1:0] 			ddr_address2;
   reg [`row_address-1:0] 			ddr_address3;
//   reg [`row_address-1:0] 			ddr_address4;
//   reg [`row_address-1:0] 			ddr_address5;
   //reg 						mrd_ct_one;
   wire 					DQS_enable_out;
   wire 					DQS_reset_out;
   wire [3:0] 					INIT_COUNT_value;
   reg [3:0] 					INIT_COUNT;
   reg 						INIT_DONE;
   wire 					init_done_value;
   reg 						init_memory;
   wire 					init_mem;
   wire 					initialize_memory;
   reg [6:0] 					INIT_PRE_COUNT;
   wire [7:0] 					DLL_RST_COUNT_value;
   reg [7:0] 					DLL_RST_COUNT;
   wire 					ld_mode;
   wire [1:0] 					MRD_COUNT_value;
   reg [11:0] 					max_ref_cnt;
   reg [1:0] 					MRD_COUNT;
   wire 					PRECHARGE_CMD;
   wire [3:0] 					ras_count_value;
   reg [3:0] 					RAS_COUNT;
   wire 					rdburst_chk;
   wire 					read_cmd;
   reg 						read_cmd1;
   reg 						read_cmd2;
   reg 						read_cmd3;
   reg 						read_cmd4;
   reg 						read_cmd5;
   reg 						read_cmd6;
   reg 						read_cmd7;
   reg 						read_cmd8;
   reg 						read_rcd_end;
   reg 						read_cmd_reg;
   reg [1:0] 					RRD_COUNT;
   reg [2:0] 					RCDR_COUNT;
   reg 						rcdr_ct_one;

   reg [2:0] 					RCDW_COUNT;
   wire [2:0] 					rp_cnt_value;
   reg [5:0] 					RFC_COUNTER_value;
   reg 						RFC_COUNT_reg;
   reg 						AR_Done_reg;
   wire [5:0] 					RFC_COUNT_value;
   wire [1:0] 					RRD_COUNT_value;
   wire [2:0] 					RCDR_COUNT_value;
   wire [2:0] 					RCDW_COUNT_value;
   wire [3:0] 					RC_COUNT_value;
   wire [2:0] 					rdburst_end_cnt_value;
   reg [2:0] 					RDBURST_END_CNT;
   reg 						rdburst_end_1;
   reg 						rdburst_end_2;
   reg 						rdburst_end_3;
   reg 						rdburst_end_4;
   reg 						rdburst_end_5;
   reg 						rdburst_end_6;
   reg 						rdburst_end_7;
   reg 						rdburst_end_8;
   wire 					rdburst_end_r;
   wire 					read_enable_out_r;
   wire 					rdburst_end;
   reg [2:0] 					RP_COUNT;
   reg [3:0] 					RC_COUNT;
   reg [5:0] 					RFC_COUNT;
   wire 					read_enable_out;
   wire [`row_address-1:0] 			ROW_ADDRESS;
   reg [`row_address-1:0] 			row_address_reg;
   reg [`row_address-1:0] 			row_address_active_reg;
   reg 						row_address_conflict;
   reg 						rst_dqs_div_r;
   wire [2:0] 					wrburst_end_cnt_value;
   reg [2:0] 					wrburst_end_cnt;
   wire 					wrburst_end;
   reg 						wrburst_end_1;
   reg 						wrburst_end_2;
   reg 						wrburst_end_3;
   reg 						wrburst_end_4;
   reg 						wrburst_end_5;
   reg 						wrburst_end_6;
   reg 						wrburst_end_7;
   reg 						wrburst_end_8;
   reg 						wrburst_end_9;
   wire 					wrburst_chk;
   reg [2:0] 					WR_COUNT;
   wire 					write_enable_out;
   reg 						write_enable_out1;
   reg 						write_enable_out2;
   reg 						write_cmd;
   wire 					write_cmd_in;
   reg 						write_cmd2;
   reg 						write_cmd3;
   reg 						write_cmd4;
   reg 						write_cmd5;
   reg 						write_cmd1;
   reg 						write_cmd6;
   reg 						write_cmd7;
   reg 						write_cmd8;
   wire 					GND;
   reg [2:0] 					dqs_div_cascount;
   reg [2:0] 					dqs_div_rdburstcount;
   wire 					rst_dqs_div_int1;
   reg 						DQS_enable1;
   reg 						DQS_enable2;
   reg 						DQS_enable3;
   reg 						DQS_enable4;
   reg 						DQS_enable5;
   reg 						DQS_enable6;
   reg 						DQS_reset1_clk0;
   reg 						DQS_reset2_clk0;
   reg 						DQS_reset3_clk0;
   reg 						DQS_reset4_clk0;
   reg 						DQS_reset5_clk0;
   reg 						DQS_reset6_clk0;
   reg 						DQS_reset4_clk0_r;
   reg 						DQS_reset5_clk0_r;
   reg 						DQS_reset6_clk0_r;
   reg 						DQS_enable_int;
   reg 						DQS_reset_int;
   reg 						rst180_r;
   reg 						rst0_r;
   reg [12:0] 					EMR;
   reg [12:0] 					LMR_DLL_rst;
   reg [12:0] 					LMR_DLL_set;
   reg [1:0] 					ODT_COUNT;
   wire [1:0] 					ODT_COUNT_value;
   wire 					ddr_ODT1;
   reg 						ddr_ODT2;

   wire 					GO_TO_ACTIVE_value;
   reg 						GO_TO_ACTIVE;
   wire 					accept_cmd_in;

   wire 					GO_TO_ODT_ON_value/* synthesis syn_keep = 1 */;
   reg 						GO_TO_ODT_ON/* synthesis syn_preserve = 1 */;


  // Following flags are added to resolve the timing erros. Most of the counter comparisons are replaced withn
  // Flag checks. // Sarala, jun23

  reg   rpCnt0 ;

  reg   mrdCnt0 ;
  reg   mrdCnt1 ;

  reg   rasCnt0 ;
  reg   rasCnt1 ;

  reg   casCnt0 ;
  reg   casCnt1 ;

  reg   rrdCnt0 ;
  reg   rrdCnt1 ;

  reg   rcdrCnt0 ;
  reg   rcdrCnt1 ;

  reg   rcdwCnt0 ;
  reg   rcdwCnt1 ;

  reg   rcCnt0 ;

  reg  auto_ref_wait;
  reg  auto_ref_wait1;
  reg  auto_ref_wait2;


//  Input : CONFIG REGISTER FORMAT
// config_register1 = {  PD,WR,TM,EMR(Enable/Disable DLL),
//                       BMR (Normal operation/Normal Operation with Reset DLL),
//                       BMR/EMR,
//                       CAS_latency (3),
//                       Burst type ,
//                       Burst_length (3) }
//New BITS For Test Mode(TM), Write Recovery(WR), Poer Down (PD) in LMR and ODS,RTT, Posted CAS, DQS#,
// RDQS,Out & OCD Program in EMR are added
// config_register2 = {  Out,RDQS,DQS_n,OCD_Progm,Posted_Cas,RTT,ODS }
//
// Input : COMMAND REGISTER FORMAT
//          000  - NOP
//          001  - Precharge
//          010  - Auto Refresh
//          011  - SElf REfresh
//          100  - Write Request
//          101  - Load Mode Register
//          110  - Read request
//          111  - Burst terminate
//
// Input : Address format
//   row address = input address(19 downto 8)
//   column addrs = input address( 7 downto 0)
//

assign ddr_csb_cntrl  = 1'b0;
assign ddr_cke_cntrl  = ~wait_200us;
assign ROW_ADDRESS    = address_reg[((`row_address + `column_address)-1):`column_address];
assign column_address = address_reg[`column_address-1:0];
assign init           = INIT_DONE;
assign GND            = 1'b0;


assign ddr_rasb_cntrl = ddr_rasb1;
assign ddr_casb_cntrl = ddr_casb1;
assign ddr_web_cntrl  = ddr_web1;

assign ddr_address_cntrl   = ddr_address1;
assign ddr_ba_cntrl        = ddr_ba1;


assign rst_dqs_div_int = rst_dqs_div_int1;

always @ (posedge clk180)
begin
  rst180_r <= rst180;
end

always @ (posedge clk)
begin
  rst0_r <= rst0;
end

//********************************************************************************************
// register input commands from the user
//
//********************************************************************************************

  always @ (posedge clk180)
  begin
    if (rst180_r == 1'b1)
      begin
        config_reg1        <= 15'b0000000000;
        config_reg2        <= 13'b0;
        command_reg        <= 4'b0000;
        row_address_reg    <= `row_address'b0;
        column_address_reg <= `column_address'b0;
        BA_address_reg     <= `bank_address'b0;
        address_reg        <= `row_address + `column_address'b0;
      end
    else
      begin
        config_reg1        <= config_register1;
        config_reg2        <= config_register2;
        command_reg        <= command_register;
        row_address_reg    <= address[((`row_address + `column_address)-1):`column_address];
        column_address_reg <= address[`column_address-1:0];
        BA_address_reg     <= bank_address;
        address_reg        <= address;
      end
  end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     burst_length <= 3'b000;
     cas_latency  <= 3'b000;
     EMR          <= 13'b0;
     LMR_DLL_rst  <= 13'b0;
     LMR_DLL_set  <= 13'b0;
     WR           <= 3'b0;
    end
  else
    begin
     burst_length <= config_reg1[2:0];
     cas_latency  <= config_reg1[6:4];
// config_register1 = {  PD,WR,TM,EMR(Enable/Disable DLL),
//                       BMR (Normal operation/Normal Operation with Reset DLL),
//                       BMR/EMR,
//                       CAS_latency (3),
//                       Burst type ,
//                       Burst_length (3) }
     LMR_DLL_rst     <= {config_reg1[14:11],1'b1,config_reg1[10],config_reg1[6:0]};//DLL is reset
     LMR_DLL_set     <= {config_reg1[14:11],1'b0,config_reg1[10],config_reg1[6:0]};//DLL is not reset
// config_register2 = {  Out,RDQS,DQS_n,OCD_Progm,Posted_Cas,RTT,ODS,DLL }
     EMR          <= {config_reg2[12:7],config_reg2[3],config_reg2[6:4],config_reg2[2:0]};
     WR           <= `WRITE_RECOVERY_VAL;
    end
end


 //  assign accept_cmd_in = ((next_state1 == IDLE) && (RP_COUNT == 3'b000) && RFC_COUNT_reg == 1'b1) ;

    assign accept_cmd_in = ((next_state == IDLE ) && rpCnt0 && RFC_COUNT_reg  && !auto_ref_wait);


   assign PRECHARGE_CMD     = (command_register == 4'b0001 && accept_cmd_in == 1'b1) ;
   assign initialize_memory = (command_register == 4'b0010);
   assign write_cmd_in      = (command_register == 4'b0100 && accept_cmd_in == 1'b1) ;
   assign ld_mode           = (command_register == 4'b0101 && accept_cmd_in == 1'b1) ;
   assign read_cmd          = (command_register == 4'b0110 && accept_cmd_in == 1'b1) ;
//Auto Refresh User Command from  is removed Since Controller is giving Auto refresh commands for every 7.7 us

//**************************************************************************
// write_cmd is used to determine when there is a new write request
//**************************************************************************

// register write_cmd until WRITE command needs to be issued

  always @ (posedge clk180)
  begin
     if (rst180_r == 1'b1)
      begin
       write_cmd1  <= 1'b0;
       write_cmd2  <= 1'b0;
       write_cmd3  <= 1'b0;
       write_cmd4  <= 1'b0;
       write_cmd5  <= 1'b0;
       write_cmd6  <= 1'b0;
       write_cmd7  <= 1'b0;
       write_cmd8  <= 1'b0;
       write_cmd   <= 1'b0;
      end
     else
      begin
	  if (accept_cmd_in)
	    write_cmd1 <= write_cmd_in;
       write_cmd2 <= write_cmd1;
       write_cmd3 <= write_cmd2;
       write_cmd4 <= write_cmd3;
       write_cmd5 <= write_cmd4;
       write_cmd6 <= write_cmd5;
       write_cmd7 <= write_cmd6;
       write_cmd8 <= write_cmd7;
       write_cmd  <= write_cmd6;
      end
  end



//************************************************************************
// register read cmd until READ command needs to be issued
//************************************************************************

  always @ (posedge clk180)
  begin
     if (rst180_r == 1'b1)
      begin
       read_cmd1      <= 1'b0;
       read_cmd2      <= 1'b0;
       read_cmd3      <= 1'b0;
       read_cmd4      <= 1'b0;
       read_cmd5      <= 1'b0;
       read_cmd6      <= 1'b0;
       read_cmd7      <= 1'b0;
       read_cmd8      <= 1'b0;
       read_cmd_reg   <= 1'b0;
       read_rcd_end   <= 1'b0;
	// mrd_ct_one <= 1'b0;
      end
     else
      begin
	  if (accept_cmd_in)
	    read_cmd1       <= read_cmd;
       read_cmd2       <= read_cmd1;
       read_cmd3       <= read_cmd2;
       read_cmd4       <= read_cmd3;
       read_cmd5       <= read_cmd4;
       read_cmd6       <= read_cmd5;
       read_cmd7       <= read_cmd6;
       read_cmd_reg    <= read_cmd7;
       read_cmd8       <= read_cmd7;
       read_rcd_end    <= read_cmd8;
	 //mrd_ct_one <= (MRD_COUNT == 2'b10);

      end
  end

//********************************************************************************************
// MRD Counter
// an executable command can be issued only after Tmrd(2 cycles) after a LMR command is issued
//********************************************************************************************
assign MRD_COUNT_value = (next_state1 == LOAD_MODE_REG) ? 2'b11 :
                          //(MRD_COUNT != 2'b00) ? (MRD_COUNT - 1'b1) :

                          (mrdCnt0 != 1'b1) ? (MRD_COUNT - 1'b1) :
                          2'b00;

//********************************************************************************************
// RFC Counter
// an executable command can be issued only after Trfc(60 ns => 60/5 = 12 cycles for 200MHz,
// 60 ns => 60/3.75 = 16 cycles for 266MHz  )
//                                after a AUTOREFRESH command is issued
//********************************************************************************************
assign RFC_COUNT_value = (next_state1 == AUTO_REFRESH ) ? (RFC_COUNTER_value) :
                          (RFC_COUNT != 6'b000000) ? (RFC_COUNT - 1'b1) :
                          6'b000000;
//********************************************************************************************
// RP Counter
// an executable command can be issued only after Trp(20 ns for a -5 device => 4 cycles)
//                        after a PRECHARGE command is issued
//********************************************************************************************
assign rp_cnt_value = (next_state1 == PRECHARGE) ? 3'b100 :
                       //(RP_COUNT != 3'b000) ? (RP_COUNT - 1'b1) :
                       (rpCnt0 != 1'b1) ? (RP_COUNT - 1'b1) :
                       3'b000;

//********************************************************************************************
// RRD Counter
// minimum interval between successive ACTIVE commands to different banks - Trrd
// 2 clock cycles
//********************************************************************************************
assign RRD_COUNT_value = (next_state1 == ACTIVE) ? 2'b10 :
                         // (RRD_COUNT != 2'b00) ? (RRD_COUNT - 1'b1) :
                           (rrdCnt0 != 1'b1) ? (RRD_COUNT - 1'b1) :
                           2'b00;

//*********************************************************************************************
// ACTIVE to READ/WRITE counter
// RCDr counter
// ACTIVE to READ delay - (-5) device requires 20 ns of delay => 4 clock cycles
//
// RCDW counter
// ACTIVE to WRITE delay - (-5) device requires 10 ns of delay => 2 clock cycles
//
//*********************************************************************************************

assign RCDR_COUNT_value =  (next_state1 == ACTIVE) ? 3'b101 :
                           // (RCDR_COUNT != 3'b000) ? (RCDR_COUNT - 1'b1) :
                            (rcdrCnt0  != 1'b1) ? (RCDR_COUNT - 1'b1) :
                            3'b000;

assign RCDW_COUNT_value = (next_state1 == ACTIVE) ? 3'b100 :
                          // (RCDW_COUNT != 2'b00) ? (RCDW_COUNT - 1'b1) :
                           (rcdwCnt0 != 1'b1) ? (RCDW_COUNT - 1'b1) :
                           2'b00;

//*********************************************************************************************
// ACTIVE to PRECHARGE counter
// RAS counter
// ACTIVE to PRECHARGE delay -
// the memory device require 40 ns (8 clock cycles)after issuing an ACTIVE command before issuing a
// PRECHARGE command
//
//*********************************************************************************************
assign ras_count_value = (next_state1 == ACTIVE) ? 4'b1000 :
                         // (RAS_COUNT != 4'b0000) ? (RAS_COUNT - 1'b1) :
                           (rasCnt0 != 1'b1) ? (RAS_COUNT - 1'b1) :
                           4'b0000;

//**********************************************************************************************
// RC counter
// an ACTIVE command to a different row can be issued only after the previous row has been
// precharged & after Trc is met
// Trc = 60 ns = 12 clock cycles
//**********************************************************************************************
assign RC_COUNT_value = (next_state1 == ACTIVE) ? 4'b1100 :
                        // (RC_COUNT != 4'b0000) ? (RC_COUNT - 1'b1) :

                         (rcCnt0 != 1'b1) ? (RC_COUNT - 1'b1) :
                         4'b0000;


//********************************************************************************************
// WR Counter
// a PRECHARGE command can be applied only after 2 cycles after a WRITE command has finished
// executing
//********************************************************************************************

   always @(posedge clk180) begin
   if (rst180_r)
	WR_COUNT <= 3'b000;
      else
	if (dqs_enable)
	  WR_COUNT <=  WR ;
	else if (WR_COUNT != 3'b000)
          WR_COUNT <= WR_COUNT - 3'b001;
   end


assign ODT_COUNT_value =  (GO_TO_ODT_ON == 1'b1)? 2'b11 :
                          (ODT_COUNT !=2'b00) ? (ODT_COUNT - 2'b01) :
                          2'b00;

//********************************************************************************************************
// Auto refresh counter - the design uses AUTO REFRESH
// the DDR SDRAM requires AUTO REFRESH cycles at an average interval of 7.8 us
// Hence, a counter value to obtain a 7.8.6 us clock for Auto Refresh
// (Refresh Request is raised for every 7.7 us to allow termination for any ongoing process)
// Hence for 200MHz frequency,The Refresh_count_value = freq * refresh_time_period = 267*7.7 = 2055
//**********************************************************************************************************

assign AUTOREF_value   = (AUTOREF_COUNT == max_ref_cnt);

assign AUTOREF_CNT_val = AUTOREF_value ? 12'b0 :
                          AUTOREF_COUNT + 1'b1;


always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
  begin
     AUTOREF_COUNT     <= 12'b0;
     RFC_COUNTER_value <= `RFC_COUNTER;
    max_ref_cnt       <=  `REF_FREQ_CNT;
  end
  else
  begin
     AUTOREF_COUNT     <= AUTOREF_CNT_val;
     RFC_COUNTER_value <= `RFC_COUNTER;
    max_ref_cnt       <= `REF_FREQ_CNT;
  end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      AUTO_REF_pulse_end <= 1'b0;
      AUTO_REF_detect1   <= 1'b0;
      AUTO_REF_detect    <= 1'b0;
    end
  else
    begin
      AUTO_REF_detect1   <= AUTOREF_value && INIT_DONE;
      AUTO_REF_detect    <= AUTO_REF_detect1;
      AUTO_REF_pulse_end <= AUTO_REF_detect;
    end
end

assign auto_ref1 = ((AUTO_REF_detect == 1'b1) && (AUTO_REF_pulse_end != 1'b1)) ? 1'b1 : 1'b0;

assign AR_done_p = (AR_Done_reg == 1'b1) ? 1'b1 : 1'b0;


always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     auto_ref_wait <= 1'b0;
     ar_done  <= 1'b0;
     Auto_Ref_issued <= 1'b0;
    end
  else
    begin
     if (auto_ref1 && !auto_ref_wait)
        auto_ref_wait <= 1'b1;
     else if (Auto_Ref_issued)
        auto_ref_wait <= 1'b0;
     else
        auto_ref_wait <= auto_ref_wait;

     ar_done         <= AR_done_p;
     Auto_Ref_issued <= Auto_Ref_issued_p;

    end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
  begin
     auto_ref_wait1 <= 1'b0;
     auto_ref_wait2 <= 1'b0;
     auto_ref       <= 1'b0;
  end
  else
  begin
     if (Auto_Ref_issued)
     begin
        auto_ref_wait1 <= 1'b0;
        auto_ref_wait2 <= 1'b0;
        auto_ref       <= 1'b0;
     end
     else
     begin
        auto_ref_wait1  <= auto_ref_wait;
        auto_ref_wait2  <= auto_ref_wait1;
        auto_ref        <= auto_ref_wait2;
     end
  end
end


assign auto_ref_req = auto_ref_wait;


assign Auto_Ref_issued_p = (next_state1 == AUTO_REFRESH);


//**********************************************************************************************
// Burst count value counter when there are cosecutive READs or WRITEs
// While doing consecutive READs or WRITEs, the Burst_count value determines when the next
// READ or WRITE command should be issued. The burst length is determined while loading the
// Load Mode Register
// burst_cnt_max shows the number of clock cycles for each burst
//**********************************************************************************************
   assign burst_cnt_max = 3'b010;


//********************************************************************************************
// CAS latency counter
// CAS latencies of 2,3,4 can be set using Mode register bits M(6:4)
//
//      M6  M5  M4   CAS latency
//      0    1   0 -    2
//      0    1   1 -    3
//      1    0   0 -    4
//      others     -   reserved
// This design uses a CAS latency of 3 for a clock rate of 200 MHz
//
//********************************************************************************************
assign cas_count_value = (next_state1 == BURST_READ) ? 2'b10 :
                         //(CAS_COUNT != 2'b00) ? (CAS_COUNT - 1'b1) :
                         (casCnt0 != 1'b1) ? (CAS_COUNT - 1'b1) :
                         2'b00;



assign rdburst_end_cnt_value = //(CAS_COUNT == 2'b01) ? burst_cnt_max :
                               (casCnt1 == 1'b1) ? burst_cnt_max :
                               (RDBURST_END_CNT != 3'b000) ? (RDBURST_END_CNT - 1'b1) :
                               3'b000;



assign wrburst_end_cnt_value = ((next_state1 == FIRST_WRITE) || (next_state1 == BURST_WRITE)) ? burst_cnt_max :
                               (wrburst_end_cnt != 3'b000) ? (wrburst_end_cnt - 1'b1) :
                               3'b000;


assign wrburst_chk = ((next_state1 == BURST_WRITE) || (next_state1 == WRITE_WAIT)) ? 1'b1 : 1'b0;

assign rdburst_chk  = ((next_state1 == BURST_READ) || (next_state1 == READ_WAIT)) ? 1'b1 : 1'b0;

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      rdburst_end_1 <= 1'b0;
      rdburst_end_2 <= 1'b0;
      rdburst_end_3 <= 1'b0;
      rdburst_end_4 <= 1'b0;
      rdburst_end_5 <= 1'b0;
    end
  else
    begin
      rdburst_end_2 <= rdburst_end_1;
      rdburst_end_3 <= rdburst_end_2;
      rdburst_end_4 <= rdburst_end_3;
      rdburst_end_5 <= rdburst_end_4;
      rdburst_end_6 <= rdburst_end_5;
      rdburst_end_7 <= rdburst_end_6;
      rdburst_end_8 <= rdburst_end_7;
     if (((CAS_COUNT[1] == 1'b1) || (CAS_COUNT[0] == 1'b1 || (burst_cnt_max == 3'b010))) && (burst_done == 1'b1))
        rdburst_end_1 <= 1'b1;
      else
        rdburst_end_1 <= 1'b0;
    end
end

assign rdburst_end_r = rdburst_end_3 || rdburst_end_4 || rdburst_end_5 || rdburst_end_6 || rdburst_end_7 || rdburst_end_8;
assign rdburst_end = rdburst_end_1 || rdburst_end_2 ;

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     wrburst_end_1 <= 1'b0;
     wrburst_end_2 <= 1'b0;
     wrburst_end_3 <= 1'b0;
     wrburst_end_4 <= 1'b0;
     wrburst_end_5 <= 1'b0;
     wrburst_end_6 <= 1'b0;
     wrburst_end_7 <= 1'b0;
     wrburst_end_8 <= 1'b0;
     wrburst_end_9 <= 1'b0;
    end
  else
    begin
     wrburst_end_2  <= wrburst_end_1;
     wrburst_end_3  <= wrburst_end_2;
     wrburst_end_4  <= wrburst_end_3;
     wrburst_end_5  <= wrburst_end_4;
     wrburst_end_6  <= wrburst_end_5;
     wrburst_end_7  <= wrburst_end_6;
     wrburst_end_8  <= wrburst_end_7;
     if (((wrburst_end_cnt[1] == 1'b1) || (wrburst_end_cnt[0] == 1'b1) || (burst_cnt_max == 3'b010)) && (burst_done == 1'b1))
         wrburst_end_1 <= 1'b1;
     else
         wrburst_end_1 <= 1'b0;
    end
end

assign wrburst_end = wrburst_end_1 || wrburst_end_2 || wrburst_end_3;

//**********************************************************************************************
// to generate the Data Strobe enable and reset signal
// The DQS signal needs to be generated center aligned with the data.
// The controller generates the DQS enable signal when the state machine is in the FIRST_WRITE
// state,to take care of the write preamble
//**********************************************************************************************

assign DQS_enable_out = ((next_state1 == FIRST_WRITE) || (next_state1 == BURST_WRITE)  || (wrburst_end_cnt != 3'b000)) ? 1'b1 : 1'b0;

assign DQS_reset_out  = (next_state1 == FIRST_WRITE) ? 1'b1 : 1'b0;


assign dqs_enable = (cas_latency == 'd3)? DQS_enable2 :
                    (cas_latency == 'd4)? DQS_enable3 :
                    DQS_enable1;

assign dqs_reset  = (cas_latency == 'd3)? DQS_reset2_clk0:
                    (cas_latency == 'd4)? DQS_reset3_clk0:
                    DQS_reset1_clk0;

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      DQS_enable_int <= 1'b0;
      DQS_reset_int  <= 1'b0;
    end
  else
    begin
      DQS_enable_int <= DQS_enable_out;
      DQS_reset_int  <= DQS_reset_out;
    end
end

always @ (posedge clk)
begin
 if (rst0_r == 1'b1)
   begin
     DQS_enable1     <= 1'b0;
     DQS_enable2     <= 1'b0;
     DQS_enable3     <= 1'b0;
     DQS_enable4     <= 1'b0;
     DQS_enable5     <= 1'b0;
     DQS_enable6     <= 1'b0;
     DQS_reset1_clk0 <= 1'b0;
     DQS_reset2_clk0 <= 1'b0;
     DQS_reset3_clk0 <= 1'b0;
     DQS_reset4_clk0 <= 1'b0;
     DQS_reset5_clk0 <= 1'b0;
     DQS_reset4_clk0_r <= 1'b0;
     DQS_reset5_clk0_r <= 1'b0;
     DQS_reset6_clk0_r <= 1'b0;
   end
 else
   begin
     DQS_enable1     <= DQS_enable_int;
     DQS_enable2     <= DQS_enable1;
     DQS_enable3     <= DQS_enable2;
     DQS_enable4     <= DQS_enable3;
     DQS_enable5     <= DQS_enable4;
     DQS_enable6     <= DQS_enable5;
     DQS_reset1_clk0 <= DQS_reset_int;
     DQS_reset2_clk0 <= DQS_reset1_clk0;
     DQS_reset3_clk0 <= DQS_reset2_clk0;
     DQS_reset4_clk0 <= DQS_reset3_clk0;
     DQS_reset5_clk0 <= DQS_reset4_clk0;
     DQS_reset6_clk0 <= DQS_reset5_clk0;
     DQS_reset4_clk0_r <= DQS_reset3_clk0;
     DQS_reset5_clk0_r <= DQS_reset4_clk0;
     DQS_reset6_clk0_r <= DQS_reset5_clk0;
   end
end

//****************************************************************************************************
//Generating WRITE and READ enable signals
//*****************************************************************************************************

assign write_enable_out = ((wrburst_chk == 1'b1) || (wrburst_end_cnt != 3'b000));

//assign read_enable_out = ((CAS_COUNT != 2'b00) || (rdburst_chk == 1'b1));

assign read_enable_out = ((casCnt0 != 1'b1) || (rdburst_chk == 1'b1));

assign read_enable_out_r = read_enable_out || rdburst_end_r;


always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
   write_enable <= 1'b0;
  else
  begin
   write_enable_out1 <= write_enable_out;
   write_enable_out2 <= write_enable_out1;

   if(cas_latency == 'd3)
      write_enable  <= write_enable_out;
   else if(cas_latency == 'd4)
           write_enable  <= write_enable_out1;
   else
       write_enable  <= write_enable_out;
   end
end

assign cmd_ack = ack_reg;

FD ACK_REG_INST1 (
                  .Q(ack_reg),
                  .D(ack_o),
                  .C(clk180)
                  );

assign ack_o =( ( (cas_latency == 'd3)&& ( (write_cmd4 == 1'b1) || (read_cmd1 == 1'b1) )  ) ||
                ( (cas_latency == 'd4)&& ( (write_cmd5 == 1'b1) || (read_cmd2 == 1'b1) ) )  );



//*********************************************************************************************
//  to initialize memory
//*********************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     init_memory <= 1'b0;
     INIT_DONE   <= 1'b0;
    end
  else
    begin
     init_memory <= init_mem;
//     INIT_DONE   <= init_done_value && (INIT_COUNT == 4'b1001);
     INIT_DONE   <= init_done_value && (INIT_COUNT == 4'b1011);
    end
end

always @ (posedge clk180)
begin
  if (initialize_memory)
    begin
      INIT_PRE_COUNT <= `INIT_PRE_COUNT_VALUE;
    end
  else
    begin
       INIT_PRE_COUNT <= INIT_PRE_COUNT - 7'h1;
    end
end

/*
assign init_mem = (initialize_memory == 1'b1) ? 1'b1 :
                  ((INIT_COUNT == 4'b1001) && (MRD_COUNT == 2'b00)) ? 1'b0 :
                  init_memory;
  */

assign init_mem = (initialize_memory == 1'b1) ? 1'b1 :
                  //((INIT_COUNT == 4'b1011) && (MRD_COUNT == 2'b00)) ? 1'b0 :
                  ((INIT_COUNT == 4'b1011) && (mrdCnt0 == 1'b1)) ? 1'b0 :
                  init_memory;


// counter for Memory Initialization sequence

assign INIT_COUNT_value = (((next_state1 == PRECHARGE) || (next_state1 == LOAD_MODE_REG) || (next_state1 == AUTO_REFRESH)) && init_memory == 1'b1) ? (INIT_COUNT + 1'b1) :
                          INIT_COUNT;

assign init_done_value =  (DLL_RST_COUNT == 8'b0000_0001) ;


//Counter for DLL Reset complete
assign DLL_RST_COUNT_value = ((INIT_COUNT == 4'b0100)) ? 8'b1100_1000 :      //200
                             (DLL_RST_COUNT != 8'b0000_0001)? (DLL_RST_COUNT - 8'b0000_0001):
                              8'b0000_0001;

//Signal to go directly to ACTIVE state
assign GO_TO_ACTIVE_value =((read_cmd == 1'b1) && (read_cmd1 != 1'b1)) ? 1'b1 : 1'b0;
//with every WIRTE cmd ODT is turned ON
assign GO_TO_ODT_ON_value = ((write_cmd_in == 1'b1) && (write_cmd1 != 1'b1))? 1'b1 : 1'b0;

// To check if there is a bank conflict after an ACTIVE command has been issued for a particular bank

//assign CONFLICT_value  = ((RRD_COUNT == 2'b01) && (BA_address_conflict == 1'b1)) ? 1'b1 : 1'b0;

assign CONFLICT_value  = ((rrdCnt1 == 1'b1) && (BA_address_conflict == 1'b1));

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
   begin
     CONFLICT   <= 1'b0;
     GO_TO_ACTIVE <= 1'b0;
     GO_TO_ODT_ON <= 1'b0;
   end
  else
   begin
     CONFLICT   <= CONFLICT_value;
     GO_TO_ACTIVE <= GO_TO_ACTIVE_value;
     GO_TO_ODT_ON <= GO_TO_ODT_ON_value;
   end
end

//**********************************************************************************************
// Register counter values
//**********************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     INIT_COUNT     <= 4'b0000;
     DLL_RST_COUNT  <= 8'b0000_0000;
     RP_COUNT       <= 3'b000;
     MRD_COUNT      <= 2'b00;
     RFC_COUNT      <= 6'b000000;
     RAS_COUNT      <= 4'b0000;
     CAS_COUNT      <= 2'b00;
     RRD_COUNT      <= 2'b00;
     RCDR_COUNT     <= 3'b000;
     RCDW_COUNT     <= 3'b000;
     RC_COUNT       <= 4'b0000;
     RDBURST_END_CNT <= 3'b000;
     wrburst_end_cnt <= 3'b000;
     ODT_COUNT       <= 2'b00;
     RFC_COUNT_reg   <= 1'b0;
     AR_Done_reg     <= 1'b0;

     rcdr_ct_one <= 1'b0;

     rpCnt0 <= 1'b1;

     mrdCnt0 <= 1'b1;
     mrdCnt1 <= 1'b0;

     rasCnt0 <= 1'b1;

     casCnt0 <= 1'b1;
     casCnt1 <= 1'b0;

     rrdCnt0 <= 1'b1;
     rrdCnt1 <= 1'b0;

     rcdrCnt0 <= 1'b1;

     rcdwCnt0 <= 1'b1;
     rcdwCnt1 <= 1'b0;

     rcCnt0 <= 1'b1;


    end
  else
    begin
     INIT_COUNT     <= INIT_COUNT_value;
     DLL_RST_COUNT  <= DLL_RST_COUNT_value;
     RP_COUNT       <= rp_cnt_value;
     MRD_COUNT      <= MRD_COUNT_value;
     RFC_COUNT      <= RFC_COUNT_value;
     RAS_COUNT      <= ras_count_value;
     CAS_COUNT      <= cas_count_value;
     RRD_COUNT      <= RRD_COUNT_value;
     RCDR_COUNT     <= RCDR_COUNT_value;
     RCDW_COUNT     <= RCDW_COUNT_value;
     RC_COUNT       <= RC_COUNT_value;
     wrburst_end_cnt <= wrburst_end_cnt_value;
     RDBURST_END_CNT <= rdburst_end_cnt_value;
     ODT_COUNT       <= ODT_COUNT_value;
       rcdr_ct_one <= (RCDR_COUNT == 3'b010);

     if(RFC_COUNT == 6'b000010 ) //2
        AR_Done_reg <= 1'b1;
     else
       AR_Done_reg <= 1'b0;

     if(AR_Done_reg == 1'b1)
        RFC_COUNT_reg <= 1'b1;
     else if (Auto_Ref_issued_p  == 1'b1)
        RFC_COUNT_reg <= 1'b0;
     else
       RFC_COUNT_reg <= RFC_COUNT_reg;

    rpCnt0  <= (RP_COUNT[2] == 1'b0 && RP_COUNT[1] == 1'b0 && !rp_cnt_value[2]);

    mrdCnt0 <= (MRD_COUNT[1] == 1'b0 && MRD_COUNT_value[1:0] != 2'b11);
    mrdCnt1 <= (MRD_COUNT[1:0] == 2'b10);

    rasCnt0 <= (RAS_COUNT[3] == 1'b0 &&  RAS_COUNT[2] == 1'b0 &&  RAS_COUNT[1] == 1'b0 && !ras_count_value[3]);

    casCnt0 <= (CAS_COUNT[1] == 1'b0 && cas_count_value[1] != 1'b1);

    casCnt1 <= (CAS_COUNT[1:0] == 2'b10);

    rrdCnt0 <= ( RRD_COUNT[1] == 1'b0 && RRD_COUNT_value[1] != 1'b1);
    rrdCnt1 <= (RRD_COUNT[1:0] == 2'b01);

    rcdrCnt0 <= ( RCDR_COUNT[2] != 1'b0 && RCDR_COUNT[1] != 1'b0 && RCDR_COUNT_value[2:0] != 3'b101);

    rcdwCnt0 <= ( RCDW_COUNT[2] == 1'b0 && RCDW_COUNT[1] == 1'b0 && !RCDW_COUNT_value[2]);
    rcdwCnt1 <= ( RCDW_COUNT[2:0] == 3'b010);

   rcCnt0 <= ( RC_COUNT[3] == 1'b0 && RC_COUNT[2] == 1'b0 && RC_COUNT[1] == 1'b0 && RC_COUNT_value[3:2] != 2'b11);

    end
end

//*********************************************************************************************
// to check current state for the address bus
//*********************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
   begin
   next_state    <= IDLE;
   end
  else
   begin
   next_state    <= next_state1;
   end
end

//*********************************************************************************************
// main state machine
//*********************************************************************************************

always @ (rst180_r or RP_COUNT or INIT_COUNT or MRD_COUNT or RFC_COUNT or CAS_COUNT or WR_COUNT or GO_TO_ACTIVE or ld_mode or
          write_cmd3 or read_cmd5 or CONFLICT or next_state or ODT_COUNT or wrburst_end or wrburst_end_cnt or
           burst_length or rdburst_end or init_memory or RCDW_COUNT or RCDR_COUNT or PRECHARGE_CMD or INIT_PRE_COUNT
           or GO_TO_ODT_ON or auto_ref or RFC_COUNT_reg or rcdr_ct_one  or rpCnt0 or mrdCnt0 or mrdCnt1 or
           rrdCnt0 or rrdCnt1 or rcdrCnt0 or rcdwCnt0 or rcCnt0 )


begin
if (rst180_r == 1'b1)
  next_state1 <= IDLE;
else
  begin
     case (next_state)
       IDLE : begin
          if (init_memory == 1'b1)//initilaize memory from user
            begin
               case (INIT_COUNT)
                 // this state is for NOP/Deselect
                 4'b0000 :
                   begin
                      if(INIT_PRE_COUNT == 7'b000_0001)
                        next_state1 <= PRECHARGE;
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0001 :
                   begin
                     // if (RP_COUNT == 3'b000)

                        if (rpCnt0 == 1'b1)
                        next_state1 <= LOAD_MODE_REG; // For EMR(2)
                      else
                        next_state1 <= IDLE;

                   end
                 4'b0010 :
                   begin
                     // if (mrd_ct_one) //MRD_COUNT == 2'b01)
                        if (mrdCnt1 == 1'b1)
                        next_state1 <= LOAD_MODE_REG;  // For EMR(3)
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0011 :
                   begin
                     // if (mrd_ct_one) //MRD_COUNT == 2'b01)
                        if (mrdCnt1 == 1'b1)
                        next_state1 <= LOAD_MODE_REG;  // For EMR
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0100 :
                   begin
                     // if (mrd_ct_one) //MRD_COUNT == 2'b01)

                        if (mrdCnt1 == 1'b1) //MRD_COUNT == 2'b01)
                        next_state1 <= LOAD_MODE_REG;  // for reseting DLL in Base Mode register
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0101 :
                   begin
                    //  if (mrd_ct_one) //MRD_COUNT == 2'b01)
                        if (mrdCnt1 == 1'b1)
                        next_state1 <= PRECHARGE;
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0110 :
                   begin
                      //if (RP_COUNT == 3'b000)  // wait for 4 clock cycles (Trp)
                        if (rpCnt0 == 1'b1)
                        next_state1 <= AUTO_REFRESH;
                      else
                        next_state1 <= IDLE;
                   end
                 4'b0111:
                   begin
                      if (RFC_COUNT_reg == 1'b1)
                        next_state1 <= AUTO_REFRESH;
                      else
                        next_state1 <= IDLE;
                   end
                 4'b1000:
                   begin
                      if (RFC_COUNT_reg == 1'b1)
                        next_state1 <= LOAD_MODE_REG;  // to deactivate the rst DLL bit in the LMR
                      else
                        next_state1 <= IDLE;
                   end
                 4'b1001:
                   begin
                    //  if (MRD_COUNT != 2'b00)
                     // if (mrd_ct_one)
                        if (mrdCnt0 != 1'b1)
                        next_state1 <= LOAD_MODE_REG; // To set OCD to default value in EMR
                      else
                        next_state1 <= next_state;
                   end
                 4'b1010:
                   begin
//                      if (MRD_COUNT != 2'b00)
                     // if (mrd_ct_one)
                         if (mrdCnt0 != 1'b1)
                        next_state1 <= LOAD_MODE_REG; //OCD exit in EMR
                      else
                        next_state1 <= next_state;
                   end
                 4'b1011:
                   begin
//                      if (MRD_COUNT != 2'b00)
                      //if (mrd_ct_one)
                        if (mrdCnt0 != 1'b1)
                        next_state1 <= IDLE;
                      else
                        next_state1 <= next_state;
                   end

                 default :
                   next_state1 <= IDLE;
               endcase
            end

         // else if ( auto_ref == 1'b1  && RFC_COUNT_reg == 1'b1 && RP_COUNT == 3'b000 )

            else if ( auto_ref == 1'b1  && RFC_COUNT_reg == 1'b1 && rpCnt0 == 1'b1 )
            next_state1 <= AUTO_REFRESH; // normal Refresh in the IDLE state
	  else if (PRECHARGE_CMD == 1'b1)
            next_state1 <= PRECHARGE;
          else if (ld_mode == 1'b1)
            next_state1 <= LOAD_MODE_REG;
          else if (GO_TO_ODT_ON == 1'b1 || CONFLICT == 1'b1)
            next_state1 <= ODT_TURN_ON;
          else if (GO_TO_ACTIVE == 1'b1 || CONFLICT == 1'b1)
            next_state1 <= ACTIVE;
          else
            next_state1 <= IDLE;
       end

       ODT_TURN_ON :
         begin
            if(ODT_COUNT == 2'd0)
              next_state1 <= ACTIVE;
            else
              next_state1 <= ODT_TURN_ON;
         end

         PRECHARGE :
              next_state1 <= IDLE;

         LOAD_MODE_REG :
              next_state1 <= IDLE;

         AUTO_REFRESH :
              next_state1 <= IDLE;

         ACTIVE :
              next_state1 <= ACTIVE_WAIT;

         ACTIVE_WAIT :
           begin
             // if ((RCDW_COUNT == 2'b01) && (write_cmd3 == 1'b1))

                if ((rcdwCnt1 == 1'b1) && (write_cmd3 == 1'b1))
                next_state1 <= FIRST_WRITE;
              else if (rcdr_ct_one && read_cmd5) // (RCDR_COUNT == 3'b001) && (read_cmd5 == 1'b1))
                next_state1 <= BURST_READ;
              else
                next_state1 <= ACTIVE_WAIT;
           end


       FIRST_WRITE :
         begin
            next_state1 <= WRITE_WAIT;
         end

       WRITE_WAIT :
         begin
            case(wrburst_end)
              1'b1 :
                next_state1 <= PRECHARGE_AFTER_WRITE;
              1'b0 :
                begin
                   if (wrburst_end_cnt == 3'b001)
                     next_state1 <= BURST_WRITE;
                   else
                     next_state1 <= WRITE_WAIT;
                end
              default :
                next_state1 <= WRITE_WAIT;
            endcase
         end
       BURST_WRITE :
         begin
            next_state1 <= WRITE_WAIT;
         end
       READ_AFTER_WRITE :
         next_state1 <= BURST_READ;
       PRECHARGE_AFTER_WRITE :
         begin
            next_state1 <= PRECHARGE_AFTER_WRITE_2;
         end
       PRECHARGE_AFTER_WRITE_2 :
         begin
            if(WR_COUNT == 3'd0)
              next_state1 <= PRECHARGE;
            else
              next_state1 <= PRECHARGE_AFTER_WRITE_2;
         end

       READ_WAIT : begin
          case(rdburst_end)
            1'b1 :
              next_state1 <= PRECHARGE_AFTER_WRITE;
            1'b0 :
              begin
                // if (CAS_COUNT == 2'b01)
                   if (casCnt1 == 1'b1)
                   next_state1 <= BURST_READ;
                 else
                   next_state1 <= READ_WAIT;
              end
            default :
              next_state1 <= READ_WAIT;
          endcase
       end
       BURST_READ :
         begin
              next_state1 <= READ_WAIT;
         end
       default :
                next_state1 <= IDLE;
    endcase
  end
end

//************************************************************************************************
// address generation logic
//************************************************************************************************

assign address_config[`row_address-1:7] = (next_state == PRECHARGE) ? {{`row_address-11{1'b0}},4'b1000} :
                                          (INIT_COUNT == 4'b0100) ? {{`row_address-13{1'b0}},EMR[12:7]} :  //EMR
                                          (INIT_COUNT == 4'b1010) ? {{`row_address-13{1'b0}},EMR[12:10],3'b111} :  //EMR (OCD set to default)
                                          (INIT_COUNT == 4'b1011) ? {{`row_address-13{1'b0}},EMR[12:10],3'b000} :  //EMR (OCD exit)
                                          (INIT_COUNT == 4'b0010) ? {`row_address-7{1'b0}} :            //EMR (2)
                                          (INIT_COUNT == 4'b0011) ? {`row_address-7{1'b0}} :            //EMR (3)
                                          (INIT_COUNT == 4'b0101 || (next_state == LOAD_MODE_REG && INIT_COUNT != 4'b1001)) ? {{`row_address-13{1'b0}},LMR_DLL_rst[12:7]}:
                                          (INIT_COUNT == 4'b1001 && next_state != PRECHARGE) ? {{`row_address-13{1'b0}},LMR_DLL_set[12:7]}:
                                          {`row_address-7{1'b0}};

assign address_config[6:4] =  (INIT_COUNT == 4'b0100 || INIT_COUNT == 4'b1010 || INIT_COUNT == 4'b1011) ? EMR[6:4] :         //EMR
                              (( INIT_COUNT == 4'b0010 || INIT_COUNT == 4'b0011)) ? 3'b000 : //EMR(2) & EMR(3)
                              (next_state == LOAD_MODE_REG) ? cas_latency :
                              3'b000;

assign address_config[3] = (INIT_COUNT == 4'b0100 || INIT_COUNT == 4'b1010 || INIT_COUNT == 4'b1011) ? EMR[3] : 1'b0; // design uses sequential burst

assign address_config[2:0] =  (INIT_COUNT == 4'b0100 || INIT_COUNT == 4'b1010 || INIT_COUNT == 4'b1011) ? EMR[2:0] : //EMR
                              ((INIT_COUNT == 4'b0010 || INIT_COUNT == 4'b0011)) ? 3'b000 : //EMR(2) & EMR(3)
                              (next_state == LOAD_MODE_REG) ? burst_length :
                              3'b000;


assign ddr_address1 = (next_state == LOAD_MODE_REG || next_state == PRECHARGE) ? address_config :
                      (next_state == ACTIVE) ? row_address_reg :
                      ((next_state == BURST_WRITE) || (next_state == FIRST_WRITE) || (next_state == BURST_READ)) ? {{`row_address - `column_address{1'b0}},column_address_reg} :
                      `row_address'b0;

assign ddr_ba1 =  ((next_state == LOAD_MODE_REG) && (INIT_COUNT == 4'b0100 || INIT_COUNT == 4'b1010 || INIT_COUNT == 4'b1011)) ? {{`bank_address-1{1'b0}},1'b1} : //EMR
                  ((next_state == LOAD_MODE_REG) && (INIT_COUNT == 4'b0010))  ? {{`bank_address-2{1'b0}},2'b10}: //EMR(2)
                  ((next_state == LOAD_MODE_REG) && (INIT_COUNT == 4'b0011))  ? {{`bank_address-2{1'b0}},2'b11}: //EMR(3)
                  ((next_state == ACTIVE) || (next_state == FIRST_WRITE) || (next_state == BURST_WRITE) || (next_state == BURST_READ)) ? BA_address_reg :
                  {{`bank_address-1{1'b0}},1'b0};

assign ddr_ODT1 = ( write_cmd8 == 1'b1 )? 1'b1 : 1'b0;

//********************************************************************************************************
//  register row address
//********************************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
     row_address_active_reg <= `row_address'b0;
  else
   begin
     if (next_state == ACTIVE)
         row_address_active_reg <= row_address_reg;
     else
         row_address_active_reg <= row_address_active_reg;
   end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
     row_address_conflict <= 1'b0;
  else
   begin
     if (row_address_reg != row_address_active_reg)
         row_address_conflict <= 1'b1;
     else
         row_address_conflict <= 1'b0;
   end
end

//********************************************************************************************************
//  register bank address
//********************************************************************************************************

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
      BA_address_active <= `bank_address'b0;
  else
    begin
      if (next_state == ACTIVE)
          BA_address_active <= BA_address_reg;
      else
          BA_address_active <= BA_address_active;
    end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
      BA_address_conflict <= 1'b0;
  else
    begin
      if (BA_address_reg != BA_address_active)
          BA_address_conflict <= 1'b1;
      else
          BA_address_conflict <= 1'b0;
    end
end

//********************************************************************************************************
//  register column address
//********************************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     column_address_reg1 <= `column_address'b0;
     column_address_reg2 <= `column_address'b0;
     column_address_reg3 <= `column_address'b0;
     column_address_reg4 <= `column_address'b0;
     column_address_reg5 <= `column_address'b0;
     column_address_reg6 <= `column_address'b0;
    end
  else
    begin
     column_address_reg1 <= column_address_reg;
     column_address_reg2 <= column_address_reg1;
     column_address_reg3 <= column_address_reg2;
     column_address_reg4 <= column_address_reg3;
     column_address_reg5 <= column_address_reg4;
     column_address_reg6 <= column_address_reg5;
    end
end



//**************************************************************************************************
//Pipeline stages for ddr_address and ddr_ba
//**************************************************************************************************

always @ (posedge clk180)
begin
if (rst180_r == 1'b1)
  begin
   ddr_address2  <= `row_address'b0;
   ddr_address3  <= `row_address'b0;
   ddr_ba2       <= `bank_address'b0;
   ddr_ba3       <= `bank_address'b0;

   ddr_ODT2      <= 1'b0;
  end
else
  begin
    ddr_address2 <= ddr_address1;
    ddr_address3 <= ddr_address2;
    ddr_ba2      <= ddr_ba1;
    ddr_ba3      <= ddr_ba2;
    ddr_ODT2      <= ddr_ODT1;
  end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      ddr_ODT_cntrl   <= 1'b0;
    end
  else
    begin
      ddr_ODT_cntrl   <= ddr_ODT2;
    end
end

/*
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      ddr_address4        <= `row_address'b0;
      ddr_address5        <= `row_address'b0;
//      ddr_address_cntrl   <= `row_address'b0;
    end
  else
    begin
      ddr_address4        <= ddr_address3;
      ddr_address5        <= ddr_address4;

//        ddr_address_cntrl   <= ddr_address1;
    end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
     ddr_ba4       <= `bank_address'b0;
     ddr_ba5       <= `bank_address'b0;
//     ddr_ba_cntrl  <= `bank_address'b0;
    end
  else
    begin
     ddr_ba4       <= ddr_ba3;
     ddr_ba5       <= ddr_ba4;

//      ddr_ba_cntrl  <= ddr_ba1;

    end
end
*/
//************************************************************************************************
// control signals to the Memory
//************************************************************************************************

assign ddr_rasb1 = ((next_state == ACTIVE) || (next_state == PRECHARGE) || (next_state == AUTO_REFRESH) || (next_state == LOAD_MODE_REG)) ? 1'b0 : 1'b1;

assign ddr_casb1 = ((next_state == BURST_READ) || (next_state == BURST_WRITE) || (next_state == FIRST_WRITE) ||
                   (next_state == AUTO_REFRESH) || (next_state == LOAD_MODE_REG)) ? 1'b0 : 1'b1;

assign ddr_web1  = ((next_state == BURST_WRITE) || (next_state == FIRST_WRITE) ||
                   (next_state == PRECHARGE) || (next_state == LOAD_MODE_REG)) ? 1'b0 : 1'b1;


//*************************************************************************************************
// register CONTROL SIGNALS outputs
//**************************************************************************************************
always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      ddr_rasb3 <= 1'b1;
      ddr_casb3 <= 1'b1;
      ddr_web3  <= 1'b1;
      ddr_rasb2 <= 1'b1;
      ddr_casb2 <= 1'b1;
      ddr_web2  <= 1'b1;
    end
  else
    begin
      ddr_rasb2    <= ddr_rasb1;
      ddr_casb2    <= ddr_casb1;
      ddr_web2     <= ddr_web1;
      ddr_rasb3    <= ddr_rasb2;
      ddr_casb3    <= ddr_casb2;
      ddr_web3     <= ddr_web2;
    end
end

always @ (posedge clk180)
begin
  if (rst180_r == 1'b1)
    begin
      ddr_rasb4          <= 1'b1;
      ddr_casb4          <= 1'b1;
      ddr_web4           <= 1'b1;
      ddr_rst_dqs_rasb4  <= 1'b1;
      ddr_rst_dqs_casb4  <= 1'b1;
      ddr_rst_dqs_web4   <= 1'b1;
    end
  else
    begin
      ddr_rasb4          <= ddr_rasb3;
      ddr_casb4          <= ddr_casb3;
      ddr_web4           <= ddr_web3;
//for rst_dqs_div
/*
       if(cas_latency == 3'b011) // CL3
       begin
          ddr_rst_dqs_rasb4  <= ddr_rasb1;
 	  ddr_rst_dqs_casb4  <= ddr_casb1;
   	  ddr_rst_dqs_web4   <= ddr_web1;
       end
       else if(cas_latency == 3'b100) // CL4
*/
       if(cas_latency == 3'b100) // CL4
       begin
        ddr_rst_dqs_rasb4  <= ddr_rasb1;
 	  ddr_rst_dqs_casb4  <= ddr_casb1;
   	  ddr_rst_dqs_web4   <= ddr_web1;
       end
       else
	 begin
            ddr_rst_dqs_rasb4  <= ddr_rst_dqs_rasb4;
   	    ddr_rst_dqs_casb4  <= ddr_rst_dqs_casb4;
   	    ddr_rst_dqs_web4   <= ddr_rst_dqs_web4;
	 end
    end
end

always @ (posedge clk180)
begin
    if (rst180_r == 1'b1)
        dqs_div_cascount <= 3'b0;
    else
      begin
        if ((ddr_rst_dqs_rasb4 == 1'b1) && (ddr_rst_dqs_casb4 == 1'b0) && (ddr_rst_dqs_web4 == 1'b1) && (cas_latency == 3'b100))//CL=4
             dqs_div_cascount <= 3'b010;
        else if ((ddr_rasb1 == 1'b1) && (ddr_casb1 == 1'b0) && (ddr_web1 == 1'b1) && (cas_latency == 3'b011))//CL=3
               dqs_div_cascount <= 3'b010;
        else
          begin
             if (dqs_div_cascount != 3'b000)
                 dqs_div_cascount <= dqs_div_cascount - 1'b1;
             else
                 dqs_div_cascount <= dqs_div_cascount;

          end
      end
end

always @ (posedge clk180)
begin
    if (rst180_r == 1'b1)
        dqs_div_rdburstcount <= 3'b000;
    else
      begin
        if (dqs_div_cascount == 2'b01)
            dqs_div_rdburstcount <= 3'b010;
        else
          begin
            if (dqs_div_rdburstcount != 2'b00)
               dqs_div_rdburstcount <= dqs_div_rdburstcount - 1'b1;
            else
               dqs_div_rdburstcount <= dqs_div_rdburstcount;
          end
      end
end

always @ (posedge clk180)
begin
    if (rst180_r == 1'b1)
        rst_dqs_div_r <= 1'b0;
    else
      begin
        if (dqs_div_cascount == 3'b001  && burst_length == 3'b010)
            rst_dqs_div_r <= 1'b1;
        else if (dqs_div_rdburstcount == 3'b001 && dqs_div_cascount == 3'b000)
            rst_dqs_div_r <= 1'b0;
        else
            rst_dqs_div_r <= rst_dqs_div_r;

      end
end

FD  rst_calib0  (
                 .Q(rst_calib),
                 .D(rst_dqs_div_r),
                 .C(clk180)
                 );

FD  rst_iob_out (
                 .Q(rst_dqs_div_int1),
                 .D(rst_dqs_div_r),
                 .C(clk180)
                 );


endmodule
