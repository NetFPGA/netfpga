///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: channel_init_sm.ejava,v $
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
//  CHANNEL_INIT_SM
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: the CHANNEL_INIT_SM module is a state machine for managing channel
//               bonding and verification.
//
//               The channel init state machine is reset until the lane up signals
//               of all the lanes that constitute the channel are asserted.  It then
//               requests channel bonding until the lanes have been bonded and
//               checks to make sure the bonding was successful.  Channel bonding is
//               skipped if there is only one lane in the channel.  If bonding is
//               unsuccessful, the lanes are reset.
//
//               After the bonding phase is complete, the state machine sends
//               verification sequences through the channel until it is clear that
//               the channel is ready to be used.  If verification is successful,
//               the CHANNEL_UP signal is asserted.  If it is unsuccessful, the
//               lanes are reset.
//
//               After CHANNEL_UP goes high, the state machine is quiescent, and will
//               reset only if one of the lanes goes down, a hard error is detected, or
//               a general reset is requested.
//
//               This module supports 1 2-byte lane designs
//

`timescale 1 ns / 10 ps

module aurora_framing_CHANNEL_INIT_SM
(
    // MGT Interface
    CH_BOND_DONE,

    EN_CHAN_SYNC,


    // Aurora Lane Interface
    CHANNEL_BOND_LOAD,
    GOT_A,
    GOT_V,

    RESET_LANES,


    // System Interface
    USER_CLK,
    RESET,

    CHANNEL_UP,
    START_RX,


    // Idle and Verification Sequence Generator Interface
    DID_VER,

    GEN_VER,


    // Channel Error Management Interface
    RESET_CHANNEL

);

`define DLY #1



//******************************* Parameter Declarations ****************************

    parameter   EXTEND_WATCHDOGS            =   0;



//***********************************Port Declarations*******************************

    // MGT Interface
    input              CH_BOND_DONE;

    output             EN_CHAN_SYNC;

    // Aurora Lane Interface
    input              CHANNEL_BOND_LOAD;
    input   [0:1]      GOT_A;
    input              GOT_V;
    output             RESET_LANES;

    // System Interface
    input              USER_CLK;
    input              RESET;

    output             CHANNEL_UP;
    output             START_RX;

    // Idle and Verification Sequence Generator Interface
    input              DID_VER;

    output             GEN_VER;


    // Channel Init State Machine Interface
    input              RESET_CHANNEL;



//***************************External Register Declarations***************************

    reg             START_RX;


//***************************Internal Register Declarations***************************

    reg             free_count_done_r;
    reg             extend_watchdogs_n_r;
    reg     [0:15]  verify_watchdog_r;
    reg             all_lanes_v_r;
    reg             got_first_v_r;
    reg     [0:31]  v_count_r;
    reg             bad_v_r;
    reg     [0:2]   rxver_count_r;
    reg     [0:7]   txver_count_r;


    // State registers
    reg             wait_for_lane_up_r;
    reg             verify_r;
    reg             ready_r;


//*********************************Wire Declarations**********************************

    wire            free_count_1_r;
    wire            free_count_2_r;
    wire            extend_watchdogs_1_r;
    wire            extend_watchdogs_2_r;
    wire            extend_watchdogs_n_c;
    wire            insert_ver_c;
    wire            verify_watchdog_done_r;
    wire            rxver_3d_done_r;
    wire            txver_8d_done_r;
    wire            reset_lanes_c;



    // Next state signals
    wire            next_verify_c;
    wire            next_ready_c;


