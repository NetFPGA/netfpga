

///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:13 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: standard_cc_module.ejava,v $
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
//  STANDARD CC MODULE
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: This module drives the Aurora module's Clock Compensation
//               interface. Clock Compensation sequences are generated according
//               to the requirements in the Aurora Protocol specification.
//
//               This module supports Aurora Modules with any number of
//               2-byte lanes and no User Flow Control.
//
//

`timescale 1 ns / 10 ps

module aurora_framing_STANDARD_CC_MODULE
(
    //Clock Compensation Control Interface
    WARN_CC,
    DO_CC,


    //System Interface
    DCM_NOT_LOCKED,
    USER_CLK,
    CHANNEL_UP

);

`define DLY #1


//***********************************Port Declarations*******************************

    //Clock Compensation Control Interface
    output      WARN_CC;
    output      DO_CC;


    //System Interface
    input       DCM_NOT_LOCKED;
    input       USER_CLK;
    input       CHANNEL_UP;


//**************************** External Register Declarations*************************

    reg             WARN_CC;
    reg             DO_CC;


//************************** Internal Register Declarations **************************

    reg     [0:9]   prepare_count_r;
    reg     [0:5]   cc_count_r;
    reg             reset_r;

    reg     [0:11]  count_13d_srl_r;
    reg             count_13d_flop_r;
    reg     [0:14]  count_16d_srl_r;
    reg             count_16d_flop_r;
    reg     [0:22]  count_24d_srl_r;
    reg             count_24d_flop_r;



//*********************************Wire Declarations**********************************

    wire    start_cc_c;
    wire    inner_count_done_r;
    wire    middle_count_done_c;
    wire    cc_idle_count_done_c;


