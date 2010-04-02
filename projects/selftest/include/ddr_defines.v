`ifndef DDR_DEFINES_V
`define DDR_DEFINES_V

`define DQS_n                     // This enables DQS# signals in port list & logic related to DQS#
//`define ODT_DISABLE_DELAY 4'd6    // This delays the ODT disable cmd, in cmd_fsm module
//`define ODT_CMD
//`define LMD_WR_CMD                // This generates LMR write cmd, in cmd_fsm module
//`define SINGLE_BURST              // This enables for testing Single Burst
`define CAS_LATENCY_3
//`define CAS_LATENCY_4

`ifdef CAS_LATENCY_3
`define INIT_PRE_COUNT_VALUE    7'b101_0000    //80  (400ns / clk period)
`define RFC_BITS                4
`define RFC_COUNT_VALUE         4'b1111;        //15
`endif

`ifdef CAS_LATENCY_4
`define INIT_PRE_COUNT_VALUE    7'b110_1011    //107 (400ns / clk period)
`define RFC_BITS                5
`define RFC_COUNT_VALUE         5'b1_0011;        //19
`endif

`endif