//*********************************Main Body of Code**********************************


    //________________Main state machine for bonding and verification________________


    // State registers
    always @(posedge USER_CLK)
        if(RESET|RESET_CHANNEL)
        begin
            wait_for_lane_up_r <=  `DLY    1'b1;
            verify_r           <=  `DLY    1'b0;
            ready_r            <=  `DLY    1'b0;
        end
        else
        begin
            wait_for_lane_up_r <=  `DLY    1'b0;
            verify_r           <=  `DLY    next_verify_c;
            ready_r            <=  `DLY    next_ready_c;
        end



    // Next state logic
    assign  next_verify_c       =   wait_for_lane_up_r |
                                    (verify_r & (!rxver_3d_done_r|!txver_8d_done_r));


    assign  next_ready_c        =   (verify_r & txver_8d_done_r & rxver_3d_done_r)|
                                    ready_r;



    // Output Logic


    // Channel up is high as long as the Global Logic is in the ready state.
    assign  CHANNEL_UP          =   ready_r;


    // Turn the receive engine on as soon as all the lanes are up.
    always @(posedge USER_CLK)
        if(RESET)   START_RX    <=  `DLY    1'b0;
        else        START_RX    <=  `DLY    !wait_for_lane_up_r;



    // Generate the Verification sequence when in the verify state.
    assign  GEN_VER             =   verify_r;



    //__________________________Channel Reset _________________________________


    // Some problems during channel bonding and verification require the lanes to
    // be reset.  When this happens, we assert the Reset Lanes signal, which gets
    // sent to all Aurora Lanes.  When the Aurora Lanes reset, their LANE_UP signals
    // go down.  This causes the Channel Error Detector to assert the Reset Channel
    // signal.
    assign reset_lanes_c =              (verify_r & verify_watchdog_done_r)|
                                        (verify_r & bad_v_r & !rxver_3d_done_r)|
                                        (RESET_CHANNEL & !wait_for_lane_up_r)|
                                        RESET;


    defparam reset_lanes_flop_i.INIT = 1'b1;
    FD reset_lanes_flop_i
    (
        .D(reset_lanes_c),
        .C(USER_CLK),
        .Q(RESET_LANES)

    );





    //___________________________Watchdog timers____________________________________


    // We create a free counter out of SRLs to count large values without excessive cost.

    defparam free_count_1_i.INIT = 16'h8000;
    SRL16 free_count_1_i
    (
        .Q(free_count_1_r),
        .A0(1'b1),
        .A1(1'b1),
        .A2(1'b1),
        .A3(1'b1),
        .CLK(USER_CLK),
        .D(free_count_1_r)
    );


    defparam free_count_2_i.INIT = 16'h8000;
    SRL16E free_count_2_i
    (
        .Q(free_count_2_r),
        .A0(1'b1),
        .A1(1'b1),
        .A2(1'b1),
        .A3(1'b1),
        .CLK(USER_CLK),
        .CE(free_count_1_r),
        .D(free_count_2_r)
    );


    // The watchdog extention SRLs are used to multiply the free count by 32
    SRL16E extend_watchdogs_1_i
    (
        .Q(extend_watchdogs_1_r),
        .A0(1'b1),
        .A1(1'b1),
        .A2(1'b1),
        .A3(1'b1),
        .CLK(USER_CLK),
        .CE(free_count_1_r),
        .D(extend_watchdogs_n_c)
    );


    SRL16E extend_watchdogs_2_i
    (
        .Q(extend_watchdogs_2_r),
        .A0(1'b1),
        .A1(1'b1),
        .A2(1'b1),
        .A3(1'b1),
        .CLK(USER_CLK),
        .CE(free_count_1_r),
        .D(extend_watchdogs_1_r)
    );

    assign  extend_watchdogs_n_c =   !extend_watchdogs_2_r;

    always @(posedge USER_CLK)
        extend_watchdogs_n_r    <=  `DLY    extend_watchdogs_n_c;



    // Finally we have logic that registers a pulse when both the inner and the
    // outer SRLs have a bit in their last position.  This should map to carry logic
    // and a register. If EXTEND WATCHDOGS is turned on, the free count is doubled.
    always @(posedge USER_CLK)
        if(EXTEND_WATCHDOGS)
            free_count_done_r <=  `DLY    extend_watchdogs_2_r & extend_watchdogs_n_r;
        else
            free_count_done_r <=  `DLY    free_count_2_r & free_count_1_r;



    // We use the freerunning count as a CE for the verify watchdog.  The
    // count runs continuously so the watchdog will vary between a count of 4096
    // and 3840 cycles - acceptable for this application. Extending the count multiplies
    //
    always @(posedge USER_CLK)
        if(free_count_done_r | !verify_r)
            verify_watchdog_r   <=  `DLY    {verify_r,verify_watchdog_r[0:14]};

    assign  verify_watchdog_done_r  =   verify_watchdog_r[15];




    //_____________________________Channel Bonding_______________________________

    // We don't use channel bonding for the single lane case, so we tie the
    // EN_CHAN_SYNC signal low.
    assign   EN_CHAN_SYNC    =   1'b0;



    //________________________________Verification__________________________


    // Vs need to appear on all lanes simultaneously.
    always @(posedge USER_CLK)
        all_lanes_v_r <=  `DLY  GOT_V;


    // Vs need to be decoded by the aurora lane and then checked by the
    // Global logic.  They must appear periodically.
    always @(posedge USER_CLK)
        if(!verify_r)                   got_first_v_r   <=  `DLY    1'b0;
        else if(all_lanes_v_r)          got_first_v_r   <=  `DLY    1'b1;


    assign  insert_ver_c    =   all_lanes_v_r & !got_first_v_r | (v_count_r[31] & verify_r);


    // Shift register for measuring the time between V counts.
    always @(posedge USER_CLK)
        v_count_r   <=  `DLY    {insert_ver_c,v_count_r[0:30]};


    // Assert bad_v_r if a V does not arrive when expected.
    always @(posedge USER_CLK)
        bad_v_r     <=  `DLY    (v_count_r[31] ^ all_lanes_v_r) & got_first_v_r;



    // Count the number of Ver sequences received.  You're done after you receive four.
    always @(posedge USER_CLK)
        if((v_count_r[31] & all_lanes_v_r) |!verify_r)
            rxver_count_r   <=  `DLY    {verify_r,rxver_count_r[0:1]};


    assign  rxver_3d_done_r     =   rxver_count_r[2];


    // Count the number of Ver sequences transmitted. You're done after you send eight.
    always @(posedge USER_CLK)
        if(DID_VER |!verify_r)
            txver_count_r   <=  `DLY    {verify_r,txver_count_r[0:6]};


    assign  txver_8d_done_r     =   txver_count_r[7];

endmodule
