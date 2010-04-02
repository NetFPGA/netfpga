///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: store_pkt.v 4020 2008-06-10 21:58:23Z grg $
//
// Module: store_pkt.v
// Project: NF2.1
// Description: stores incoming packet into the SRAM, sends new wr addres to regs
//
// Note: Assumes that the length header is FIRST!
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module dram_queue_arbiter
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter PKT_LEN_WIDTH = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter OQ_STAGE_NUM = 6,
      parameter NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES))

   ( // --- Interface to header_parser
     input                            dst_oq_avail,
     input      [NUM_OUTPUT_QUEUES-1:0]    parsed_dst_oq,
     input      [PKT_LEN_WIDTH-1:0]   parsed_pkt_byte_len,
     input      [PKT_WORDS_WIDTH-1:0] parsed_pkt_word_len,
     input                            header_parser_rdy,
     output reg                       rd_dst_oq,

     // --- Interface to registers
     output reg	[NUM_OUTPUT_QUEUES-1:0]    pkts_dropped,

     // --- Interface to input fifo
     output reg                       input_fifo_rd_en,
     input                            input_fifo_empty,
     input      [DATA_WIDTH-1:0]      input_fifo_data_out,
     input      [CTRL_WIDTH-1:0]      input_fifo_ctrl_out,

    input [NUM_OUTPUT_QUEUES*9-1:0]     fifo_wr_data_count,

    output reg [NUM_OUTPUT_QUEUES-1:0]     odd_word,

    output     [DATA_WIDTH-1:0]        out_data_0,
    output    [CTRL_WIDTH-1:0]        out_ctrl_0,
    input                              out_rdy_0,
    output                            out_wr_0,

    output     [DATA_WIDTH-1:0]        out_data_1,
    output     [CTRL_WIDTH-1:0]        out_ctrl_1,
    input                              out_rdy_1,
    output                             out_wr_1,

    output     [DATA_WIDTH-1:0]        out_data_2,
    output     [CTRL_WIDTH-1:0]        out_ctrl_2,
    input                              out_rdy_2,
    output                             out_wr_2,

    output     [DATA_WIDTH-1:0]        out_data_3,
    output     [CTRL_WIDTH-1:0]        out_ctrl_3,
    input                              out_rdy_3,
    output                             out_wr_3,

    output     [DATA_WIDTH-1:0]        out_data_4,
    output     [CTRL_WIDTH-1:0]        out_ctrl_4,
    input                              out_rdy_4,
    output                             out_wr_4,

    output  [DATA_WIDTH-1:0]           out_data_5,
    output  [CTRL_WIDTH-1:0]           out_ctrl_5,
    output                             out_wr_5,
    input                              out_rdy_5,

    output  [DATA_WIDTH-1:0]           out_data_6,
    output  [CTRL_WIDTH-1:0]           out_ctrl_6,
    output                             out_wr_6,
    input                              out_rdy_6,

    output  [DATA_WIDTH-1:0]           out_data_7,
    output  [CTRL_WIDTH-1:0]           out_ctrl_7,
    output                             out_wr_7,
    input                              out_rdy_7,

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

   parameter NUM_STORE_STATES                       = 2;
   parameter ST_WAIT_DST_PORT                       = 1;
   parameter ST_WAIT_EOP                            = 2;
   parameter FIFO_RDY_THRESHOLD			    = 500;//in 72bit word

   //------------------------ Wires/regs --------------------------------
   reg [NUM_STORE_STATES-1:0]  store_state;
   reg [NUM_STORE_STATES-1:0]  store_state_next;

   reg [NUM_OUTPUT_QUEUES-1:0]      dst_oq;
   reg [NUM_OUTPUT_QUEUES-1:0]      dst_oq_next;

   reg [PKT_LEN_WIDTH-1:0]     pkt_byte_len;
   reg [PKT_LEN_WIDTH-1:0]     pkt_byte_len_next;

   reg [PKT_WORDS_WIDTH-1:0]   pkt_word_len;
   reg [PKT_WORDS_WIDTH-1:0]   pkt_word_len_next;

   reg [NUM_OUTPUT_QUEUES-1:0]                       out_wr;

   reg [NUM_OUTPUT_QUEUES-1:0]      output_fifo_rdy, output_fifo_rdy_next;

   //-------------------------- Logic -----------------------------------
   assign out_wr_0 = out_wr[0];
   assign out_wr_1 = out_wr[1];
   assign out_wr_2 = out_wr[2];
   assign out_wr_3 = out_wr[3];
   assign out_wr_4 = out_wr[4];
   assign out_wr_5 = out_wr[5];
   assign out_wr_6 = out_wr[6];
   assign out_wr_7 = out_wr[7];

   assign out_ctrl_0 = input_fifo_ctrl_out;
   assign out_ctrl_1 = input_fifo_ctrl_out;
   assign out_ctrl_2 = input_fifo_ctrl_out;
   assign out_ctrl_3 = input_fifo_ctrl_out;
   assign out_ctrl_4 = input_fifo_ctrl_out;
   assign out_ctrl_5 = input_fifo_ctrl_out;
   assign out_ctrl_6 = input_fifo_ctrl_out;
   assign out_ctrl_7 = input_fifo_ctrl_out;

   assign out_data_0 = input_fifo_data_out;
   assign out_data_1 = input_fifo_data_out;
   assign out_data_2 = input_fifo_data_out;
   assign out_data_3 = input_fifo_data_out;
   assign out_data_4 = input_fifo_data_out;
   assign out_data_5 = input_fifo_data_out;
   assign out_data_6 = input_fifo_data_out;
   assign out_data_7 = input_fifo_data_out;

   /*******************************************************
    * wait until the dst port fifo has a destination
    * then read the dst port, load the addresses to use,
    * and start moving data from the input fifo to the
    * sram queues. When the eop is reached, write the pkt
    * length in the beginning of the pkt
    * If the oq is full then drop pkt.
    * Also generate pkt_stored and pkt_dropped signals
    *******************************************************/

   always @(*) begin
      out_wr = 0;
      input_fifo_rd_en = 0;
      rd_dst_oq = 0;
      dst_oq_next = dst_oq;
      store_state_next = store_state;
      pkt_byte_len_next = pkt_byte_len;
      pkt_word_len_next = pkt_word_len;
      output_fifo_rdy_next = output_fifo_rdy;
      odd_word = 0;
      pkts_dropped = 0;

      case(store_state)
         /* wait until we have a destination port */
         ST_WAIT_DST_PORT: begin
	    output_fifo_rdy_next[0] = out_rdy_0 && (fifo_wr_data_count[(0+1)*9-1:0*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[1] = out_rdy_1 && (fifo_wr_data_count[(1+1)*9-1:1*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[2] = out_rdy_2 && (fifo_wr_data_count[(2+1)*9-1:2*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[3] = out_rdy_3 && (fifo_wr_data_count[(3+1)*9-1:3*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[4] = out_rdy_4 && (fifo_wr_data_count[(4+1)*9-1:4*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
            output_fifo_rdy_next[5] = out_rdy_5 && (fifo_wr_data_count[(5+1)*9-1:5*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[6] = out_rdy_6 && (fifo_wr_data_count[(6+1)*9-1:6*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);
	    output_fifo_rdy_next[7] = out_rdy_7 && (fifo_wr_data_count[(7+1)*9-1:7*9] + parsed_pkt_word_len < FIFO_RDY_THRESHOLD);

            if(dst_oq_avail) begin
               store_state_next = ST_WAIT_EOP;
               dst_oq_next = parsed_dst_oq;
	       pkt_byte_len_next = parsed_pkt_byte_len;
	       pkt_word_len_next = parsed_pkt_word_len;
            end
         end

        ST_WAIT_EOP: begin
	   if (!pkt_word_len[0])
		odd_word = dst_oq;
           if(!input_fifo_empty) begin
                out_wr = dst_oq & output_fifo_rdy;
                input_fifo_rd_en = 1;
           	if(input_fifo_ctrl_out != 8'hff && input_fifo_ctrl_out != 0) begin
			store_state_next = ST_WAIT_DST_PORT;
			pkts_dropped = dst_oq & ~output_fifo_rdy;
                	rd_dst_oq = 1;
	   	end
           end
        end // case: ST_WAIT_EOP
      endcase // case(store_state)
   end // always @ (*)

   always @(posedge clk) begin

      if(reset) begin
         output_fifo_rdy		  <= 0;
         store_state                      <= ST_WAIT_DST_PORT;
         dst_oq                           <= 0;
         pkt_byte_len                     <= 0;
         pkt_word_len                     <= 0;
      end
      else begin
         store_state            <= store_state_next;
         dst_oq                 <= dst_oq_next;
         pkt_byte_len           <= pkt_byte_len_next;
         pkt_word_len           <= pkt_word_len_next;
	 output_fifo_rdy        <= output_fifo_rdy_next;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // store_pkt
