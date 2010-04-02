///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:14 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: sym_dec.ejava,v $
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
//  SYM_DEC
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: The SYM_DEC module is a symbol decoder for the 2-byte
//               Aurora Lane.  Its inputs are the raw data from the MGT.
//               It word-aligns the regular data and decodes all of the
//               Aurora control symbols.  Its outputs are the word-aligned
//               data and signals indicating the arrival of specific
//               control characters.
//
//               This module supports Immediate Mode Native Flow Control.
//

`timescale 1 ns / 10 ps

module aurora_framing_SYM_DEC
(
    // RX_LL Interface
    RX_PAD,
    RX_PE_DATA,
    RX_PE_DATA_V,
    RX_SCP,
    RX_ECP,
    RX_SNF,
    RX_FC_NB,


    // Lane Init SM Interface
    DO_WORD_ALIGN,

    RX_SP,
    RX_SPA,
    RX_NEG,


    // Global Logic Interface
    GOT_A,
    GOT_V,


    // MGT Interface
    RX_DATA,
    RX_CHAR_IS_K,
    RX_CHAR_IS_COMMA,


    // System Interface
    USER_CLK,
    RESET
);

`define DLY #1

//***********************************Parameter Declarations**************************

    parameter       K_CHAR_0        =   4'hb;
    parameter       K_CHAR_1        =   4'hc;
    parameter       SP_DATA_0       =   4'h4;
    parameter       SP_DATA_1       =   4'ha;
    parameter       SPA_DATA_0      =   4'h2;
    parameter       SPA_DATA_1      =   4'hc;
    parameter       SP_NEG_DATA_0   =   4'hb;
    parameter       SP_NEG_DATA_1   =   4'h5;
    parameter       SPA_NEG_DATA_0  =   4'hd;
    parameter       SPA_NEG_DATA_1  =   4'h3;
    parameter       PAD_0           =   4'h9;
    parameter       PAD_1           =   4'hc;
    parameter       SCP_0           =   4'h5;
    parameter       SCP_1           =   4'hc;
    parameter       SCP_2           =   4'hf;
    parameter       SCP_3           =   4'hb;
    parameter       ECP_0           =   4'hf;
    parameter       ECP_1           =   4'hd;
    parameter       ECP_2           =   4'hf;
    parameter       ECP_3           =   4'he;
    parameter       SNF_0           =   4'hd;
    parameter       SNF_1           =   4'hc;
    parameter       A_CHAR_0        =   4'h7;
    parameter       A_CHAR_1        =   4'hc;
    parameter       VER_DATA_0      =   4'he;
    parameter       VER_DATA_1      =   4'h8;


//***********************************Port Declarations*******************************

    // RX_LL Interface
    output          RX_PAD;           // LSByte is PAD.
    output  [0:15]  RX_PE_DATA;       // Word aligned data from channel partner.
    output          RX_PE_DATA_V;     // Data is valid data and not a control character.
    output          RX_SCP;           // SCP symbol received.
    output          RX_ECP;           // ECP symbol received.
    output          RX_SNF;           // SNF symbol received.
    output  [0:3]   RX_FC_NB;         // Flow Control size code.  Valid with RX_SNF or RX_SUF.


    // Lane Init SM Interface
    input           DO_WORD_ALIGN;    // Word alignment is allowed.

    output          RX_SP;            // SP sequence received with positive or negative data.
    output          RX_SPA;           // SPA sequence received.
    output          RX_NEG;           // Intverted data for SP or SPA received.


    // Global Logic Interface
    output  [0:1]   GOT_A;            // A character received on indicated byte(s).
    output          GOT_V;            // V sequence received.


    // MGT Interface
    input   [15:0]  RX_DATA;          // Raw RX data from MGT.
    input   [1:0]   RX_CHAR_IS_K;     // Bits indicating which bytes are control characters.
    input   [1:0]   RX_CHAR_IS_COMMA; // Rx'ed a comma.


    // System Interface
    input           USER_CLK;         // System clock for all non-MGT Aurora Logic.
    input           RESET;



//**************************External Register Declarations****************************

    reg     [0:15]  RX_PE_DATA;
    reg             RX_PAD;
    reg             RX_PE_DATA_V;
    reg             RX_SCP;
    reg             RX_ECP;
    reg             RX_SNF;
    reg     [0:3]   RX_FC_NB;
    reg             RX_SP;
    reg             RX_SPA;
    reg             RX_NEG;
    reg     [0:1]   GOT_A;
    reg             GOT_V;


