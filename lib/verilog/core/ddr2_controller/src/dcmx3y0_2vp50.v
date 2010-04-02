////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2006 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: I.34
//  \   \         Application: netgen
//  /   /         Filename: dcmx3y0_2vp50.v
// /___/   /\     Timestamp: Fri Feb  2 13:14:09 2007
// \   \  /  \
//  \___\/\___\
//
// Command	: -ofmt verilog -sim -insert_glbl false -w dcmx3y0_2vp50.ngo
// Device	: xc2vp50ff1152-5
// Input file	: dcmx3y0_2vp50.ngo
// Output file	: dcmx3y0_2vp50.v
// # of Modules	: 1
// Design Name	: dcmx3y0_2vp50
// Xilinx        : /cad/xilinx/ise8.2i
//
// Purpose:
//     This verilog netlist is a verification model and uses simulation
//     primitives which may not represent the true implementation of the
//     device, however the netlist is functionally correct and should not
//     be modified. This file cannot be synthesized and should only be used
//     with supported simulation tools.
//
// Reference:
//     Development System Reference Guide, Chapter 23
//     Synthesis and Simulation Design Guide, Chapter 6
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ps

module dcmx3y0_2vp50 (
  clock1_in, clock2_out, clock1_out, clock2_in
);
  input clock1_in;
  output clock2_out;
  output clock1_out;
  input clock2_in;

// synthesis translate_off
  wire VCC_1;
  wire clkd1buf_1;
  wire clkd1inv_1;
  wire clkd1buf_2;
  wire clkd1inv_2;
  VCC VCC_0 (
    .P(VCC_1)
  );
  //defparam BUF1_1.LOC = "SLICE_X134Y0";
  defparam BUF1_1.INIT = 16'hff00;
  LUT4 BUF1_1 (
    .I0(VCC_1),
    .I1(VCC_1),
    .I2(VCC_1),
    .I3(clock1_in),
    .O(clkd1buf_1)
  );
  //defparam INV1_1.LOC = "SLICE_X134Y0";
  defparam INV1_1.INIT = 16'h00ff;
  LUT4 INV1_1 (
    .I0(VCC_1),
    .I1(VCC_1),
    .I2(VCC_1),
    .I3(clkd1buf_1),
    .O(clkd1inv_1)
  );
  //defparam INV2_1.LOC = "SLICE_X69Y1";
  defparam INV2_1.INIT = 16'h3333;
  LUT4 INV2_1 (
    .I0(VCC_1),
    .I1(clkd1inv_1),
    .I2(VCC_1),
    .I3(VCC_1),
    .O(clock1_out)
  );
  //defparam BUF1_2.LOC = "SLICE_X135Y1";
  defparam BUF1_2.INIT = 16'hf0f0;
  LUT4 BUF1_2 (
    .I0(VCC_1),
    .I1(VCC_1),
    .I2(clock2_in),
    .I3(VCC_1),
    .O(clkd1buf_2)
  );
  //defparam INV1_2.LOC = "SLICE_X135Y1";
  defparam INV1_2.INIT = 16'h00ff;
  LUT4 INV1_2 (
    .I0(VCC_1),
    .I1(VCC_1),
    .I2(VCC_1),
    .I3(clkd1buf_2),
    .O(clkd1inv_2)
  );
  //defparam INV2_2.LOC = "SLICE_X68Y0";
  defparam INV2_2.INIT = 16'h3333;
  LUT4 INV2_2 (
    .I0(VCC_1),
    .I1(clkd1inv_2),
    .I2(VCC_1),
    .I3(VCC_1),
    .O(clock2_out)
  );
// synthesis translate_on
endmodule

