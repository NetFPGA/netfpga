///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module:
// Project: NF2.1
// Description:
//
///////////////////////////////////////////////////////////////////////////////

  module tail_cache
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter STAGE_NUM = 6,
      parameter TRANSF_BLOCK_SZ = 2034 //in unit of byte
      )

   (
    // intfc to preceding module
    input [DATA_WIDTH-1:0] in_data,
    input [CTRL_WIDTH-1:0] in_ctrl,
    input in_wr,

    output tc_rdy,

    // intfc to tail cache arbiter
    input [2:0] tca_queue_num,
    input tca_queue_rd,

    // intfc to DRAM ctrl
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_dram_data_ctrl,
    output tc_dram_wr,
    input dram_tc_wr_rdy,

    // status signals to tail cache arbiter and head cache arbiter
    output [9:0] tc_q_occup_word_cnt_0, //unit is 18-byte. count up to 1023.
    output [9:0] tc_q_occup_word_cnt_1,
    output [9:0] tc_q_occup_word_cnt_2,
    output [9:0] tc_q_occup_word_cnt_3,
    output [9:0] tc_q_occup_word_cnt_4,
    output [9:0] tc_q_occup_word_cnt_5,
    output [9:0] tc_q_occup_word_cnt_6,
    output [9:0] tc_q_occup_word_cnt_7,

    output [NUM_OUTPUT_QUEUES-1:0] tc_q_occup_one_blk,

    // intfc to head cache arb
    input [NUM_OUTPUT_QUEUES-1:0] hc_tc_rdy,

    // intfc to head cache (cut-thru path)
    output [NUM_OUTPUT_QUEUES-1:0] tc_hc_wr,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_0,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_1,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_2,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_3,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_4,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_5,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_6,
    output [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] tc_hc_data_ctrl_7,

    // --- Misc
    input clk,
    input reset
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

   localparam BUFFER_DEPTH = 1023;//width: 144
   localparam NUM_OQ_WIDTH = log2(NUM_OUTPUT_QUEUES);
   localparam TRANSF_BYTE_CNT_WIDTH = log2(TRANSF_BLOCK_SZ);
   localparam MAX_PKT      = 2048;   // allow for 2K bytes
   localparam PKT_BYTE_CNT_WIDTH = log2(MAX_PKT);
   localparam PKT_WORD_CNT_WIDTH = log2(MAX_PKT/CTRL_WIDTH);

   //----------------------------------------
   // destination queue parser
   wire [NUM_OQ_WIDTH-1:0]     parsed_dst_oq;
   wire [NUM_OUTPUT_QUEUES-1:0] parsed_one_hot_dst_oq;
   wire [PKT_BYTE_CNT_WIDTH-1:0] parsed_pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0] parsed_pkt_word_len;
   wire                        header_parser_rdy;
   wire                        dst_oq_avail;

   //----------------------------------------
   // small fifo
   wire [CTRL_WIDTH-1:0]       input_fifo_ctrl_out;
   reg  input_fifo_ctrl_out_prev_1bit;
   wire [DATA_WIDTH-1:0]       input_fifo_data_out;
   wire                        input_fifo_empty;
   wire                        input_fifo_nearly_full;

   //----------------------------------------
   // tail cache queues
   wire [NUM_OUTPUT_QUEUES-1:0]  almost_full_oq;
   wire [9:0]                    data_count_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] dout_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0]         empty_oq;

   //----------------------------------------
   // input state machine
   localparam INP_WAIT_FOR_PACKET_STATE = 0,
              INP_STORE_PACKET_STATE    = 1;

   reg [1:0] inp_state, inp_state_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] selected_outputs, selected_outputs_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] wr_oq;
   wire [NUM_OUTPUT_QUEUES-1:0] rd_oq;
   reg [DATA_WIDTH+CTRL_WIDTH-1:0] oq_odd, oq_odd_nxt;
   reg [2*(DATA_WIDTH+CTRL_WIDTH)-1:0] oq_pair_din;
   reg                         input_fifo_rd_en;
   reg                         rd_dst_oq, in_pkt_stored;
   reg                         inp_cnt_odd, inp_cnt_odd_nxt;

   //-----------------------------------------
   // output state machine
   localparam OUTP_IDLE_STATE = 0,
              OUTP_TX_STATE   = 1;

   reg        outp_state, outp_state_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0] tca_queue_one_hot, tca_queue_one_hot_nxt;
   reg [TRANSF_BYTE_CNT_WIDTH-1:0] dram_tx_byte_cnt, dram_tx_byte_cnt_nxt;

   //----------------------------------------
   // other wire, reg
   wire [NUM_OUTPUT_QUEUES-1:0] oq_has_space;

   //-----------------------------------------
   // Instantiations

   oq_header_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .OP_LUT_STAGE_NUM(OP_LUT_STAGE_NUM),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES))
   oq_header_parser
     (
       //output:
       .parsed_dst_oq        (parsed_dst_oq),
       .parsed_one_hot_dst_oq(parsed_one_hot_dst_oq),
       .parsed_pkt_byte_len  (parsed_pkt_byte_len),
       .parsed_pkt_word_len  (parsed_pkt_word_len),
       .header_parser_rdy    (header_parser_rdy),
       .dst_oq_avail         (dst_oq_avail),

       //input:
       .rd_dst_oq            (rd_dst_oq),
       .in_wr                (in_wr),
       .in_ctrl              (in_ctrl),
       .in_data              (in_data),

       .clk                  (clk),
       .reset                (reset)
       );

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(4))
   input_fifo
     (
      // -- rd intfc:
      //input:
      .rd_en        (input_fifo_rd_en),
      //output:
      .dout         ({input_fifo_ctrl_out, input_fifo_data_out}),
      .empty        (input_fifo_empty),

      // -- wr intfc:
      //input:
      .din          ({in_ctrl, in_data}),
      .wr_en        (in_wr),
      //output:
      .nearly_full  (input_fifo_nearly_full),
      .full         (),
      .prog_full    (),

      .reset        (reset),
      .clk          (clk)
      );

   generate
      genvar i;
      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: tail_cache
         syncfifo_1024x144 oq  //actually required = 578 x 144
           (
            // -- wr intfc
            //input:
            .wr_en        ( wr_oq[i] ),
            .din          ( oq_pair_din ),
            //output:
            .full         (  ),
            .almost_full  ( almost_full_oq[i] ),

            // -- rd intfc
            //input:
            .rd_en        ( rd_oq[i] ),
            //output:
            .data_count   ( data_count_oq[i] ), // Bus [9 : 0]
            .dout         ( dout_oq[i] ), // Bus [143 : 0]
            .empty        ( empty_oq[i] ),

            .srst          ( reset ),
            .clk          ( clk )
            );
      end // block: tail_cache
   endgenerate

   //--------------------------------------------------------
   // Logic
   assign in_rdy = header_parser_rdy && !input_fifo_nearly_full;

   generate
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: has_space_occup_one_blk
         assign oq_has_space[i] = (BUFFER_DEPTH - data_count_oq[i]) * 2 > parsed_pkt_word_len;

         assign tc_q_occup_one_blk[i] =
                data_count_oq[i] >= (TRANSF_BLOCK_SZ / (2*(DATA_WIDTH+CTRL_WIDTH)/8));

      end
   endgenerate

   assign tc_q_occup_word_cnt_0 = data_count_oq[0];
   assign tc_q_occup_word_cnt_1 = data_count_oq[1];
   assign tc_q_occup_word_cnt_2 = data_count_oq[2];
   assign tc_q_occup_word_cnt_3 = data_count_oq[3];
   assign tc_q_occup_word_cnt_4 = data_count_oq[4];
   assign tc_q_occup_word_cnt_5 = data_count_oq[5];
   assign tc_q_occup_word_cnt_6 = data_count_oq[6];
   assign tc_q_occup_word_cnt_7 = data_count_oq[7];

   assign tc_hc_data_ctrl_0 = dout_oq[0];
   assign tc_hc_data_ctrl_1 = dout_oq[1];
   assign tc_hc_data_ctrl_2 = dout_oq[2];
   assign tc_hc_data_ctrl_3 = dout_oq[3];
   assign tc_hc_data_ctrl_4 = dout_oq[4];
   assign tc_hc_data_ctrl_5 = dout_oq[5];
   assign tc_hc_data_ctrl_6 = dout_oq[6];
   assign tc_hc_data_ctrl_7 = dout_oq[7];

   // Logic to write the packet to the correct queue.
   // First check if the output fifo has enough space to write the
   // packet. If not, drop it. Otherwise write it.
   //
   always @* begin
      // defaults
      inp_state_nxt         = inp_state;
      selected_outputs_nxt   = selected_outputs;
      inp_cnt_odd_nxt = inp_cnt_odd;
      oq_odd_nxt      = oq_odd;

      wr_oq                   = 0;
      oq_pair_din             = { 2 * (DATA_WIDTH + CTRL_WIDTH) {1'b 0}};
      input_fifo_rd_en        = 0;
      rd_dst_oq               = 0;
      in_pkt_stored           = 1'b0;

      case (inp_state)
         INP_WAIT_FOR_PACKET_STATE: begin
            // we have parsed a header for a packet
            if(dst_oq_avail) begin
               inp_state_nxt         = INP_STORE_PACKET_STATE;
               selected_outputs_nxt   = parsed_one_hot_dst_oq & oq_has_space;
               in_pkt_stored           = 1'b 1;
            end
         end // case: INP_WAIT_FOR_PACKET_STATE

         INP_STORE_PACKET_STATE: begin
            // don't do anything if the fifo is empty
            if(!input_fifo_empty) begin
               input_fifo_rd_en    = 1'b 1;
               inp_cnt_odd_nxt = ~ inp_cnt_odd;

               if (inp_cnt_odd_nxt) begin
                  oq_odd_nxt = {input_fifo_ctrl_out, input_fifo_data_out};
               end
               else begin
                  wr_oq       = selected_outputs;
                  oq_pair_din = {oq_odd, input_fifo_ctrl_out, input_fifo_data_out};
               end

               // write until we reach the end
               if(input_fifo_ctrl_out != 0 && input_fifo_ctrl_out_prev_1bit == 1'b 0) begin
                  rd_dst_oq          = 1'b1;

                  if (~ inp_cnt_odd_nxt) begin
                     wr_oq = selected_outputs;
                     oq_pair_din = {oq_odd_nxt, {(CTRL_WIDTH + DATA_WIDTH) {1'b 0} } };
                  end

                  inp_state_nxt    = INP_WAIT_FOR_PACKET_STATE;

               end

            end // if (!input_fifo_empty)

         end // case: INP_STORE_PACKET_STATE

      endcase // case(inp_state)

   end // always @ *


   //----------------------------------------------------
   // output state machine

   always @(*) begin

      outp_state_nxt = outp_state;
      tca_queue_one_hot_nxt = tca_queue_one_hot;
      dram_tx_byte_cnt_nxt = dram_tx_byte_cnt;

      case (outp_state)
        OUTP_IDLE_STATE:
          if (tca_queue_rd) begin
             case (tca_queue_num)
               3'h 0: tca_queue_one_hot_nxt = 8'h  1;
               3'h 1: tca_queue_one_hot_nxt = 8'h  2;
               3'h 2: tca_queue_one_hot_nxt = 8'h  4;
               3'h 3: tca_queue_one_hot_nxt = 8'h  8;
               3'h 4: tca_queue_one_hot_nxt = 8'h 10;
               3'h 5: tca_queue_one_hot_nxt = 8'h 20;
               3'h 6: tca_queue_one_hot_nxt = 8'h 40;
               3'h 7: tca_queue_one_hot_nxt = 8'h 80;
             endcase // case(tca_queue_num)

             dram_tx_byte_cnt_nxt = {TRANSF_BYTE_CNT_WIDTH {1'h 0}};

             outp_state_nxt = OUTP_TX_STATE;

          end // if (tca_queue_rd)

        OUTP_TX_STATE: begin
          if (tc_dram_wr)
            dram_tx_byte_cnt_nxt = dram_tx_byte_cnt + (DATA_WIDTH+CTRL_WIDTH)*2/8;

           if (dram_tx_byte_cnt_nxt == TRANSF_BLOCK_SZ) begin
              tca_queue_one_hot_nxt = 8'h 0;
              outp_state_nxt = OUTP_IDLE_STATE;

           end

        end // case: OUTP_TX_STATE

      endcase // case(outp_state)

   end // always @ (*)

   assign rd_oq = (~ empty_oq) &
                  (tca_queue_one_hot & {NUM_OUTPUT_QUEUES {dram_tc_wr_rdy}} |
                   ~tca_queue_one_hot & hc_tc_rdy);

   assign tc_hc_wr = (~ empty_oq)  & ~tca_queue_one_hot & hc_tc_rdy;

   assign tc_dram_wr = |( (~ empty_oq) & tca_queue_one_hot &
                          {NUM_OUTPUT_QUEUES {dram_tc_wr_rdy}});


   always @(posedge clk) begin
      if (reset) begin
         inp_state         <= INP_WAIT_FOR_PACKET_STATE;
         selected_outputs  <= {NUM_OUTPUT_QUEUES {1'b 0}};
         inp_cnt_odd       <= 1'b 0;
         outp_state        <= OUTP_IDLE_STATE;
         tca_queue_one_hot <= {NUM_OUTPUT_QUEUES {1'b 0}};
         dram_tx_byte_cnt  <= {TRANSF_BYTE_CNT_WIDTH {1'b 0}};
         input_fifo_ctrl_out_prev_1bit <= 1'b 0;
         oq_odd            <= {(DATA_WIDTH + CTRL_WIDTH) {1'b 0}};

      end
      else begin
         inp_state         <= inp_state_nxt;
         selected_outputs  <= selected_outputs_nxt;
         inp_cnt_odd       <= inp_cnt_odd_nxt;
         outp_state        <= outp_state_nxt;
         tca_queue_one_hot <= tca_queue_one_hot_nxt;
         dram_tx_byte_cnt  <= dram_tx_byte_cnt_nxt;
         input_fifo_ctrl_out_prev_1bit <= | input_fifo_ctrl_out;

         oq_odd            <= oq_odd_nxt;

      end

   end


endmodule // tail_cache

