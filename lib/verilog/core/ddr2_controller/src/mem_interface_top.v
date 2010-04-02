`timescale 1ns/100ps

`include "parameters_32bit_00.v"
`include "ddr_defines.v"

module mem_interface_top
(
	dip1,
	dip2,
	reset_in,
	dip3,
	SYS_CLK,
	SYS_CLKb,

	clk_int,
	clk90_int,
	clk180,
	clk270,
	sys_rst,
	sys_rst90,
	sys_rst180,
	sys_rst270,
	cntrl0_rst_dqs_div_in,
	cntrl0_rst_dqs_div_out,
	cntrl0_ddr2_casb,
	cntrl0_ddr2_cke,
	cntrl0_burst_done,
	cntrl0_user_input_address,
	cntrl0_user_bank_address,
	cntrl0_user_command_register,
	cntrl0_user_input_data,
	cntrl0_user_data_mask,
	cntrl0_ar_done,
	cntrl0_user_cmd_ack,
	cntrl0_auto_ref_req,
	cntrl0_user_data_valid,
	cntrl0_user_output_data,
	cntrl0_init_val,
	cntrl0_ddr2_clk0,
	cntrl0_ddr2_clk0b,

	cntrl0_ddr2_clk1,
	cntrl0_ddr2_clk1b,
	cntrl0_ddr2_csb,
	cntrl0_ddr2_rasb,
	cntrl0_ddr2_web,
	cntrl0_ddr2_address,
	cntrl0_user_config_register1,
	cntrl0_user_config_register2,
	cntrl0_ddr2_ODT0,
	`ifdef DQS_n
	cntrl0_ddr2_dqs_n,
	`endif

	cntrl0_ddr2_dqs,
	cntrl0_ddr2_ba,
	cntrl0_ddr2_dm,
	cntrl0_ddr2_dq
);

//Input/Output declarations
input   dip1;
input   dip2;
input   reset_in;
input   dip3;
input   SYS_CLK;
input   SYS_CLKb;

output  clk_int;
output  clk90_int;
output  clk180;
output  clk270;
output  sys_rst;
output  sys_rst90;
output  sys_rst180;
output  sys_rst270;



input   cntrl0_rst_dqs_div_in;
output  cntrl0_rst_dqs_div_out;
output  cntrl0_ddr2_casb;
output  cntrl0_ddr2_cke;
input   cntrl0_burst_done;
input   [((`row_address + `column_address)-1): 0]  cntrl0_user_input_address;
input   [1:0]  cntrl0_user_bank_address;

input   [3:0]  cntrl0_user_command_register;
input   [63:0]  cntrl0_user_input_data;
input   [7:0]  cntrl0_user_data_mask;
output  cntrl0_auto_ref_req;
output  cntrl0_ar_done;
output  cntrl0_user_cmd_ack;
output  cntrl0_user_data_valid;
output  [63:0]  cntrl0_user_output_data;
output  cntrl0_init_val;
output  cntrl0_ddr2_clk0;
output  cntrl0_ddr2_clk0b;

output  cntrl0_ddr2_clk1;
output  cntrl0_ddr2_clk1b;

output  cntrl0_ddr2_csb;
output  cntrl0_ddr2_rasb;
output  cntrl0_ddr2_web;
output  [12:0]cntrl0_ddr2_address;
output  [1:0]cntrl0_ddr2_ba;
input   [14:0]  cntrl0_user_config_register1;
input   [12:0]  cntrl0_user_config_register2;
output  cntrl0_ddr2_ODT0;
`ifdef DQS_n
inout   [3:0]cntrl0_ddr2_dqs_n;
`endif
inout   [3:0]cntrl0_ddr2_dqs;
output  [3:0]cntrl0_ddr2_dm;
inout   [31:0]cntrl0_ddr2_dq;
wire    sys_clk_ibuf;
wire    wait_200us;
wire    clk_int;
wire    clk90_int;
wire    sys_rst;
wire    sys_rst90;
wire    sys_rst180;
wire    sys_rst270;
wire    clk180;
wire    clk270;
wire    [4:0] delay_sel;

//----  Component instantiations  ----
assign  clk180     =  ~clk_int;
assign  clk270     =  ~clk90_int;


ddr2_top_32bit_00  ddr2_top0
(
	.dip1  (dip1),
	.dip3  (dip3),
	.reset_in      (reset_in),
	.wait_200us    (wait_200us),
	.clk_int       (clk_int),
	.clk90_int     (clk90_int),
	.sys_rst       (sys_rst),
	.sys_rst90     (sys_rst90),
	.sys_rst180    (sys_rst180),
	.sys_rst270    (sys_rst270),
	.clk180        (clk180),
	.clk270        (clk270),

	.delay_sel_val (delay_sel),
	.rst_dqs_div_in(cntrl0_rst_dqs_div_in),
	.rst_dqs_div_out       (cntrl0_rst_dqs_div_out),
	.user_input_data       (cntrl0_user_input_data),
	.user_data_mask        (cntrl0_user_data_mask),
	.user_output_data      (cntrl0_user_output_data),
	.user_input_address    (cntrl0_user_input_address),
	.user_bank_address     (cntrl0_user_bank_address),
	.user_command_register (cntrl0_user_command_register),
	.user_cmd_ack          (cntrl0_user_cmd_ack),
	.auto_ref_req          (cntrl0_auto_ref_req),
	.burst_done            (cntrl0_burst_done),
	.init_val              (cntrl0_init_val),
	.ar_done               (cntrl0_ar_done),
	.user_data_valid       (cntrl0_user_data_valid),

	.ddr_casb              (cntrl0_ddr2_casb),
	.ddr_cke               (cntrl0_ddr2_cke),
	.ddr2_clk0             ( cntrl0_ddr2_clk0 ),
	.ddr2_clk0b            ( cntrl0_ddr2_clk0b ),

	.ddr2_clk1             ( cntrl0_ddr2_clk1 ),
	.ddr2_clk1b            ( cntrl0_ddr2_clk1b ),
	.ddr_csb               (cntrl0_ddr2_csb),
	.ddr_rasb              (cntrl0_ddr2_rasb),

	.ddr_web               (cntrl0_ddr2_web),
	.ddr_address           (cntrl0_ddr2_address),
	.ddr_ba(cntrl0_ddr2_ba),
	.ddr_dm(cntrl0_ddr2_dm),
	.ddr_dq(cntrl0_ddr2_dq),
	.ddr_ODT0      (cntrl0_ddr2_ODT0),
	`ifdef DQS_n
	.ddr_dqs_n     (cntrl0_ddr2_dqs_n),
	`endif
	.user_config_register1 (cntrl0_user_config_register1),
	.user_config_register2 (cntrl0_user_config_register2),
	.ddr_dqs               (cntrl0_ddr2_dqs)
);

IBUFGDS_LVDS_25  lvds_clk_input(
	.I     (SYS_CLK),
	.IB    (SYS_CLKb),
	.O     (sys_clk_ibuf)
);

infrastructure_top infrastructure_top0
(
	.reset_in              (reset_in),
	.wait_200us            (wait_200us),
	.delay_sel_val1_val    (delay_sel),
	.sys_rst_val           (sys_rst),
	.sys_rst90_val         (sys_rst90),
	.sys_clk_ibuf          (sys_clk_ibuf),
	.clk_int_val           (clk_int),
	.clk90_int_val         (clk90_int),
	.sys_rst180_val        (sys_rst180),
	.sys_rst270_val        (sys_rst270)

);

endmodule
