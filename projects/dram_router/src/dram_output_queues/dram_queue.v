///////////////////////////////////////////////////////////////////////////////
//
// Module: dram_queue.v
// Project: NF2.1
// Description: stores incoming packets into the DRAM
//
///////////////////////////////////////////////////////////////////////////////

  module dram_queue
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2 * (DATA_WIDTH + CTRL_WIDTH),
      parameter DRAM_BLOCK_RDWR_ADDR_WIDTH = `DRAM_BLOCK_RDWR_ADDR_WIDTH,
      parameter DRAM_BLOCK_SIZE = 150,
      parameter DEFAULT_ADDR          = 0
)
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
    input			       odd_word,

    // -- For Multicast
    output [8:0]			fifo_wr_data_count,
    input				pkts_dropped,

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

     //Registers
     output				pkts_stored,
     output				pkts_removed,

     input				shortcut_disable,
     output				input_words,
     output				output_words,
     output				dram_wr_words,
     output				dram_rd_words,
     output				shortcut_words,

     input  [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	block_addr_lo,
     input  [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	block_addr_hi,
     output [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	rd_addr,
     output [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	wr_addr,

     input [1:0]				ctrl,

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
   wire	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	oq_wr_addr;
   wire	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]	oq_rd_addr;

   wire [DRAM_DATA_WIDTH-1:0]	fifo_din;
   wire				fifo_wr_en;
   wire				fifo_almost_full;
   wire				remove_pkt_idle;


   //---------------- Modules ------------------------

   store_pkt_dram
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .DRAM_ADDR_WIDTH(DRAM_ADDR_WIDTH),
       .DRAM_DATA_WIDTH(DRAM_DATA_WIDTH),
       .DRAM_BLOCK_SIZE(DRAM_BLOCK_SIZE),
       .DRAM_BLOCK_RDWR_ADDR_WIDTH(DRAM_BLOCK_RDWR_ADDR_WIDTH),
       .DEFAULT_ADDR(DEFAULT_ADDR)
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
	.odd_word		(odd_word),

        // --- Interface to remove_pkt
	.fifo_din_out 		(fifo_din),
	.fifo_wr_en_out 	(fifo_wr_en),
	.fifo_almost_full_in 	(fifo_almost_full),
	.remove_pkt_idle 	(remove_pkt_idle),

        // -- For Multicast
        .fifo_wr_data_count	(fifo_wr_data_count),

        // -- Interface to registers
        .shortcut_disable	(shortcut_disable),
        .input_words		(input_words),
      	.dram_wr_words		(dram_wr_words),
      	.shortcut_words		(shortcut_words),
        .block_addr_lo		(block_addr_lo),
        .block_addr_hi		(block_addr_hi),
	.pkts_stored		(pkts_stored),
        .wr_addr		(wr_addr),
        .ctrl			(ctrl),

        // --- misc
        .clk (clk),
        .reset (reset)
   );

   remove_pkt_dram
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .DRAM_ADDR_WIDTH(DRAM_ADDR_WIDTH),
       .DRAM_DATA_WIDTH(DRAM_DATA_WIDTH),
       .DRAM_BLOCK_SIZE(DRAM_BLOCK_SIZE),
       .DRAM_BLOCK_RDWR_ADDR_WIDTH(DRAM_BLOCK_RDWR_ADDR_WIDTH),
       .DEFAULT_ADDR(DEFAULT_ADDR)
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
        .block_addr_lo		(block_addr_lo),
        .block_addr_hi		(block_addr_hi),
	.pkts_removed		(pkts_removed),
        .rd_addr		(rd_addr),
        .ctrl			(ctrl),

      // --- Misc
        .clk (clk),
        .reset (reset)
   );

endmodule // output_queues




