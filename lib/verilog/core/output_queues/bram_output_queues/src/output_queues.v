///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: output_queues.v
// Project: NF2.1
// Description: stores incoming packets into BRAM fifos and implements a round
// robin arbiter to service the output queues
//
///////////////////////////////////////////////////////////////////////////////

  module output_queues
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter STAGE_NUM = 6)

   (// --- data path interface
    output     [DATA_WIDTH-1:0]        out_data_0,
    output     [CTRL_WIDTH-1:0]        out_ctrl_0,
    input                              out_rdy_0,
    output                             out_wr_0,

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

    // --- Interface to the previous module
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    output                             in_rdy,
    input                              in_wr,

    // --- Register interface
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

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

   //------------- Internal Parameters ---------------
   parameter NUM_OQ_WIDTH       = log2(NUM_OUTPUT_QUEUES);
   parameter MAX_PKT            = 2048;   // allow for 2K bytes
   parameter PKT_BYTE_CNT_WIDTH = log2(MAX_PKT);
   parameter PKT_WORD_CNT_WIDTH = log2(MAX_PKT/CTRL_WIDTH);

   parameter NUM_STATES            = 1;
   parameter WRITE_WAIT_FOR_PACKET = 0;
   parameter WRITE_STORE_PACKET    = 1;

   parameter BUFFER_SIZE         = 2048;
   parameter BUFFER_SIZE_WIDTH   = log2(BUFFER_SIZE);

   //--------------- Regs/Wires ----------------------

   wire  reg_req_wire;
   wire  reg_ack_wire;
   wire  reg_rd_wr_L_wire;
   wire  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_wire;
   wire  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_wire;
   wire  [UDP_REG_SRC_WIDTH-1:0]      reg_src_wire;

   wire [PKT_BYTE_CNT_WIDTH-1:0] parsed_pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0] parsed_pkt_word_len;
   wire                          dst_oq_avail;
   wire [NUM_OQ_WIDTH-1:0]       parsed_dst_oq;
   wire [NUM_OUTPUT_QUEUES-1:0]  parsed_one_hot_dst_oq;
   reg                           rd_dst_oq;
   wire                          header_parser_rdy;

   reg                           input_fifo_rd_en;
   wire                          input_fifo_empty;
   wire [DATA_WIDTH-1:0]         input_fifo_data_out;
   wire [CTRL_WIDTH-1:0]         input_fifo_ctrl_out;
   reg  [CTRL_WIDTH-1:0]         input_fifo_ctrl_out_prev;
   wire                          input_fifo_nearly_full;

   wire [NUM_OUTPUT_QUEUES-1:0]  rd_oq;
   reg [NUM_OUTPUT_QUEUES-1:0]   wr_oq;
   wire [NUM_OUTPUT_QUEUES-1:0]  almost_full_oq;
   wire [BUFFER_SIZE_WIDTH-1:0]  data_count_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [DATA_WIDTH+CTRL_WIDTH-1:0] dout_oq[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0]     empty_oq;

   wire [11:0]                      bytes_in[NUM_OUTPUT_QUEUES-1:0];
   wire [NUM_OUTPUT_QUEUES-1:0]     pkt_in;
   wire [NUM_OUTPUT_QUEUES-1:0]     pkt_dropped;
   wire [NUM_OUTPUT_QUEUES-1:0]     disable_oqs;

   reg [NUM_STATES-1:0]             write_state;
   reg [NUM_STATES-1:0]             write_state_nxt;
   reg                              in_pkt_stored, in_pkt_stored_next;

   reg [NUM_OUTPUT_QUEUES-1:0]      out_wr;
   reg [NUM_OUTPUT_QUEUES-1:0]      selected_outputs, selected_outputs_next;
   wire [NUM_OUTPUT_QUEUES-1:0]     oq_has_space;
   wire [NUM_OUTPUT_QUEUES-1:0]     out_rdy;

   genvar                     i;

   //---------------- Modules ------------------------
   oq_header_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .OP_LUT_STAGE_NUM(OP_LUT_STAGE_NUM),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES))
   oq_header_parser
     (
       .parsed_dst_oq        (parsed_dst_oq),
       .parsed_one_hot_dst_oq(parsed_one_hot_dst_oq),
       .parsed_pkt_byte_len  (parsed_pkt_byte_len),
       .parsed_pkt_word_len  (parsed_pkt_word_len),
       .header_parser_rdy    (header_parser_rdy),
       .dst_oq_avail         (dst_oq_avail),
       .rd_dst_oq            (rd_dst_oq),
       .in_wr                (in_wr),
       .in_ctrl              (in_ctrl),
       .in_data              (in_data),
       .clk                  (clk),
       .reset                (reset));

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(4))
   input_fifo
     (.dout         ({input_fifo_ctrl_out, input_fifo_data_out}),
      .full         (),
      .prog_full    (),
      .nearly_full  (input_fifo_nearly_full),
      .empty        (input_fifo_empty),
      .din          ({in_ctrl, in_data}),
      .wr_en        (in_wr),
      .rd_en        (input_fifo_rd_en),
      .reset        (reset),
      .clk          (clk));

   generate
      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:bram_oq
         syncfifo_2048x72 oq
           (
            .clk          (clk),
            .din          ({input_fifo_ctrl_out, input_fifo_data_out}), // Bus [71 : 0]
            .rd_en        (rd_oq[i]),
            .rst          (reset),
            .wr_en        (wr_oq[i]),
            .almost_full  (almost_full_oq[i]),
            .data_count   (data_count_oq[i]), // Bus [11 : 0]
            .dout         (dout_oq[i]), // Bus [71 : 0]
            .empty        (empty_oq[i]),
            .full         ());
      end // block: bram_oq
   endgenerate

   wire [`CPCI_NF2_DATA_WIDTH-NUM_OUTPUT_QUEUES-1:0] temp;

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG ({`BRAM_OQ_BLOCK_ADDR, 1'b0}),
       .REG_ADDR_WIDTH (`BRAM_OQ_REG_ADDR_WIDTH - 1),
       .NUM_COUNTERS (0),
       .NUM_SOFTWARE_REGS (1),
       .NUM_HARDWARE_REGS (1), // dummy
       .COUNTER_INPUT_WIDTH (0))
   generic_regs_a
     (
      .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),

      .reg_req_out       (reg_req_wire),
      .reg_ack_out       (reg_ack_wire),
      .reg_rd_wr_L_out   (reg_rd_wr_L_wire),
      .reg_addr_out      (reg_addr_wire),
      .reg_data_out      (reg_data_wire),
      .reg_src_out       (reg_src_wire),

      // --- counters interface
      .counter_updates   (),
      .counter_decrement (),

      // --- SW regs interface
      .software_regs     ({temp, disable_oqs}),

      // --- HW regs interface
      .hardware_regs     (),

      .clk               (clk),
      .reset             (reset));

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG ({`BRAM_OQ_BLOCK_ADDR, 1'b1}),
       .REG_ADDR_WIDTH (`BRAM_OQ_REG_ADDR_WIDTH - 1),
       //.NUM_COUNTERS (3*NUM_OUTPUT_QUEUES),
       .NUM_COUNTERS (3),
       .NUM_SOFTWARE_REGS (0),
       //.NUM_HARDWARE_REGS (NUM_OUTPUT_QUEUES),
       .NUM_HARDWARE_REGS (1),
       .NUM_INSTANCES (NUM_OUTPUT_QUEUES),
       .COUNTER_INPUT_WIDTH (12))
   generic_regs_b
     (
      .reg_req_in        (reg_req_wire),
      .reg_ack_in        (reg_ack_wire),
      .reg_rd_wr_L_in    (reg_rd_wr_L_wire),
      .reg_addr_in       (reg_addr_wire),
      .reg_data_in       (reg_data_wire),
      .reg_src_in        (reg_src_wire),

      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),

      // --- counters interface
      .counter_updates   ({{11'h0, pkt_dropped[7]},
                           {11'h0, pkt_dropped[6]},
                           {11'h0, pkt_dropped[5]},
                           {11'h0, pkt_dropped[4]},
                           {11'h0, pkt_dropped[3]},
                           {11'h0, pkt_dropped[2]},
                           {11'h0, pkt_dropped[1]},
                           {11'h0, pkt_dropped[0]},
                           {11'h0, pkt_in[7]},
                           {11'h0, pkt_in[6]},
                           {11'h0, pkt_in[5]},
                           {11'h0, pkt_in[4]},
                           {11'h0, pkt_in[3]},
                           {11'h0, pkt_in[2]},
                           {11'h0, pkt_in[1]},
                           {11'h0, pkt_in[0]},
                           bytes_in[7],
                           bytes_in[6],
                           bytes_in[5],
                           bytes_in[4],
                           bytes_in[3],
                           bytes_in[2],
                           bytes_in[1],
                           bytes_in[0]}
                          ),
      .counter_decrement ({(3*NUM_OUTPUT_QUEUES){1'b0}}),

      // --- SW regs interface
      .software_regs     (),

      // --- HW regs interface
      .hardware_regs     ({{(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[7],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[6],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[5],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[4],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[3],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[2],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[1],
                           {(32 - BUFFER_SIZE_WIDTH){1'b0}}, data_count_oq[0]}
                          ),

      .clk               (clk),
      .reset             (reset));


   //------------------ Logic ------------------------

   assign in_rdy = header_parser_rdy && !input_fifo_nearly_full;

   generate
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:gen_space_check
         assign oq_has_space[i] = (BUFFER_SIZE - data_count_oq[i] > parsed_pkt_word_len);
      end
   endgenerate

   /* Logic to write the packet to the correct queue.
    * First check if the output fifo has enough space to write the
    * packet. If not, drop it. Otherwise write it.
    */
   always @* begin
      // defaults
      write_state_nxt         = write_state;
      selected_outputs_next   = selected_outputs;
      wr_oq                   = 0;
      input_fifo_rd_en        = 0;
      rd_dst_oq               = 0;
      in_pkt_stored_next      = 1'b0;

      case (write_state)
         WRITE_WAIT_FOR_PACKET: begin
            /* we have parsed a header for a packet */
            if(dst_oq_avail) begin
               write_state_nxt         = WRITE_STORE_PACKET;
               selected_outputs_next   = parsed_one_hot_dst_oq & oq_has_space;
               in_pkt_stored_next      = 1'b1;
            end
         end // case: WRITE_WAIT_FOR_PACKET

         WRITE_STORE_PACKET: begin
            /* don't do anything if the fifo is empty */
            if(!input_fifo_empty) begin
               /* write until we reach the end */
               if(input_fifo_ctrl_out != 0 && input_fifo_ctrl_out_prev == 0) begin
                  write_state_nxt    = WRITE_WAIT_FOR_PACKET;
                  rd_dst_oq          = 1'b1;
               end
               input_fifo_rd_en    = 1'b1;
               wr_oq               = selected_outputs;
            end // if (!input_fifo_empty)
         end // case: WRITE_STORE_PACKET

      endcase // case(write_state)

   end // always @ *

   always @(posedge clk) begin
      if (reset) begin
         write_state                 <= WRITE_WAIT_FOR_PACKET;
         selected_outputs            <= 0;
         input_fifo_ctrl_out_prev    <= 1;
         in_pkt_stored               <= 0;
      end
      else begin
         write_state         <= write_state_nxt;
         selected_outputs    <= selected_outputs_next;
         in_pkt_stored       <= in_pkt_stored_next;
         if(input_fifo_rd_en)
           input_fifo_ctrl_out_prev <= input_fifo_ctrl_out;
      end // else: !if(reset)
   end // always @ (posedge clk)

   /* logic to push packets from the queues to the outputs */
   assign rd_oq = (~empty_oq) & out_rdy & ~disable_oqs;
   always @(posedge clk) begin
      out_wr <= rd_oq;
   end

   assign out_rdy[0] = out_rdy_0;
   assign out_rdy[1] = out_rdy_1;
   assign out_rdy[2] = out_rdy_2;
   assign out_rdy[3] = out_rdy_3;
   assign out_rdy[4] = out_rdy_4;
   assign out_rdy[5] = out_rdy_5;
   assign out_rdy[6] = out_rdy_6;
   assign out_rdy[7] = out_rdy_7;

   assign out_wr_0 = out_wr[0];
   assign out_wr_1 = out_wr[1];
   assign out_wr_2 = out_wr[2];
   assign out_wr_3 = out_wr[3];
   assign out_wr_4 = out_wr[4];
   assign out_wr_5 = out_wr[5];
   assign out_wr_6 = out_wr[6];
   assign out_wr_7 = out_wr[7];

   assign {out_ctrl_0, out_data_0} = dout_oq[0];
   assign {out_ctrl_1, out_data_1} = dout_oq[1];
   assign {out_ctrl_2, out_data_2} = dout_oq[2];
   assign {out_ctrl_3, out_data_3} = dout_oq[3];
   assign {out_ctrl_4, out_data_4} = dout_oq[4];
   assign {out_ctrl_5, out_data_5} = dout_oq[5];
   assign {out_ctrl_6, out_data_6} = dout_oq[6];
   assign {out_ctrl_7, out_data_7} = dout_oq[7];

   /* logic to update the registers */
   generate
      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:reg_updates
         assign bytes_in[i]      = (in_pkt_stored && selected_outputs[i]) ? parsed_pkt_byte_len : 0;
         assign pkt_in[i]        = in_pkt_stored & selected_outputs[i];
         assign pkt_dropped[i]   = in_pkt_stored & parsed_one_hot_dst_oq[i] & ~selected_outputs[i];
      end
   endgenerate

endmodule // output_queues




