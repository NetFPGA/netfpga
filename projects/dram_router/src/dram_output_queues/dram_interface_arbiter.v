`timescale 1ns/1ps
  module dram_interface_arbiter
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter DRAM_ADDR_WIDTH = 22,
      parameter DRAM_DATA_WIDTH = 2 * (DATA_WIDTH + CTRL_WIDTH),
      parameter DRAM_BLOCK_ADDR_WIDTH = 3,
      parameter DRAM_BLOCK_SIZE	      = 128,
      parameter DRAM_BASE_ADDR	      = 0,
      parameter PKT_LEN_WIDTH = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter OQ_STAGE_NUM = 6,
      parameter NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES))

   (

     // --- Interface to DRAM
     output				dram_wr_req,
     output	[DRAM_ADDR_WIDTH-1:0]	dram_wr_ptr,
     output				dram_wr_data_vld,
     output	[DRAM_DATA_WIDTH-1:0]	dram_wr_data,
     input				dram_wr_ack,
     input				dram_wr_full,
     input				dram_wr_done,

     // --- Interface to DRAM
     output				dram_rd_req,
     output	[DRAM_ADDR_WIDTH-1:0]	dram_rd_ptr,
     output				dram_rd_en,
     input 	[DRAM_DATA_WIDTH-1:0]	dram_rd_data,
     input				dram_rd_ack,
     input				dram_rd_rdy,
     input				dram_rd_done,

     // --- Interface to dram_queue
     input	[NUM_OUTPUT_QUEUES-1:0]	dram_wr_req_in,
     input 	[NUM_OUTPUT_QUEUES * DRAM_ADDR_WIDTH - 1:0]	dram_wr_ptr_in,
     input	[NUM_OUTPUT_QUEUES-1:0] dram_wr_data_vld_in,
     input	[NUM_OUTPUT_QUEUES * DRAM_DATA_WIDTH - 1:0]	dram_wr_data_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_wr_ack_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_wr_full_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_wr_done_in,

     // --- Interface to dram_queue
     input	[NUM_OUTPUT_QUEUES-1:0]	dram_rd_req_in,
     input 	[NUM_OUTPUT_QUEUES * DRAM_ADDR_WIDTH - 1:0]	dram_rd_ptr_in,
     input	[NUM_OUTPUT_QUEUES-1:0] dram_rd_en_in,
     output reg	[NUM_OUTPUT_QUEUES * DRAM_DATA_WIDTH - 1:0]	dram_rd_data_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_rd_ack_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_rd_rdy_in,
     output reg	[NUM_OUTPUT_QUEUES-1:0] dram_rd_done_in,

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

   parameter NUM_STATES                       	    = 2;
   parameter ST_WAIT_REQ	                    = 1;
   parameter ST_WAIT_DONE                           = 2;

   //------------------------ Wires/regs --------------------------------
   reg [NUM_STATES-1:0]  store_state;
   reg [NUM_STATES-1:0]  store_state_next;

   reg [NUM_STATES-1:0]  remove_state;
   reg [NUM_STATES-1:0]  remove_state_next;

   reg [NUM_OQ_WIDTH-1:0]	oq_wr;
   reg [NUM_OQ_WIDTH-1:0]	oq_wr_next;

   reg [NUM_OQ_WIDTH-1:0]	oq_rd;
   reg [NUM_OQ_WIDTH-1:0]	oq_rd_next;

   wire				local_dram_wr_req;
   reg	[DRAM_ADDR_WIDTH-1:0]	local_dram_wr_ptr;
   wire				local_dram_wr_data_vld;
   reg	[DRAM_DATA_WIDTH-1:0]	local_dram_wr_data;

   wire				local_dram_rd_req;
   reg	 [DRAM_ADDR_WIDTH-1:0]	local_dram_rd_ptr;
   wire				local_dram_rd_en;

   //-------------------------- Logic -----------------------------------
   assign local_dram_wr_req = dram_wr_req_in[oq_wr];
   assign local_dram_wr_data_vld = dram_wr_data_vld_in[oq_wr];
   assign local_dram_rd_req = dram_rd_req_in[oq_rd];
   assign local_dram_rd_en = dram_rd_en_in[oq_rd];

   always @(*) begin
      case(oq_wr)
	0: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*1-1:DRAM_DATA_WIDTH*0];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*1-1:DRAM_ADDR_WIDTH*0];
	end
	1: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*2-1:DRAM_DATA_WIDTH*1];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*2-1:DRAM_ADDR_WIDTH*1];
	end
	2: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*3-1:DRAM_DATA_WIDTH*2];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*3-1:DRAM_ADDR_WIDTH*2];
	end
	3: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*4-1:DRAM_DATA_WIDTH*3];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*4-1:DRAM_ADDR_WIDTH*3];
	end
	4: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*5-1:DRAM_DATA_WIDTH*4];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*5-1:DRAM_ADDR_WIDTH*4];
	end
	5: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*6-1:DRAM_DATA_WIDTH*5];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*6-1:DRAM_ADDR_WIDTH*5];
	end
	6: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*7-1:DRAM_DATA_WIDTH*6];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*7-1:DRAM_ADDR_WIDTH*6];
	end
	default: begin
		local_dram_wr_data = dram_wr_data_in[DRAM_DATA_WIDTH*8-1:DRAM_DATA_WIDTH*7];
		local_dram_wr_ptr  = dram_wr_ptr_in[DRAM_ADDR_WIDTH*8-1:DRAM_ADDR_WIDTH*7];
	end
     endcase
   end

   always @(*) begin
      case(oq_rd)
	0: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*1-1:DRAM_ADDR_WIDTH*0];
	end
	1: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*2-1:DRAM_ADDR_WIDTH*1];
	end
	2: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*3-1:DRAM_ADDR_WIDTH*2];
	end
	3: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*4-1:DRAM_ADDR_WIDTH*3];
	end
	4: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*5-1:DRAM_ADDR_WIDTH*4];
	end
	5: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*6-1:DRAM_ADDR_WIDTH*5];
	end
	6: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*7-1:DRAM_ADDR_WIDTH*6];
	end
	default: begin
		local_dram_rd_ptr  = dram_rd_ptr_in[DRAM_ADDR_WIDTH*8-1:DRAM_ADDR_WIDTH*7];
	end
     endcase
   end

   assign dram_wr_req = local_dram_wr_req;
   assign dram_wr_ptr = local_dram_wr_ptr;
   assign dram_wr_data = local_dram_wr_data;
   assign dram_wr_data_vld = local_dram_wr_data_vld;

   always @(*) begin
      dram_wr_done_in = 0;
      dram_wr_ack_in = 0;
      dram_wr_full_in = 0;

      oq_wr_next = oq_wr;
      store_state_next = store_state;

      case(store_state)
         /* wait until we have a destination port */
         ST_WAIT_REQ: begin
	   if(dram_wr_req == 1) begin
		store_state_next = ST_WAIT_DONE;
           end
	   else oq_wr_next = oq_wr + 1;//should wrap over when oq_wr == 7
         end

        ST_WAIT_DONE: begin
	   if(dram_wr_done == 1) begin
		store_state_next = ST_WAIT_REQ;
		oq_wr_next = oq_wr + 1;
	   end
        end // case: ST_WAIT_DONE

        default: begin end

      endcase // case(store_state)
      dram_wr_done_in[oq_wr] = dram_wr_done;
      dram_wr_ack_in[oq_wr] = dram_wr_ack;
      dram_wr_full_in[oq_wr] = dram_wr_full;
   end // always @ (*)

   assign dram_rd_req = local_dram_rd_req;
   assign dram_rd_ptr = local_dram_rd_ptr;
   assign dram_rd_en = local_dram_rd_en;

   always @(*) begin
      dram_rd_done_in = 0;
      dram_rd_ack_in = 0;
      dram_rd_rdy_in = 0;
      dram_rd_data_in = 0;

      oq_rd_next = oq_rd;
      remove_state_next = remove_state;

      case(remove_state)
         /* wait until we have a destination port */
         ST_WAIT_REQ: begin
	   if(dram_rd_req == 1) begin
	      remove_state_next = ST_WAIT_DONE;
	   end
	   else oq_rd_next = oq_rd + 1;//should wrap over when oq_wr == 7
         end

        ST_WAIT_DONE: begin
	   if(dram_rd_done == 1) begin
		remove_state_next = ST_WAIT_REQ;
		oq_rd_next = oq_rd + 1;
	   end
        end // case: ST_WAIT_DONE

        default: begin end

      endcase // case(store_state)

      dram_rd_done_in[oq_rd] = dram_rd_done;
      dram_rd_ack_in[oq_rd] = dram_rd_ack;
      dram_rd_rdy_in[oq_rd] = dram_rd_rdy;
      if(oq_rd == 0) dram_rd_data_in[DRAM_DATA_WIDTH * 1-1:DRAM_DATA_WIDTH * 0] = dram_rd_data;
      if(oq_rd == 1) dram_rd_data_in[DRAM_DATA_WIDTH * 2-1:DRAM_DATA_WIDTH * 1] = dram_rd_data;
      if(oq_rd == 2) dram_rd_data_in[DRAM_DATA_WIDTH * 3-1:DRAM_DATA_WIDTH * 2] = dram_rd_data;
      if(oq_rd == 3) dram_rd_data_in[DRAM_DATA_WIDTH * 4-1:DRAM_DATA_WIDTH * 3] = dram_rd_data;
      if(oq_rd == 4) dram_rd_data_in[DRAM_DATA_WIDTH * 5-1:DRAM_DATA_WIDTH * 4] = dram_rd_data;
      if(oq_rd == 5) dram_rd_data_in[DRAM_DATA_WIDTH * 6-1:DRAM_DATA_WIDTH * 5] = dram_rd_data;
      if(oq_rd == 6) dram_rd_data_in[DRAM_DATA_WIDTH * 7-1:DRAM_DATA_WIDTH * 6] = dram_rd_data;
      if(oq_rd == 7) dram_rd_data_in[DRAM_DATA_WIDTH * 8-1:DRAM_DATA_WIDTH * 7] = dram_rd_data;

   end // always @ (*)


   always @(posedge clk) begin

      if(reset) begin
         store_state                      <= ST_WAIT_REQ;
         remove_state                      <= ST_WAIT_REQ;
	 oq_rd				  <= 0;
	 oq_wr				  <= 0;
      end
      else begin
         store_state     <= store_state_next;
         remove_state    <= remove_state_next;
         oq_rd           <= oq_rd_next;
         oq_wr           <= oq_wr_next;
      end // else: !if(reset)
   end // always @ (posedge clk)
endmodule
