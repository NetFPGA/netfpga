///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: global_logic.ejava,v $
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
//  GLOBAL_LOGIC
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: The GLOBAL_LOGIC module handles channel bonding, channel
//               verification, channel error manangement and idle generation.
//
//               This module supports 1 2-byte lane designs
//

`timescale 1 ns / 10 ps

module aurora_framing_GLOBAL_LOGIC
(
    // MGT Interface
    CH_BOND_DONE,

    EN_CHAN_SYNC,


    // Aurora Lane Interface
    LANE_UP,
    SOFT_ERROR,
    HARD_ERROR,
    CHANNEL_BOND_LOAD,
    GOT_A,
    GOT_V,

    GEN_A,
    GEN_K,
    GEN_R,
    GEN_V,
    RESET_LANES,


    // System Interface
    USER_CLK,
    RESET,
    POWER_DOWN,

    CHANNEL_UP,
    START_RX,
    CHANNEL_SOFT_ERROR,
    CHANNEL_HARD_ERROR

);

`define DLY #1

//*******************************Parameter Declarations******************************

    parameter   EXTEND_WATCHDOGS    =   0;


//***********************************Port Declarations*******************************

    // MGT Interface
    input              CH_BOND_DONE;

    output             EN_CHAN_SYNC;


    // Aurora Lane Interface
    input              SOFT_ERROR;
    input              LANE_UP;
    input              HARD_ERROR;
    input              CHANNEL_BOND_LOAD;
    input   [0:1]      GOT_A;
    input              GOT_V;

    output             GEN_A;
    output  [0:1]      GEN_K;
    output  [0:1]      GEN_R;
    output  [0:1]      GEN_V;
    output             RESET_LANES;


    // System Interface
    input              USER_CLK;
    input              RESET;
    input              POWER_DOWN;

    output             CHANNEL_UP;
    output             START_RX;
    output             CHANNEL_SOFT_ERROR;
    output             CHANNEL_HARD_ERROR;



//*********************************Wire Declarations**********************************

    wire               gen_ver_i;
    wire               reset_channel_i;
    wire               did_ver_i;


//*********************************Main Body of Code**********************************


    // State Machine for channel bonding and verification.
    defparam aurora_framing_channel_init_sm_i.EXTEND_WATCHDOGS = EXTEND_WATCHDOGS;
    aurora_framing_CHANNEL_INIT_SM aurora_framing_channel_init_sm_i
    (
        // MGT Interface
        .CH_BOND_DONE(CH_BOND_DONE),

        .EN_CHAN_SYNC(EN_CHAN_SYNC),


        // Aurora Lane Interface

        .CHANNEL_BOND_LOAD(CHANNEL_BOND_LOAD),
        .GOT_A(GOT_A),
        .GOT_V(GOT_V),

        .RESET_LANES(RESET_LANES),


        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(RESET),

        .START_RX(START_RX),
        .CHANNEL_UP(CHANNEL_UP),


        // Idle and Verification Sequence Generator Interface
        .DID_VER(did_ver_i),

        .GEN_VER(gen_ver_i),


        // Channel Error Management Module Interface
        .RESET_CHANNEL(reset_channel_i)

    );



    // Idle and verification sequence generator module.
    aurora_framing_IDLE_AND_VER_GEN aurora_framing_idle_and_ver_gen_i
    (
        // Channel Init SM Interface
        .GEN_VER(gen_ver_i),

        .DID_VER(did_ver_i),


        // Aurora Lane Interface
        .GEN_A(GEN_A),
        .GEN_K(GEN_K),
        .GEN_R(GEN_R),
        .GEN_V(GEN_V),


        // System Interface
        .RESET(RESET),
        .USER_CLK(USER_CLK)
    );



    // Channel Error Management module.
    aurora_framing_CHANNEL_ERROR_DETECT aurora_framing_channel_error_detect_i
    (
        // Aurora Lane Interface
        .SOFT_ERROR(SOFT_ERROR),
        .HARD_ERROR(HARD_ERROR),
        .LANE_UP(LANE_UP),


        // System Interface
        .USER_CLK(USER_CLK),
        .POWER_DOWN(POWER_DOWN),

        .CHANNEL_SOFT_ERROR(CHANNEL_SOFT_ERROR),
        .CHANNEL_HARD_ERROR(CHANNEL_HARD_ERROR),


        // Channel Init State Machine Interface
        .RESET_CHANNEL(reset_channel_i)
    );

endmodule