//**************************Internal Register Declarations****************************

    reg             left_aligned_r;
    reg     [0:7]   previous_cycle_data_r;
    reg             previous_cycle_control_r;
    reg             prev_beat_sp_r;
    reg             prev_beat_spa_r;
    reg     [0:15]  word_aligned_data_r;
    reg     [0:1]   word_aligned_control_bits_r;
    reg     [0:15]  rx_pe_data_r;
    reg     [0:1]   rx_pe_control_r;
    reg     [0:1]   rx_pad_d_r;
    reg     [0:3]   rx_scp_d_r;
    reg     [0:3]   rx_ecp_d_r;
    reg     [0:1]   rx_snf_d_r;
    reg     [0:3]   prev_beat_sp_d_r;
    reg     [0:3]   prev_beat_spa_d_r;
    reg     [0:3]   rx_sp_d_r;
    reg     [0:3]   rx_spa_d_r;
    reg     [0:1]   rx_sp_neg_d_r;
    reg     [0:1]   rx_spa_neg_d_r;
    reg     [0:3]   prev_beat_v_d_r;
    reg             prev_beat_v_r;
    reg     [0:3]   rx_v_d_r;
    reg     [0:3]   got_a_d_r;
    reg             first_v_received_r;


//*********************************Wire Declarations**********************************

    wire            got_v_c;


