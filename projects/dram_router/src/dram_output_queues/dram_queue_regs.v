///////////////////////////////////////////////////////////////////////////////
//
// Module: dram_queue_regs.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
// Counter registers
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module dram_queue_regs
   #(
       parameter UDP_REG_SRC_WIDTH = 2,
       //parameter DRAM_BLOCK_RDWR_ADDR_WIDTH = `DRAM_BLOCK_RDWR_ADDR_WIDTH,
       parameter OQ_BLOCK_ADDR = `OQ_BLOCK_ADDR,//Don't be confused! This is "block addr" of registers!
       parameter OQ_REG_ADDR_WIDTH = `OQ_REG_ADDR_WIDTH,
       parameter NUM_OUTPUT_QUEUES = 8
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

      // Counters
      input [NUM_OUTPUT_QUEUES-1:0]	     pkts_stored,
      input [NUM_OUTPUT_QUEUES-1:0]	     pkts_dropped,
      input [NUM_OUTPUT_QUEUES-1:0]	     pkts_removed,
      input [NUM_OUTPUT_QUEUES-1:0]	     shortcut_words,
      input [NUM_OUTPUT_QUEUES-1:0]	     input_words,
      input [NUM_OUTPUT_QUEUES-1:0]	     output_words,
      input [NUM_OUTPUT_QUEUES-1:0]	     dram_wr_words,
      input [NUM_OUTPUT_QUEUES-1:0]	     dram_rd_words,

      // SW
      output [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     block_addr_lo,
      output [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     block_addr_hi,
      output [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]	shortcut_disable,
      output [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]	ctrl,

      // HW
      input  [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     rd_addr,
      input  [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     wr_addr,

      input                                  clk,
      input                                  reset
    );

   // ------------- Internal parameters --------------
   localparam UPDATE_WIDTH = 4;
   localparam NUM_REGS_CNTR = 8;
   localparam NUM_REGS_SW = 4;
   localparam NUM_REGS_HW = 3;

   // ------------- Wires/reg ------------------
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_block_addr_lo;
   wire [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_block_addr_hi;

   reg	[UPDATE_WIDTH-2:0]			   count;
   reg  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_shortcut_words;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_shortcut_words_next, update_shortcut_words;
   reg  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_dram_rd_words;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_dram_rd_words_next, update_dram_rd_words;
   reg  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_dram_wr_words;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_dram_wr_words_next, update_dram_wr_words;
   reg  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_input_words;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_input_words_next, update_input_words;
   reg 	[UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_output_words;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_output_words_next, update_output_words;
   reg  [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]     local_pkts_in_q;
   wire  [`CPCI_NF2_DATA_WIDTH * NUM_OUTPUT_QUEUES-1:0]    local_pkts_in_q_next;

   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     update_pkts_stored;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     update_pkts_dropped;
   wire  [UPDATE_WIDTH * NUM_OUTPUT_QUEUES-1:0]     update_pkts_removed;

   assign update_shortcut_words = (count == 0) ? local_shortcut_words : 0;
   assign update_dram_rd_words  = (count == 0) ? local_dram_rd_words : 0;
   assign update_dram_wr_words  = (count == 0) ? local_dram_wr_words : 0;
   assign update_input_words 	= (count == 0) ? local_input_words : 0;
   assign update_output_words 	= (count == 0) ? local_output_words : 0;

   // Default value for addr_hi and addr_lo
   generate
      genvar j;
      for(j=0; j<NUM_OUTPUT_QUEUES; j=j+1) begin:block_addr_default_value
   	assign block_addr_lo[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] = local_block_addr_lo[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] ? local_block_addr_lo[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] : j*1024;
   	assign block_addr_hi[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] = local_block_addr_hi[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] ? local_block_addr_hi[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] : (j+1)*1024 - 1;

   	assign update_pkts_stored[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 		= pkts_stored[j];
   	assign update_pkts_removed[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= pkts_removed[j];
   	assign update_pkts_dropped[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= pkts_dropped[j];

   	assign local_shortcut_words_next[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= (count == 0) ? shortcut_words[j] : local_shortcut_words[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] + shortcut_words[j];
   	assign local_input_words_next[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= (count == 0) ? input_words[j] : local_input_words[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] + input_words[j];
   	assign local_output_words_next[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= (count == 0) ? output_words[j] : local_output_words[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] + output_words[j];
   	assign local_dram_rd_words_next[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= (count == 0) ? dram_rd_words[j] : local_dram_rd_words[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] + dram_rd_words[j];
   	assign local_dram_wr_words_next[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] 	= (count == 0) ? dram_wr_words[j] : local_dram_wr_words[(j+1)*UPDATE_WIDTH-1:j*UPDATE_WIDTH] + dram_wr_words[j];

   	assign local_pkts_in_q_next[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] 	= local_pkts_in_q[(j+1)*`CPCI_NF2_DATA_WIDTH-1:j*`CPCI_NF2_DATA_WIDTH] + pkts_stored[j] - pkts_removed[j];
      end //block:block_addr_default_value
   endgenerate

   generic_regs
   #(
      .UDP_REG_SRC_WIDTH		(UDP_REG_SRC_WIDTH),                       // identifies which module started this request
      .TAG 				(OQ_BLOCK_ADDR),                       // Tag to match against
      .REG_ADDR_WIDTH			(OQ_REG_ADDR_WIDTH),                       // Width of block addresses
      .NUM_COUNTERS			(NUM_REGS_CNTR),                       // How many counters (per instance)
      .NUM_SOFTWARE_REGS		(NUM_REGS_SW),                       // How many sw regs (per instance)
      .NUM_HARDWARE_REGS		(NUM_REGS_HW),                       // How many hw regs (per instance)
      .NUM_INSTANCES			(NUM_OUTPUT_QUEUES),                       // Number of instances
      .COUNTER_INPUT_WIDTH		(UPDATE_WIDTH),                       // Width of each counter update request
      .MIN_UPDATE_INTERVAL		(8),                       // Clocks between successive counter inputs
      .COUNTER_WIDTH			(`CPCI_NF2_DATA_WIDTH),    // How wide should counters be?
      .RESET_ON_READ			(0),                       // Resets the counters when they are read
      .REG_START_ADDR			(0),                       // Address of the first counter
      .ACK_UNFOUND_ADDRESSES		(1),                       // If 1, then send an ack for req that have
                                                                   // this block's tag but not the rigt address
      .REVERSE_WORD_ORDER		(0)                       // Reverse order of registers in and out
   ) generic_regs
   (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // --- counters interface
      .counter_updates	({update_dram_rd_words, update_dram_wr_words, update_shortcut_words, update_output_words, update_input_words, update_pkts_removed,update_pkts_dropped,update_pkts_stored}),   // all the counter updates are concatenated
      .counter_decrement (64'b0), // if 1 then subtract the update, else add.

      // --- SW regs interface
      .software_regs	({shortcut_disable, local_block_addr_hi, local_block_addr_lo, ctrl}), // signals from the software

      // --- HW regs interface
      .hardware_regs	({local_pkts_in_q, rd_addr,wr_addr}), // signals from the hardware

      .clk		(clk),
      .reset		(reset)
    );

   always @(posedge clk) begin

      if(reset) begin
	 local_shortcut_words   <= 1024'b0;
	 local_input_words   	<= 1024'b0;
	 local_output_words   	<= 1024'b0;
	 local_dram_wr_words   	<= 1024'b0;
	 local_dram_rd_words   	<= 1024'b0;
	 local_pkts_in_q        <= 1024'b0;
	 count			<= 0;
      end
      else begin
         local_shortcut_words   <= local_shortcut_words_next;
	 local_input_words   	<= local_input_words_next;
	 local_output_words   	<= local_output_words_next;
	 local_dram_wr_words   	<= local_dram_wr_words_next;
	 local_dram_rd_words   	<= local_dram_rd_words_next;
	 local_pkts_in_q	<= local_pkts_in_q_next;
	 count			<= count + 1;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule
