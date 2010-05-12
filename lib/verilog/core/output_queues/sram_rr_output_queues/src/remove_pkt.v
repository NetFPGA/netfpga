///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: remove_pkt.v 3868 2008-06-04 16:18:03Z grg $
//
// Module: remove_pkt.v
// Project: NF2.1
// Description: implements a round-robin arbiter over the output queues,
//              reads a packet from the SRAM, strips the header and sends it
//              to a tx fifo.
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps
  module remove_pkt
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter OQ_STAGE_NUM = 6,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter IOQ_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter PKT_LEN_WIDTH = 11,
      parameter PKT_WORDS_WIDTH = PKT_LEN_WIDTH-log2(CTRL_WIDTH),
      parameter NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES))

   ( // --- Interface to SRAM
     input                              rd_0_ack,
     input  [DATA_WIDTH+CTRL_WIDTH-1:0] rd_0_data,
     input                              rd_0_vld,
     output reg [SRAM_ADDR_WIDTH-1:0]   rd_0_addr,
     output reg                         rd_0_req,

     // --- Interface to regs
     output reg [NUM_OQ_WIDTH-1:0]      src_oq,
     output reg                         rd_src_addr,
     input      [SRAM_ADDR_WIDTH-1:0]   src_oq_rd_addr,
     input      [SRAM_ADDR_WIDTH-1:0]   src_oq_high_addr,
     input      [SRAM_ADDR_WIDTH-1:0]   src_oq_low_addr,
     input      [NUM_OUTPUT_QUEUES-1:0] src_oq_empty,
     output     [SRAM_ADDR_WIDTH-1:0]   src_oq_rd_addr_new,
     output reg                         pkt_removed,
     output reg [PKT_LEN_WIDTH-1:0]     removed_pkt_data_length,
     output reg [CTRL_WIDTH-1:0]        removed_pkt_overhead_length,
     output reg [PKT_WORDS_WIDTH-1:0]   removed_pkt_total_word_length,
     output reg [NUM_OQ_WIDTH-1:0]      removed_oq,

     input      [NUM_OUTPUT_QUEUES-1:0] enable_send_pkt,

     // --- Interface to datapath
     output     [DATA_WIDTH-1:0]        out_data_0,
     output     [CTRL_WIDTH-1:0]        out_ctrl_0,
     input                              out_rdy_0,
     output reg                         out_wr_0,

     output     [DATA_WIDTH-1:0]        out_data_1,
     output     [CTRL_WIDTH-1:0]        out_ctrl_1,
     input                              out_rdy_1,
     output reg                         out_wr_1,

     output     [DATA_WIDTH-1:0]        out_data_2,
     output     [CTRL_WIDTH-1:0]        out_ctrl_2,
     input                              out_rdy_2,
     output reg                         out_wr_2,

     output     [DATA_WIDTH-1:0]        out_data_3,
     output     [CTRL_WIDTH-1:0]        out_ctrl_3,
     input                              out_rdy_3,
     output reg                         out_wr_3,

     output     [DATA_WIDTH-1:0]        out_data_4,
     output     [CTRL_WIDTH-1:0]        out_ctrl_4,
     input                              out_rdy_4,
     output reg                         out_wr_4,

     output  [DATA_WIDTH-1:0]           out_data_5,
     output  [CTRL_WIDTH-1:0]           out_ctrl_5,
     output reg                         out_wr_5,
     input                              out_rdy_5,

     output  [DATA_WIDTH-1:0]           out_data_6,
     output  [CTRL_WIDTH-1:0]           out_ctrl_6,
     output reg                         out_wr_6,
     input                              out_rdy_6,

     output  [DATA_WIDTH-1:0]           out_data_7,
     output  [CTRL_WIDTH-1:0]           out_ctrl_7,
     output reg                         out_wr_7,
     input                              out_rdy_7,

     // --- Misc
     input                              clk,
     input                              reset
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

   //----------------- Internal parameters ----------------------
   parameter NUM_REMOVE_STATES= 4;
   parameter RM_IDLE          = 1;
   parameter RM_LATCH_ADDR    = 2;
   parameter RM_WAIT_PKT_LEN  = 4;
   parameter RM_MOVE_PKT      = 8;

   parameter COUNT_IDLE       = 1;
   parameter COUNT_HDRS       = 2;
   parameter COUNT_DATA       = 4;

   parameter HP_IDLE         = 0;
   parameter HP_WAIT_EOP     = 1;

   parameter SRAM_PIPELINE_DEPTH   = 7;

   //--------------------- Wires/Regs --------------------------
   reg [NUM_REMOVE_STATES-1:0]  remove_state;
   reg [NUM_REMOVE_STATES-1:0]  remove_state_next;

   wire [NUM_OQ_WIDTH-1:0]      src_oq_plus1;
   reg [NUM_OQ_WIDTH-1:0]       src_oq_next;

   reg [SRAM_ADDR_WIDTH-1:0]    rd_0_addr_next;
   wire [SRAM_ADDR_WIDTH-1:0]   rd_0_addr_plus1;

   wire [CTRL_WIDTH-1:0]        sram_ctrl_out;
   wire [DATA_WIDTH-1:0]        sram_data_out;

   reg [PKT_WORDS_WIDTH-1:0]    pkt_len_counter;
   reg                          header_parse_state;
   reg                          header_parse_state_next;
   reg                          ld_pkt_len;

   reg                          ld_oq_dst;
   reg [NUM_OUTPUT_QUEUES-1:0]  out_wr_selected;

   reg [NUM_OQ_WIDTH-1:0]       removed_oq_next;

   reg                          pkt_removed_next;

   reg [NUM_OUTPUT_QUEUES-1:0]  output_fifo_wr_en;
   wire [NUM_OUTPUT_QUEUES-1:0] output_fifo_rd_en;
   wire [NUM_OUTPUT_QUEUES-1:0] output_fifo_empty;
   wire [DATA_WIDTH+CTRL_WIDTH-1:0] output_fifo_dout[0:NUM_OUTPUT_QUEUES-1];

   reg [SRAM_ADDR_WIDTH-1:0]   lo_addr;
   reg [SRAM_ADDR_WIDTH-1:0]   lo_addr_next;

   reg [SRAM_ADDR_WIDTH-1:0]   hi_addr;
   reg [SRAM_ADDR_WIDTH-1:0]   hi_addr_next;


   // ---------------------- Modules -----------------------------

   /* we wait for these fifos to empty before writing to them again
    * We check if they are empty before pulling out a packet because
    * these fifos drain at 1Gbps while the SRAMs can pullout data at
    * 4Gbps. This prevents head-of-line blocking.
    * In reality, we should check if the fifos are almost full to
    * accomodate the SRAM latency and decrease turnaround time between
    * packets.
    */
   generate
   genvar i;
   if(DATA_WIDTH==32) begin:output_fifo32
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: output_fifos
         syncfifo_512x36 gmac_tx_fifo
           (
            .clk         (clk),
            .din         (rd_0_data),
            .wr_en       (output_fifo_wr_en[i]),

            .dout        (output_fifo_dout[i]),
            .rd_en       (output_fifo_rd_en[i]),

            .empty       (output_fifo_empty[i]),
            .full        (),
            .rst         (reset)
            );
      end // block: output_fifos
   end // block: output_fifo32
   else if(DATA_WIDTH==64) begin: output_fifo64
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: output_fifos
         // we only need 256x72, but since we are going to
         // use 2 brams because of datawidth anyway...
         syncfifo_512x72 gmac_tx_fifo
           (
            .clk         (clk),
            .din         (rd_0_data),
            .wr_en       (output_fifo_wr_en[i]),

            .dout        (output_fifo_dout[i]),
            .rd_en       (output_fifo_rd_en[i]),

            .empty       (output_fifo_empty[i]),
            .full        (),
            .rst         (reset)
            );
      end // block: output_fifos
   end // block: output_fifo64
   endgenerate

   //---------------------- Logic ------------------------------

   /* address logic */
   assign {sram_ctrl_out, sram_data_out} = rd_0_data;
   assign src_oq_plus1  = (src_oq==NUM_OUTPUT_QUEUES-1) ? 0 : src_oq + 1;
   assign rd_0_addr_plus1 = (rd_0_addr == hi_addr) ?
                            lo_addr : rd_0_addr + 1;

   assign src_oq_rd_addr_new = rd_0_addr;

   /***************************************************************
    * Pipe the outputs to the tx queues
    ***************************************************************/
   assign output_fifo_rd_en[0] = !output_fifo_empty[0] && out_rdy_0;
   assign output_fifo_rd_en[1] = !output_fifo_empty[1] && out_rdy_1;
   assign output_fifo_rd_en[2] = !output_fifo_empty[2] && out_rdy_2;
   assign output_fifo_rd_en[3] = !output_fifo_empty[3] && out_rdy_3;
   assign output_fifo_rd_en[4] = !output_fifo_empty[4] && out_rdy_4;
   assign output_fifo_rd_en[5] = !output_fifo_empty[5] && out_rdy_5;
   assign output_fifo_rd_en[6] = !output_fifo_empty[6] && out_rdy_6;
   assign output_fifo_rd_en[7] = !output_fifo_empty[7] && out_rdy_7;

   assign {out_ctrl_0, out_data_0} = output_fifo_dout[0];
   assign {out_ctrl_1, out_data_1} = output_fifo_dout[1];
   assign {out_ctrl_2, out_data_2} = output_fifo_dout[2];
   assign {out_ctrl_3, out_data_3} = output_fifo_dout[3];
   assign {out_ctrl_4, out_data_4} = output_fifo_dout[4];
   assign {out_ctrl_5, out_data_5} = output_fifo_dout[5];
   assign {out_ctrl_6, out_data_6} = output_fifo_dout[6];
   assign {out_ctrl_7, out_data_7} = output_fifo_dout[7];

   always @(posedge clk) begin
      if(reset) begin
         out_wr_0 <= 0;
         out_wr_1 <= 0;
         out_wr_2 <= 0;
         out_wr_3 <= 0;
         out_wr_4 <= 0;
         out_wr_5 <= 0;
         out_wr_6 <= 0;
         out_wr_7 <= 0;
      end
      else begin
         out_wr_0 <= output_fifo_rd_en[0];
         out_wr_1 <= output_fifo_rd_en[1];
         out_wr_2 <= output_fifo_rd_en[2];
         out_wr_3 <= output_fifo_rd_en[3];
         out_wr_4 <= output_fifo_rd_en[4];
         out_wr_5 <= output_fifo_rd_en[5];
         out_wr_6 <= output_fifo_rd_en[6];
         out_wr_7 <= output_fifo_rd_en[7];
      end
   end // always @ (posedge clk)

   /*****************************************************************
    * cycle through the output queues until one of them is not empty
    * send read requests until the pkt length is set
    * Then issue exactly the required number of reads for this pkt
    * Then start on the next pkt.
    *****************************************************************/
   always @(*) begin
      remove_state_next   = remove_state;
      src_oq_next         = src_oq;
      removed_oq_next     = removed_oq;
      rd_0_req            = 0;
      rd_0_addr_next      = rd_0_addr;
      hi_addr_next        = hi_addr;
      lo_addr_next        = lo_addr;
      pkt_removed_next    = 0; // signal to store the reg info until the pkt is removed
      rd_src_addr         = 0;

      case(remove_state)
        RM_IDLE: begin
           /* loop until we find a non-empty queue
            * whose fifo has space for a full packet */
           if(src_oq_empty[src_oq] | !enable_send_pkt[src_oq] | !output_fifo_empty[src_oq]) begin
              src_oq_next = src_oq_plus1;
           end
           else begin
              remove_state_next = RM_LATCH_ADDR;
              rd_src_addr = 1;
           end
        end // case: RM_IDLE

        RM_LATCH_ADDR: begin
           rd_0_addr_next      = src_oq_rd_addr;
           hi_addr_next        = src_oq_high_addr;
           lo_addr_next        = src_oq_low_addr;
           remove_state_next   = RM_WAIT_PKT_LEN;
        end

        /* wait in this state until we know the pkt length */
        RM_WAIT_PKT_LEN: begin
           if(ld_pkt_len) begin
              remove_state_next = RM_MOVE_PKT;
           end
           rd_0_req = 1;
           if(rd_0_ack) begin
              rd_0_addr_next = rd_0_addr_plus1;
           end
        end // case: RM_WAIT_PKT_LEN

        /* issue enough reads to read just one pkt */
        RM_MOVE_PKT: begin
           /* if the rd address was accepted then put the next one */
           rd_0_req = 1;
           if(rd_0_ack) begin
              rd_0_addr_next = rd_0_addr_plus1;
           end

           if(rd_0_ack && (pkt_len_counter == SRAM_PIPELINE_DEPTH)) begin
              remove_state_next   = RM_IDLE;
              src_oq_next         = src_oq_plus1;
              pkt_removed_next    = 1;
              removed_oq_next     = src_oq;
           end
        end // case: RM_MOVE_PKT

        default: begin end

      endcase // case(remove_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         remove_state            <= RM_IDLE;
         rd_0_addr               <= 0;
         src_oq                  <= 0;
         removed_oq              <= 0;
         hi_addr                 <= 0;
         lo_addr                 <= 0;
         pkt_removed             <= 0;
      end
      else begin
         remove_state            <= remove_state_next;
         rd_0_addr               <= rd_0_addr_next;
         hi_addr                 <= hi_addr_next;
         lo_addr                 <= lo_addr_next;
         src_oq                  <= src_oq_next;
         removed_oq              <= removed_oq_next;
         pkt_removed             <= pkt_removed_next;
      end
   end // always @ (posedge clk)

   /*************************************************************************
    * Wait until a pkt starts to be removed from the SRAM
    * Parse the headers and latch the output destination and the pkt length
    *************************************************************************/

   always @(*) begin
      header_parse_state_next   = header_parse_state;
      ld_pkt_len                = 0;
      ld_oq_dst                 = 0;
      output_fifo_wr_en         = 0;

      case(header_parse_state)
        HP_IDLE: begin
           if(rd_0_vld) begin
              output_fifo_wr_en   = out_wr_selected;
           end
           if(rd_0_vld & sram_ctrl_out == IOQ_STAGE_NUM) begin
              ld_pkt_len = 1;
           end
           if(rd_0_vld & sram_ctrl_out == IOQ_STAGE_NUM) begin
              ld_oq_dst           = 1;
              output_fifo_wr_en   = sram_data_out[`IOQ_DST_PORT_POS + NUM_OUTPUT_QUEUES - 1:`IOQ_DST_PORT_POS] & output_fifo_empty;
           end
           if(rd_0_vld & sram_ctrl_out == 0) begin
              header_parse_state_next = HP_WAIT_EOP;
           end
        end

        HP_WAIT_EOP: begin
           if(rd_0_vld) begin
              output_fifo_wr_en = out_wr_selected;
              if(sram_ctrl_out!=0) begin // eop
                 header_parse_state_next = HP_IDLE;
              end
           end
        end

        default: begin end
      endcase // case pkt_len_parse_state
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         header_parse_state    <= HP_IDLE;
         pkt_len_counter       <= 0;
         out_wr_selected       <= 0;
      end
      else begin
         header_parse_state <= header_parse_state_next;

         if(ld_pkt_len) begin
            pkt_len_counter <= sram_data_out[PKT_WORDS_WIDTH+`IOQ_WORD_LEN_POS:`IOQ_WORD_LEN_POS] + 'h1;
         end
         else if(rd_0_ack) begin
            pkt_len_counter <= pkt_len_counter - 1;
         end

         /* only send the pkt to the destinations that are ready
          * For unicasts, this was already checked before issuing SRAM reads,
          * so this has no effect.
          * For broadcasts, only ready queues will receive it */
         if(ld_oq_dst) begin
            out_wr_selected <= sram_data_out[`IOQ_DST_PORT_POS + NUM_OUTPUT_QUEUES - 1:`IOQ_DST_PORT_POS] & output_fifo_empty;
         end
      end
   end // always @ (posedge clk)

   always @(posedge clk) begin
      if(reset) begin
         removed_pkt_data_length          <= 0;
         removed_pkt_overhead_length      <= 0;
         removed_pkt_total_word_length    <= 0;
      end
      else begin
         if(ld_pkt_len) begin
            removed_pkt_data_length          <= sram_data_out[PKT_LEN_WIDTH+`IOQ_BYTE_LEN_POS:`IOQ_BYTE_LEN_POS];
            removed_pkt_overhead_length      <= CTRL_WIDTH;
            removed_pkt_total_word_length    <= sram_data_out[PKT_WORDS_WIDTH+`IOQ_WORD_LEN_POS:`IOQ_WORD_LEN_POS] + 1;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)


   // synthesis translate_off
   integer pkt_len_counter_sim;

   reg in_pkt;
   always @(posedge clk) begin
      if(ld_pkt_len) begin
         pkt_len_counter_sim <= sram_data_out[PKT_WORDS_WIDTH+`IOQ_WORD_LEN_POS:`IOQ_WORD_LEN_POS];
      end
      else if(rd_0_vld) begin
         pkt_len_counter_sim <= pkt_len_counter_sim - 1;
      end

      if (reset)
         in_pkt <= 1'b0;
      else if (!in_pkt && rd_0_vld & sram_ctrl_out == 0)
         in_pkt <= 1'b1;
      else if(in_pkt && rd_0_vld & sram_ctrl_out != 0) begin
         in_pkt <= 1'b0;
         if (pkt_len_counter_sim != 1) begin
            $display("%t %m ERROR: Pkt length count in SRAM is larger than the packet size!", $time);
            $finish;
         end
      end
   end // always @ (posedge clk)
   // synthesis translate_on

endmodule // remove_pkt

