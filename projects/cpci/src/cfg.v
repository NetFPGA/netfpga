/***********************************************************************

  File:   cfg.v
  Rev:    3.0.0

  This is the user configurable options file for Xilinx's PCI Logicore.


  Copyright (c) 2003 Xilinx, Inc.  All rights reserved.

***********************************************************************/

`define MEMORY 1'b0
`define IO     1'b1

`define DISABLE  1'b0
`define ENABLE   1'b1

`define PREFETCH    1'b1
`define NOFETCH     1'b0
`define IO_PREFETCH 1'b1

`define TYPE00     2'b00
`define TYPE01     2'b01
`define TYPE10     2'b10
`define IO_TYPE    2'b11

// BAR sizes in bytes
`define SIZE2G     32'h8000_0000
`define SIZE1G     32'hc000_0000
`define SIZE512M   32'he000_0000
`define SIZE256M   32'hf000_0000
`define SIZE128M   32'hf800_0000
`define SIZE64M    32'hfc00_0000
`define SIZE32M    32'hfe00_0000
`define SIZE16M    32'hff00_0000
`define SIZE8M     32'hff80_0000
`define SIZE4M     32'hffc0_0000
`define SIZE2M     32'hffe0_0000
`define SIZE1M     32'hfff0_0000
`define SIZE512K   32'hfff8_0000
`define SIZE256K   32'hfffc_0000
`define SIZE128K   32'hfffe_0000
`define SIZE64K    32'hffff_0000
`define SIZE32K    32'hffff_8000
`define SIZE16K    32'hffff_c000
`define SIZE8K     32'hffff_e000
`define SIZE4K     32'hffff_f000
`define SIZE2K     32'hffff_f800
`define SIZE1K     32'hffff_fc00
`define SIZE512    32'hffff_fe00
`define SIZE256    32'hffff_ff00
`define SIZE128    32'hffff_ff80
`define SIZE64     32'hffff_ffc0
`define SIZE32     32'hffff_ffe0
`define SIZE16     32'hffff_fff0

module cfg ( CFG );


  // Declare the port directions.
  output  [255:0]       CFG;

  /*************************************************************/
  /*  Configure Device, Vendor ID, Class Code, and Revision ID */
  /*************************************************************/

  // Device ID and Vendor ID
  assign CFG[151:120] = 32'h0001_FEED ;

  // Class Code and  Revision ID
  assign CFG[183:152] = 32'h02000000 ;

  /*************************************************************/
  /*  Configure Subsystem ID and SubVendor ID                  */
  /*************************************************************/

  // Subsystem ID and  Subvendor ID
  assign CFG[215:184] = 32'h0000_FEED ;

  // External Subsystem ID and Subvendor ID
  assign CFG[114] = `DISABLE ;

  /*************************************************************/
  /*  Configure Base Address Registers                         */
  /*************************************************************/

  // BAR0
assign CFG[0]       = `ENABLE ;
assign CFG[32:1]    = `SIZE128M ;
assign CFG[33]      = `NOFETCH ;
assign CFG[35:34]   = `TYPE00 ;
assign CFG[36]      = `MEMORY ;

  // BAR1
assign CFG[37]      = `DISABLE ;
assign CFG[69:38]   = `SIZE2G ;
assign CFG[70]      = `NOFETCH ;
assign CFG[72:71]   = `TYPE00 ;
assign CFG[73]      = `MEMORY ;

  // BAR2
assign CFG[74]      = `DISABLE ;
assign CFG[106:75]  = `SIZE2G ;
assign CFG[107]     = `NOFETCH ;
assign CFG[109:108] = `TYPE00 ;
assign CFG[110]     = `MEMORY ;

  /*************************************************************/
  /*  Configure MAX_LAT MIN_GNT                                */
  /*************************************************************/

  assign CFG[231:224] = 8'h00 ;
  assign CFG[223:216] = 8'h00 ;

  /************************************************************/
  /*  Configure other PCI options                             */
  /************************************************************/

  // Latency Timer Enable
  assign CFG[112] = `ENABLE ;

  // Interrupt Enable
  assign CFG[113] = `ENABLE ;

/************************************************************/
/*  For advanced users only.                                */
/************************************************************/

  // Capability List Enable
  assign CFG[116] = `DISABLE ;

  // Capability List Pointer
  assign CFG[239:232] = 8'h00 ;

  // User Config Space Enable
  assign CFG[118] = `DISABLE ;

  // Interrupt Acknowledge
  assign CFG[240] = `DISABLE ;

  /*****************************************************/
  /*  Do not modify any of the following settings!     */
  /*****************************************************/

  // Obsolete
  assign CFG[111] = `DISABLE ;

  // Obsolete
  assign CFG[117] = `DISABLE ;

  // Obsolete
  assign CFG[119] = `DISABLE ;

  // Enable 66 MHz
  assign CFG[244] = `DISABLE ;

  assign CFG[254:245] = 10'b0010000000;

  // Do Not Modify
  assign CFG[115] = `DISABLE ;
  assign CFG[241] = `DISABLE ;
  assign CFG[242] = `DISABLE ;
  assign CFG[243] = `DISABLE ;
  assign CFG[255] = `DISABLE ;

endmodule
