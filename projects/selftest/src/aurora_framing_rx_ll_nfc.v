///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:13 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: rx_ll_nfc.ejava,v $
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
//  RX_LL_NFC
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: the RX_LL_NFC module detects, decodes and executes NFC messages
//               from the channel partner.  When a message is recieved, the module
//               signals the TX_LL module that idles are required until the number
//               of idles the TX_LL module sends are enough to fulfil the request.
//
//               This module supports 1 2-byte lane designs.
//

`timescale 1 ns / 10 ps

module aurora_framing_RX_LL_NFC
(
    // Aurora Lane Interface
    RX_SNF,
    RX_FC_NB,


    // TX_LL Interface
    DECREMENT_NFC,

    TX_WAIT,

    // Global Logic Interface
    CHANNEL_UP,


    // USER Interface
    USER_CLK

 );

`define DLY #1


//***********************************Port Declarations*******************************

    // Aurora Lane Interface
    input       RX_SNF;
    input   [0:3]   RX_FC_NB;


    // TX_LL Interface
    input       DECREMENT_NFC;

    output      TX_WAIT;


    // Global Logic Interface
    input       CHANNEL_UP;


    // USER Interface
    input       USER_CLK;


//**************************Internal Register Declarations****************************


    reg             load_nfc_r;
    reg     [0:3]   fcnb_r;
    reg     [0:8]   nfc_counter_r;
    reg             xoff_r;
    reg     [0:8]   fcnb_decode_c;


//*********************************Main Body of Code**********************************





    //_________________Stage 1: Detect the most recent NFC message____________________


    // Generate the load NFC signal if an NFC signal is detected.
    always @(posedge USER_CLK)
        load_nfc_r          <=  `DLY    RX_SNF;


    // Register the FC_NB signal.
    always @(posedge USER_CLK)
        fcnb_r  <=  `DLY    RX_FC_NB;




    //________________ Stage 2: Use the FCNB code to set the counter_______________


    // We use a counter to keep track of the number of dead cycles we must produce to
    // satisfy the NFC request from the Channel Partner.  Note we *increment* nfc_counter
    // when decrement NFC is asserted.  This is because the nfc counter uses the difference
    // between the max value and the current value to determine how many cycles to demand
    // a pause.  This allows us to use the carry chain more effectively to save LUTS, and
    // gives us a registered output from the counter.
    always @(posedge USER_CLK)
        if (!CHANNEL_UP)         nfc_counter_r   <=  `DLY    9'h100;
        else if (load_nfc_r)     nfc_counter_r   <=  `DLY    fcnb_decode_c;
        else if (!nfc_counter_r[0] && DECREMENT_NFC && !xoff_r)
                                nfc_counter_r   <=  `DLY    nfc_counter_r + 9'h001;



    // We load the counter with a decoded version of the FCNB code.  The decode values are
    // chosen such that the counter will assert TX_WAIT for the number of cycles required
    // by the FCNB code.
    always @(fcnb_r)
        case(fcnb_r)
            4'h0    :   fcnb_decode_c   =   9'h100; // XON
            4'h1    :   fcnb_decode_c   =   9'h0FE; // 2
            4'h2    :   fcnb_decode_c   =   9'h0FC; // 4
            4'h3    :   fcnb_decode_c   =   9'h0F8; // 8
            4'h4    :   fcnb_decode_c   =   9'h0F0; // 16
            4'h5    :   fcnb_decode_c   =   9'h0E0; // 32
            4'h6    :   fcnb_decode_c   =   9'h0C0; // 64
            4'h7    :   fcnb_decode_c   =   9'h080; // 128
            4'h8    :   fcnb_decode_c   =   9'h000; // 256
            4'hF    :   fcnb_decode_c   =   9'h000; // 8
            default :   fcnb_decode_c   =   9'h100; // 8
        endcase


    // The XOFF signal forces an indefinite wait.  We decode FCNB to determine whether
    // XOFF should be asserted.
    always @(posedge USER_CLK)
        if (!CHANNEL_UP)             xoff_r  <=  `DLY    1'b0;
        else if (load_nfc_r)
        begin
            if (fcnb_r == 4'hF)      xoff_r  <=  `DLY    1'b1;
            else                    xoff_r  <=  `DLY    1'b0;
        end


    // The TXWAIT signal comes from the MSBit of the counter.  We wait whenever the counter
    // is not at max value.
    assign TX_WAIT  =   !nfc_counter_r[0];




endmodule