//*********************************Main Body of Code**********************************



 //________________________Clock Correction State Machine__________________________



    // The clock correction state machine is a counter with three sections.  The first
    // section counts out the idle period before a clock correction occurs.  The second
    // section counts out a period when NFC and UFC operations should not be attempted
    // because they will not be completed.  The last section counts out the cycles of
    // the clock correction sequence.




    // The inner count for the CC counter counts to 13.  It is implemented using
    // an SRL16 and a flop

    // The SRL counts 12 bits of the count
    always @(posedge USER_CLK)
        count_13d_srl_r     <=  `DLY    {count_13d_flop_r, count_13d_srl_r[0:10]};


    // The inner count is done when a 1 reaches the end of the SRL
    assign  inner_count_done_r  =  count_13d_srl_r[11];


    // The flop extends the shift register to 13 bits for counting. It is held at
    // zero while channel up is low to clear the register, and is seeded with a
    // single 1 when channel up transitions from 0 to 1
    always @(posedge USER_CLK)
        if(~CHANNEL_UP)
            count_13d_flop_r    <=  `DLY    1'b0;
        else if(CHANNEL_UP && reset_r)
            count_13d_flop_r    <=  `DLY    1'b1;
        else
            count_13d_flop_r    <=  `DLY    inner_count_done_r;







    // The middle count for the CC counter counts to 16.  Its count increments only
    // when the inner count is done.  It is implemented using an SRL16 and a flop


    // The SRL counts 15 bits of the count. It is enabled only when the inner count
    // is done
    always @(posedge USER_CLK)
        if(inner_count_done_r|| !CHANNEL_UP)
            count_16d_srl_r     <=  `DLY    {count_16d_flop_r, count_16d_srl_r[0:13]};


    // The middle count is done when a 1 reaches the end of the SRL and the inner
    // count finishes
    assign  middle_count_done_c =   inner_count_done_r && count_16d_srl_r[14];



    // The flop extends the shift register to 16 bits for counting. It is held at
    // zero while channel up is low to clear the register, and is seeded with a
    // single 1 when channel up transitions from 0 to 1
    always @(posedge USER_CLK)
        if(~CHANNEL_UP)
            count_16d_flop_r    <=  `DLY    1'b0;
        else if(CHANNEL_UP && reset_r)
            count_16d_flop_r    <=  `DLY    1'b1;
        else if(inner_count_done_r)
            count_16d_flop_r    <=  `DLY    middle_count_done_c;






    // The outer count (aka the cc idle count) is done when it reaches 24.  Its count
    // increments only when the middle count is done.  It is implemented with 2 SRL16s
    // and a flop


    // The SRL counts 23 bits of the count. It is enabled only when the middle count is
    // done
    always @(posedge USER_CLK)
        if(middle_count_done_c || !CHANNEL_UP)
            count_24d_srl_r     <=  `DLY    {count_24d_flop_r, count_24d_srl_r[0:21]};


    // The cc idle count is done when a 1 reaches the end of the SRL and the middle count finishes
    assign  cc_idle_count_done_c    =   middle_count_done_c & count_24d_srl_r[22];

    // The flop extends the shift register to 24 bits for counting. It is held at
    // zero while channel up is low to clear the register, and is seeded with a single
    // 1 when channel up transitions from 0 to 1
    always @(posedge USER_CLK)
        if(~CHANNEL_UP)
            count_24d_flop_r    <=  `DLY    1'b0;
        else if(CHANNEL_UP && reset_r)
            count_24d_flop_r    <=  `DLY    1'b1;
        else if(middle_count_done_c)
            count_24d_flop_r    <=  `DLY    cc_idle_count_done_c;









    // For simulation, initialize prepare count to all zeros to simulate an SRL16
    // after configuration. The circuit will also work is the init value includes
    // ones.
    initial
        prepare_count_r = 10'b0000000000;



     // Because UFC and CC sequences are not allowed to preempt one another, there
     // there is a warning signal to indicate an impending CC sequence.  This signal
     // is used to prevent UFC messages from starting.
     // For 1 lane, we need an 10-cycle count.
     always @(posedge USER_CLK)
         prepare_count_r <=  `DLY    {cc_idle_count_done_c,prepare_count_r[0:8]};




    // The state machine stays in the prepare_cc state from when the cc idle
    // count finishes, to when the prepare count has finished.  While in this
    // state, UFC operations cannot start, which prevents them from having to
    // be pre-empted by CC sequences.
    always @(posedge USER_CLK)
         if(!CHANNEL_UP)                            WARN_CC    <=  `DLY    1'b0;
         else if(cc_idle_count_done_c)              WARN_CC    <=  `DLY    1'b1;
         else if(prepare_count_r[9])                WARN_CC    <=  `DLY    1'b0;



    // For simulation, init to zeros, to simulate an SRL after configuration. The circuit
    // will also operate if the SRL is not initialized to all zeros
    initial
         cc_count_r = 6'b000000;



    // Track the state of channel up on the previous cycle. We use this signal to determine
    // when to seed the shift register counters with ones
    always @(posedge USER_CLK)
        reset_r <=  `DLY    !CHANNEL_UP;



    //Do a CC after CHANNEL_UP is asserted or CC_warning is complete.
    assign start_cc_c   =   prepare_count_r[9] || (CHANNEL_UP && reset_r);



     // This SRL counter keeps track of the number of cycles spent in the CC
     // sequence.  It starts counting when the prepare_cc state ends, and
     // finishes counting after 6 cycles have passed.
     always @(posedge USER_CLK)
         cc_count_r      <=  `DLY    {(!CHANNEL_UP|prepare_count_r[9]),cc_count_r[0:4]};



     // The TX_LL module stays in the do_cc state for 6 cycles.  It starts
     // when the prepare_cc state ends.
     always @(posedge USER_CLK)
         if(!CHANNEL_UP)                 DO_CC <=  `DLY    1'b0;
         else if(start_cc_c)             DO_CC <=  `DLY    1'b1;
         else if(cc_count_r[5])          DO_CC <=  `DLY    1'b0;






endmodule


