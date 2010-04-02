///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_header_parser.v 4880 2009-02-12 09:32:37Z jnaous $
//
// Module: oq_header_parser.v
// Project: NF2.1
// Description: finds the destination port in the module headers and puts it in fifo
//
///////////////////////////////////////////////////////////////////////////////

  module oq_header_parser
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter IOQ_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES),
      parameter MAX_PKT = 2048,   // allow for 2K bytes
      parameter PKT_BYTE_CNT_WIDTH = log2(MAX_PKT),
      parameter PKT_WORD_CNT_WIDTH = log2(MAX_PKT/CTRL_WIDTH)
   )

   (
     output	[NUM_OUTPUT_QUEUES-1:0]	 parsed_dst_oq,
     output     [PKT_BYTE_CNT_WIDTH-1:0] parsed_pkt_byte_len,
     output     [PKT_WORD_CNT_WIDTH-1:0] parsed_pkt_word_len,
     output                        header_parser_rdy,
     output                        dst_oq_avail,
     input                         rd_dst_oq,

     input                         in_wr,
     input [CTRL_WIDTH-1:0]        in_ctrl,
     input [DATA_WIDTH-1:0]        in_data,

     input                         clk,
     input                         reset
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
   //------------------- Internal parameters -----------------
   parameter NUM_INPUT_STATES        = 3;
   parameter IN_WAIT_DST_PORT_LENGTH = 1;
   parameter IN_WAIT_PKT_DATA        = 2;
   parameter IN_WAIT_EOP             = 4;


   //---------------------- Regs/Wires -----------------------
   reg [NUM_INPUT_STATES-1:0]  input_state;
   reg [NUM_INPUT_STATES-1:0]  input_state_next;

   wire [NUM_OUTPUT_QUEUES-1:0]      dst_oq;
   wire [PKT_BYTE_CNT_WIDTH-1:0]pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0]pkt_word_len;
   reg                         wr_en;
   wire                        empty;
   wire                        full;

   //----------------------- Module --------------------------

   fallthrough_small_fifo #(.WIDTH(NUM_OUTPUT_QUEUES + PKT_BYTE_CNT_WIDTH + PKT_WORD_CNT_WIDTH))
      dst_oq_fifo
        (.din ({pkt_word_len, pkt_byte_len, dst_oq}),     // Data in
         .wr_en (wr_en),             // Write enable
         .rd_en (rd_dst_oq),       // Read the next word
         .dout ({parsed_pkt_word_len, parsed_pkt_byte_len, parsed_dst_oq}),
         .full (full),
         .prog_full (),
         .nearly_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------ Logic --------------------------

   assign header_parser_rdy = !full;
   assign dst_oq_avail = !empty;

   assign dst_oq = in_data[`IOQ_DST_PORT_POS + NUM_OUTPUT_QUEUES - 1:`IOQ_DST_PORT_POS];
   assign pkt_byte_len = in_data[`IOQ_BYTE_LEN_POS + PKT_BYTE_CNT_WIDTH-1:`IOQ_BYTE_LEN_POS];
   assign pkt_word_len = in_data[`IOQ_WORD_LEN_POS + PKT_WORD_CNT_WIDTH-1:`IOQ_WORD_LEN_POS];

   /*********************************************************
    * As data comes in, look for the dst port and queue it
    *********************************************************/

   always @(*) begin
      wr_en = 0;
      input_state_next    = input_state;

      case(input_state)
        IN_WAIT_DST_PORT_LENGTH: begin
           if(in_wr && in_ctrl==IOQ_STAGE_NUM) begin
              wr_en = 1;
              input_state_next = IN_WAIT_PKT_DATA;
           end
        end // case: IP_WAIT_DST_PORT

        IN_WAIT_PKT_DATA: begin
           if(in_wr && in_ctrl==0) begin
              input_state_next = IN_WAIT_EOP;
           end
        end

        IN_WAIT_EOP: begin
           if(in_wr && in_ctrl != 0) begin
              input_state_next = IN_WAIT_DST_PORT_LENGTH;
           end
        end
      endcase // case(input_process_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         input_state <= IN_WAIT_DST_PORT_LENGTH;
      end
      else begin
         input_state <= input_state_next;
      end
      // synthesis translate_off
      if(in_wr && in_ctrl==0 && input_state==IN_WAIT_DST_PORT_LENGTH) begin
         $display("%t %m **** ERROR: Did not find dst port", $time);
         $stop;
      end
      // synthesis translate_on
   end


endmodule // header_parser
