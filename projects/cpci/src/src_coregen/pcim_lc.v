/***********************************************************************

  File:   pcim_lc.v
  Rev:    3.1.161

  This is a lower-level Verilog module which serves as a wrapper
  for the PCI interface.  This module makes use of Unified Library
  Primitives.  Do not modify this file.

  Copyright (c) 2005-2007 Xilinx, Inc.  All rights reserved.

***********************************************************************/


module pcim_lc (
                AD_IO,
                CBE_IO,
                PAR_IO,
                FRAME_IO,
                TRDY_IO,
                IRDY_IO,
                STOP_IO,
                DEVSEL_IO,
                IDSEL_I,
                INTA_O,
                PERR_IO,
                SERR_IO,
                REQ_O,
                GNT_I,

                RST_I,
                PCLK,

                CFG,

                FRAMEQ_N,
                TRDYQ_N,
                IRDYQ_N,
                STOPQ_N,
                DEVSELQ_N,

                ADDR,
                ADIO,

                CFG_VLD,
                CFG_HIT,
                C_TERM,
                C_READY,
                ADDR_VLD,
                BASE_HIT,
                S_TERM,
                S_READY,
                S_ABORT,
                S_WRDN,
                S_SRC_EN,
                S_DATA_VLD,
                S_CBE,
                PCI_CMD,

                REQUEST,
                REQUESTHOLD,
                COMPLETE,
                M_WRDN,
                M_READY,
                M_SRC_EN,
                M_DATA_VLD,
                M_CBE,
                TIME_OUT,
                CFG_SELF,

                M_DATA,
                DR_BUS,
                I_IDLE,
                M_ADDR_N,

                IDLE,
                B_BUSY,
                S_DATA,
                BACKOFF,

                INTR_N,
                PERRQ_N,
                SERRQ_N,
                KEEPOUT,
                CSR,
                SUB_DATA,

                RST,
                CLK
                );
                // synthesis syn_edif_bit_format = "%u<%i>"
                // synthesis syn_edif_scalar_format = "%u"
                // synthesis syn_noclockbuf = 1
                // synthesis syn_hier = "hard"


  // I/O declarations

  inout  [31:0] AD_IO;
  inout   [3:0] CBE_IO;
  inout         PAR_IO;
  inout         FRAME_IO;
  inout         TRDY_IO;
  inout         IRDY_IO;
  inout         STOP_IO;
  inout         DEVSEL_IO;
  input         IDSEL_I;
  output        INTA_O;
  inout         PERR_IO;
  inout         SERR_IO;
  output        REQ_O;
  input         GNT_I;

  input         RST_I;
  input         PCLK;

  input [255:0] CFG;

  output        FRAMEQ_N;
  output        TRDYQ_N;
  output        IRDYQ_N;
  output        STOPQ_N;
  output        DEVSELQ_N;

  output [31:0] ADDR;
  inout  [31:0] ADIO;

  output        CFG_VLD;
  output        CFG_HIT;
  input         C_TERM;
  input         C_READY;
  output        ADDR_VLD;
  output  [7:0] BASE_HIT;
  input         S_TERM;
  input         S_READY;
  input         S_ABORT;
  output        S_WRDN;
  output        S_SRC_EN;
  output        S_DATA_VLD;
  output  [3:0] S_CBE;
  output [15:0] PCI_CMD;

  input         REQUEST;
  input         REQUESTHOLD;
  input         COMPLETE;
  input         M_WRDN;
  input         M_READY;
  output        M_SRC_EN;
  output        M_DATA_VLD;
  input   [3:0] M_CBE;
  output        TIME_OUT;
  input         CFG_SELF;

  output        M_DATA;
  output        DR_BUS;
  output        I_IDLE;
  output        M_ADDR_N;

  output        IDLE;
  output        B_BUSY;
  output        S_DATA;
  output        BACKOFF;

  input         INTR_N;
  output        PERRQ_N;
  output        SERRQ_N;
  input         KEEPOUT;
  output [39:0] CSR;
  input  [31:0] SUB_DATA;

  inout         RST;
  inout         CLK;


// I/O structure instantiations

