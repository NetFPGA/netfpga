///////////////////////////////////////////////////////////////////////////////
//
// Module: dram_queue.v
// Project: NF2.1
// Author: hyzeng
// Description: stores incoming packets into the DRAM
//
///////////////////////////////////////////////////////////////////////////////

  module dram_queue
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2 * (DATA_WIDTH + CTRL_WIDTH),
      parameter DRAM_BASE_ADDR = 0,
      parameter DRAM_BLOCK_ADDR_WIDTH = 5,
      parameter DRAM_BLOCK_SIZE	      = 128)
   (// --- data path interface
    output     [DATA_WIDTH-1:0]        out_data,
    output     [CTRL_WIDTH-1:0]        out_ctrl,
    input                              out_rdy,
    output                             out_wr,

    // --- Interface to the previous module
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    output                             in_rdy,
    input                              in_wr,

    // --- DRAM sm interface
     output				dram_wr_req,
     output [DRAM_ADDR_WIDTH-1:0]	dram_wr_ptr,
     output				dram_wr_data_vld,
     output [DRAM_DATA_WIDTH-1:0]	dram_wr_data,
     input				dram_wr_ack,
     input				dram_wr_full,
     input				dram_wr_done,

     output				dram_rd_req,
     output [DRAM_ADDR_WIDTH-1:0]	dram_rd_ptr,
     output				dram_rd_en,
     input [DRAM_DATA_WIDTH-1:0]	dram_rd_data,
     input				dram_rd_ack,
     input				dram_rd_done,
     input				dram_rd_rdy,

     input				dram_sm_idle,

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

    // --- Misc
    input                              clk,
    input                              reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //--------------- Regs/Wires ----------------------
   wire	[DRAM_BLOCK_ADDR_WIDTH-1:0]	oq_wr_addr;
   wire	[DRAM_BLOCK_ADDR_WIDTH-1:0]	oq_rd_addr;

   wire [DRAM_DATA_WIDTH-1:0]	fifo_din;
   wire				fifo_wr_en;
   wire				fifo_almost_full;
   wire				remove_pkt_idle;

   wire				shortcut_disable;
   wire [DRAM_BLOCK_ADDR_WIDTH-1:0]			block_num;
   wire				input_words;
   wire				output_words;
   wire				dram_wr_words;
   wire				dram_rd_words;
   wire				shortcut_words;

   //---------------- Modules ------------------------

   store_pkt_dram
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .DRAM_ADDR_WIDTH(DRAM_ADDR_WIDTH),
       .DRAM_DATA_WIDTH(DRAM_DATA_WIDTH),
       .DRAM_BASE_ADDR(DRAM_BASE_ADDR),
       .DRAM_BLOCK_ADDR_WIDTH(DRAM_BLOCK_ADDR_WIDTH),
       .DRAM_BLOCK_SIZE(DRAM_BLOCK_SIZE)
)
   store_pkt_dram
     (
           .oq_wr_addr 		(oq_wr_addr),
           .oq_rd_addr 		(oq_rd_addr),

     	// --- DRAM sm interface
     	.dram_wr_req		(dram_wr_req),
     	.dram_wr_ptr		(dram_wr_ptr),
     	.dram_wr_data_vld	(dram_wr_data_vld),
     	.dram_wr_data		(dram_wr_data),
     	.dram_wr_ack		(dram_wr_ack),
     	.dram_wr_full		(dram_wr_full),
     	.dram_wr_done		(dram_wr_done),

      	// --- Interface to the previous module
    	.in_data          	(in_data),
    	.in_ctrl          	(in_ctrl),
    	.in_rdy           	(in_rdy),
    	.in_wr            	(in_wr),

      // --- Interface to remove_pkt
	.fifo_din_out (fifo_din),
	.fifo_wr_en_out (fifo_wr_en),
	.fifo_almost_full_in (fifo_almost_full),
	.remove_pkt_idle (remove_pkt_idle),

      // -- Interface to registers
        .shortcut_disable	(shortcut_disable),
        .input_words		(input_words),
      	.dram_wr_words		(dram_wr_words),
      	.shortcut_words		(shortcut_words),
        .block_num	        (block_num),

           // --- misc
           .clk (clk),
           .reset (reset));

   remove_pkt_dram
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .DRAM_ADDR_WIDTH(DRAM_ADDR_WIDTH),
       .DRAM_DATA_WIDTH(DRAM_DATA_WIDTH),
       .DRAM_BASE_ADDR(DRAM_BASE_ADDR),
       .DRAM_BLOCK_ADDR_WIDTH(DRAM_BLOCK_ADDR_WIDTH),
       .DRAM_BLOCK_SIZE(DRAM_BLOCK_SIZE)
)
   remove_pkt_dram
     (// --- Interface to DRAM

	.dram_rd_req	(dram_rd_req),
	.dram_rd_ptr	(dram_rd_ptr),
	.dram_rd_en	(dram_rd_en),
	.dram_rd_data	(dram_rd_data),
	.dram_rd_ack	(dram_rd_ack),
	.dram_rd_done	(dram_rd_done),
	.dram_rd_rdy	(dram_rd_rdy),

	.oq_wr_addr 		(oq_wr_addr),
	.oq_rd_addr 		(oq_rd_addr),

      // --- Interface to datapath
	.out_data (out_data),
	.out_ctrl (out_ctrl),
	.out_wr (out_wr),
	.out_rdy (out_rdy),

      // --- Interface to store_pkt
	.fifo_din_in (fifo_din),
	.fifo_wr_en_in (fifo_wr_en),
	.fifo_almost_full_out (fifo_almost_full),
	.remove_pkt_idle (remove_pkt_idle),

      // -- Interface to registers
        .output_words		(output_words),
      	.dram_rd_words		(dram_rd_words),
        .block_num		(block_num),

      // --- Misc
      .clk (clk),
      .reset (reset));

   dram_queue_regs
   #(
      .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
      .DRAM_BLOCK_ADDR_WIDTH(DRAM_BLOCK_ADDR_WIDTH)
   ) dram_queue_regs
   (// --- register interface
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

      .shortcut_disable	(shortcut_disable),
      .block_num	(block_num),
      .input_words	(input_words),
      .output_words	(output_words),
      .dram_wr_words	(dram_wr_words),
      .dram_rd_words	(dram_rd_words),
      .shortcut_words	(shortcut_words),

      // --- misc
      .clk                           (clk),
      .reset                         (reset)
     );
endmodule // output_queues




