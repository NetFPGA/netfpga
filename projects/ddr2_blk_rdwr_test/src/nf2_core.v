///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: nf2_core.v
// Project: NetFPGA
// Description: Core module of a test circuit for DDR2 block read/write module
//
// This is instantiated within the nf2_top module.
// This should contain internal logic only - not I/O buffers or pads.
//
///////////////////////////////////////////////////////////////////////////////

module nf2_core
   (
    // CPCI interface and clock
    input                               cpci_clk_int,   // 62.5 MHz
    input                               cpci_rd_wr_L,
    input                               cpci_req,
    input   [`CPCI_NF2_ADDR_WIDTH-1:0]  cpci_addr,
    input   [`CPCI_NF2_DATA_WIDTH-1:0]  cpci_wr_data,
    output  [`CPCI_NF2_DATA_WIDTH-1:0]  cpci_rd_data,
    output                              cpci_data_tri_en,
    output                              cpci_wr_rdy,
    output                              cpci_rd_rdy,

    // --- DDR2 interface
    output [3:0]   ddr2_cmd,
    output [21:0]  ddr2_addr,
    output [1:0]   ddr2_bank_addr,
    output         ddr2_burst_done,
    output [63:0]  ddr2_wr_data,
    output [7:0]   ddr2_wr_data_mask,
    output [14:0]  ddr2_config1,
    output [12:0]  ddr2_config2,

    input          ddr2_cmd_ack,
    input [63:0]   ddr2_rd_data,
    input          ddr2_rd_data_valid,
    input          ddr2_auto_ref_req,
    input          ddr2_ar_done,
    input          ddr2_init_val,
    input          ddr2_reset,
    input          ddr2_reset90,
    input          clk_ddr_200,
    input          clk90_ddr_200,

    // core clock
    input        core_clk_int,

    // misc
    input        reset

    );

   //------------- local parameters --------------
   localparam DATA_WIDTH = 64;
   localparam CTRL_WIDTH = DATA_WIDTH/8;
   localparam NUM_QUEUES = 8;
   localparam PKT_LEN_CNT_WIDTH = 11;

   // --- wires/regs from ddr2_blk_rdwr_test_u
   wire test_done, test_success;
   wire [2:0] dbg_ddr2_sm_state;
   wire [11:0] dbg_arb_wr_byte_cnt;
   wire [11:0] dbg_arb_rd_byte_cnt;
   wire dbg_fifo_p_wr_data_full, dbg_fifo_ack_rempty, dbg_rd_done_seen;

   // --- wires/regs from cpci_bus
   wire cpci_reg_fifo_empty, cpci_reg_rd_wr_L;
   wire [`CPCI_NF2_ADDR_WIDTH-1:0] cpci_reg_addr;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] cpci_reg_wr_data;

   // --- wires/regs from registers
   wire 			   cpci_reg_fifo_rd_en, cpci_reg_rd_vld;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] cpci_reg_rd_data;


   //--------------------------------------------------
   //
   // --- DDR2 block read/write tester
   //
   //--------------------------------------------------

   ddr2_blk_rdwr_test ddr2_blk_rdwr_test_u
     (
      //output:
      .test_done    ( test_done ),
      .test_success ( test_success ),

      // --- misc
      //input:
      .clk ( core_clk_int ),
      .reset ( reset ),

      // --- ddr2 intfc
      //input:
      .init_val_180 ( ddr2_init_val ),            // Initialization done
      .cmd_ack_180 ( ddr2_cmd_ack ),             // Command acknowledged
      .auto_ref_req_180 ( ddr2_auto_ref_req ),        // Auto-refresh request
      .ar_done_180 ( ddr2_ar_done ),             // Auto-refresh done
      .rd_data_90 ( ddr2_rd_data ),       //[63:0], Data returned from mem
      .rd_data_valid_90 ( ddr2_rd_data_valid ),       // Data is valid

      //output:
      .cmd_180 ( ddr2_cmd ),          //[3:0] Command
      .bank_addr_0 ( ddr2_bank_addr ), //[1:0], Bank address
      .addr_0 ( ddr2_addr ),        //[21:0] Rd/Wr address
      .burst_done_0 ( ddr2_burst_done ),         // Burst complete
      .config1 ( ddr2_config1 ),     //[14:0] Config register 1
      .config2 ( ddr2_config2 ),     //[12:0] Config register 2
      .wr_data_90 ( ddr2_wr_data ),     //[63:0] Data written to mem
      .wr_data_mask_90 ( ddr2_wr_data_mask ),  //[7:0] Write data mask

      //-------------------------------------
      //misc:
      //input:
      .reset_0 ( ddr2_reset ),
      .clk_0 ( clk_ddr_200 ),
      .clk_90 ( clk90_ddr_200 )
      );
   // synthesis attribute keep_hierarchy of ddr2_blk_rdwr_test_u is false;

   //---------------------------------------------
   //
   // CPCI interface
   //
   //---------------------------------------------

   cpci_bus cpci_bus_u
     (
      // -- cpci intfc
      // input:
      .cpci_rd_wr_L      (cpci_rd_wr_L),
      .cpci_req          (cpci_req),
      .cpci_addr         (cpci_addr),
      .cpci_wr_data      (cpci_wr_data),

      // output:
      .cpci_rd_data      (cpci_rd_data),
      .cpci_data_tri_en  (cpci_data_tri_en),
      .cpci_wr_rdy       (cpci_wr_rdy),
      .cpci_rd_rdy       (cpci_rd_rdy),

      // -- internal reg intfc
      // input:
      .fifo_rd_en        (cpci_reg_fifo_rd_en ),
      .bus_rd_data       (cpci_reg_rd_data),
      .bus_rd_vld        (cpci_reg_rd_vld),

      // output:
      .fifo_empty        (cpci_reg_fifo_empty ),
      .bus_rd_wr_L       (cpci_reg_rd_wr_L),
      .bus_addr          (cpci_reg_addr),
      .bus_wr_data       (cpci_reg_wr_data),

      // -- misc
      .reset            (reset),
      .pci_clk          (cpci_clk_int),
      .core_clk         (core_clk_int)
      );

   // synthesis attribute keep_hierarchy of cpci_bus_u is false;


   //-------------------------------------------------
   //
   // register address decoder, register bus mux and demux
   //
   //-----------------------------------------------

   nf2_reg nf2_reg_u
     (// interface to cpci_bus
      .fifo_empty        (cpci_reg_fifo_empty),
      .fifo_rd_en        (cpci_reg_fifo_rd_en),
      .bus_rd_wr_L       (cpci_reg_rd_wr_L),
      .bus_addr          (cpci_reg_addr),
      .bus_wr_data       (cpci_reg_wr_data),
      .bus_rd_data       (cpci_reg_rd_data),
      .bus_rd_vld        (cpci_reg_rd_vld),

      // input:
      .test_done         (test_done),
      .test_success      (test_success),

      // misc
      .clk               (core_clk_int),
      .reset             (reset)
      );

endmodule // nf2_core
