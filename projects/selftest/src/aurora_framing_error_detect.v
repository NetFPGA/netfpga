///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:09 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: error_detect.ejava,v $
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
//  ERROR_DETECT
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description : The ERROR_DETECT module monitors the MGT to detect hard
//                errors.  It accumulates the Soft errors according to the
//                leaky bucket algorithm described in the Aurora
//                Specification to detect Hard errors.  All errors are
//                reported to the Global Logic Interface.
//
//                * Supports Virtex 2 Pro
//

`timescale 1 ns / 10 ps

module aurora_framing_ERROR_DETECT
(
    // Lane Init SM Interface
    ENABLE_ERROR_DETECT,

    HARD_ERROR_RESET,


    // Global Logic Interface
    SOFT_ERROR,
    HARD_ERROR,


    // MGT Interface
    RX_DISP_ERR,
    TX_K_ERR,
    RX_NOT_IN_TABLE,
    RX_BUF_STATUS,
    TX_BUF_ERR,
    RX_REALIGN,


    // System Interface
    USER_CLK

);

// for test
`define DLY #1

//***********************************Port Declarations*******************************

    // Lane Init SM Interface
    input           ENABLE_ERROR_DETECT;

    output          HARD_ERROR_RESET;


    // Global Logic Interface
    output          SOFT_ERROR;
    output          HARD_ERROR;


    // MGT Interface
    input   [1:0]   RX_DISP_ERR;
    input   [1:0]   TX_K_ERR;
    input   [1:0]   RX_NOT_IN_TABLE;
    input           RX_BUF_STATUS;
    input           TX_BUF_ERR;
    input           RX_REALIGN;


    // System Interface
    input           USER_CLK;

//**************************External Register Declarations****************************

    reg             HARD_ERROR;
    reg             SOFT_ERROR;


//**************************Internal Register Declarations****************************

    reg     [0:1]   count_r;
    reg             bucket_full_r;
    reg     [0:1]   soft_error_r;
    reg     [0:1]   good_count_r;
    reg             soft_error_flop_r;  // Traveling flop for timing.
    reg             hard_error_flop_r;  // Traveling flop for timing.

//*********************************Wire Declarations**********************************


//*********************************Main Body of Code**********************************


    // Detect Soft Errors
    always @(posedge USER_CLK)
    if(ENABLE_ERROR_DETECT)
    begin
        soft_error_r[0] <=  `DLY   RX_DISP_ERR[1]|RX_NOT_IN_TABLE[1];
        soft_error_r[1] <=  `DLY   RX_DISP_ERR[0]|RX_NOT_IN_TABLE[0];
    end
    else
    begin
        soft_error_r[0] <=  `DLY   1'b0;
        soft_error_r[1] <=  `DLY   1'b0;
    end


    always @(posedge USER_CLK)
    begin
        soft_error_flop_r   <=  `DLY    |soft_error_r;
        SOFT_ERROR          <=  `DLY    soft_error_flop_r;
    end





    // Detect Hard Errors
    always @(posedge USER_CLK)
        if(ENABLE_ERROR_DETECT)
        begin
            hard_error_flop_r  <=  `DLY ((TX_K_ERR != 2'b00)|RX_BUF_STATUS|
                                                    TX_BUF_ERR|RX_REALIGN|bucket_full_r);
            HARD_ERROR         <=  `DLY     hard_error_flop_r;
        end
        else
        begin
            hard_error_flop_r   <=  `DLY    1'b0;
            HARD_ERROR          <=  `DLY    1'b0;
        end





    // Assert hard error reset when there is a hard error.  This assignment
    // just renames the two fanout branches of the hard error signal.
    assign HARD_ERROR_RESET =   hard_error_flop_r;



    //_______________________________Leaky Bucket__________________________________


    // Good cycle counter: it takes 2 consecutive good cycles to remove a demerit from
    // the leaky bucket

    always @(posedge USER_CLK)
        if(!ENABLE_ERROR_DETECT)    good_count_r    <=  `DLY    2'b00;
        else
        begin
            casez({soft_error_r, good_count_r})
                4'b0000 :   good_count_r    <=  `DLY    2'b10;
                4'b0001 :   good_count_r    <=  `DLY    2'b11;
                4'b0010 :   good_count_r    <=  `DLY    2'b00;
                4'b0011 :   good_count_r    <=  `DLY    2'b01;
                4'b?1?? :   good_count_r    <=  `DLY    2'b00;
                4'b10?? :   good_count_r    <=  `DLY    2'b01;
                default :   good_count_r    <=  `DLY    good_count_r;

            endcase
        end



    // Perform the leaky bucket algorithm using an up/down counter.  A drop is
    // added to the bucket whenever a soft error occurs and is allowed to leak
    // out whenever the good cycles counter reaches 2.  Once the bucket fills
    // (3 drops) it stays full until it is reset by disabling and then enabling
    // the error detection circuit.
    always @(posedge USER_CLK)
        if(!ENABLE_ERROR_DETECT)    count_r <=  `DLY    2'b00;
        else
        begin
            casez({soft_error_r,good_count_r,count_r})

                6'b000???    :   count_r <=  `DLY    count_r;
                6'b001?00    :   count_r <=  `DLY    2'b00;
                6'b001?01    :   count_r <=  `DLY    2'b00;
                6'b001?10    :   count_r <=  `DLY    2'b01;
                6'b001?11    :   count_r <=  `DLY    2'b10;

                6'b010000    :   count_r <=  `DLY    2'b01;
                6'b010100    :   count_r <=  `DLY    2'b01;
                6'b011000    :   count_r <=  `DLY    2'b01;
                6'b011100    :   count_r <=  `DLY    2'b00;

                6'b010001    :   count_r <=  `DLY    2'b10;
                6'b010101    :   count_r <=  `DLY    2'b10;
                6'b011001    :   count_r <=  `DLY    2'b10;
                6'b011101    :   count_r <=  `DLY    2'b01;

                6'b010010    :   count_r <=  `DLY    2'b11;
                6'b010110    :   count_r <=  `DLY    2'b11;
                6'b011010    :   count_r <=  `DLY    2'b11;
                6'b011110    :   count_r <=  `DLY    2'b10;

                6'b01??11    :   count_r <=  `DLY    2'b11;

                6'b10??00    :   count_r <=  `DLY    2'b01;
                6'b10??01    :   count_r <=  `DLY    2'b10;
                6'b10??10    :   count_r <=  `DLY    2'b11;
                6'b10??11    :   count_r <=  `DLY    2'b11;

                6'b11??00    :   count_r <=  `DLY    2'b10;
                6'b11??01    :   count_r <=  `DLY    2'b11;
                6'b11??10    :   count_r <=  `DLY    2'b11;
                6'b11??11    :   count_r <=  `DLY    2'b11;
            endcase
        end

    // Detect when the bucket is full and register the signal.

    always @(posedge USER_CLK)
        if(!ENABLE_ERROR_DETECT)    bucket_full_r    <=  `DLY    1'b0;
        else
        begin
            casez({soft_error_r, good_count_r, count_r})
                6'b010011 :   bucket_full_r    <=  `DLY    1'b1;
                6'b010111 :   bucket_full_r    <=  `DLY    1'b1;
                6'b011011 :   bucket_full_r    <=  `DLY    1'b1;
                6'b10??11 :   bucket_full_r    <=  `DLY    1'b1;
                6'b11??1? :   bucket_full_r    <=  `DLY    1'b1;
                default   :   bucket_full_r    <=  `DLY    1'b0;

            endcase
        end

endmodule

