/***********************************************************************

  File:   pcim_top.v
  Rev:    3.1.161

  This is the top-level template file for Verilog designs.
  The user should place his backend application design in the
  userapp module.

  Copyright (c) 2005-2007 Xilinx, Inc.  All rights reserved.

***********************************************************************/


//`include "defines.v"

module pcim_top (
            inout  [31:0] AD,             // PCI ports -- do not modify names!
            inout   [3:0] CBE,
            inout         PAR,
            inout         FRAME_N,
            inout         TRDY_N,
            inout         IRDY_N,
            inout         STOP_N,
            inout         DEVSEL_N,
            input         IDSEL,
            output        INTR_A,
            inout         PERR_N,
            inout         SERR_N,
            output        REQ_N,
            input         GNT_N,
            input         RST_N,
            input         PCLK,           // Add user ports here

            // Additional ports
            output         reg_hit,       // Indicates a hit on the CPCI registers
            output         cnet_hit,      // Indicates a hit on the CNET address range

            output         reg_we,        // Write enable signal for CPCI registers
            output         cnet_we,       // Write enable signal for CNET

            output [31:0]  pci_addr,      // The address of the current transaction
            output [31:0]  pci_data,      // The current data DWORD
            output         pci_data_vld,  // Data on pci_data is valid
            output [3:0]   pci_be,        // Byte enables for current transaction

            output         pci_retry,     // Retry signal from CSRs
            output         pci_fatal,     // Fatal signal from CSRs


            input [31:0]   reg_data,      // Data to be read for registers
            input [31:0]   cnet_data,     // Data to be read for CNET

            input          cnet_retry,    // Generate a retry for CNET
            input          cnet_reprog,   // Is CNET being reprogrammed?

            input          reg_vld,       // Is the data on reg_data valid?
            input          cnet_vld,      // Is the data on cnet_data valid?
            input          dma_vld,       // Is the data on dma_data valid?

            input          intr_req,      // Interrupt request

            input          dma_request,   // Transaction request for DMA

            input [31:0]   dma_data,      // Data from DMA block
            input [3:0]    dma_cbe,       // Command/byte enables for DMA block

            output         dma_data_vld,  // Indicates data should be captured
            output         dma_src_en,    // Next piece of data should be provided
                                          // on dma_data

            input          dma_wrdn,      // Logic high = Write, low = read

            input          dma_complete,  // Complete signal

            output         dma_lat_timeout, // Latency timer has expired
            output         dma_addr_st,   // Indicates that the core is
                                          // currently in the address phase
            output         dma_data_st,   // Core in the data state


            output         clk,		      // Output clock signal
            output         pci_reset      // Reset signal
                );
                // synthesis syn_edif_bit_format = "%u<%i>"
                // synthesis syn_edif_scalar_format = "%u"
                // synthesis syn_noclockbuf = 1
                // synthesis syn_hier = "hard"


  // Internal buses -- do not modify names!

  wire  [255:0] CFG;
  wire   [31:0] ADDR;
  wire   [31:0] ADIO;
  wire    [7:0] BASE_HIT;
  wire    [3:0] S_CBE;
  wire   [15:0] PCI_CMD;
  wire    [3:0] M_CBE;
  wire   [39:0] CSR;
  wire   [31:0] SUB_DATA;


  // Instantiation of PCI Interface -- do not modify names!

  pcim_lc PCI_CORE (
                .AD_IO ( AD ),
                .CBE_IO ( CBE ),
                .PAR_IO ( PAR ),
                .FRAME_IO ( FRAME_N ),
                .TRDY_IO ( TRDY_N ),
                .IRDY_IO ( IRDY_N ),
                .STOP_IO ( STOP_N ),
                .DEVSEL_IO ( DEVSEL_N ),
                .IDSEL_I ( IDSEL ),
                .INTA_O ( INTR_A ),
                .PERR_IO ( PERR_N ),
                .SERR_IO ( SERR_N ),
                .REQ_O ( REQ_N ),
                .GNT_I ( GNT_N ),
                .RST_I ( RST_N ),
                .PCLK ( PCLK ),
                .FRAMEQ_N ( FRAMEQ_N ),
                .TRDYQ_N ( TRDYQ_N ),
                .IRDYQ_N ( IRDYQ_N ),
                .STOPQ_N ( STOPQ_N ),
                .DEVSELQ_N ( DEVSELQ_N ),
                .ADDR ( ADDR ),
                .ADIO ( ADIO ),
                .CFG_VLD ( CFG_VLD ),
                .CFG_HIT ( CFG_HIT ),
                .C_TERM ( C_TERM ),
                .C_READY ( C_READY ),
                .ADDR_VLD ( ADDR_VLD ),
                .BASE_HIT ( BASE_HIT ),
                .S_TERM ( S_TERM ),
                .S_READY ( S_READY ),
                .S_ABORT ( S_ABORT ),
                .S_WRDN ( S_WRDN ),
                .S_SRC_EN ( S_SRC_EN ),
                .S_DATA_VLD ( S_DATA_VLD ),
                .S_CBE ( S_CBE ),
                .PCI_CMD ( PCI_CMD ),
                .REQUEST ( REQUEST ),
                .REQUESTHOLD ( REQUESTHOLD ),
                .COMPLETE ( COMPLETE ),
                .M_WRDN ( M_WRDN ),
                .M_READY ( M_READY ),
                .M_SRC_EN ( M_SRC_EN ),
                .M_DATA_VLD ( M_DATA_VLD ),
                .M_CBE ( M_CBE ),
                .TIME_OUT ( TIME_OUT ),
                .CFG_SELF ( CFG_SELF ),
                .M_DATA ( M_DATA ),
                .DR_BUS ( DR_BUS ),
                .I_IDLE ( I_IDLE ),
                .M_ADDR_N ( M_ADDR_N ),
                .IDLE ( IDLE ),
                .B_BUSY ( B_BUSY ),
                .S_DATA ( S_DATA ),
                .BACKOFF ( BACKOFF ),
                .INTR_N ( INTR_N ),
                .PERRQ_N ( PERRQ_N ),
                .SERRQ_N ( SERRQ_N ),
                .KEEPOUT ( KEEPOUT ),
                .CSR ( CSR ),
                .SUB_DATA ( SUB_DATA ),
                .CFG ( CFG ),
                .RST ( RST ),
                .CLK ( clk )
                );


  // Instantiation of the configuration module

  cfg CFG_INST (
                .CFG ( CFG )
                );


  // Instantiation of userapp back-end application template

  pci_userapp USER_APP (
                .FRAMEQ_N ( FRAMEQ_N ),
                .TRDYQ_N ( TRDYQ_N ),
                .IRDYQ_N ( IRDYQ_N ),
                .STOPQ_N ( STOPQ_N ),
                .DEVSELQ_N ( DEVSELQ_N ),
                .ADDR ( ADDR ),
                .ADIO ( ADIO ),
                .CFG_VLD ( CFG_VLD ),
                .CFG_HIT ( CFG_HIT ),
                .C_TERM ( C_TERM ),
                .C_READY ( C_READY ),
                .ADDR_VLD ( ADDR_VLD ),
                .BASE_HIT ( BASE_HIT ),
                .S_TERM ( S_TERM ),
                .S_READY ( S_READY ),
                .S_ABORT ( S_ABORT ),
                .S_WRDN ( S_WRDN ),
                .S_SRC_EN ( S_SRC_EN ),
                .S_DATA_VLD ( S_DATA_VLD ),
                .S_CBE ( S_CBE ),
                .PCI_CMD ( PCI_CMD ),
                .REQUEST ( REQUEST ),
                .REQUESTHOLD ( REQUESTHOLD ),
                .COMPLETE ( COMPLETE ),
                .M_WRDN ( M_WRDN ),
                .M_READY ( M_READY ),
                .M_SRC_EN ( M_SRC_EN ),
                .M_DATA_VLD ( M_DATA_VLD ),
                .M_CBE ( M_CBE ),
                .TIME_OUT ( TIME_OUT ),
                .CFG_SELF ( CFG_SELF ),
                .M_DATA ( M_DATA ),
                .DR_BUS ( DR_BUS ),
                .I_IDLE ( I_IDLE ),
                .M_ADDR_N ( M_ADDR_N ),
                .IDLE ( IDLE ),
                .B_BUSY ( B_BUSY ),
                .S_DATA ( S_DATA ),
                .BACKOFF ( BACKOFF ),
                .INTR_N ( INTR_N ),
                .PERRQ_N ( PERRQ_N ),
                .SERRQ_N ( SERRQ_N ),
                .KEEPOUT ( KEEPOUT ),
                .CSR ( CSR ),
                .SUB_DATA ( SUB_DATA ),
                .CFG ( CFG ),
                .RST ( RST ),
                .CLK ( clk ),

                .reg_hit (reg_hit),
                .cnet_hit (cnet_hit),

                .reg_we (reg_we),
                .cnet_we (cnet_we),

                .pci_addr (pci_addr),
                .pci_data (pci_data),
                .pci_data_vld (pci_data_vld),
                .pci_be (pci_be),

		.pci_retry (pci_retry),
		.pci_fatal (pci_fatal),

                .reg_data (reg_data),
                .cnet_data (cnet_data),

                .cnet_retry (cnet_retry),
                .cnet_reprog (cnet_reprog),

                .reg_vld (reg_vld),
                .cnet_vld (cnet_vld),
                .dma_vld (dma_vld),

		.intr_req (intr_req),

                .dma_request (dma_request),

                .dma_data (dma_data),
                .dma_cbe (dma_cbe),

                .dma_data_vld (dma_data_vld),
                .dma_src_en (dma_src_en),

                .dma_wrdn (dma_wrdn),

                .dma_complete (dma_complete),

                .dma_lat_timeout (dma_lat_timeout),
                .dma_addr_st (dma_addr_st),

                .dma_data_st (dma_data_st)
                );

assign pci_reset = RST;

endmodule