//*********************************Main Body of Code**********************************


    //__________________________Word Alignment__________________________________

    // Determine whether the lane is aligned to the left byte (MS byte) or the
    // right byte (LS byte).  This information is used for word alignment.  To
    // prevent the word align from changing during normal operation, we do word
    // alignment only when it is allowed by the lane_init_sm.
    always @(posedge USER_CLK)
        if(DO_WORD_ALIGN & !first_v_received_r)
            case({RX_CHAR_IS_COMMA,RX_CHAR_IS_K})
                4'b1010   :   left_aligned_r  <=  `DLY    1'b1;
                4'b0101   :   left_aligned_r  <=  `DLY    1'b0;
                default :     left_aligned_r  <=  `DLY    left_aligned_r;
            endcase



    // Store the LS byte from the previous cycle.  If the lane is aligned on
    // the LS byte, we use it as the MS byte on the current cycle.
    always @(posedge USER_CLK)
        previous_cycle_data_r       <=  `DLY  RX_DATA[7:0];



    // Store the control bit from the previous cycle LS byte.  It becomes the
    // control bit for the MS byte on this cycle if the lane is aligned to the
    // LS byte.
    always @(posedge USER_CLK)
        previous_cycle_control_r    <=  `DLY  RX_CHAR_IS_K[0];



    // Select the word-aligned MS byte.  Use the current MS byte if the data is
    // left-aligned, otherwise use the LS byte from the previous cycle.
    always @(posedge USER_CLK)
        word_aligned_data_r[0:7]    <=  `DLY    left_aligned_r? RX_DATA[15:8]
                                                              : previous_cycle_data_r;


    // Select the word-aligned LS byte.  Use the current LSByte if the data is
    // right-aligned, otherwise use the current MS byte.
    always @(posedge USER_CLK)
        word_aligned_data_r[8:15]   <=  `DLY    left_aligned_r? RX_DATA[7:0]  : RX_DATA[15:8];



    // Select the word-aligned MS byte control bit.  Use the current MSByte's
    // control bit if the data is left-aligned, otherwise use the LS byte's
    // control bit from the previous cycle.
    always @(posedge USER_CLK)
        word_aligned_control_bits_r[0]  <=  `DLY    left_aligned_r? RX_CHAR_IS_K[1]
                                                                  : previous_cycle_control_r;



    // Select the word-aligned LS byte control bit.  Use the current LSByte's control
    // bit if the data is left-aligned, otherwise use the current MS byte's control bit.
    always @(posedge USER_CLK)
        word_aligned_control_bits_r[1]  <=  `DLY    left_aligned_r? RX_CHAR_IS_K[0]
                                                                   : RX_CHAR_IS_K[1];



    // Pipeline the word-aligned data for 1 cycle to match the Decodes.
    always @(posedge USER_CLK)
        rx_pe_data_r   <=  `DLY    word_aligned_data_r;


    // Register the pipelined word-aligned data for the RX_LL interface.
    always @(posedge USER_CLK)
        RX_PE_DATA  <=  `DLY  rx_pe_data_r;





    //_____________________________Decode Control Symbols___________________________


    // All decodes are pipelined to keep the number of logic levels to a minimum.


    // Delay the control bits: they are most often used in the second stage of
    // the decoding process.
    always @(posedge USER_CLK)
        rx_pe_control_r     <=  `DLY    word_aligned_control_bits_r;



    // Decode PAD
    always @(posedge USER_CLK)
    begin
        rx_pad_d_r[0]   <=  `DLY    (word_aligned_data_r[8:11]     ==  PAD_0);
        rx_pad_d_r[1]   <=  `DLY    (word_aligned_data_r[12:15]    ==  PAD_1);
    end

    always @(posedge USER_CLK)
        RX_PAD      <=  `DLY  (rx_pad_d_r== 2'b11) & (rx_pe_control_r == 2'b01);



    // Decode RX_PE_DATA_V
    always @(posedge USER_CLK)
        RX_PE_DATA_V <=  `DLY  !rx_pe_control_r[0];



    // Decode RX_SCP
    always @(posedge USER_CLK)
    begin
        rx_scp_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  SCP_0);
        rx_scp_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  SCP_1);
        rx_scp_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SCP_2);
        rx_scp_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  SCP_3);
    end

    always @(posedge USER_CLK)
        RX_SCP      <=  `DLY  &{rx_pe_control_r, rx_scp_d_r};



    // Decode RX_ECP
    always @(posedge USER_CLK)
    begin
        rx_ecp_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  ECP_0);
        rx_ecp_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  ECP_1);
        rx_ecp_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  ECP_2);
        rx_ecp_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  ECP_3);
    end

    always @(posedge USER_CLK)
        RX_ECP      <=  `DLY  &{rx_pe_control_r, rx_ecp_d_r};


    // Decode RX_SNF
    always @(posedge USER_CLK)
    begin
        rx_snf_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  SNF_0);
        rx_snf_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  SNF_1);
    end

    always @(posedge USER_CLK)
        RX_SNF      <=  `DLY  &{rx_pe_control_r[0], rx_snf_d_r};


    // Extract the Flow Control Size code and register it for the RX_LL interface.
    always @(posedge USER_CLK)
        RX_FC_NB    <=  `DLY  rx_pe_data_r[8:11];


    // For an SP sequence to be valid, there must be 2 bytes of SP Data preceded
    // by a Comma and an SP Data byte in the MS byte and LS byte positions
    // respectively.  This flop stores the decode of the Comma and SP Data byte
    // combination from the previous cycle.  Data can be positive or negative.
    always @(posedge USER_CLK)
    begin
        prev_beat_sp_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  K_CHAR_0);
        prev_beat_sp_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  K_CHAR_1);
        prev_beat_sp_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SP_DATA_0)|
                                          (word_aligned_data_r[8:11]  ==  SP_NEG_DATA_0);
        prev_beat_sp_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  SP_DATA_1)|
                                          (word_aligned_data_r[12:15] ==  SP_NEG_DATA_1);
    end

    always @(posedge USER_CLK)
        prev_beat_sp_r  <=  `DLY  (rx_pe_control_r == 2'b10) &
                                  (prev_beat_sp_d_r == 4'b1111);



    // This flow stores the decode of a Comma and SPA Data byte combination from the
    // previous cycle.  It is used along with decodes for SPA data in the current
    // cycle to determine whether an SPA sequence was received.
    always @(posedge USER_CLK)
    begin
        prev_beat_spa_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  K_CHAR_0);
        prev_beat_spa_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  K_CHAR_1);
        prev_beat_spa_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SPA_DATA_0);
        prev_beat_spa_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  SPA_DATA_1);
    end

    always @(posedge USER_CLK)
        prev_beat_spa_r  <=  `DLY  (rx_pe_control_r == 2'b10) &
                                   (prev_beat_spa_d_r == 4'b1111);




    // Indicate the SP sequence was received.
    always @(posedge USER_CLK)
    begin
        rx_sp_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  SP_DATA_0)|
                                   (word_aligned_data_r[0:3]   ==  SP_NEG_DATA_0);
        rx_sp_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  SP_DATA_1)|
                                   (word_aligned_data_r[4:7]   ==  SP_NEG_DATA_1);
        rx_sp_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SP_DATA_0)|
                                   (word_aligned_data_r[8:11]  ==  SP_NEG_DATA_0);
        rx_sp_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  SP_DATA_1)|
                                   (word_aligned_data_r[12:15] ==  SP_NEG_DATA_1);
    end

    always @(posedge USER_CLK)
        RX_SP   <=  `DLY  prev_beat_sp_r &
                         (rx_pe_control_r == 2'b00) &
                         (rx_sp_d_r == 4'b1111);



    // Indicate the SPA sequence was received.
    always @(posedge USER_CLK)
    begin
        rx_spa_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  SPA_DATA_0);
        rx_spa_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  SPA_DATA_1);
        rx_spa_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SPA_DATA_0);
        rx_spa_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  SPA_DATA_1);
    end

    always @(posedge USER_CLK)
        RX_SPA   <=  `DLY  prev_beat_spa_r &
                          (rx_pe_control_r == 2'b00) &
                          (rx_spa_d_r == 4'b1111);



    // Indicate reversed data received.  We look only at the word-aligned LS byte
    // which, during an /SP/ or /SPA/ sequence, will always contain a data byte.
    always @(posedge USER_CLK)
    begin
        rx_sp_neg_d_r[0]   <=  `DLY    (word_aligned_data_r[8:11]   ==  SP_NEG_DATA_0);
        rx_sp_neg_d_r[1]   <=  `DLY    (word_aligned_data_r[12:15]  ==  SP_NEG_DATA_1);

        rx_spa_neg_d_r[0]   <=  `DLY    (word_aligned_data_r[8:11]  ==  SPA_NEG_DATA_0);
        rx_spa_neg_d_r[1]   <=  `DLY    (word_aligned_data_r[12:15] ==  SPA_NEG_DATA_1);
    end

    always @(posedge USER_CLK)
        RX_NEG   <=  `DLY  !rx_pe_control_r[1] &
                          ((rx_sp_neg_d_r == 2'b11)|
                           (rx_spa_neg_d_r == 2'b11));



    // GOT_A is decoded from the non_word-aligned input.
    always @(posedge USER_CLK)
    begin
        got_a_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]    ==  A_CHAR_0);
        got_a_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]    ==  A_CHAR_1);
        got_a_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]   ==  A_CHAR_0);
        got_a_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15]  ==  A_CHAR_1);
    end

    always @(posedge USER_CLK)
    begin
        GOT_A[0]    <=  `DLY rx_pe_control_r[0] & (got_a_d_r[0:1] == 2'b11);
        GOT_A[1]    <=  `DLY rx_pe_control_r[1] & (got_a_d_r[2:3] == 2'b11);
    end




    //_______________________Verification symbol decode__________________________



    // This flow stores the decode of a Comma and SPA Data byte combination from the
    // previous cycle.  It is used along with decodes for SPA data in the current
    // cycle to determine whether an SPA sequence was received.
    always @(posedge USER_CLK)
    begin
        prev_beat_v_d_r[0]   <=  `DLY    (word_aligned_data_r[0:3]   ==  K_CHAR_0);
        prev_beat_v_d_r[1]   <=  `DLY    (word_aligned_data_r[4:7]   ==  K_CHAR_1);
        prev_beat_v_d_r[2]   <=  `DLY    (word_aligned_data_r[8:11]  ==  VER_DATA_0);
        prev_beat_v_d_r[3]   <=  `DLY    (word_aligned_data_r[12:15] ==  VER_DATA_1);
    end

    always @(posedge USER_CLK)
        prev_beat_v_r  <=  `DLY  (rx_pe_control_r == 2'b10) &
                                 (prev_beat_v_d_r == 4'b1111);




    // Indicate the SP sequence was received.
    always @(posedge USER_CLK)
    begin
        rx_v_d_r[0]     <=  `DLY    (word_aligned_data_r[0:3]   ==  VER_DATA_0);
        rx_v_d_r[1]     <=  `DLY    (word_aligned_data_r[4:7]   ==  VER_DATA_1);
        rx_v_d_r[2]     <=  `DLY    (word_aligned_data_r[8:11]  ==  VER_DATA_0);
        rx_v_d_r[3]     <=  `DLY    (word_aligned_data_r[12:15] ==  VER_DATA_1);
    end


    assign  got_v_c     =  prev_beat_v_r & (rx_pe_control_r == 2'b00) &
                          (rx_v_d_r == 4'b1111);

    always @(posedge USER_CLK)
        GOT_V   <=  `DLY    got_v_c;



    // Remember that the first V sequence has been detected.
    initial
        first_v_received_r  =   1'b0;

    always @(posedge USER_CLK)
        if(RESET)           first_v_received_r  <=  `DLY    1'b0;
        else if(got_v_c)    first_v_received_r  <=  `DLY    1'b1;

endmodule
