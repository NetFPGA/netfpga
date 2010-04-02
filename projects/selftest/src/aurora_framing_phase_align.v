///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2007/01/29 20:11:06 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: phase_align.ejava,v $
//          Rev:  $Revision: 1.1.2.10 $
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
//  PHASE_ALIGN
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: Phase alignment circuit for the comma alignment signal.  Ensures
//               that the enable comma align signal is syncronous with the MGT
//               recovered clock.
//

`timescale 1 ns / 10 ps

module aurora_framing_PHASE_ALIGN
(
    //Aurora Lane Interface
    ENA_COMMA_ALIGN,


    //MGT Interface
    RX_REC_CLK,

    ENA_CALIGN_REC
);

`define DLY #1

//***********************************Port Declarations*******************************

//synthesis attribute keep_hierarchy PHASE_ALIGN true;

    //Aurora Lane Interface
    input  [0:0]         ENA_COMMA_ALIGN;


    //MGT Interface
    input   [0:0]        RX_REC_CLK;

    output  [0:0]        ENA_CALIGN_REC;


//**************************External Register Declarations****************************


//**************************Internal Register Declarations****************************

    wire     [0:1]   phase_align_flops_r;

//*********************************Wire Declarations**********************************



//*********************************Main Body of Code**********************************

    // To phase align the signal, we sample it using a flop clocked with the recovered
    // clock.  We then sample the output of the first flop and pass it to the output.
    // This ensures that the signal is not metastable, and prevents transitions from
    // occuring except at the clock edge.  The comma alignment circuit cannot tolerate
    // transitions except at the recovered clock edge.

    FD phase_align_flops_0 (
                .D(ENA_COMMA_ALIGN[0]),
                .C(RX_REC_CLK[0]),
                .Q(phase_align_flops_r[0])
                );


    FD phase_align_flops_1 (
                .D(phase_align_flops_r[0]),
                .C(RX_REC_CLK[0]),
                .Q(phase_align_flops_r[1])
                );

     assign  ENA_CALIGN_REC[0] =    phase_align_flops_r[1];


endmodule
