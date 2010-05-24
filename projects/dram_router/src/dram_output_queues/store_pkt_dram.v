///////////////////////////////////////////////////////////////////////////////
//
// Module: store_pkt_dram.v
// Project: NF2.1
// Description: stores incoming packet into the DRAM,
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module store_pkt_dram
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2 * (DATA_WIDTH + CTRL_WIDTH),
      parameter DRAM_BLOCK_RDWR_ADDR_WIDTH = 3,
      parameter DRAM_BLOCK_SIZE	      = 128,//in 64bit words
      parameter DRAM_BASE_ADDR	      = 0,
      parameter DEFAULT_ADDR          = 0
   )
   (
     // --- Interface to the other cache
     output reg	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_wr_addr,
     input 	[DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_rd_addr,

     // --- Interface to DRAM
     output reg				dram_wr_req,
     output reg	[DRAM_ADDR_WIDTH-1:0]	dram_wr_ptr,
     output reg				dram_wr_data_vld,
     output reg	[DRAM_DATA_WIDTH-1:0]	dram_wr_data,
     input				dram_wr_ack,
     input				dram_wr_full,
     input				dram_wr_done,

     // --- Interface to the previous module
     input  [DATA_WIDTH-1:0]            in_data,
     input  [CTRL_WIDTH-1:0]            in_ctrl,
     output reg                       	in_rdy,
     input                              in_wr,

     output [8:0]			fifo_wr_data_count,
     output reg [DRAM_DATA_WIDTH-1:0]	fifo_din_out,
     output reg				fifo_wr_en_out,
     input				fifo_almost_full_in,
     input				remove_pkt_idle,

     input				odd_word,

     //	-- Interface to registers
     input [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  block_addr_hi,
     input [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  block_addr_lo,
     output [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0]  wr_addr,

     input				shortcut_disable,
     output				input_words,
     output reg				dram_wr_words,
     output reg				shortcut_words,
     output 				pkts_stored,
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

   parameter NUM_STORE_STATES                       = 5;
   parameter ST_WAIT_FOR_DATA                       = 5'd1;
   parameter ST_WAIT_FOR_ACK	                    = 5'd2;
   parameter ST_WRITE                               = 5'd4;
   parameter ST_WAIT_DRAM_NOT_FULL                  = 5'd8;
   parameter ST_REQ			            = 5'd16;
   parameter PKT_THRESHOLD			    = 120;

   parameter NUM_EOP_STATES                         = 5;
   parameter ST_WAIT_FOR_EOP                        = 5'd1;
   parameter ST_EOP		                    = 5'd2;
   parameter ST_DUMMY_WORD                          = 5'd4;
   parameter ST_IDLE	                            = 5'd8;

   //------------------------ Wires/regs --------------------------------
   reg [NUM_STORE_STATES-1:0]  store_state;
   reg [NUM_STORE_STATES-1:0]  store_state_next;

   reg [NUM_EOP_STATES-1:0]  eop_state;
   reg [NUM_EOP_STATES-1:0]  eop_state_next;

   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_wr_addr_next;
   wire [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] oq_wr_addr_plus_1;
   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] hi_addr;
   reg [DRAM_BLOCK_RDWR_ADDR_WIDTH-1:0] lo_addr;

   reg [DATA_WIDTH + CTRL_WIDTH - 1:0] fifo_din;
   reg                          fifo_wr_en;
   wire				fifo_almost_full;
   reg				fifo_rd_en;
   wire [DRAM_DATA_WIDTH-1:0]	fifo_dout;
   wire				fifo_empty;
   wire				fifo_full;
   wire [7:0]			fifo_rd_data_count;

   wire				fifo_rdy;
   wire				dram_rdy;
   wire				shortcut_rdy;
   reg              shortcut_disable_local;

   //-------------------------- Logic -----------------------------------
   // 1 BRAM FIFO that buffers up to 4KBytes
   async_72x512_fifo async_72x512_fifo(
	.din(fifo_din),
	.rd_clk(clk),
	.rd_en(fifo_rd_en),
	.rst(reset),
	.wr_clk(clk),
	.wr_en(fifo_wr_en),
	.almost_full(fifo_almost_full),
	.dout(fifo_dout),
	.empty(fifo_empty),
	.full(fifo_full),
	.rd_data_count(fifo_rd_data_count),
	.wr_data_count(fifo_wr_data_count)
   );

   // 2 State Machine that put the words into DRAM when BRAM FIFO has more than 2KBytes Words

   assign oq_wr_addr_plus_1 = (oq_wr_addr >= hi_addr) ? lo_addr : (oq_wr_addr + 1);
   assign dram_rdy = !((oq_wr_addr + 1 == oq_rd_addr) || ((oq_wr_addr == hi_addr) && (oq_rd_addr == lo_addr)));
   assign fifo_rdy = fifo_rd_data_count > PKT_THRESHOLD;

   assign input_words = fifo_wr_en;
   assign pkts_stored = (in_ctrl == 8'hff && in_wr);
   assign wr_addr     = oq_wr_addr;

   assign shortcut_rdy =  (!fifo_empty) && (!shortcut_disable_local) && (!fifo_almost_full_in) && ~|(oq_wr_addr ^ oq_rd_addr) && remove_pkt_idle;
   //assign in_rdy = !fifo_almost_full;



   always @(*) begin

      fifo_din                  = {in_ctrl,in_data};
      fifo_wr_en                = in_wr;

      eop_state_next 		= eop_state;
      in_rdy = !fifo_almost_full;

      case(eop_state)
	ST_IDLE: begin
	 if(odd_word) eop_state_next = ST_WAIT_FOR_EOP;
	end

	ST_WAIT_FOR_EOP: begin
	 if(in_ctrl != 8'hff && in_ctrl != 0 && in_wr) begin
		eop_state_next = ST_EOP;
		in_rdy = 0;
	 end
	end

	ST_EOP: begin
	 in_rdy = 0;
	 eop_state_next = ST_IDLE;
	 fifo_din = {8'h0f,64'h0};
	 fifo_wr_en = 1;
	end
      endcase

   end

   always @(*) begin
      dram_wr_words		= 0;

      store_state_next          = store_state;
      fifo_rd_en     		= 0;
      //if(oq_wr_addr < lo_addr)
	//oq_wr_addr_next 	= lo_addr;
      //else
	oq_wr_addr_next 	= oq_wr_addr;

      fifo_din_out		= fifo_dout;
      fifo_wr_en_out		= 0;
      shortcut_words		= 0;

      dram_wr_data_vld = 0;
      dram_wr_req = 0;
      dram_wr_data = fifo_dout;
      dram_wr_ptr = oq_wr_addr * DRAM_BLOCK_SIZE;

      case(store_state)
         ST_WAIT_FOR_DATA: begin
	     if(shortcut_rdy) begin   //shortcut!
		    fifo_wr_en_out = 1;
		    fifo_rd_en = 1;
		    shortcut_words = 1;
	     end
             else if(fifo_rdy && dram_rdy) begin // We have enough data
		    store_state_next = ST_REQ;
             end
         end //ST_WAIT_FOR_DATA

         ST_REQ: begin
	    dram_wr_req = 1;			 // Send out a request
	    if(dram_wr_ack) store_state_next = ST_WRITE;
         end //ST_REQ

         ST_WRITE: begin
 	    dram_wr_data_vld = 1;
	    fifo_rd_en = 1;
	    dram_wr_words = 1;
            if (dram_wr_full) begin
		store_state_next = ST_WAIT_DRAM_NOT_FULL;
	    end
	    if (dram_wr_done) begin
		store_state_next = ST_WAIT_FOR_DATA;
		oq_wr_addr_next = oq_wr_addr_plus_1;
	    end
         end //ST_WRITE

         ST_WAIT_DRAM_NOT_FULL: begin
            if (!dram_wr_full) begin
		store_state_next = ST_WRITE;
	    end
         end //ST_WAIT_DRAM_NOT_FULL

        default: begin end

      endcase // case(store_state)

   end // always @ (*)

   always @(posedge clk) begin

      if(reset) begin
         store_state                      	<= ST_WAIT_FOR_DATA;
         eop_state                      	<= ST_IDLE;
	     oq_wr_addr				<= DEFAULT_ADDR;
      end
      else begin
         hi_addr <= block_addr_hi;
         lo_addr <= block_addr_lo;
         eop_state       <= eop_state_next;
         store_state     <= store_state_next;
         shortcut_disable_local <= shortcut_disable;

	 if(ctrl[`OQ_CONTROL_INITIALIZE_OQ_POS]) begin
		//store_state     <= ST_WAIT_FOR_DATA;
		oq_wr_addr	<= lo_addr;
	 end
	 else begin
		oq_wr_addr	<= oq_wr_addr_next;

	 end
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // store_pkt
