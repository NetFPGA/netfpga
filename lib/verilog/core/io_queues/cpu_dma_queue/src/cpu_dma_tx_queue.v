///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: cpu_dma_tx_queue.v
// Project: NF2.1
// Description: Transmit queue for CPU DMA queue
//
//              A slim CPU tx_fifo connecting to the DMA interface.
//              FIFO is first-word-fall-through.
//
// Note (1): Transmit is relative to the NetFPGA -- this is, transmit represents
// transfers from the NetFPGA to the host.
//
// Note (2): Pakcets *must* have the 0xff header for this module to work
// correctly.
//
// Explanation of signals:
//
//   cpu_q_dma_pkt_avail: One or more *complete* packets are in the queue.
//      - The signal is only asserted after the *last* word of a packet is
//        written if the queue was previously empty.
//      - The signal is deasserted when the first word is read when the queue
//        contains only a single packet.
//
//   cpu_q_dma_rd_rdy: Data is available for reading on the data/ctrl buses.
//      - Asserted independently of the dma_pkt_avail signal
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_tx_queue
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter ENABLE_HEADER    = 0,
      parameter STAGE_NUMBER     = 'hff,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8
   )
   (
      input  [DATA_WIDTH-1:0]       in_data,
      input  [CTRL_WIDTH-1:0]       in_ctrl,
      input                         in_wr,
      output                        in_rdy,

      // --- DMA rd nterface
      output                        cpu_q_dma_pkt_avail,
      output reg                    cpu_q_dma_rd_rdy,

      input                         cpu_q_dma_rd,
      output reg [DMA_DATA_WIDTH-1:0] cpu_q_dma_rd_data,
      output reg [DMA_CTRL_WIDTH-1:0] cpu_q_dma_rd_ctrl,

      // Register interface -- TX
      input                         tx_queue_en,
      output reg                    tx_pkt_stored,
      output reg                    tx_pkt_removed,
      output reg                    tx_q_underrun,
      output reg                    tx_q_overrun,
      output reg [11:0]             tx_pkt_byte_cnt,
      output reg [9:0]              tx_pkt_word_cnt,

      // --- Misc
      input                         reset,
      input                         clk
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

   // -------- Internal parameters --------------

   localparam MAX_PKT_SIZE             = 2048;

   localparam LAST_WORD_BYTE_CNT_WIDTH = log2(CTRL_WIDTH);
   localparam PKT_BYTE_CNT_WIDTH       = log2(MAX_PKT_SIZE)+1;
   localparam PKT_WORD_CNT_WIDTH       = PKT_BYTE_CNT_WIDTH - LAST_WORD_BYTE_CNT_WIDTH;

   localparam IN_PROCESS_HDR           = 1'b0;
   localparam IN_PROCESS_BODY          = 1'b1;

   localparam OUT_PROCESS_HDR          = 1'b0;
   localparam OUT_PROCESS_BODY         = 1'b1;

   // ------------- Wires/reg ------------------

   reg [5:0]                           num_pkts_in_q; //the max count of pkts is 35.

   reg                                 tx_fifo_rd;

   // wires from endianness reordering
   wire [CTRL_WIDTH-1:0]               tx_fifo_ctrl_in;
   wire [DATA_WIDTH-1:0]               tx_fifo_data_in;

   // wires from tx_fifo
   wire [DMA_CTRL_WIDTH-1:0]           tx_fifo_ctrl_out;
   wire [DMA_DATA_WIDTH-1:0]           tx_fifo_data_out;
   wire                                tx_fifo_almost_full;
   wire                                tx_fifo_full;
   wire                                tx_fifo_empty;

   reg [PKT_BYTE_CNT_WIDTH-1:0]        tx_pkt_byte_cnt_nxt;

   reg [PKT_WORD_CNT_WIDTH-1:0]        tx_pkt_word_cnt_nxt;

   wire [PKT_BYTE_CNT_WIDTH-1:0]       curr_pkt_byte_len;
   wire [PKT_WORD_CNT_WIDTH-1:0]       curr_pkt_word_len;

   wire [PKT_BYTE_CNT_WIDTH-1:0]       pkt_len_out;

   reg                                 tx_pkt_stored_nxt;

   reg                                 in_state;
   reg                                 in_state_nxt;

   reg                                 out_state;
   reg                                 out_state_nxt;

   reg                                 tx_fifo_wr;
   reg                                 pkt_len_wr;
   reg                                 pkt_len_wr_nxt;
   reg                                 pkt_len_rd;


   // ------------- Modules -------------------
   generate
      if(DATA_WIDTH == 32) begin: cpu_fifos32

	 // pkt data and ctrl stored in tx_fifo are in little endian
         cdq_tx_fifo_512x36 tx_fifo (
            .din        ({tx_fifo_ctrl_in, tx_fifo_data_in}),
            .wr_en      (tx_fifo_wr),

	    .dout       ({tx_fifo_ctrl_out, tx_fifo_data_out}),
            .rd_en      (tx_fifo_rd),

            .full       (tx_fifo_full),
            .almost_full(tx_fifo_almost_full),
            .empty      (tx_fifo_empty),

            .rst        (reset),
            .clk        (clk)
	    );

      end // block: cpu_tx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         /* need to reorder for endianness and so that ctrl is next to data on the cpu side*/
         wire [CTRL_WIDTH+DATA_WIDTH-1:0] tx_fifo_din;
         assign tx_fifo_din = {tx_fifo_ctrl_in[3:0], tx_fifo_data_in[31:0],
                               tx_fifo_ctrl_in[7:4], tx_fifo_data_in[63:32]};

         // Deal with 64->32 width change tracking the need for an extra read
         reg aligned64;
         wire need_extra_rd = !aligned64 && out_state != OUT_PROCESS_BODY;
         always @(posedge clk) begin
            if (reset)
               aligned64 <= 1'b1;
            else begin
               if (tx_fifo_rd)
                  aligned64 <= !aligned64;
               else if (need_extra_rd)
                  aligned64 <= 1'b1;
            end
         end

         // stored in little endian for each 32-bit data and 4-bit ctrl
         //
         // Note: An *async* fifo is used because of the width change. The
         // Xilinx FIFO generator only supports width changes in asyncrhonous
         // FIFOs.
         //
         // Unforunately this has the side effect of increasing the delay
         // between writing data and having that data availabe at the output.
         cdq_tx_fifo_256x72_to_36 tx_fifo (
            .din        (tx_fifo_din),
            .wr_en      (tx_fifo_wr),

	    .dout       ({tx_fifo_ctrl_out, tx_fifo_data_out}),
            .rd_en      (tx_fifo_rd || need_extra_rd),

            .full       (tx_fifo_full),
            .almost_full(tx_fifo_almost_full),
            .empty      (tx_fifo_empty),

            .rst        (reset),
            .wr_clk     (clk),
            .rd_clk     (clk)
	    );

     end // block: cpu_fifos64

   endgenerate

   /* Whenever a packet is received, this fifo will store its status
    * and length after it is done. This is used to indicate that a packet is
    * available and whether it is good to read.
    * The depth of this fifo has to be the max number of pkt in the
    * rxfifo.
    */
  fallthrough_small_fifo
    #(.WIDTH (PKT_BYTE_CNT_WIDTH),
      .MAX_DEPTH_BITS (3)
   ) pkt_len_fifo (

     .din            (tx_pkt_byte_cnt),
     .wr_en          (pkt_len_wr),

     .rd_en          (pkt_len_rd),

     .dout           (pkt_len_out),
     .full           (pkt_len_full),
     .nearly_full    (pkt_len_nearly_full),
     .prog_full      (),
     .empty          (pkt_len_empty),

     .reset          (reset),
     .clk            (clk)
   );

   // -------------- Logic --------------------

   generate
      // Reorder the input: CPU uses little endian, the User Data Path uses
      // big endian
      genvar k;
      for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
         assign tx_fifo_ctrl_in[k] = in_ctrl[CTRL_WIDTH-1-k];
         assign tx_fifo_data_in[8*k+:8] = in_data[DATA_WIDTH-8-8*k+:8];
      end
   endgenerate

   assign cpu_q_dma_pkt_avail = num_pkts_in_q != 0 && tx_queue_en;

   // Internal signal generation
   assign in_rdy = !tx_fifo_almost_full && !pkt_len_full;

   // Extract the byte length from the input data
   assign curr_pkt_byte_len = in_data[PKT_BYTE_CNT_WIDTH-1:0];

   generate
      if (CTRL_WIDTH == 8) begin: extract_word_len
         // Extract the word length from the input data
         assign curr_pkt_word_len = in_data[`IOQ_WORD_LEN_POS +: PKT_WORD_CNT_WIDTH];
      end
      else begin: calc_word_len
         // Calculate the word length based on the byte length
         assign curr_pkt_word_len = curr_pkt_byte_len[LAST_WORD_BYTE_CNT_WIDTH-1:0] == 'h0 ?
            curr_pkt_byte_len[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] :
            curr_pkt_byte_len[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] + 'h1;
      end
   endgenerate

   // Input state machine
   always @* begin
      in_state_nxt = in_state;
      tx_pkt_byte_cnt_nxt = tx_pkt_byte_cnt;
      tx_pkt_word_cnt_nxt = tx_pkt_word_cnt;
      tx_pkt_stored_nxt = 0;
      pkt_len_wr_nxt = 0;
      tx_fifo_wr = 0;

      if (reset) begin
         in_state_nxt = IN_PROCESS_HDR;
         tx_pkt_byte_cnt_nxt = 'h0;
         tx_pkt_word_cnt_nxt = 'h0;
      end
      else begin
         case (in_state)
            IN_PROCESS_HDR: begin
               if (in_wr) begin
                  if (in_ctrl == STAGE_NUMBER) begin
                     pkt_len_wr_nxt = 1;
                     tx_pkt_byte_cnt_nxt = curr_pkt_byte_len;
                     tx_pkt_word_cnt_nxt = curr_pkt_word_len;
                  end
                  else if (in_ctrl == 'h0) begin
                     in_state_nxt = IN_PROCESS_BODY;
                     tx_fifo_wr = 1;
                  end
               end
            end

            IN_PROCESS_BODY: begin
               if (in_wr) begin
                  tx_fifo_wr = 1;
                  if (in_ctrl != 'h0) begin
                     in_state_nxt = IN_PROCESS_HDR;
                     tx_pkt_stored_nxt = 1;
                  end
               end
            end
         endcase
      end
   end

   always @(posedge clk) begin
      in_state <= in_state_nxt;
      tx_pkt_byte_cnt <= tx_pkt_byte_cnt_nxt;
      tx_pkt_word_cnt <= tx_pkt_word_cnt_nxt;
      tx_pkt_stored <= tx_pkt_stored_nxt;
      pkt_len_wr <= pkt_len_wr_nxt;
   end

   // Output state machine
   always @* begin
      out_state_nxt = out_state;
      cpu_q_dma_rd_ctrl = 'h0;
      cpu_q_dma_rd_data = 'h0;
      tx_pkt_removed = 0;
      pkt_len_rd = 0;
      tx_fifo_rd = 0;
      cpu_q_dma_rd_rdy = 0;

      if (reset) begin
         out_state_nxt = OUT_PROCESS_HDR;
      end
      else begin
         case (out_state)
            OUT_PROCESS_HDR: begin
               cpu_q_dma_rd_ctrl = 'h0;
               cpu_q_dma_rd_data = pkt_len_out;
               cpu_q_dma_rd_rdy = !pkt_len_empty && tx_queue_en;
               if (cpu_q_dma_rd) begin
                  out_state_nxt = OUT_PROCESS_BODY;
                  pkt_len_rd = 1;
               end
            end

            OUT_PROCESS_BODY: begin
               // Note: the rd_vld signal is independent of tx_queue_en. This
               // is to allow the end of a packet to be read of the queue_en
               // is modified during a packet read.
               cpu_q_dma_rd_ctrl = tx_fifo_ctrl_out;
               cpu_q_dma_rd_data = tx_fifo_data_out;
               cpu_q_dma_rd_rdy = !tx_fifo_empty;
               if (cpu_q_dma_rd && tx_fifo_ctrl_out != 'h0) begin
                  out_state_nxt = OUT_PROCESS_HDR;
                  tx_pkt_removed = 1;
               end
               tx_fifo_rd = cpu_q_dma_rd && (!tx_fifo_empty);
            end
         endcase

      end
   end

   always @(posedge clk) begin
      out_state <= out_state_nxt;
   end

   // Joint state machine to track queue occupancy
   always @(posedge clk) begin
      if(reset) begin
	 num_pkts_in_q        <= 'h 0;
      end // if (reset)
      else begin
         // Track the number of *whole* packets in the FIFO
         //
         // Note: pkt_len_rd is asserted when the first word of a packet is
         // read.
         case ({pkt_len_rd, tx_pkt_stored})
           2'b 10: num_pkts_in_q <= num_pkts_in_q - 'h 1;
           2'b 01: num_pkts_in_q <= num_pkts_in_q + 'h 1;
         endcase // case({pkt_len_rd, tx_pkt_stored})
      end // else: !if(reset)
   end // always @ (posedge clk)


   // Register update logic
   always @(posedge clk)
   begin
      tx_q_underrun <= cpu_q_dma_rd && tx_fifo_empty;
      tx_q_overrun <= in_wr && tx_fifo_full;
   end

endmodule // cpu_dma_tx_queue
