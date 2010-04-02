///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: channel_error_detect.ejava,v $
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
//  CHANNEL_ERROR_DETECT
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: the CHANNEL_ERROR_DETECT module monitors the error signals
//               from the Aurora Lanes in the channel.  If one or more errors
//               are detected, the error is reported as a channel error.  If
//               a hard error is detected, it sends a message to the channel
//               initialization state machine to reset the channel.
//
//               This module supports 1 2-byte lane designs
//

`timescale 1 ns / 10 ps

module aurora_framing_CHANNEL_ERROR_DETECT
(
    // Aurora Lane Interface
    SOFT_ERROR,
    HARD_ERROR,
    LANE_UP,


    // System Interface
    USER_CLK,
    POWER_DOWN,

    CHANNEL_SOFT_ERROR,
    CHANNEL_HARD_ERROR,


    // Channel Init SM Interface
    RESET_CHANNEL
);

`define DLY #1


//***********************************Port Declarations*******************************

    //Aurora Lane Interface
    input              SOFT_ERROR;
    input              HARD_ERROR;
    input              LANE_UP;


    //System Interface
    input              USER_CLK;
    input              POWER_DOWN;

    output             CHANNEL_SOFT_ERROR;
    output             CHANNEL_HARD_ERROR;


    //Channel Init SM Interface
    output             RESET_CHANNEL;


//*****************************External Register Declarations*************************

    reg                CHANNEL_SOFT_ERROR;
    reg                CHANNEL_HARD_ERROR;
    reg                RESET_CHANNEL;


//***************************Internal Register Declarations***************************

    reg                soft_error_r;
    reg                hard_error_r;


//*********************************Wire Declarations**********************************

    wire               channel_soft_error_c;
    wire               channel_hard_error_c;
    wire               reset_channel_c;


//*********************************Main Body of Code**********************************


    // Register all of the incoming error signals.  This is neccessary for timing.
    always @(posedge USER_CLK)
    begin
        soft_error_r    <=  `DLY    SOFT_ERROR;
        hard_error_r    <=  `DLY    HARD_ERROR;
    end



    // Assert Channel soft error if any of the soft error signals are asserted.
    initial
        CHANNEL_SOFT_ERROR = 1'b1;

    assign channel_soft_error_c = soft_error_r;

    always @(posedge USER_CLK)
        CHANNEL_SOFT_ERROR  <=  `DLY    channel_soft_error_c;



    // Assert Channel hard error if any of the hard error signals are asserted.
    initial
        CHANNEL_HARD_ERROR = 1'b1;

    assign channel_hard_error_c = hard_error_r;

    always @(posedge USER_CLK)
        CHANNEL_HARD_ERROR  <=  `DLY    channel_hard_error_c;




    // "reset_channel_r" is asserted when any of the LANE_UP signals are low.
    initial
        RESET_CHANNEL   =  1'b1;

    assign reset_channel_c = !LANE_UP;

    always @(posedge USER_CLK)
        RESET_CHANNEL    <=  `DLY    reset_channel_c | POWER_DOWN;

endmodule
