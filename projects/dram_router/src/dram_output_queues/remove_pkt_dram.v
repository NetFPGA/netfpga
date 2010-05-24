///////////////////////////////////////////////////////////////////////////////
//
// Module: remove_pkt_dram.v
// Project: NF2.1
// Description: stores incoming packet into the DRAM
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module remove_pkt_dram
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2 * (DATA_WIDTH + CTRL_WIDTH),
      parameter DRAM_BLOCK_RDWR_ADDR_WIDTH = 3,
      parameter DRAM_BLOCK_SIZE	      = 128,//in 64bit words
      parameter DRAM_BASE_ADDR = 0,
      parameter DEFAULT_ADDR          = 0
   )
   (
     // --- Interface to the other cache
     output reg	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_rd_addr,
     input 	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_wr_addr,

     // --- Interface to DRAM
     output reg				dram_rd_req,
     output reg [DRAM_ADDR_WIDTH-1:0]	dram_rd_ptr,
     output reg				dram_rd_en,
     input [DRAM_DATA_WIDTH-1:0]	dram_rd_data,
     input				dram_rd_ack,
     input				dram_rd_rdy,
     input				dram_rd_done,

     output  [DATA_WIDTH-1:0]           out_data,
     output  [CTRL_WIDTH-1:0]           out_ctrl,
     output                             out_wr,
     input                              out_rdy,

     input [DRAM_DATA_WIDTH-1:0]	fifo_din_in,
     input				fifo_wr_en_in,
     output				fifo_almost_full_out,
     output reg				remove_pkt_idle,

     //	-- Interface to registers
     output 				output_words,
     output reg				dram_rd_words,
     input [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  block_addr_hi,
     input [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  block_addr_lo,
     output [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  rd_addr,
     output				pkts_removed,
     input [1:0]			ctrl,

     // --- misc
     input                            clk,
     input                            reset
     );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //--------------------- Internal parameters --------------------------

   parameter NUM_REMOVE_STATES                       = 5;
   parameter ST_WAIT_FOR_DATA                       = 5'd1;
   parameter ST_WAIT_FOR_ACK	                    = 5'd2;
   parameter ST_REQ     	                    = 5'd4;
   parameter ST_READ     	                    = 5'd8;
   parameter ST_DONE	 	                    = 5'd16;
   parameter PKT_THRESHOLD			    = 100;

   //------------------------ Wires/regs --------------------------------
   reg [NUM_REMOVE_STATES-1:0]  remove_state;
   reg [NUM_REMOVE_STATES-1:0]  remove_state_next;
   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_rd_addr_next;
   wire [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_rd_addr_plus_1;
   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] hi_addr;
   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] lo_addr;

   wire				fifo_almost_full;
   reg				fifo_wr_en;
   reg [DRAM_DATA_WIDTH-1:0]	fifo_din;
   wire				fifo_empty;
   wire				fifo_full;
   wire [7:0]			fifo_wr_data_count;
   wire [8:0]			fifo_rd_data_count;

   wire				fifo_rdy;
   wire				dram_rdy;

   //-------------------------- Logic -----------------------------------
   // 1 BRAM FIFO that buffers up to 4KBytes
   async_144x256_fifo async_144x256_fifo(
	.din(fifo_din),
	.rd_clk(clk),
	.rd_en(fifo_rd_en),
	.rst(reset),
	.wr_clk(clk),
	.wr_en(fifo_wr_en),
	.almost_full(fifo_almost_full),
	.dout({out_ctrl, out_data}),
	.empty(fifo_empty),
	.full(fifo_full),
	.rd_data_count(fifo_rd_data_count),
	.wr_data_count(fifo_wr_data_count)
   );

   assign fifo_rd_en = out_rdy && !fifo_empty && !ctrl[`OQ_CONTROL_DISABLE_SEND_POS];
   assign out_wr = fifo_rd_en && (out_ctrl != 8'h0f);
   assign fifo_almost_full_out = fifo_almost_full;

   assign output_words = fifo_rd_en;

   assign rd_addr     = oq_rd_addr;

   // 2 State Machine that put the words into DRAM when BRAM FIFO has more than 2KBytes Words
   assign oq_rd_addr_plus_1 = (oq_rd_addr >= hi_addr) ? lo_addr : (oq_rd_addr + 1);
   assign dram_rdy = (oq_rd_addr != oq_wr_addr);
   assign fifo_rdy = fifo_wr_data_count < PKT_THRESHOLD;
   assign pkts_removed = (out_ctrl == 8'hff && out_wr);


   always @(*) begin
      dram_rd_words		= 0;

      remove_state_next         = remove_state;
      fifo_wr_en     		= 0;
      remove_pkt_idle 		= 0;
      //if(oq_rd_addr < lo_addr)
	//oq_rd_addr_next 	= lo_addr;
      //else
	oq_rd_addr_next 	= oq_rd_addr;

      dram_rd_en = 0;
      dram_rd_req = 0;
      dram_rd_ptr = oq_rd_addr * DRAM_BLOCK_SIZE;
      fifo_din = dram_rd_data;

      case(remove_state)
         ST_WAIT_FOR_DATA: begin
	    // For shortcut, connected to store_pkt
	    remove_pkt_idle = 1;
	    fifo_wr_en = fifo_wr_en_in;
	    fifo_din = fifo_din_in;
            ////////////////////////////////////////
            if(fifo_rdy && dram_rdy) begin // We have enough data
		remove_state_next = ST_REQ;
            end
         end //ST_WAIT_FOR_DATA

         ST_REQ: begin
	    dram_rd_req = 1;			 // Send out a request
	    if(dram_rd_ack) remove_state_next = ST_READ;
         end //ST_REQ

         ST_WAIT_FOR_ACK: begin
            if(dram_rd_ack) begin
		remove_state_next = ST_READ;
            end
         end //ST_WAIT_FOR_ACK

         ST_READ: begin
   		dram_rd_en = dram_rd_rdy;
	    	fifo_wr_en = dram_rd_rdy;
		dram_rd_words = dram_rd_rdy;
	    	fifo_din = dram_rd_data;
	    	if (dram_rd_done) begin
			remove_state_next = ST_DONE;
	    	end
         end //ST_READ

         ST_DONE: begin
   		dram_rd_en = dram_rd_rdy;
	    	fifo_wr_en = dram_rd_rdy;
	    	fifo_din = dram_rd_data;
		remove_state_next = ST_WAIT_FOR_DATA;
		oq_rd_addr_next = oq_rd_addr_plus_1;
         end //ST_DONE

        default: begin end

      endcase // case(remove_state)

   end // always @ (*)

   always @(posedge clk) begin

      if(reset) begin
         remove_state                      	<= ST_WAIT_FOR_DATA;
	 oq_rd_addr				<= DEFAULT_ADDR;
      end
      else begin
        hi_addr <= block_addr_hi;
        lo_addr <= block_addr_lo;
        remove_state            	<= remove_state_next;
	 if(ctrl[`OQ_CONTROL_INITIALIZE_OQ_POS]) begin
		//remove_state                    <= ST_WAIT_FOR_DATA;
		oq_rd_addr			<= lo_addr;
	 end
	 else begin
		oq_rd_addr			<= oq_rd_addr_next;

	 end
      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // store_pkt
