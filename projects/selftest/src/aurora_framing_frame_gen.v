//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: frame_gen.ejava,v $
//          Rev:  $Revision: 1.1.2.3 $
//
//      Company:  Xilinx
// Contributors:  R. K. Awalt, B. L. Woodard, N. Gulstone, N. Jayarajan
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

//
//  FRAME GEN
//
//  Author: Nanditha Jayarajan, Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//
//  Description: This module is a pattern generator to test the Aurora
//               designs in hardware. It generates data and passes it
//               through the Aurora channel. If connected to a framing
//               interface, it generates frames of varying size and
//               separation. The data it generates on each cycle is
//               a word of all zeros, except for one high bit which
//               is shifted right each cycle. REM is always set to
//               the maximum value.
//
//  jad: Modified to use LFSR

`timescale 1 ns / 10 ps
`define DLY #1


module aurora_framing_FRAME_GEN
(
    // User Interface
    TX_D,
    TX_REM,
    TX_SOF_N,
    TX_EOF_N,
    TX_SRC_RDY_N,
    TX_DST_RDY_N,

    // System Interface
    USER_CLK,
    RESET
);

//***********************************Port Declarations*******************************

   // User Interface
    output  [15:0]     TX_D;
    output             TX_REM;
    output             TX_SOF_N;
    output             TX_EOF_N;
    output             TX_SRC_RDY_N;
    input              TX_DST_RDY_N;

      // System Interface
    input              USER_CLK;
    input              RESET;


//***************************External Register Declarations***************************

    reg                TX_SRC_RDY_N;
    reg                TX_SOF_N;
    reg                TX_EOF_N;


//***************************Internal Register Declarations***************************

    reg     [15:0]     tx_d_r;
    reg     [0:7]      frame_size_r;
    reg     [0:7]      bytes_sent_r;
    reg     [0:3]      ifg_size_r;

    //State registers for one-hot state machine
    reg                idle_r;
    reg                single_cycle_frame_r;
    reg                sof_r;
    reg                data_cycle_r;
    reg                eof_r;



//*********************************Wire Declarations**********************************

    wire               ifg_done_c;

    //Next state signals for one-hot state machine
    wire               next_idle_c;
    wire               next_single_cycle_frame_c;
    wire               next_sof_c;
    wire               next_data_cycle_c;
    wire               next_eof_c;


//*********************************Main Body of Code**********************************




    //______________________________ Transmit Data  __________________________________
    //Transmit data when TX_DST_RDY_N is asserted and not in an IFG
    always @(posedge USER_CLK)
        if(RESET)
        begin
            tx_d_r          <=  `DLY    16'd1;
        end
        else if(!TX_DST_RDY_N && !idle_r)
        begin
//            tx_d_r          <=  `DLY    {tx_d_r[15],tx_d_r[0:14]};
            tx_d_r          <=  `DLY    {tx_d_r[14:0], ~(tx_d_r[15]^tx_d_r[14]^tx_d_r[12]^tx_d_r[3])};
        end


    //Connect TX_D to the internal tx_d_r register
    assign  TX_D    =   tx_d_r;


    //Tie REM to indicate all words valid
    assign  TX_REM  =   1'd1;


    //Use a counter to determine the size of the next frame to send
    always @(posedge USER_CLK)
        if(RESET)
            frame_size_r    <=  `DLY    8'h00;
        else if(single_cycle_frame_r || eof_r)
            frame_size_r    <=  `DLY    frame_size_r + 1;


    //Use a second counter to determine how many bytes of the frame have already been sent
    always @(posedge USER_CLK)
        if(RESET)
            bytes_sent_r    <=  `DLY    8'h00;
        else if(sof_r)
            bytes_sent_r    <=  `DLY    8'h01;
        else if(!TX_DST_RDY_N && !idle_r)
            bytes_sent_r    <=  `DLY    bytes_sent_r + 1;


    //Use a freerunning counter to determine the IFG
    always @(posedge USER_CLK)
        if(RESET)
            ifg_size_r      <=  `DLY    4'h0;
        else
            ifg_size_r      <=  `DLY    ifg_size_r + 1;


    //IFG is done when ifg_size register is 0
    assign  ifg_done_c  =   (ifg_size_r == 4'h0);



    //_____________________________ Framing State machine______________________________
    //Use a state machine to determine whether to start a frame, end a frame, send
    //data or send nothing

    //State registers for 1-hot state machine
    always @(posedge USER_CLK)
        if(RESET)
        begin
            idle_r                  <=  `DLY    1'b1;
            single_cycle_frame_r    <=  `DLY    1'b0;
            sof_r                   <=  `DLY    1'b0;
            data_cycle_r            <=  `DLY    1'b0;
            eof_r                   <=  `DLY    1'b0;
        end
        else if(!TX_DST_RDY_N)
        begin
            idle_r                  <=  `DLY    next_idle_c;
            single_cycle_frame_r    <=  `DLY    next_single_cycle_frame_c;
            sof_r                   <=  `DLY    next_sof_c;
            data_cycle_r            <=  `DLY    next_data_cycle_c;
            eof_r                   <=  `DLY    next_eof_c;
        end


    //Nextstate logic for 1-hot state machine
    assign  next_idle_c                 =   !ifg_done_c &&
                                            (single_cycle_frame_r || eof_r || idle_r);

    assign  next_single_cycle_frame_c   =   (ifg_done_c && (frame_size_r == 0)) &&
                                            (idle_r || single_cycle_frame_r || eof_r);

    assign  next_sof_c                  =   (ifg_done_c && (frame_size_r != 0)) &&
                                            (idle_r || single_cycle_frame_r || eof_r);

    assign  next_data_cycle_c           =   (frame_size_r != bytes_sent_r) &&
                                            (sof_r || data_cycle_r);

    assign  next_eof_c                  =   (frame_size_r == bytes_sent_r) &&
                                            (sof_r || data_cycle_r);


    //Output logic for 1-hot state machine
    always @(posedge USER_CLK)
        if(RESET)
        begin
            TX_SOF_N        <=  `DLY    1'b1;
            TX_EOF_N        <=  `DLY    1'b1;
            TX_SRC_RDY_N    <=  `DLY    1'b1;
        end
        else if(!TX_DST_RDY_N)
        begin
            TX_SOF_N        <=  `DLY    !(sof_r || single_cycle_frame_r);
            TX_EOF_N        <=  `DLY    !(eof_r || single_cycle_frame_r);
            TX_SRC_RDY_N    <=  `DLY    idle_r;
        end




endmodule