IOBUF_PCI33_3 XPCI_ADB31 (.O(AD_I31),.IO(AD_IO[31]),.I(AD_O31),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB30 (.O(AD_I30),.IO(AD_IO[30]),.I(AD_O30),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB29 (.O(AD_I29),.IO(AD_IO[29]),.I(AD_O29),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB28 (.O(AD_I28),.IO(AD_IO[28]),.I(AD_O28),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB27 (.O(AD_I27),.IO(AD_IO[27]),.I(AD_O27),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB26 (.O(AD_I26),.IO(AD_IO[26]),.I(AD_O26),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB25 (.O(AD_I25),.IO(AD_IO[25]),.I(AD_O25),.T(OE_ADO_T   ));
IOBUF_PCI33_3 XPCI_ADB24 (.O(AD_I24),.IO(AD_IO[24]),.I(AD_O24),.T(OE_ADO_T   ));

IOBUF_PCI33_3 XPCI_ADB23 (.O(AD_I23),.IO(AD_IO[23]),.I(AD_O23),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB22 (.O(AD_I22),.IO(AD_IO[22]),.I(AD_O22),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB21 (.O(AD_I21),.IO(AD_IO[21]),.I(AD_O21),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB20 (.O(AD_I20),.IO(AD_IO[20]),.I(AD_O20),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB19 (.O(AD_I19),.IO(AD_IO[19]),.I(AD_O19),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB18 (.O(AD_I18),.IO(AD_IO[18]),.I(AD_O18),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB17 (.O(AD_I17),.IO(AD_IO[17]),.I(AD_O17),.T(OE_ADO_LT  ));
IOBUF_PCI33_3 XPCI_ADB16 (.O(AD_I16),.IO(AD_IO[16]),.I(AD_O16),.T(OE_ADO_LT  ));

IOBUF_PCI33_3 XPCI_ADB15 (.O(AD_I15),.IO(AD_IO[15]),.I(AD_O15),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB14 (.O(AD_I14),.IO(AD_IO[14]),.I(AD_O14),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB13 (.O(AD_I13),.IO(AD_IO[13]),.I(AD_O13),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB12 (.O(AD_I12),.IO(AD_IO[12]),.I(AD_O12),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB11 (.O(AD_I11),.IO(AD_IO[11]),.I(AD_O11),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB10 (.O(AD_I10),.IO(AD_IO[10]),.I(AD_O10),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB9  (.O(AD_I9 ),.IO(AD_IO[9 ]),.I(AD_O9 ),.T(OE_ADO_LB  ));
IOBUF_PCI33_3 XPCI_ADB8  (.O(AD_I8 ),.IO(AD_IO[8 ]),.I(AD_O8 ),.T(OE_ADO_LB  ));

IOBUF_PCI33_3 XPCI_ADB7  (.O(AD_I7 ),.IO(AD_IO[7 ]),.I(AD_O7 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB6  (.O(AD_I6 ),.IO(AD_IO[6 ]),.I(AD_O6 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB5  (.O(AD_I5 ),.IO(AD_IO[5 ]),.I(AD_O5 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB4  (.O(AD_I4 ),.IO(AD_IO[4 ]),.I(AD_O4 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB3  (.O(AD_I3 ),.IO(AD_IO[3 ]),.I(AD_O3 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB2  (.O(AD_I2 ),.IO(AD_IO[2 ]),.I(AD_O2 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB1  (.O(AD_I1 ),.IO(AD_IO[1 ]),.I(AD_O1 ),.T(OE_ADO_B   ));
IOBUF_PCI33_3 XPCI_ADB0  (.O(AD_I0 ),.IO(AD_IO[0 ]),.I(AD_O0 ),.T(OE_ADO_B   ));

FDPE XPCI_ADQ31 (.Q(AD31),.D(AD_I31),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ30 (.Q(AD30),.D(AD_I30),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ29 (.Q(AD29),.D(AD_I29),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ28 (.Q(AD28),.D(AD_I28),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ27 (.Q(AD27),.D(AD_I27),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ26 (.Q(AD26),.D(AD_I26),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ25 (.Q(AD25),.D(AD_I25),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ24 (.Q(AD24),.D(AD_I24),.C(CLK),.CE(1'b1),.PRE(RST));

FDPE XPCI_ADQ23 (.Q(AD23),.D(AD_I23),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ22 (.Q(AD22),.D(AD_I22),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ21 (.Q(AD21),.D(AD_I21),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ20 (.Q(AD20),.D(AD_I20),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ19 (.Q(AD19),.D(AD_I19),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ18 (.Q(AD18),.D(AD_I18),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ17 (.Q(AD17),.D(AD_I17),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ16 (.Q(AD16),.D(AD_I16),.C(CLK),.CE(1'b1),.PRE(RST));

FDPE XPCI_ADQ15 (.Q(AD15),.D(AD_I15),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ14 (.Q(AD14),.D(AD_I14),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ13 (.Q(AD13),.D(AD_I13),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ12 (.Q(AD12),.D(AD_I12),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ11 (.Q(AD11),.D(AD_I11),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ10 (.Q(AD10),.D(AD_I10),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ9  (.Q(AD9 ),.D(AD_I9 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ8  (.Q(AD8 ),.D(AD_I8 ),.C(CLK),.CE(1'b1),.PRE(RST));

FDPE XPCI_ADQ7  (.Q(AD7 ),.D(AD_I7 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ6  (.Q(AD6 ),.D(AD_I6 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ5  (.Q(AD5 ),.D(AD_I5 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ4  (.Q(AD4 ),.D(AD_I4 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ3  (.Q(AD3 ),.D(AD_I3 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ2  (.Q(AD2 ),.D(AD_I2 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ1  (.Q(AD1 ),.D(AD_I1 ),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_ADQ0  (.Q(AD0 ),.D(AD_I0 ),.C(CLK),.CE(1'b1),.PRE(RST));

IOBUF_PCI33_3 XPCI_CBB3 (.O(CBE_I3),.IO(CBE_IO[3]),.I(CBE_O3),.T(OE_CBE  ));
IOBUF_PCI33_3 XPCI_CBB2 (.O(CBE_I2),.IO(CBE_IO[2]),.I(CBE_O2),.T(OE_CBE  ));
IOBUF_PCI33_3 XPCI_CBB1 (.O(CBE_I1),.IO(CBE_IO[1]),.I(CBE_O1),.T(OE_CBE  ));
IOBUF_PCI33_3 XPCI_CBB0 (.O(CBE_I0),.IO(CBE_IO[0]),.I(CBE_O0),.T(OE_CBE  ));

FDPE XPCI_CBQ3 (.Q(CBE_IN3),.D(CBE_I3),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_CBQ2 (.Q(CBE_IN2),.D(CBE_I2),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_CBQ1 (.Q(CBE_IN1),.D(CBE_I1),.C(CLK),.CE(1'b1),.PRE(RST));
FDPE XPCI_CBQ0 (.Q(CBE_IN0),.D(CBE_I0),.C(CLK),.CE(1'b1),.PRE(RST));

IOBUF_PCI33_3 XPCI_PAR      (.O(PAR_I),.IO(PAR_IO),
                             .I(PAR_O),.T(OE_PAR));

IOBUF_PCI33_3 XPCI_FRAME    (.O(FRAME_I),.IO(FRAME_IO),
                             .I(FRAME_O),.T(OE_FRAME));

IOBUF_PCI33_3 XPCI_TRDY     (.O(TRDY_I),.IO(TRDY_IO),
                             .I(TRDY_O),.T(OE_TRDY));

IOBUF_PCI33_3 XPCI_IRDY     (.O(IRDY_I),.IO(IRDY_IO),
                             .I(IRDY_O),.T(OE_IRDY));

IOBUF_PCI33_3 XPCI_STOP     (.O(STOP_I),.IO(STOP_IO),
                             .I(STOP_O),.T(OE_STOP));

IOBUF_PCI33_3 XPCI_DEVSEL   (.O(DEVSEL_I),.IO(DEVSEL_IO),
                             .I(DEVSEL_O),.T(OE_DEVSEL));

IOBUF_PCI33_3 XPCI_PERR     (.O(PERR_I),.IO(PERR_IO),
                             .I(PERR_O),.T(OE_PERR));

IOBUF_PCI33_3 XPCI_SERR     (.O(SERR_I),.IO(SERR_IO),
                             .I( 1'b0 ),.T(OE_SERR));

OBUFT_PCI33_3 XPCI_REQ      (.O(REQ_O),.T(OE_REQ),.I(REQ_OUT));
OBUFT_PCI33_3 XPCI_INTA     (.O(INTA_O),.T(OE_INTA),.I( 1'b0 ));

IBUF_PCI33_3  XPCI_IDSEL    (.O(IDSEL_IN),.I(IDSEL_I));
IBUF_PCI33_3  XPCI_GNT      (.O(GNT_IN),.I(GNT_I));
IBUF_PCI33_3  XPCI_RST      (.O(RST_N),.I(RST_I));

IBUFG_PCI33_3 XPCI_CKI      (.O(NUB),.I(PCLK));
BUFG XPCI_CKA               (.O(CLK),.I(NUB));


  // PCI interface instantiation

  PCI_LC_I PCI_LC(
    .OE_ADO_T64  ( NC_000 ),
    .OE_ADO_T    ( OE_ADO_T    ),
    .OE_ADO_LT64 ( NC_001 ),
    .OE_ADO_LT   ( OE_ADO_LT   ),
    .OE_ADO_LB64 ( NC_002 ),
    .OE_ADO_LB   ( OE_ADO_LB   ),
    .OE_ADO_B64  ( NC_003 ),
    .OE_ADO_B    ( OE_ADO_B    ),
    .AD63 ( 1'b0 ),
    .AD62 ( 1'b0 ),
    .AD61 ( 1'b0 ),
    .AD60 ( 1'b0 ),
    .AD59 ( 1'b0 ),
    .AD58 ( 1'b0 ),
    .AD57 ( 1'b0 ),
    .AD56 ( 1'b0 ),
    .AD55 ( 1'b0 ),
    .AD54 ( 1'b0 ),
    .AD53 ( 1'b0 ),
    .AD52 ( 1'b0 ),
    .AD51 ( 1'b0 ),
    .AD50 ( 1'b0 ),
    .AD49 ( 1'b0 ),
    .AD48 ( 1'b0 ),
    .AD47 ( 1'b0 ),
    .AD46 ( 1'b0 ),
    .AD45 ( 1'b0 ),
    .AD44 ( 1'b0 ),
    .AD43 ( 1'b0 ),
    .AD42 ( 1'b0 ),
    .AD41 ( 1'b0 ),
    .AD40 ( 1'b0 ),
    .AD39 ( 1'b0 ),
    .AD38 ( 1'b0 ),
    .AD37 ( 1'b0 ),
    .AD36 ( 1'b0 ),
    .AD35 ( 1'b0 ),
    .AD34 ( 1'b0 ),
    .AD33 ( 1'b0 ),
    .AD32 ( 1'b0 ),
    .AD31 ( AD31 ),
    .AD30 ( AD30 ),
    .AD29 ( AD29 ),
    .AD28 ( AD28 ),
    .AD27 ( AD27 ),
    .AD26 ( AD26 ),
    .AD25 ( AD25 ),
    .AD24 ( AD24 ),
    .AD23 ( AD23 ),
    .AD22 ( AD22 ),
    .AD21 ( AD21 ),
    .AD20 ( AD20 ),
    .AD19 ( AD19 ),
    .AD18 ( AD18 ),
    .AD17 ( AD17 ),
    .AD16 ( AD16 ),
    .AD15 ( AD15 ),
    .AD14 ( AD14 ),
    .AD13 ( AD13 ),
    .AD12 ( AD12 ),
    .AD11 ( AD11 ),
    .AD10 ( AD10 ),
    .AD9  ( AD9  ),
    .AD8  ( AD8  ),
    .AD7  ( AD7  ),
    .AD6  ( AD6  ),
    .AD5  ( AD5  ),
    .AD4  ( AD4  ),
    .AD3  ( AD3  ),
    .AD2  ( AD2  ),
    .AD1  ( AD1  ),
    .AD0  ( AD0  ),
    .AD_O63 ( NC_004 ),
    .AD_O62 ( NC_005 ),
    .AD_O61 ( NC_006 ),
    .AD_O60 ( NC_007 ),
    .AD_O59 ( NC_008 ),
    .AD_O58 ( NC_009 ),
    .AD_O57 ( NC_010 ),
    .AD_O56 ( NC_011 ),
    .AD_O55 ( NC_012 ),
    .AD_O54 ( NC_013 ),
    .AD_O53 ( NC_014 ),
    .AD_O52 ( NC_015 ),
    .AD_O51 ( NC_016 ),
    .AD_O50 ( NC_017 ),
    .AD_O49 ( NC_018 ),
    .AD_O48 ( NC_019 ),
    .AD_O47 ( NC_020 ),
    .AD_O46 ( NC_021 ),
    .AD_O45 ( NC_022 ),
    .AD_O44 ( NC_023 ),
    .AD_O43 ( NC_024 ),
    .AD_O42 ( NC_025 ),
    .AD_O41 ( NC_026 ),
    .AD_O40 ( NC_027 ),
    .AD_O39 ( NC_028 ),
    .AD_O38 ( NC_029 ),
    .AD_O37 ( NC_030 ),
    .AD_O36 ( NC_031 ),
    .AD_O35 ( NC_032 ),
    .AD_O34 ( NC_033 ),
    .AD_O33 ( NC_034 ),
    .AD_O32 ( NC_035 ),
    .AD_O31 ( AD_O31 ),
    .AD_O30 ( AD_O30 ),
    .AD_O29 ( AD_O29 ),
    .AD_O28 ( AD_O28 ),
    .AD_O27 ( AD_O27 ),
    .AD_O26 ( AD_O26 ),
    .AD_O25 ( AD_O25 ),
    .AD_O24 ( AD_O24 ),
    .AD_O23 ( AD_O23 ),
    .AD_O22 ( AD_O22 ),
    .AD_O21 ( AD_O21 ),
    .AD_O20 ( AD_O20 ),
    .AD_O19 ( AD_O19 ),
    .AD_O18 ( AD_O18 ),
    .AD_O17 ( AD_O17 ),
    .AD_O16 ( AD_O16 ),
    .AD_O15 ( AD_O15 ),
    .AD_O14 ( AD_O14 ),
    .AD_O13 ( AD_O13 ),
    .AD_O12 ( AD_O12 ),
    .AD_O11 ( AD_O11 ),
    .AD_O10 ( AD_O10 ),
    .AD_O9  ( AD_O9  ),
    .AD_O8  ( AD_O8  ),
    .AD_O7  ( AD_O7  ),
    .AD_O6  ( AD_O6  ),
    .AD_O5  ( AD_O5  ),
    .AD_O4  ( AD_O4  ),
    .AD_O3  ( AD_O3  ),
    .AD_O2  ( AD_O2  ),
    .AD_O1  ( AD_O1  ),
    .AD_O0  ( AD_O0  ),

    .OE_CBE64  ( NC_036 ),
    .OE_CBE    ( OE_CBE   ),
    .CBE_I7  ( 1'b0 ),
    .CBE_I6  ( 1'b0 ),
    .CBE_I5  ( 1'b0 ),
    .CBE_I4  ( 1'b0 ),
    .CBE_I3  ( CBE_I3  ),
    .CBE_I2  ( CBE_I2  ),
    .CBE_I1  ( CBE_I1  ),
    .CBE_I0  ( CBE_I0  ),
    .CBE_IN7 ( 1'b0 ),
    .CBE_IN6 ( 1'b0 ),
    .CBE_IN5 ( 1'b0 ),
    .CBE_IN4 ( 1'b0 ),
    .CBE_IN3 ( CBE_IN3 ),
    .CBE_IN2 ( CBE_IN2 ),
    .CBE_IN1 ( CBE_IN1 ),
    .CBE_IN0 ( CBE_IN0 ),
    .CBE_O7  ( NC_037 ),
    .CBE_O6  ( NC_038 ),
    .CBE_O5  ( NC_039 ),
    .CBE_O4  ( NC_040 ),
    .CBE_O3  ( CBE_O3  ),
    .CBE_O2  ( CBE_O2  ),
    .CBE_O1  ( CBE_O1  ),
    .CBE_O0  ( CBE_O0  ),

    .OE_PAR64( NC_041 ),
    .PAR64_I ( 1'b0 ),
    .PAR64_O ( NC_042 ),

    .OE_PAR ( OE_PAR ),
    .PAR_I ( PAR_I ),
    .PAR_O ( PAR_O ),

    .OE_FRAME ( OE_FRAME ),
    .FRAME_I ( FRAME_I ),
    .FRAME_O ( FRAME_O ),

    .OE_REQ64 ( NC_043 ),
    .REQ64_I ( 1'b1 ),
    .REQ64_O ( NC_044 ),

    .OE_TRDY ( OE_TRDY ),
    .TRDY_I ( TRDY_I ),
    .TRDY_O ( TRDY_O ),

    .OE_IRDY ( OE_IRDY ),
    .IRDY_I ( IRDY_I ),
    .IRDY_O ( IRDY_O ),

    .OE_STOP ( OE_STOP ),
    .STOP_I ( STOP_I ),
    .STOP_O ( STOP_O ),

    .OE_DEVSEL ( OE_DEVSEL ),
    .DEVSEL_I ( DEVSEL_I ),
    .DEVSEL_O ( DEVSEL_O ),

    .OE_ACK64 ( NC_045 ),
    .ACK64_I ( 1'b1 ),
    .ACK64_O ( NC_046 ),

    .IDSEL_IN ( IDSEL_IN ),

    .OE_INTA ( OE_INTA ),

    .OE_PERR ( OE_PERR ),
    .PERR_I ( PERR_I ),
    .PERR_O ( PERR_O ),

    .OE_SERR ( OE_SERR ),
    .SERR_I ( SERR_I ),

    .OE_REQ ( OE_REQ ),
    .REQ_OUT ( REQ_OUT ),

    .GNT_IN ( GNT_IN ),

    .RST_N ( RST_N ),

    .CFG255 ( CFG[255] ),
    .CFG254 ( CFG[254] ),
    .CFG253 ( CFG[253] ),
    .CFG252 ( CFG[252] ),
    .CFG251 ( CFG[251] ),
    .CFG250 ( CFG[250] ),
    .CFG249 ( CFG[249] ),
    .CFG248 ( CFG[248] ),
    .CFG247 ( CFG[247] ),
    .CFG246 ( CFG[246] ),
    .CFG245 ( CFG[245] ),
    .CFG244 ( CFG[244] ),
    .CFG243 ( CFG[243] ),
    .CFG242 ( CFG[242] ),
    .CFG241 ( CFG[241] ),
    .CFG240 ( CFG[240] ),
    .CFG239 ( CFG[239] ),
    .CFG238 ( CFG[238] ),
    .CFG237 ( CFG[237] ),
    .CFG236 ( CFG[236] ),
    .CFG235 ( CFG[235] ),
    .CFG234 ( CFG[234] ),
    .CFG233 ( CFG[233] ),
    .CFG232 ( CFG[232] ),
    .CFG231 ( CFG[231] ),
    .CFG230 ( CFG[230] ),
    .CFG229 ( CFG[229] ),
    .CFG228 ( CFG[228] ),
    .CFG227 ( CFG[227] ),
    .CFG226 ( CFG[226] ),
    .CFG225 ( CFG[225] ),
    .CFG224 ( CFG[224] ),
    .CFG223 ( CFG[223] ),
    .CFG222 ( CFG[222] ),
    .CFG221 ( CFG[221] ),
    .CFG220 ( CFG[220] ),
    .CFG219 ( CFG[219] ),
    .CFG218 ( CFG[218] ),
    .CFG217 ( CFG[217] ),
    .CFG216 ( CFG[216] ),
    .CFG215 ( CFG[215] ),
    .CFG214 ( CFG[214] ),
    .CFG213 ( CFG[213] ),
    .CFG212 ( CFG[212] ),
    .CFG211 ( CFG[211] ),
    .CFG210 ( CFG[210] ),
    .CFG209 ( CFG[209] ),
    .CFG208 ( CFG[208] ),
    .CFG207 ( CFG[207] ),
    .CFG206 ( CFG[206] ),
    .CFG205 ( CFG[205] ),
    .CFG204 ( CFG[204] ),
    .CFG203 ( CFG[203] ),
    .CFG202 ( CFG[202] ),
    .CFG201 ( CFG[201] ),
    .CFG200 ( CFG[200] ),
    .CFG199 ( CFG[199] ),
    .CFG198 ( CFG[198] ),
    .CFG197 ( CFG[197] ),
    .CFG196 ( CFG[196] ),
    .CFG195 ( CFG[195] ),
    .CFG194 ( CFG[194] ),
    .CFG193 ( CFG[193] ),
    .CFG192 ( CFG[192] ),
    .CFG191 ( CFG[191] ),
    .CFG190 ( CFG[190] ),
    .CFG189 ( CFG[189] ),
    .CFG188 ( CFG[188] ),
    .CFG187 ( CFG[187] ),
    .CFG186 ( CFG[186] ),
    .CFG185 ( CFG[185] ),
    .CFG184 ( CFG[184] ),
    .CFG183 ( CFG[183] ),
    .CFG182 ( CFG[182] ),
    .CFG181 ( CFG[181] ),
    .CFG180 ( CFG[180] ),
    .CFG179 ( CFG[179] ),
    .CFG178 ( CFG[178] ),
    .CFG177 ( CFG[177] ),
    .CFG176 ( CFG[176] ),
    .CFG175 ( CFG[175] ),
    .CFG174 ( CFG[174] ),
    .CFG173 ( CFG[173] ),
    .CFG172 ( CFG[172] ),
    .CFG171 ( CFG[171] ),
    .CFG170 ( CFG[170] ),
    .CFG169 ( CFG[169] ),
    .CFG168 ( CFG[168] ),
    .CFG167 ( CFG[167] ),
    .CFG166 ( CFG[166] ),
    .CFG165 ( CFG[165] ),
    .CFG164 ( CFG[164] ),
    .CFG163 ( CFG[163] ),
    .CFG162 ( CFG[162] ),
    .CFG161 ( CFG[161] ),
    .CFG160 ( CFG[160] ),
    .CFG159 ( CFG[159] ),
    .CFG158 ( CFG[158] ),
    .CFG157 ( CFG[157] ),
    .CFG156 ( CFG[156] ),
    .CFG155 ( CFG[155] ),
    .CFG154 ( CFG[154] ),
    .CFG153 ( CFG[153] ),
    .CFG152 ( CFG[152] ),
    .CFG151 ( CFG[151] ),
    .CFG150 ( CFG[150] ),
    .CFG149 ( CFG[149] ),
    .CFG148 ( CFG[148] ),
    .CFG147 ( CFG[147] ),
    .CFG146 ( CFG[146] ),
    .CFG145 ( CFG[145] ),
    .CFG144 ( CFG[144] ),
    .CFG143 ( CFG[143] ),
    .CFG142 ( CFG[142] ),
    .CFG141 ( CFG[141] ),
    .CFG140 ( CFG[140] ),
    .CFG139 ( CFG[139] ),
    .CFG138 ( CFG[138] ),
    .CFG137 ( CFG[137] ),
    .CFG136 ( CFG[136] ),
    .CFG135 ( CFG[135] ),
    .CFG134 ( CFG[134] ),
    .CFG133 ( CFG[133] ),
    .CFG132 ( CFG[132] ),
    .CFG131 ( CFG[131] ),
    .CFG130 ( CFG[130] ),
    .CFG129 ( CFG[129] ),
    .CFG128 ( CFG[128] ),
    .CFG127 ( CFG[127] ),
    .CFG126 ( CFG[126] ),
    .CFG125 ( CFG[125] ),
    .CFG124 ( CFG[124] ),
    .CFG123 ( CFG[123] ),
    .CFG122 ( CFG[122] ),
    .CFG121 ( CFG[121] ),
    .CFG120 ( CFG[120] ),
    .CFG119 ( CFG[119] ),
    .CFG118 ( CFG[118] ),
    .CFG117 ( CFG[117] ),
    .CFG116 ( CFG[116] ),
    .CFG115 ( CFG[115] ),
    .CFG114 ( CFG[114] ),
    .CFG113 ( CFG[113] ),
    .CFG112 ( CFG[112] ),
    .CFG111 ( CFG[111] ),
    .CFG110 ( CFG[110] ),
    .CFG109 ( CFG[109] ),
    .CFG108 ( CFG[108] ),
    .CFG107 ( CFG[107] ),
    .CFG106 ( CFG[106] ),
    .CFG105 ( CFG[105] ),
    .CFG104 ( CFG[104] ),
    .CFG103 ( CFG[103] ),
    .CFG102 ( CFG[102] ),
    .CFG101 ( CFG[101] ),
    .CFG100 ( CFG[100] ),
    .CFG99  ( CFG[99] ),
    .CFG98  ( CFG[98] ),
    .CFG97  ( CFG[97] ),
    .CFG96  ( CFG[96] ),
    .CFG95  ( CFG[95] ),
    .CFG94  ( CFG[94] ),
    .CFG93  ( CFG[93] ),
    .CFG92  ( CFG[92] ),
    .CFG91  ( CFG[91] ),
    .CFG90  ( CFG[90] ),
    .CFG89  ( CFG[89] ),
    .CFG88  ( CFG[88] ),
    .CFG87  ( CFG[87] ),
    .CFG86  ( CFG[86] ),
    .CFG85  ( CFG[85] ),
    .CFG84  ( CFG[84] ),
    .CFG83  ( CFG[83] ),
    .CFG82  ( CFG[82] ),
    .CFG81  ( CFG[81] ),
    .CFG80  ( CFG[80] ),
    .CFG79  ( CFG[79] ),
    .CFG78  ( CFG[78] ),
    .CFG77  ( CFG[77] ),
    .CFG76  ( CFG[76] ),
    .CFG75  ( CFG[75] ),
    .CFG74  ( CFG[74] ),
    .CFG73  ( CFG[73] ),
    .CFG72  ( CFG[72] ),
    .CFG71  ( CFG[71] ),
    .CFG70  ( CFG[70] ),
    .CFG69  ( CFG[69] ),
    .CFG68  ( CFG[68] ),
    .CFG67  ( CFG[67] ),
    .CFG66  ( CFG[66] ),
    .CFG65  ( CFG[65] ),
    .CFG64  ( CFG[64] ),
    .CFG63  ( CFG[63] ),
    .CFG62  ( CFG[62] ),
    .CFG61  ( CFG[61] ),
    .CFG60  ( CFG[60] ),
    .CFG59  ( CFG[59] ),
    .CFG58  ( CFG[58] ),
    .CFG57  ( CFG[57] ),
    .CFG56  ( CFG[56] ),
    .CFG55  ( CFG[55] ),
    .CFG54  ( CFG[54] ),
    .CFG53  ( CFG[53] ),
    .CFG52  ( CFG[52] ),
    .CFG51  ( CFG[51] ),
    .CFG50  ( CFG[50] ),
    .CFG49  ( CFG[49] ),
    .CFG48  ( CFG[48] ),
    .CFG47  ( CFG[47] ),
    .CFG46  ( CFG[46] ),
    .CFG45  ( CFG[45] ),
    .CFG44  ( CFG[44] ),
    .CFG43  ( CFG[43] ),
    .CFG42  ( CFG[42] ),
    .CFG41  ( CFG[41] ),
    .CFG40  ( CFG[40] ),
    .CFG39  ( CFG[39] ),
    .CFG38  ( CFG[38] ),
    .CFG37  ( CFG[37] ),
    .CFG36  ( CFG[36] ),
    .CFG35  ( CFG[35] ),
    .CFG34  ( CFG[34] ),
    .CFG33  ( CFG[33] ),
    .CFG32  ( CFG[32] ),
    .CFG31  ( CFG[31] ),
    .CFG30  ( CFG[30] ),
    .CFG29  ( CFG[29] ),
    .CFG28  ( CFG[28] ),
    .CFG27  ( CFG[27] ),
    .CFG26  ( CFG[26] ),
    .CFG25  ( CFG[25] ),
    .CFG24  ( CFG[24] ),
    .CFG23  ( CFG[23] ),
    .CFG22  ( CFG[22] ),
    .CFG21  ( CFG[21] ),
    .CFG20  ( CFG[20] ),
    .CFG19  ( CFG[19] ),
    .CFG18  ( CFG[18] ),
    .CFG17  ( CFG[17] ),
    .CFG16  ( CFG[16] ),
    .CFG15  ( CFG[15] ),
    .CFG14  ( CFG[14] ),
    .CFG13  ( CFG[13] ),
    .CFG12  ( CFG[12] ),
    .CFG11  ( CFG[11] ),
    .CFG10  ( CFG[10] ),
    .CFG9   ( CFG[9] ),
    .CFG8   ( CFG[8] ),
    .CFG7   ( CFG[7] ),
    .CFG6   ( CFG[6] ),
    .CFG5   ( CFG[5] ),
    .CFG4   ( CFG[4] ),
    .CFG3   ( CFG[3] ),
    .CFG2   ( CFG[2] ),
    .CFG1   ( CFG[1] ),
    .CFG0   ( CFG[0] ),
    .FRAMEQ_N ( FRAMEQ_N ),
    .REQ64Q_N ( NC_047 ),
    .TRDYQ_N ( TRDYQ_N ),
    .IRDYQ_N ( IRDYQ_N ),
    .STOPQ_N ( STOPQ_N ),
    .DEVSELQ_N ( DEVSELQ_N ),
    .ACK64Q_N ( NC_048 ),
    .ADDR31 ( ADDR[31] ),
    .ADDR30 ( ADDR[30] ),
    .ADDR29 ( ADDR[29] ),
    .ADDR28 ( ADDR[28] ),
    .ADDR27 ( ADDR[27] ),
    .ADDR26 ( ADDR[26] ),
    .ADDR25 ( ADDR[25] ),
    .ADDR24 ( ADDR[24] ),
    .ADDR23 ( ADDR[23] ),
    .ADDR22 ( ADDR[22] ),
    .ADDR21 ( ADDR[21] ),
    .ADDR20 ( ADDR[20] ),
    .ADDR19 ( ADDR[19] ),
    .ADDR18 ( ADDR[18] ),
    .ADDR17 ( ADDR[17] ),
    .ADDR16 ( ADDR[16] ),
    .ADDR15 ( ADDR[15] ),
    .ADDR14 ( ADDR[14] ),
    .ADDR13 ( ADDR[13] ),
    .ADDR12 ( ADDR[12] ),
    .ADDR11 ( ADDR[11] ),
    .ADDR10 ( ADDR[10] ),
    .ADDR9  ( ADDR[ 9] ),
    .ADDR8  ( ADDR[ 8] ),
    .ADDR7  ( ADDR[ 7] ),
    .ADDR6  ( ADDR[ 6] ),
    .ADDR5  ( ADDR[ 5] ),
    .ADDR4  ( ADDR[ 4] ),
    .ADDR3  ( ADDR[ 3] ),
    .ADDR2  ( ADDR[ 2] ),
    .ADDR1  ( ADDR[ 1] ),
    .ADDR0  ( ADDR[ 0] ),
    .ADIO63 ( NC_049 ),
    .ADIO62 ( NC_050 ),
    .ADIO61 ( NC_051 ),
    .ADIO60 ( NC_052 ),
    .ADIO59 ( NC_053 ),
    .ADIO58 ( NC_054 ),
    .ADIO57 ( NC_055 ),
    .ADIO56 ( NC_056 ),
    .ADIO55 ( NC_057 ),
    .ADIO54 ( NC_058 ),
    .ADIO53 ( NC_059 ),
    .ADIO52 ( NC_060 ),
    .ADIO51 ( NC_061 ),
    .ADIO50 ( NC_062 ),
    .ADIO49 ( NC_063 ),
    .ADIO48 ( NC_064 ),
    .ADIO47 ( NC_065 ),
    .ADIO46 ( NC_066 ),
    .ADIO45 ( NC_067 ),
    .ADIO44 ( NC_068 ),
    .ADIO43 ( NC_069 ),
    .ADIO42 ( NC_070 ),
    .ADIO41 ( NC_071 ),
    .ADIO40 ( NC_072 ),
    .ADIO39 ( NC_073 ),
    .ADIO38 ( NC_074 ),
    .ADIO37 ( NC_075 ),
    .ADIO36 ( NC_076 ),
    .ADIO35 ( NC_077 ),
    .ADIO34 ( NC_078 ),
    .ADIO33 ( NC_079 ),
    .ADIO32 ( NC_080 ),
    .ADIO31 ( ADIO[31] ),
    .ADIO30 ( ADIO[30] ),
    .ADIO29 ( ADIO[29] ),
    .ADIO28 ( ADIO[28] ),
    .ADIO27 ( ADIO[27] ),
    .ADIO26 ( ADIO[26] ),
    .ADIO25 ( ADIO[25] ),
    .ADIO24 ( ADIO[24] ),
    .ADIO23 ( ADIO[23] ),
    .ADIO22 ( ADIO[22] ),
    .ADIO21 ( ADIO[21] ),
    .ADIO20 ( ADIO[20] ),
    .ADIO19 ( ADIO[19] ),
    .ADIO18 ( ADIO[18] ),
    .ADIO17 ( ADIO[17] ),
    .ADIO16 ( ADIO[16] ),
    .ADIO15 ( ADIO[15] ),
    .ADIO14 ( ADIO[14] ),
    .ADIO13 ( ADIO[13] ),
    .ADIO12 ( ADIO[12] ),
    .ADIO11 ( ADIO[11] ),
    .ADIO10 ( ADIO[10] ),
    .ADIO9  ( ADIO[ 9] ),
    .ADIO8  ( ADIO[ 8] ),
    .ADIO7  ( ADIO[ 7] ),
    .ADIO6  ( ADIO[ 6] ),
    .ADIO5  ( ADIO[ 5] ),
    .ADIO4  ( ADIO[ 4] ),
    .ADIO3  ( ADIO[ 3] ),
    .ADIO2  ( ADIO[ 2] ),
    .ADIO1  ( ADIO[ 1] ),
    .ADIO0  ( ADIO[ 0] ),
    .CFG_VLD ( CFG_VLD ),
    .CFG_HIT ( CFG_HIT ),
    .C_TERM ( C_TERM ),
    .C_READY ( C_READY ),
    .ADDR_VLD ( ADDR_VLD ),
    .BASE_HIT7 ( BASE_HIT[7] ),
    .BASE_HIT6 ( BASE_HIT[6] ),
    .BASE_HIT5 ( BASE_HIT[5] ),
    .BASE_HIT4 ( BASE_HIT[4] ),
    .BASE_HIT3 ( BASE_HIT[3] ),
    .BASE_HIT2 ( BASE_HIT[2] ),
    .BASE_HIT1 ( BASE_HIT[1] ),
    .BASE_HIT0 ( BASE_HIT[0] ),
    .S_CYCLE64 ( NC_081 ),
    .S_TERM ( S_TERM ),
    .S_READY ( S_READY ),
    .S_ABORT ( S_ABORT ),
    .S_WRDN ( S_WRDN ),
    .S_SRC_EN ( S_SRC_EN ),
    .S_DATA_VLD ( S_DATA_VLD ),
    .S_CBE7 ( NC_082 ),
    .S_CBE6 ( NC_083 ),
    .S_CBE5 ( NC_084 ),
    .S_CBE4 ( NC_085 ),
    .S_CBE3 ( S_CBE[3] ),
    .S_CBE2 ( S_CBE[2] ),
    .S_CBE1 ( S_CBE[1] ),
    .S_CBE0 ( S_CBE[0] ),
    .PCI_CMD15 ( PCI_CMD[15] ),
    .PCI_CMD14 ( PCI_CMD[14] ),
    .PCI_CMD13 ( PCI_CMD[13] ),
    .PCI_CMD12 ( PCI_CMD[12] ),
    .PCI_CMD11 ( PCI_CMD[11] ),
    .PCI_CMD10 ( PCI_CMD[10] ),
    .PCI_CMD9  ( PCI_CMD[ 9] ),
    .PCI_CMD8  ( PCI_CMD[ 8] ),
    .PCI_CMD7  ( PCI_CMD[ 7] ),
    .PCI_CMD6  ( PCI_CMD[ 6] ),
    .PCI_CMD5  ( PCI_CMD[ 5] ),
    .PCI_CMD4  ( PCI_CMD[ 4] ),
    .PCI_CMD3  ( PCI_CMD[ 3] ),
    .PCI_CMD2  ( PCI_CMD[ 2] ),
    .PCI_CMD1  ( PCI_CMD[ 1] ),
    .PCI_CMD0  ( PCI_CMD[ 0] ),
    .REQUEST ( REQUEST ),
    .REQUEST64 ( 1'b0 ),
    .REQUESTHOLD ( REQUESTHOLD ),
    .COMPLETE ( COMPLETE ),
    .M_WRDN ( M_WRDN ),
    .M_READY ( M_READY ),
    .M_SRC_EN ( M_SRC_EN ),
    .M_DATA_VLD ( M_DATA_VLD ),
    .M_CBE7 ( 1'b0 ),
    .M_CBE6 ( 1'b0 ),
    .M_CBE5 ( 1'b0 ),
    .M_CBE4 ( 1'b0 ),
    .M_CBE3 ( M_CBE[3] ),
    .M_CBE2 ( M_CBE[2] ),
    .M_CBE1 ( M_CBE[1] ),
    .M_CBE0 ( M_CBE[0] ),
    .TIME_OUT ( TIME_OUT ),
    .M_FAIL64 ( NC_086 ),
    .CFG_SELF ( CFG_SELF ),
    .M_DATA ( M_DATA ),
    .DR_BUS ( DR_BUS ),
    .I_IDLE ( I_IDLE ),
    .M_ADDR_N ( M_ADDR_N ),
    .IDLE ( IDLE ),
    .B_BUSY ( B_BUSY ),
    .S_DATA ( S_DATA ),
    .BACKOFF ( BACKOFF ),
    .SLOT64 ( 1'b0 ),
    .INTR_N  ( INTR_N ),
    .PERRQ_N ( PERRQ_N ),
    .SERRQ_N ( SERRQ_N ),
    .KEEPOUT ( KEEPOUT ),
    .CSR39 ( CSR[39] ),
    .CSR38 ( CSR[38] ),
    .CSR37 ( CSR[37] ),
    .CSR36 ( CSR[36] ),
    .CSR35 ( CSR[35] ),
    .CSR34 ( CSR[34] ),
    .CSR33 ( CSR[33] ),
    .CSR32 ( CSR[32] ),
    .CSR31 ( CSR[31] ),
    .CSR30 ( CSR[30] ),
    .CSR29 ( CSR[29] ),
    .CSR28 ( CSR[28] ),
    .CSR27 ( CSR[27] ),
    .CSR26 ( CSR[26] ),
    .CSR25 ( CSR[25] ),
    .CSR24 ( CSR[24] ),
    .CSR23 ( CSR[23] ),
    .CSR22 ( CSR[22] ),
    .CSR21 ( CSR[21] ),
    .CSR20 ( CSR[20] ),
    .CSR19 ( CSR[19] ),
    .CSR18 ( CSR[18] ),
    .CSR17 ( CSR[17] ),
    .CSR16 ( CSR[16] ),
    .CSR15 ( CSR[15] ),
    .CSR14 ( CSR[14] ),
    .CSR13 ( CSR[13] ),
    .CSR12 ( CSR[12] ),
    .CSR11 ( CSR[11] ),
    .CSR10 ( CSR[10] ),
    .CSR9 ( CSR[9] ),
    .CSR8 ( CSR[8] ),
    .CSR7 ( CSR[7] ),
    .CSR6 ( CSR[6] ),
    .CSR5 ( CSR[5] ),
    .CSR4 ( CSR[4] ),
    .CSR3 ( CSR[3] ),
    .CSR2 ( CSR[2] ),
    .CSR1 ( CSR[1] ),
    .CSR0 ( CSR[0] ),
    .SUB_DATA31 ( SUB_DATA[31] ),
    .SUB_DATA30 ( SUB_DATA[30] ),
    .SUB_DATA29 ( SUB_DATA[29] ),
    .SUB_DATA28 ( SUB_DATA[28] ),
    .SUB_DATA27 ( SUB_DATA[27] ),
    .SUB_DATA26 ( SUB_DATA[26] ),
    .SUB_DATA25 ( SUB_DATA[25] ),
    .SUB_DATA24 ( SUB_DATA[24] ),
    .SUB_DATA23 ( SUB_DATA[23] ),
    .SUB_DATA22 ( SUB_DATA[22] ),
    .SUB_DATA21 ( SUB_DATA[21] ),
    .SUB_DATA20 ( SUB_DATA[20] ),
    .SUB_DATA19 ( SUB_DATA[19] ),
    .SUB_DATA18 ( SUB_DATA[18] ),
    .SUB_DATA17 ( SUB_DATA[17] ),
    .SUB_DATA16 ( SUB_DATA[16] ),
    .SUB_DATA15 ( SUB_DATA[15] ),
    .SUB_DATA14 ( SUB_DATA[14] ),
    .SUB_DATA13 ( SUB_DATA[13] ),
    .SUB_DATA12 ( SUB_DATA[12] ),
    .SUB_DATA11 ( SUB_DATA[11] ),
    .SUB_DATA10 ( SUB_DATA[10] ),
    .SUB_DATA9  ( SUB_DATA[9] ),
    .SUB_DATA8  ( SUB_DATA[8] ),
    .SUB_DATA7  ( SUB_DATA[7] ),
    .SUB_DATA6  ( SUB_DATA[6] ),
    .SUB_DATA5  ( SUB_DATA[5] ),
    .SUB_DATA4  ( SUB_DATA[4] ),
    .SUB_DATA3  ( SUB_DATA[3] ),
    .SUB_DATA2  ( SUB_DATA[2] ),
    .SUB_DATA1  ( SUB_DATA[1] ),
    .SUB_DATA0  ( SUB_DATA[0] ),
    .CLK ( CLK ),
    .CLKX ( CLK ),
    .RST ( RST )
  );

endmodule
