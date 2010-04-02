///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:15 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: tx_ll_datapath.ejava,v $
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
//  TX_LL_DATAPATH
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: This module pipelines the data path while handling the PAD
//               character placement and valid data flags.
//
//               This module supports 1 2-byte lane designs
//

`timescale 1 ns / 10 ps

module aurora_framing_TX_LL_DATAPATH
(
    // LocalLink PDU Interface
    TX_D,
    TX_REM,
    TX_SRC_RDY_N,
    TX_SOF_N,
    TX_EOF_N,


    // Aurora Lane Interface
    TX_PE_DATA_V,
    GEN_PAD,
    TX_PE_DATA,


    // TX_LL Control Module Interface
    HALT_C,
    TX_DST_RDY_N,

    // System Interface
    CHANNEL_UP,
    USER_CLK

);

`define DLY #1


//***********************************Port Declarations*******************************


    // LocalLink PDU Interface
    input   [0:15]     TX_D;
    input              TX_REM;
    input              TX_SRC_RDY_N;
    input              TX_SOF_N;
    input              TX_EOF_N;


    // Aurora Lane Interface
    output             TX_PE_DATA_V;
    output             GEN_PAD;
    output  [0:15]     TX_PE_DATA;


    // TX_LL Control Module Interface
    input              HALT_C;
    input              TX_DST_RDY_N;

    // System Interface
    input              CHANNEL_UP;
    input              USER_CLK;


//**************************External Register Declarations****************************

    reg     [0:15]     TX_PE_DATA;
    reg                TX_PE_DATA_V;
    reg                GEN_PAD;


//**************************Internal Register Declarations****************************

    reg                in_frame_r;
    reg     [0:15]     storage_r;
    reg                storage_v_r;
    reg                storage_pad_r;
    reg     [0:15]     tx_pe_data_r;
    reg                valid_c;
    reg                tx_pe_data_v_r;
    reg                gen_pad_c;
    reg                gen_pad_r;



//******************************Internal Wire Declarations****************************

    wire               in_frame_c;
    wire               ll_valid_c;


//*********************************Main Body of Code**********************************






    // LocalLink input is only valid when TX_SRC_RDY_N and TX_DST_RDY_N are both asserted
    assign ll_valid_c    =   !TX_SRC_RDY_N && !TX_DST_RDY_N;

    // Data must only be read if it is within a frame. If the frame will last multiple
    // cycles, assert in_frame_r until the frame ends
    always @(posedge USER_CLK)
        if(!CHANNEL_UP)                   in_frame_r    <=  `DLY    1'b0;
        else if(ll_valid_c)
        begin
            if(!TX_SOF_N && TX_EOF_N )    in_frame_r    <=  `DLY    1'b1;
            else if(!TX_EOF_N)            in_frame_r    <=  `DLY    1'b0;
        end


    assign in_frame_c   =   ll_valid_c && (in_frame_r  || !TX_SOF_N);



    // The data from the LocalLink interface must be delayed one cycle to
    // make room for the SCP code group in the channel.
    always @(posedge USER_CLK)
        if(!HALT_C) storage_r   <=  `DLY    TX_D;


    // This pipeline register aligns the data with the control path.
    always @(posedge USER_CLK)
        if(!HALT_C) tx_pe_data_r    <=  `DLY    storage_r;


    // We generate the valid_c signal based on the REM signal and the EOF signal.
    always @(TX_EOF_N or TX_REM)
        if(TX_EOF_N)    valid_c =   1'b1;
        else
            case(TX_REM)
                1'h0    : valid_c    =   1'b1;
                1'h1    : valid_c    =   1'b1;
                default:  valid_c    =   1'b1;
            endcase


    // If the word is valid, it is placed in the storage register and storage_v_r is
    // asserted to indicate the data is valid.  Note that data is only moved to storage
    // if the PDU datapath is not halted, the data is valid and both TX_SRC_RDY_N and
    // TX_DST_RDY_N are asserted.
    always @(posedge USER_CLK)
        if(!HALT_C)     storage_v_r     <=  `DLY    valid_c && in_frame_c;






    // Register the tx_pe_data_valid signal.  All data is moved from the storage register
    // to the tx_pe_data register for transmission when the datapath is not halted.  If the
    // storage register contains valid PDU data, the tx_pe_data register is marked as
    // containing valid PDU data
    always @(posedge USER_CLK)
        if(!HALT_C)     tx_pe_data_v_r    <=  `DLY    storage_v_r;






    // We generate the gen_pad_c signal based on the REM signal and the EOF signal.
    always @(TX_EOF_N or TX_REM)
        if(TX_EOF_N)    gen_pad_c   =   1'b0;
        else
            case(TX_REM)
                1'h0    : gen_pad_c    =   1'b1;
                1'h1    : gen_pad_c    =   1'b0;
                default:  gen_pad_c    =   1'b0;
            endcase



    // Store padded data when padded and TX_SRC_RDY_N and TX_DST_RDY_N are both asserted.
    always @(posedge USER_CLK)
        if(!HALT_C)     storage_pad_r   <=  `DLY    gen_pad_c && in_frame_c;


    // Register the gen_pad signal.
    always @(posedge USER_CLK)
    if(!HALT_C)     gen_pad_r     <=  `DLY    storage_pad_r;





    // Implement the data out register.
    always @(posedge USER_CLK)
    begin
        TX_PE_DATA      <=  `DLY    tx_pe_data_r;
        TX_PE_DATA_V    <=  `DLY    tx_pe_data_v_r & !HALT_C;
        GEN_PAD         <=  `DLY    gen_pad_r & !HALT_C;
    end




endmodule
