/***************************************
 * $Id: output_queues.v 5197 2009-03-06 01:24:43Z grg $
 *
 * Module: output_queues.v
 * Author: Jad Naous
 * Project: output_queues v2
 * Description: Stores packets and sends them out
 *
 * Multicast packets are written into each queues. Even
 * though this wastes SRAM BW, that's OK since if we write
 * to 1 queue and read from there then either we drop them
 * if the port is not ready to accept them or they delay
 * other pkts in the SRAM. If the SRAM is already full, new
 * pkts will be dropped => bandwidth will be wasted somewhere
 * and the BW wasted is equal to that wasted in the SRAM.
 *
 * In addition, the reason why sending a reasonably large number of
 * multicast packets does not overflow the input queues is because
 * the SRAM arbiter gives preference to writes. i.e. it gives the
 * full 8Gbps to writes in that case. Nothing can be done if more
 * than 1 queue is sending broadcasts at line-rate.
 *
 * Btw, this is all by intuition, so it might be all wrong :)
 *
 * Change history:
 *
 ***************************************/

  module output_queues
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter OP_LUT_STAGE_NUM = 4,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter STAGE_NUM = 6,
      parameter SRAM_ADDR_WIDTH = 19)

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

    // --- SRAM sm interface
    output [SRAM_ADDR_WIDTH-1:0]       wr_0_addr,
    output                             wr_0_req,
    input                              wr_0_ack,
    output [DATA_WIDTH+CTRL_WIDTH-1:0] wr_0_data,

    input                              rd_0_ack,
    input  [DATA_WIDTH+CTRL_WIDTH-1:0] rd_0_data,
    input                              rd_0_vld,
    output [SRAM_ADDR_WIDTH-1:0]       rd_0_addr,
    output                             rd_0_req,

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
   localparam PKT_LEN_WIDTH         = 11;
   localparam PKT_WORDS_WIDTH       = PKT_LEN_WIDTH-log2(CTRL_WIDTH);
   localparam NUM_OQ_WIDTH          = log2(NUM_OUTPUT_QUEUES);
   localparam SRAM_WIDTH            = DATA_WIDTH+CTRL_WIDTH;

   localparam WAIT_FOR_IOQ_HEADER   = 1,
              CHECK_SPACE           = 2,
              STORE_HDR_MODULE      = 4,
              DROP_PKT              = 8,
              STORE_PKT             = 16;

   //--------------- Regs/Wires ----------------------
   wire [SRAM_ADDR_WIDTH*NUM_OUTPUT_QUEUES-1:0] sram_wr_addr;
   wire [NUM_OUTPUT_QUEUES-1:0]                 sram_wr_req;
   wire [NUM_OUTPUT_QUEUES-1:0]                 sram_wr_ack;
   wire [SRAM_WIDTH*NUM_OUTPUT_QUEUES-1:0]      sram_wr_data;

   wire [SRAM_ADDR_WIDTH*NUM_OUTPUT_QUEUES-1:0] sram_rd_addr;
   wire [NUM_OUTPUT_QUEUES-1:0]                 sram_rd_req;
   wire [SRAM_WIDTH-1:0]                        sram_rd_data;
   wire [NUM_OUTPUT_QUEUES-1:0]                 sram_rd_vld;
   wire [NUM_OUTPUT_QUEUES-1:0]                 sram_rd_ack;

   wire [CTRL_WIDTH-1:0]                        in_fifo_ctrl;
   wire [DATA_WIDTH-1:0]                        in_fifo_data;
   reg                                          in_fifo_rd_en;

   wire [NUM_OUTPUT_QUEUES-1:0]                 wr_ack;
   reg [NUM_OUTPUT_QUEUES-1:0]                  wr_req;
   wire [SRAM_ADDR_WIDTH*NUM_OUTPUT_QUEUES-1:0] space_avail;
   wire [SRAM_ADDR_WIDTH-1:0]                   words_avail[NUM_OUTPUT_QUEUES-1:0];
   reg  [SRAM_ADDR_WIDTH*NUM_OUTPUT_QUEUES-1:0] space_avail_reg;

   wire [NUM_OUTPUT_QUEUES-1:0]                 out_rdy;
   wire [NUM_OUTPUT_QUEUES-1:0]                 out_wr;
   wire [DATA_WIDTH-1:0]                        out_data[NUM_OUTPUT_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0]                        out_ctrl[NUM_OUTPUT_QUEUES-1:0];

   wire [PKT_LEN_WIDTH-1:0]                     bytes_in[NUM_OUTPUT_QUEUES-1:0];

   wire [NUM_OUTPUT_QUEUES-1:0]                 dst_oq_found;

   reg [4:0]                                    state, state_nxt;
   reg [PKT_LEN_WIDTH-1:0]                      pkt_len, pkt_len_nxt;
   reg [PKT_WORDS_WIDTH-1:0]                    pkt_wlen, pkt_wlen_nxt;
   reg [NUM_OUTPUT_QUEUES-1:0]                  dst_oq, dst_oq_nxt;
   reg                                          latch_space;
   reg [NUM_OUTPUT_QUEUES-1:0]                  pkt_stored;
   reg [NUM_OUTPUT_QUEUES-1:0]                  pkt_dropped;

   reg                                          in_fifo_ctrl_prev_0;

   wire [NUM_OUTPUT_QUEUES-1:0]                 enough_space_is_avail;

   reg [NUM_OUTPUT_QUEUES-1:0]                  acked, acked_nxt;

   //---------------- Modules ------------------------

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(4))
       input_fifo
         (.dout         ({in_fifo_ctrl, in_fifo_data}),
          .full         (),
          .nearly_full  (in_fifo_nearly_full),
          .prog_full    (),
          .empty        (in_fifo_empty),
          .din          ({in_ctrl, in_data}),
          .wr_en        (in_wr),
          .rd_en        (in_fifo_rd_en),
          .reset        (reset),
          .clk          (clk));

   arbitrator #(.SERV_DATA_WIDTH(SRAM_WIDTH), .SUPP_DATA_WIDTH(SRAM_ADDR_WIDTH),
                .FIFO_DEPTH_BITS(3), .NUM_CLIENTS(NUM_OUTPUT_QUEUES), .USE_RESULTS(1))
     sram_rd_arbitrator
       (.client_supp_data   (sram_rd_addr),
        .client_serv_data   (),
        .client_req         (sram_rd_req),
        .client_ack         (sram_rd_ack),
        .client_vld         (sram_rd_vld),
        .client_rslt_data   (sram_rd_data),

        .server_supp_data   (rd_0_addr),
        .server_serv_data   (),
        .server_req         (rd_0_req),
        .server_ack         (rd_0_ack),
        .server_vld         (rd_0_vld),
        .server_rslt_data   (rd_0_data),

        .clk                (clk),
        .reset              (reset)
        );

   arbitrator #(.SERV_DATA_WIDTH(SRAM_WIDTH), .SUPP_DATA_WIDTH(SRAM_ADDR_WIDTH),
                .FIFO_DEPTH_BITS(1), .NUM_CLIENTS(NUM_OUTPUT_QUEUES), .USE_RESULTS(0))
     sram_wr_arbitrator
       (.client_supp_data   (sram_wr_addr),
        .client_serv_data   (sram_wr_data),
        .client_req         (sram_wr_req),
        .client_ack         (sram_wr_ack),
        .client_vld         (),
        .client_rslt_data   (),

        .server_supp_data   (wr_0_addr),
        .server_serv_data   (wr_0_data),
        .server_req         (wr_0_req),
        .server_ack         (wr_0_ack),
        .server_vld         (),
        .server_rslt_data   (),

        .clk                (clk),
        .reset              (reset)
        );

   generate
      genvar  i;
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:gen_sram_fifos
         wire [SRAM_ADDR_WIDTH-1:0]   addr_low  = i*(2**SRAM_ADDR_WIDTH/NUM_OUTPUT_QUEUES);
         wire [SRAM_ADDR_WIDTH-1:0]   addr_high = addr_low + 2**SRAM_ADDR_WIDTH/NUM_OUTPUT_QUEUES - 1'b1;

         wire                         rd_req;
         wire [71:0]                  rd_data;

         sram_fifo
           #(.SRAM_WIDTH (DATA_WIDTH+CTRL_WIDTH),
             .SRAM_ADDR_WIDTH (SRAM_ADDR_WIDTH))
             sram_fifo
               (.wr_ack                           (wr_ack[i]),
                .space_avail                      (space_avail[(i+1)*SRAM_ADDR_WIDTH-1:i*SRAM_ADDR_WIDTH]),
                .rd_ack                           (),
                .rd_data                          (rd_data),
                .rd_vld                           (rd_vld),
                .words_avail                      (words_avail[i]),
                .sram_wr_addr                     (sram_wr_addr[(i+1)*SRAM_ADDR_WIDTH-1:i*SRAM_ADDR_WIDTH]),
                .sram_wr_req                      (sram_wr_req[i]),
                .sram_wr_data                     (sram_wr_data[(i+1)*SRAM_WIDTH-1:i*SRAM_WIDTH]),
                .sram_rd_addr                     (sram_rd_addr[(i+1)*SRAM_ADDR_WIDTH-1:i*SRAM_ADDR_WIDTH]),
                .sram_rd_req                      (sram_rd_req[i]),
                .sram_rd_data                     (sram_rd_data),
                .sram_rd_vld                      (sram_rd_vld[i]),
                .wr_data                          ({in_fifo_ctrl, in_fifo_data}),
                .wr_req                           (wr_req[i]),
                .rd_req                           (rd_req),
                .addr_high                        (addr_high),
                .addr_low                         (addr_low),
                .sram_wr_ack                      (sram_wr_ack[i]),
                .sram_rd_ack                      (sram_rd_ack[i]),
                .reset                            (reset),
                .clk                              (clk));

         /* this fifo is needed to account for the latency of the
          * out_rdy signals */
         fallthrough_small_fifo
           #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
             .MAX_DEPTH_BITS(3),
             .PROG_FULL_THRESHOLD(2)) /* make smaller as SRAM latency increases */
             latency_fifo
               (.dout         ({out_ctrl[i], out_data[i]}),
                .full         (),
                .nearly_full  (),
                .prog_full    (latency_fifo_almost_full),
                .empty        (latency_fifo_empty),
                .din          (rd_data),
                .wr_en        (rd_vld),
                .rd_en        (latency_fifo_rd_en),
                .reset        (reset),
                .clk          (clk));

         assign rd_req               = words_avail[i] != 0 && !latency_fifo_almost_full;
         assign latency_fifo_rd_en   = out_rdy[i] && !latency_fifo_empty;
         assign out_wr[i]            = out_rdy[i] && !latency_fifo_empty;

      end // block: gen_sram_fifos
   endgenerate

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (`OQ_BLOCK_ADDR),
       .REG_ADDR_WIDTH (`OQ_REG_ADDR_WIDTH),
       .NUM_COUNTERS (3*NUM_OUTPUT_QUEUES),
       .NUM_SOFTWARE_REGS (1),
       .NUM_HARDWARE_REGS (NUM_OUTPUT_QUEUES),
       .COUNTER_INPUT_WIDTH (PKT_LEN_WIDTH))
   generic_regs
     (
      .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),

      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),

      // --- counters interface
      .counter_updates   ({{10'h0, pkt_dropped[7]}, {10'h0, pkt_stored[7]}, bytes_in[7],
                           {10'h0, pkt_dropped[6]}, {10'h0, pkt_stored[6]}, bytes_in[6],
                           {10'h0, pkt_dropped[5]}, {10'h0, pkt_stored[5]}, bytes_in[5],
                           {10'h0, pkt_dropped[4]}, {10'h0, pkt_stored[4]}, bytes_in[4],
                           {10'h0, pkt_dropped[3]}, {10'h0, pkt_stored[3]}, bytes_in[3],
                           {10'h0, pkt_dropped[2]}, {10'h0, pkt_stored[2]}, bytes_in[2],
                           {10'h0, pkt_dropped[1]}, {10'h0, pkt_stored[1]}, bytes_in[1],
                           {10'h0, pkt_dropped[0]}, {10'h0, pkt_stored[0]}, bytes_in[0]}
                          ),
      .counter_decrement ({(3*NUM_OUTPUT_QUEUES){1'b0}}),

      // --- SW regs interface
      .software_regs     (),

      // --- HW regs interface
      .hardware_regs     ({{(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[7],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[6],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[5],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[4],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[3],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[2],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[1],
                           {(32 - SRAM_ADDR_WIDTH){1'b0}}, words_avail[0]
                           }
                          ),

      .clk               (clk),
      .reset             (reset));

   //------------------ Logic ------------------------
   assign dst_oq_found = in_fifo_data[`IOQ_DST_PORT_POS + NUM_OUTPUT_QUEUES-1:`IOQ_DST_PORT_POS];
   assign in_rdy = !in_fifo_nearly_full;

   /* generate wires that check for space */
   generate
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:gen_space_avail
         /* set to one if we don't care b/c we are not writing to it or
          * if indeed there is enough space */
         assign enough_space_is_avail[i] = !dst_oq[i] || space_avail_reg[(i+1)*SRAM_ADDR_WIDTH-1:i*SRAM_ADDR_WIDTH] > pkt_wlen;
      end
   endgenerate

   /* read incoming packets and write them into their
    * destination queues */
   always @(*) begin
      state_nxt       = state;
      pkt_len_nxt     = pkt_len;
      pkt_wlen_nxt    = pkt_wlen;
      dst_oq_nxt      = dst_oq;
      latch_space     = 0;
      in_fifo_rd_en   = 0;
      wr_req          = 0;
      pkt_stored      = 0;
      pkt_dropped     = 0;
      acked_nxt       = acked;

      case (state)
         /* drop all headers except IOQ header */
         WAIT_FOR_IOQ_HEADER: begin
            if(!in_fifo_empty) begin
               if(in_fifo_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  state_nxt       = CHECK_SPACE;
                  pkt_len_nxt     = in_fifo_data[`IOQ_BYTE_LEN_POS + PKT_LEN_WIDTH-1:`IOQ_BYTE_LEN_POS];
                  /* add 1 to account for extra module header */
                  pkt_wlen_nxt    = in_fifo_data[`IOQ_WORD_LEN_POS + PKT_WORDS_WIDTH-1:`IOQ_WORD_LEN_POS] + 1'b1;
                  dst_oq_nxt      = dst_oq_found;
                  latch_space     = 1'b1;
               end
               // synthesis translate_off
               else if(in_fifo_ctrl == 0) begin
                  $display("%t %m ERROR: Did not find IOQ header in pkt.", $time);
               end
               // synthesis translate_on
               else begin
                  in_fifo_rd_en    = 1;
               end
            end // if (!in_fifo_empty)
         end // case: WAIT_FOR_IOQ_HEADER

         /* check if the queues have space */
         CHECK_SPACE: begin
            /* check if we can write anywhere */
            if(|(enough_space_is_avail & dst_oq)) begin
               state_nxt     = STORE_HDR_MODULE;
               /* only write to queues that have space */
               dst_oq_nxt    = enough_space_is_avail & dst_oq;
	       /* indicate drops */
	       pkt_dropped   = dst_oq & ~enough_space_is_avail;
            end
            else begin
               state_nxt       = DROP_PKT;
               in_fifo_rd_en   = 1;
            end
         end // case: CHECK_SPACE

         /* store the IOQ hdr, and drop the rest */
         STORE_HDR_MODULE: begin
            if(!in_fifo_empty) begin
               if(in_fifo_ctrl == `IO_QUEUE_STAGE_NUM || in_fifo_ctrl == 0) begin
                  /* write to all dst oqs. Don't req writes for ones that have
                   * been acked already */
                  wr_req      = dst_oq & ~acked;
                  acked_nxt   = acked | wr_ack;

                  /* if all are acked */
                  if((acked | wr_ack) == dst_oq) begin
                     in_fifo_rd_en  = 1'b1;
                     acked_nxt      = 0;
                     if(in_fifo_ctrl == 0) begin
                        state_nxt   = STORE_PKT;
                     end
                  end
               end // if (in_fifo_ctrl == `IO_QUEUE_STAGE_NUM || in_fifo_ctrl == 0)
               else begin
                  in_fifo_rd_en = 1'b1;
               end // else: !if(in_fifo_ctrl == `IO_QUEUE_STAGE_NUM || in_fifo_ctrl == 0)
            end // if (!in_fifo_empty)
         end // case: STORE_HDR_MODULE

         /* store pkt data till the end */
         STORE_PKT: begin
            if(!in_fifo_empty) begin
               /* write to all dst oqs. Don't req writes for ones that have
                * been acked already */
               wr_req      = dst_oq & ~acked;
               acked_nxt   = acked | wr_ack;

               /* if all are acked */
               if((acked | wr_ack) == dst_oq) begin
                  in_fifo_rd_en  = 1'b1;
                  acked_nxt      = 0;
                  if(in_fifo_ctrl != 0) begin // eop
                     state_nxt    = WAIT_FOR_IOQ_HEADER;
                     pkt_stored   = dst_oq;
                  end
               end
            end
         end // case: STORE_PKT

         DROP_PKT: begin
            if(!in_fifo_empty) begin
               in_fifo_rd_en = 1'b1;
               if(in_fifo_ctrl != 0 && in_fifo_ctrl_prev_0) begin
                  state_nxt             = WAIT_FOR_IOQ_HEADER;
                  pkt_dropped           = dst_oq;
               end
            end
         end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state                  <= WAIT_FOR_IOQ_HEADER;
         pkt_len                <= 0;
         pkt_wlen               <= 0;
         dst_oq                 <= 0;
         space_avail_reg        <= 0;
         in_fifo_ctrl_prev_0    <= 0;
         acked                  <= 0;
      end
      else begin
         state          <= state_nxt;
         pkt_len        <= pkt_len_nxt;
         pkt_wlen       <= pkt_wlen_nxt;
         dst_oq         <= dst_oq_nxt;
         acked          <= acked_nxt;
         if(latch_space) begin
            space_avail_reg <= space_avail;
         end
         if(in_fifo_rd_en) begin
            in_fifo_ctrl_prev_0 <= in_fifo_ctrl == 0;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

   /* logic to update the registers */
   generate
      for (i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:reg_updates
         assign bytes_in[i]      = pkt_stored[i] ? pkt_len : 0;
      end
   endgenerate

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

   assign {out_ctrl_0, out_data_0} =  {out_ctrl[0], out_data[0]};
   assign {out_ctrl_1, out_data_1} =  {out_ctrl[1], out_data[1]};
   assign {out_ctrl_2, out_data_2} =  {out_ctrl[2], out_data[2]};
   assign {out_ctrl_3, out_data_3} =  {out_ctrl[3], out_data[3]};
   assign {out_ctrl_4, out_data_4} =  {out_ctrl[4], out_data[4]};
   assign {out_ctrl_5, out_data_5} =  {out_ctrl[5], out_data[5]};
   assign {out_ctrl_6, out_data_6} =  {out_ctrl[6], out_data[6]};
   assign {out_ctrl_7, out_data_7} =  {out_ctrl[7], out_data[7]};

endmodule // output_queues

