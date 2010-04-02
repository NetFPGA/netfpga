///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: chbond_count_dec.ejava,v $
//          Rev:  $Revision: 1.1.2.3 $
//
//      Company:  Xilinx
// Contributors:  R. K. Awalt, B. L. Woodard, N. Gulstone
//
//   Disclaimer:  XILINX IS PROVIDING THIS DESIGN, CODE, OR
//                INFORMATION "AS IS" SOLELY FOR USE IN DEVELOPING
//                PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY
//                PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
//                ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,
//                APPLICATION OR STANDARD, XILINX IS MAKING NO
//                REPRESENTATION THAT THIS IMPLEMENTATION IS FREE
//                FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE
//                RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY
//                REQUIRE FOR YOUR IMPLEMENTATION.  XILINX
//                EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH
//                RESPECT TO THE ADEQUACY OF THE IMPLEMENTATION,
//                INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
//                REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
//                FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES
//                OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//                PURPOSE.
//
//                (c) Copyright 2004 Xilinx, Inc.
//                All rights reserved.
//
///////////////////////////////////////////////////////////////////////////////
//
//  CHBOND_COUNT_DEC
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: This module decodes the MGT's RXCLKCORCNT.  Its
//               CHANNEL_BOND_LOAD output is active when RXCLKCORCNT
//               indicates the elastic buffer has executed channel
//               bonding for the current RXDATA.
//
//               * Supports Virtex 2 Pro

`timescale 1 ns / 10 ps

module aurora_framing_CHBOND_COUNT_DEC (

    RX_CLK_COR_CNT,
    CHANNEL_BOND_LOAD,
    USER_CLK

);

`define DLY #1

//******************************Parameter Declarations*******************************

    parameter CHANNEL_BOND_LOAD_CODE = 3'b101;     //Code indicating channel bond load complete


//***********************************Port Declarations*******************************


    input   [2:0]   RX_CLK_COR_CNT;

    output          CHANNEL_BOND_LOAD;

    input           USER_CLK;


//**************************External Register Declarations****************************

    reg             CHANNEL_BOND_LOAD;

//*********************************Main Body of Code**********************************

    always @(posedge USER_CLK)
        CHANNEL_BOND_LOAD <= (RX_CLK_COR_CNT == CHANNEL_BOND_LOAD_CODE);

endmodule
