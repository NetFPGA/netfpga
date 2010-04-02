///////////////////////////////////////////////////////////////////////////////
//
// Module: dram_queue_regs.v
// Project: NF2.1
// Author: hyzeng
// Description: Demultiplexes, stores and serves register requests for DRAM queue
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module dram_queue_regs
   #(
       parameter UDP_REG_SRC_WIDTH = 2,
       parameter DRAM_BLOCK_ADDR_WIDTH = 3
   )
   (
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output                                 reg_req_out,
      output                                 reg_ack_out,
      output                                 reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]         reg_src_out,

      output				     shortcut_disable,
      output [DRAM_BLOCK_ADDR_WIDTH-1:0]     block_num,
      input				     shortcut_words,
      input				     input_words,
      input				     output_words,
      input				     dram_wr_words,
      input				     dram_rd_words,

      input                                  clk,
      input                                  reset
    );

   wire                             sw_req_in;
   wire                             sw_ack_in;
   wire                             sw_rd_wr_L_in;
   wire [`UDP_REG_ADDR_WIDTH-1:0]   sw_addr_in;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]  sw_data_in;
   wire [UDP_REG_SRC_WIDTH-1:0]     sw_src_in;

   // ------------- Internal parameters --------------
   localparam NUM_REGS_USED = 5;

   // ------------- Wires/reg ------------------

   wire [NUM_REGS_USED-1+2:2]   updates;
   wire [2 * `CPCI_NF2_DATA_WIDTH-1:0]   software_regs;
   wire  [DRAM_BLOCK_ADDR_WIDTH-1:0]     temp_block_num;



   // -------------- Logic --------------------
   generic_cntr_regs
   #(
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`DRAM_QUEUE_BLOCK_ADDR),     // Tag to match against
      .REG_ADDR_WIDTH      (`DRAM_QUEUE_REG_ADDR_WIDTH),// Width of block addresses
      .NUM_REGS_USED       (NUM_REGS_USED),              // How many registers
      .INPUT_WIDTH         (1),                          // Width of each update request
      .MIN_UPDATE_INTERVAL (1),                          // Clocks between successive inputs
      .REG_WIDTH           (`CPCI_NF2_DATA_WIDTH),       // How wide should each counter be?
      .RESET_ON_READ       (0),
      .REG_START_ADDR	   (2)
   ) generic_cntr_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out       (sw_req_in),
      .reg_ack_out       (sw_ack_in),
      .reg_rd_wr_L_out   (sw_rd_wr_L_in),
      .reg_addr_out      (sw_addr_in),
      .reg_data_out      (sw_data_in),
      .reg_src_out       (sw_src_in),

      // --- update interface
      .updates          (updates),
      .decrement	(0),

      .clk              (clk),
      .reset            (reset)
    );

    assign updates[`DRAM_QUEUE_SHORTCUT_WORDS]     	= shortcut_words;
    assign updates[`DRAM_QUEUE_INPUT_WORDS]     	= input_words;
    assign updates[`DRAM_QUEUE_OUTPUT_WORDS]	  	= output_words;
    assign updates[`DRAM_QUEUE_DRAM_WR_WORDS]   	= dram_wr_words;
    assign updates[`DRAM_QUEUE_DRAM_RD_WORDS]    	= dram_rd_words;

   generic_sw_regs
   #(
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`DRAM_QUEUE_BLOCK_ADDR),     // Tag to match against
      .REG_ADDR_WIDTH      (`DRAM_QUEUE_REG_ADDR_WIDTH),// Width of block addresses
      .NUM_REGS_USED       (2)              // How many registers
   ) generic_sw_regs(
      .reg_req_in       (sw_req_in),
      .reg_ack_in       (sw_ack_in),
      .reg_rd_wr_L_in   (sw_rd_wr_L_in),
      .reg_addr_in      (sw_addr_in),
      .reg_data_in      (sw_data_in),
      .reg_src_in       (sw_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // --- SW regs interface
      .software_regs	(software_regs), // signals from the software

      .clk              (clk),
      .reset            (reset)
    );

    assign shortcut_disable = software_regs[(`DRAM_QUEUE_SHORTCUT_DISABLE+1) * `CPCI_NF2_DATA_WIDTH-1:`DRAM_QUEUE_SHORTCUT_DISABLE * `CPCI_NF2_DATA_WIDTH];
    assign temp_block_num = software_regs[(`DRAM_QUEUE_BLOCK_NUM+1) * `CPCI_NF2_DATA_WIDTH-1:`DRAM_QUEUE_BLOCK_NUM * `CPCI_NF2_DATA_WIDTH];
    assign block_num = (temp_block_num == 0) ? 8'hff : temp_block_num;

endmodule
