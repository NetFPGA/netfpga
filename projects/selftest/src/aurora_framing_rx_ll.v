///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:13 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: rx_ll.ejava,v $
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
//  RX_LL
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: The RX_LL module receives data from the Aurora Channel,
//               converts it to LocalLink and sends it to the user interface.
//               It also handles NFC and UFC messages.
//
//               This module supports 1 2-byte lane designs.
//
//               This module supports Immediate Mode Native Flow Control.
//

`timescale 1 ns / 10 ps

module aurora_framing_RX_LL
(
    // LocalLink PDU Interface
    RX_D,
    RX_REM,
    RX_SRC_RDY_N,
    RX_SOF_N,
    RX_EOF_N,


    // Global Logic Interface
    START_RX,


    // Aurora Lane Interface
    RX_PAD,
    RX_PE_DATA,
    RX_PE_DATA_V,
    RX_SCP,
    RX_ECP,
    RX_SNF,
    RX_FC_NB,

    // TX_LL Interface
    DECREMENT_NFC,

    TX_WAIT,

    // Error Interface
    FRAME_ERROR,


    // System Interface
    USER_CLK


);

`define DLY #1


//***********************************Port Declarations*******************************


    // LocalLink PDU Interface
    output  [0:15]     RX_D;
    output             RX_REM;
    output             RX_SRC_RDY_N;
    output             RX_SOF_N;
    output             RX_EOF_N;


    // Global Logic Interface
    input              START_RX;


    // Aurora Lane Interface
    input              RX_PAD;
    input   [0:15]     RX_PE_DATA;
    input              RX_PE_DATA_V;
    input              RX_SCP;
    input              RX_ECP;
    input              RX_SNF;
    input   [0:3]      RX_FC_NB;

    // TX_LL Interface
    input              DECREMENT_NFC;

    output             TX_WAIT;

    // Error Interface
    output             FRAME_ERROR;

    // System Interface
    input              USER_CLK;





//*********************************Main Body of Code**********************************



    //_______________________________NFC processing_________________________________

    aurora_framing_RX_LL_NFC aurora_framing_nfc_module_i
    (
        // Aurora Lane Interface
        .RX_SNF(RX_SNF),
        .RX_FC_NB(RX_FC_NB),


        // TX_LL Interface
        .DECREMENT_NFC(DECREMENT_NFC),

        .TX_WAIT(TX_WAIT),

        // Global Logic Interface
        .CHANNEL_UP(START_RX),


        // USER Interface
        .USER_CLK(USER_CLK)

    );






    aurora_framing_RX_LL_PDU_DATAPATH aurora_framing_rx_ll_pdu_datapath_i
    (

        // Traffic Separator Interface
        .PDU_DATA(RX_PE_DATA),
        .PDU_DATA_V(RX_PE_DATA_V),
        .PDU_PAD(RX_PAD),
        .PDU_SCP(RX_SCP),
        .PDU_ECP(RX_ECP),


        // LocalLink PDU Interface
        .RX_D(RX_D),
        .RX_REM(RX_REM),
        .RX_SRC_RDY_N(RX_SRC_RDY_N),
        .RX_SOF_N(RX_SOF_N),
        .RX_EOF_N(RX_EOF_N),


        // Error Interface
        .FRAME_ERROR(FRAME_ERROR),


        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(~START_RX)
    );





endmodule
