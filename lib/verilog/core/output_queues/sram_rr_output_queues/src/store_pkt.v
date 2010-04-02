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
  module store_pkt
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 5,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter PKT_LEN_WIDTH = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter OQ_STAGE_NUM = 6,
      parameter NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES))

   ( // --- Interface to header_parser
     input                            dst_oq_avail,
     input      [NUM_OQ_WIDTH-1:0]    parsed_dst_oq,
     input      [PKT_LEN_WIDTH-1:0]   parsed_pkt_byte_len,
     input      [PKT_WORDS_WIDTH-1:0] parsed_pkt_word_len,
     output reg                       rd_dst_oq,

     // --- Interface to registers
     output reg [SRAM_ADDR_WIDTH-1:0] dst_oq_wr_addr_new,
     output reg                       pkt_stored,
     output reg                       pkt_dropped,
     output reg [PKT_LEN_WIDTH-1:0]   stored_pkt_data_length,
     output reg [CTRL_WIDTH-1:0]      stored_pkt_overhead_length,
     output reg [PKT_WORDS_WIDTH-1:0] stored_pkt_total_word_length,
     output reg [NUM_OQ_WIDTH-1:0]    dst_oq,
     output reg                       rd_dst_addr,
     input      [SRAM_ADDR_WIDTH-1:0] dst_oq_high_addr,
     input      [SRAM_ADDR_WIDTH-1:0] dst_oq_low_addr,
     input      [SRAM_ADDR_WIDTH-1:0] dst_oq_wr_addr,
     input      [NUM_OUTPUT_QUEUES-1:0]	dst_oq_full,

     // --- Interface to SRAM
     output reg [SRAM_ADDR_WIDTH-1:0]       wr_0_addr,
     output reg                             wr_0_req,
     input                                  wr_0_ack,
     output reg [DATA_WIDTH+CTRL_WIDTH-1:0] wr_0_data,

     // --- Interface to input fifo
     output reg                       input_fifo_rd_en,
     input                            input_fifo_empty,
     input      [DATA_WIDTH-1:0]      input_fifo_data_out,
     input      [CTRL_WIDTH-1:0]      input_fifo_ctrl_out,

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

   parameter NUM_STORE_STATES                       = 7;
   parameter ST_WAIT_DST_PORT                       = 1;
   parameter ST_READ_ADDR                           = 2;
   parameter ST_LATCH_ADDR                          = 4;
   parameter ST_MOVE_PKT                            = 8;
   parameter ST_WAIT_FOR_DATA                       = 16;
   parameter ST_WAIT_EOP                            = 32;
   parameter ST_DROP_PKT                            = 64;

   parameter COUNT_IDLE       = 1;
   parameter COUNT_HDRS       = 2;
   parameter COUNT_DATA       = 4;

   //------------------------ Wires/regs --------------------------------
   reg [NUM_STORE_STATES-1:0]  store_state;
   reg [NUM_STORE_STATES-1:0]  store_state_next;

   wire [SRAM_ADDR_WIDTH-1:0]  wr_0_addr_plus1;
   reg [SRAM_ADDR_WIDTH-1:0]   wr_0_addr_next;
   reg [DATA_WIDTH+CTRL_WIDTH-1:0] wr_0_data_next;
   reg                             wr_0_req_next;

   wire                        eop;

   reg                         input_fifo_ctrl_out_prev_is_0;

   reg [NUM_OQ_WIDTH-1:0]      dst_oq_next;

   reg [PKT_LEN_WIDTH-1:0]     pkt_byte_len;
   reg [PKT_LEN_WIDTH-1:0]     pkt_byte_len_next;

   reg [PKT_WORDS_WIDTH-1:0]   pkt_word_len;
   reg [PKT_WORDS_WIDTH-1:0]   pkt_word_len_next;

   reg [SRAM_ADDR_WIDTH-1:0]   lo_addr;
   reg [SRAM_ADDR_WIDTH-1:0]   lo_addr_next;

   reg [SRAM_ADDR_WIDTH-1:0]   hi_addr;
   reg [SRAM_ADDR_WIDTH-1:0]   hi_addr_next;

   //-------------------------- Logic -----------------------------------

   /* wrap around the address */
   assign wr_0_addr_plus1 = (wr_0_addr >= hi_addr) ?
                            lo_addr : wr_0_addr + 1;

   assign eop = (input_fifo_ctrl_out_prev_is_0 && input_fifo_ctrl_out!=0);

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
      rd_dst_oq                 = 0;
      rd_dst_addr               = 0;
      store_state_next          = store_state;
      wr_0_req_next             = wr_0_req;
      input_fifo_rd_en          = 0;
      pkt_dropped               = 0;
      wr_0_data_next            = wr_0_data;
      wr_0_addr_next            = wr_0_addr;
      dst_oq_wr_addr_new        = wr_0_addr_plus1;
      pkt_stored                = 0;
      dst_oq_next               = dst_oq;
      pkt_byte_len_next         = pkt_byte_len;
      pkt_word_len_next         = pkt_word_len;
      lo_addr_next              = lo_addr;
      hi_addr_next              = hi_addr;

      case(store_state)
         /* wait until we have a destination port */
         ST_WAIT_DST_PORT: begin
            if(dst_oq_avail) begin
               store_state_next = ST_READ_ADDR;
               dst_oq_next = parsed_dst_oq;
	       pkt_byte_len_next = parsed_pkt_byte_len;
	       pkt_word_len_next = parsed_pkt_word_len;
               rd_dst_oq = 1;
            end
         end

         // Request the destination address
         ST_READ_ADDR: begin
            store_state_next = ST_LATCH_ADDR;
            rd_dst_addr = 1;
         end

	 // Latch the destination addresses (write pointer, lo and hi
	 // addresses)
         ST_LATCH_ADDR: begin
            if(!dst_oq_full[dst_oq]) begin

               store_state_next = ST_MOVE_PKT;

               wr_0_req_next = 1;
               wr_0_addr_next = dst_oq_wr_addr;
               lo_addr_next = dst_oq_low_addr;
               hi_addr_next = dst_oq_high_addr;

               /* fifos are first-word fallthrough so the data is already available at the output */
               wr_0_data_next = {input_fifo_ctrl_out, input_fifo_data_out};
               input_fifo_rd_en = 1;
            end
            else begin
               store_state_next = ST_DROP_PKT;
               input_fifo_rd_en = !input_fifo_empty;
            end
         end // case: ST_WAIT_DST_PORT

        /* pipeline is full */
        ST_MOVE_PKT: begin
           if(wr_0_ack & !input_fifo_empty) begin
              wr_0_req_next = 1;
              wr_0_addr_next = wr_0_addr_plus1;
              wr_0_data_next = {input_fifo_ctrl_out, input_fifo_data_out};
              input_fifo_rd_en = 1;
              if(eop) begin
                 store_state_next = ST_WAIT_EOP;
              end
           end
           else if (wr_0_ack & input_fifo_empty) begin
              store_state_next = ST_WAIT_FOR_DATA;
              wr_0_req_next = 0;
           end
        end // case: ST_MOVE_PKT

        /* Wait until the fifo is not empty */
        ST_WAIT_FOR_DATA: begin
           if(!input_fifo_empty) begin
              wr_0_req_next = 1;
              wr_0_addr_next = wr_0_addr_plus1;
              wr_0_data_next = {input_fifo_ctrl_out, input_fifo_data_out};
              input_fifo_rd_en = 1;
              if(eop) begin
                 store_state_next = ST_WAIT_EOP;
              end
              else begin
                 store_state_next = ST_MOVE_PKT;
              end
           end // if (wr_0_ack)
        end // case: ST_WAIT_FOR_DATA

        ST_WAIT_EOP: begin
           if(wr_0_ack) begin
              wr_0_req_next = 0;
              pkt_stored = 1;
              store_state_next = ST_WAIT_DST_PORT;
           end // if (wr_0_ack)
        end // case: ST_WAIT_LEN

        ST_DROP_PKT: begin
           if(eop) begin
              store_state_next = ST_WAIT_DST_PORT;
              pkt_dropped = 1;
           end
           input_fifo_rd_en = !input_fifo_empty;
        end

        default: begin end

      endcase // case(store_state)

   end // always @ (*)

   always @(posedge clk) begin

      if(reset) begin
         store_state                      <= ST_WAIT_DST_PORT;
         input_fifo_ctrl_out_prev_is_0    <= 0;
         wr_0_req                         <= 0;
         wr_0_addr                        <= 0;
         wr_0_data                        <= 0;
         dst_oq                           <= 0;
         pkt_byte_len                     <= 0;
         pkt_word_len                     <= 0;
         lo_addr                          <= 0;
         hi_addr                          <= 0;
      end
      else begin
         store_state            <= store_state_next;
         wr_0_req               <= wr_0_req_next;
         wr_0_addr              <= wr_0_addr_next;
         wr_0_data              <= wr_0_data_next;
         dst_oq                 <= dst_oq_next;
         pkt_byte_len           <= pkt_byte_len_next;
         pkt_word_len           <= pkt_word_len_next;
         lo_addr                <= lo_addr_next;
         hi_addr                <= hi_addr_next;
         if(input_fifo_rd_en) begin
            input_fifo_ctrl_out_prev_is_0 <= (input_fifo_ctrl_out==0);
         end
      end // else: !if(reset)
      // synthesis translate_off
      if(store_state_next == ST_DROP_PKT) begin
         $display("%t %m WARNING: output queue %u is full. Pkt is being dropped.", $time, dst_oq);
      end
      // synthesis translate_on
   end // always @ (posedge clk)


   always @(posedge clk) begin
      stored_pkt_data_length <= pkt_byte_len;
      stored_pkt_overhead_length <= CTRL_WIDTH;

      // Calculate the total WORD length
      stored_pkt_total_word_length <= pkt_word_len + 1;
   end

endmodule // store_pkt
