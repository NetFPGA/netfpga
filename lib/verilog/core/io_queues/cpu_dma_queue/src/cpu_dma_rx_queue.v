///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_main.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: cpu_dma_rx_queue.v
// Project: NF2.1
// Description: Receive queue for CPU DMA queue
//
//              A slim CPU rx_fifo connecting to the DMA interface.
//              FIFO is first-word-fall-through.
//
//              Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
// Note (1): Receive is relative to the NetFPGA -- this is, receive represents
// transfers from the host to the NetFPGA.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_rx_queue
   #(
      parameter DATA_WIDTH       = 64,
      parameter CTRL_WIDTH       = DATA_WIDTH/8,
      parameter ENABLE_HEADER    = 0,
      parameter STAGE_NUMBER     = 'hff,
      parameter DMA_DATA_WIDTH   = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH   = DMA_DATA_WIDTH/8,
      parameter PORT_NUMBER      = 0
   )
   (
      output reg [DATA_WIDTH-1:0]   out_data,
      output reg [CTRL_WIDTH-1:0]   out_ctrl,
      output reg                    out_wr,
      input                         out_rdy,

      // DMA wr txfifo interface
      output reg                    cpu_q_dma_nearly_full,
      output reg                    cpu_q_dma_can_wr_pkt,

      input                         cpu_q_dma_wr,
      input                         cpu_q_dma_wr_pkt_vld,
      input [DMA_DATA_WIDTH-1:0]    cpu_q_dma_wr_data,
      input [DMA_CTRL_WIDTH-1:0]    cpu_q_dma_wr_ctrl,

      // Register interface -- RX
      input                         rx_queue_en,
      output  reg                   rx_pkt_stored,
      output  reg                   rx_pkt_dropped,
      output  reg                   rx_pkt_removed,
      output  reg                   rx_q_underrun,
      output  reg                   rx_q_overrun,
      output  reg [11:0]            rx_pkt_byte_cnt,
      output  reg [9:0]             rx_pkt_word_cnt,

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

   localparam OUT_WAIT_FOR_PKT         = 2'h0;
   localparam OUT_XFER_PKT             = 2'h1;
   localparam OUT_DROP_PKT             = 2'h2;

   // ------------- Wires/reg ------------------

   reg [5:0]                           num_pkts_in_q; //the max count of pkts is 35.

   reg                                 input_in_pkt;

   reg                                 rx_fifo_rd_en;
   wire                                rx_fifo_wr_en;

   // wires from rx_fifo
   wire                                rx_fifo_full;
   wire                                rx_fifo_almost_full;
   wire                                rx_fifo_prog_full;
   wire                                rx_fifo_empty;

   wire [DATA_WIDTH-1:0]               out_data_local;
   wire [CTRL_WIDTH-1:0]               out_ctrl_local;

   reg [PKT_BYTE_CNT_WIDTH-1:0]        num_bytes_written;

   wire                                pkt_vld_out;
   wire [PKT_BYTE_CNT_WIDTH-1:0]       pkt_byte_len_out;
   wire [PKT_WORD_CNT_WIDTH-1:0]       pkt_word_len_out;

   wire [`IOQ_WORD_LEN_POS - `IOQ_SRC_PORT_POS-1:0] port_number = PORT_NUMBER;

   wire [DMA_DATA_WIDTH-1:0]           rx_fifo_data_in;
   wire [DMA_CTRL_WIDTH-1:0]           rx_fifo_ctrl_in;

   wire [PKT_WORD_CNT_WIDTH-1:0]       rx_pkt_word_cnt_nxt;

   reg [DATA_WIDTH-1:0]                out_data_nxt;
   reg [CTRL_WIDTH-1:0]                out_ctrl_nxt;
   reg                                 out_wr_nxt;
   wire                                pkt_len_nearly_full;

   reg                                 rx_pkt_vld;

   reg [1:0]                           out_state;
   reg [1:0]                           out_state_nxt;

   reg                                 local_pkt_stored;
   reg                                 local_pkt_stored_nxt;
   reg                                 local_pkt_removed;
   reg                                 local_pkt_removed_nxt;

   // ------------- Modules -------------------

   generate
      if(DATA_WIDTH == 32) begin: cpu_fifos32

         cdq_rx_fifo_512x36 rx_fifo (
            .din        ({rx_fifo_ctrl_in, rx_fifo_data_in}),
            .wr_en      (rx_fifo_wr_en),

            .dout       ({out_ctrl_local, out_data_local}),
            .rd_en      (rx_fifo_rd_en),

            .full       (rx_fifo_full),
            .almost_full(rx_fifo_almost_full),
            .prog_full  (rx_fifo_prog_full),
            .empty      (rx_fifo_empty),

            .clk        (clk),
            .rst        (reset)
         );

      end // block: cpu_rx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         wire [CTRL_WIDTH+DATA_WIDTH-1:0]    rx_fifo_dout;
         wire [DMA_CTRL_WIDTH+DMA_DATA_WIDTH-1:0] rx_fifo_din;

         // The control/data words are mixed due to 32->64 bit conversion.
         // Reorder these.
         assign out_ctrl_local = {rx_fifo_dout[71:68], rx_fifo_dout[35:32]};
         assign out_data_local = {rx_fifo_dout[67:36], rx_fifo_dout[31:0]};

         // Pad the data being written to add ensure a whole number of words
         reg need_pad;
         always @(posedge clk)
         begin
            if (reset)
               need_pad <= 0;
            else begin
               if (rx_fifo_wr_en)
                  need_pad <= !need_pad;
               else if (!input_in_pkt && need_pad)
                  need_pad <= 0;
            end
         end
         assign rx_fifo_din = (need_pad && !input_in_pkt) ? 'h0 :
            {rx_fifo_ctrl_in, rx_fifo_data_in};

         // Note: An *async* fifo is used because of the width change. The
         // Xilinx FIFO generator only supports width changes in asyncrhonous
         // FIFOs.
         //
         // Unforunately this has the side effect of increasing the delay
         // between writing data and having that data availabe at the output.
         cdq_rx_fifo_512x36_to_72 rx_fifo (
            .din        (rx_fifo_din),
            .wr_en      (rx_fifo_wr_en || (need_pad && !input_in_pkt)),

            .dout       (rx_fifo_dout),
            .rd_en      (rx_fifo_rd_en),

            .full       (rx_fifo_full),
            .almost_full(rx_fifo_almost_full),
            .prog_full  (rx_fifo_prog_full),
            .empty      (rx_fifo_empty),

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
    #(.WIDTH (PKT_BYTE_CNT_WIDTH+1),
      .MAX_DEPTH_BITS (3)
   ) pkt_len_fifo (

     .din            ({rx_pkt_vld, rx_pkt_byte_cnt}),
     .wr_en          (local_pkt_stored),

     .rd_en          (local_pkt_removed),

     .dout           ({pkt_vld_out, pkt_byte_len_out}),
     .full           (),
     .nearly_full    (pkt_len_nearly_full),
     .prog_full      (),
     .empty          (pkt_len_fifo_empty),

     .reset          (reset),
     .clk            (clk)
   );


   // -------------- Logic --------------------

   generate
      // Reorder the input: CPU uses little endian, the User Data Path uses
      // big endian
      genvar k;
      for(k=0; k<DMA_CTRL_WIDTH; k=k+1) begin: reorder_endianness
         assign rx_fifo_ctrl_in[k] = cpu_q_dma_wr_ctrl[DMA_CTRL_WIDTH-1-k];
         assign rx_fifo_data_in[8*k+:8] = cpu_q_dma_wr_data[DMA_DATA_WIDTH-8-8*k+:8];
      end

      // Calculate the word length of the packet
      if (ENABLE_HEADER) begin
         assign pkt_word_len_out = pkt_byte_len_out[LAST_WORD_BYTE_CNT_WIDTH-1:0] == 0 ?
            pkt_byte_len_out[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] :
            pkt_byte_len_out[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] + 1;
      end
   endgenerate

   // Calculate the word length based on the byte length
   assign rx_pkt_word_cnt_nxt = cpu_q_dma_wr_data[LAST_WORD_BYTE_CNT_WIDTH-1:0] == 'h0 ?
      cpu_q_dma_wr_data[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] :
      cpu_q_dma_wr_data[PKT_BYTE_CNT_WIDTH-1:LAST_WORD_BYTE_CNT_WIDTH] + 'h1;


   // Output state machine
   always @* begin
      rx_fifo_rd_en = 0;
      rx_pkt_removed = 0;
      local_pkt_removed = 0;
      out_data_nxt = 'h0;
      out_ctrl_nxt = 'h0;
      out_wr_nxt = 0;
      out_state_nxt = out_state;

      if (reset) begin
         out_state_nxt = OUT_WAIT_FOR_PKT;
      end
      else begin
         case (out_state)
            // Wait for a packet to be placed in the FIFO
            // The entire packet must be in the FIFO before proceeding.
            OUT_WAIT_FOR_PKT: begin
               if (out_rdy && !pkt_len_fifo_empty) begin
                  if (pkt_vld_out) begin
                     if (ENABLE_HEADER) begin
                        out_data_nxt =
                              {pkt_word_len_out,
                               port_number,
                               {(`IOQ_SRC_PORT_POS - PKT_BYTE_CNT_WIDTH){1'b0}},
                               pkt_byte_len_out};
                        out_ctrl_nxt = STAGE_NUMBER;
                        out_state_nxt = OUT_XFER_PKT;
                     end
                     else begin
                        out_data_nxt = out_data_local;
                        out_ctrl_nxt = out_ctrl_local;
                        if (out_ctrl_local != 'h0) begin
                           rx_pkt_removed = 1;
                           local_pkt_removed = 1;
                           out_state_nxt = OUT_WAIT_FOR_PKT;
                        end
                        else
                           out_state_nxt = OUT_XFER_PKT;
                        rx_fifo_rd_en = 1;
                     end
                     out_wr_nxt = 1;
                  end
                  else begin
                     out_state_nxt = OUT_DROP_PKT;
                  end
               end
            end

            // Send the packet to the user data path
            OUT_XFER_PKT: begin
               if (out_rdy) begin
                  out_data_nxt = out_data_local;
                  out_ctrl_nxt = out_ctrl_local;
                  if (out_ctrl_local != 'h0) begin
                     rx_pkt_removed = 1;
                     local_pkt_removed = 1;
                     out_state_nxt = OUT_WAIT_FOR_PKT;
                  end
                  rx_fifo_rd_en = 1;
                  out_wr_nxt = 1;
               end
            end

            // Drop the packet (an invalid packet was written into the FIFO,
            // most likely as a result of a DMA timeout)
            OUT_DROP_PKT: begin
               if (out_ctrl_local != 'h0) begin
                  local_pkt_removed = 1;
                  out_state_nxt = OUT_WAIT_FOR_PKT;
               end
               rx_fifo_rd_en = 1;
            end
         endcase
      end
   end

   always @(posedge clk) begin
      out_state <= out_state_nxt;
      out_data <= out_data_nxt;
      out_ctrl <= out_ctrl_nxt;
      out_wr <= out_wr_nxt;
   end

   assign rx_fifo_wr_en = cpu_q_dma_wr && (!rx_fifo_full) && input_in_pkt;

   // Input state machine
   always @(posedge clk) begin
      if(reset) begin
         rx_pkt_byte_cnt         <= 'h0;
         rx_pkt_word_cnt         <= 'h0;
         input_in_pkt            <= 1'b 0;
         rx_pkt_vld              <= 1'b 0;
         rx_pkt_stored           <= 1'b 0;
         local_pkt_stored           <= 1'b 0;
         num_bytes_written       <= 'h 0;
      end // if (reset)

      else begin
         // Track where we are in a packet
         if (cpu_q_dma_wr && !input_in_pkt) begin
            input_in_pkt <= 1;
            rx_pkt_byte_cnt <= cpu_q_dma_wr_data;
            rx_pkt_word_cnt <= rx_pkt_word_cnt_nxt;
         end
         else if (cpu_q_dma_wr && input_in_pkt && cpu_q_dma_wr_ctrl != 0)
            input_in_pkt <= 0;

         // Calculate the number of bytes written
         //if (rx_fifo_wr_en) begin
         //   if (!input_in_pkt)
         //      num_bytes_written <= 'h4;
         //   else begin
         //      case (cpu_q_dma_wr_ctrl)
         //         'h8:     num_bytes_written <= num_bytes_written + 4;
         //         'h4:     num_bytes_written <= num_bytes_written + 3;
         //         'h2:     num_bytes_written <= num_bytes_written + 2;
         //         'h1:     num_bytes_written <= num_bytes_written + 1;
         //         default: num_bytes_written <= num_bytes_written + 4;
         //      endcase
         //   end
         //end

         // Packet stored/dropped signals
         //
         // Note: The rx_pkt_stored signal indicates the storage of a *good*
         // packet, whereas local_pkt_stored indicates the storage of *any*
         // packet.
         rx_pkt_vld <= cpu_q_dma_wr_pkt_vld;
         rx_pkt_stored <= rx_fifo_wr_en && (| cpu_q_dma_wr_ctrl) && cpu_q_dma_wr_pkt_vld;
         rx_pkt_dropped <= rx_fifo_wr_en && (| cpu_q_dma_wr_ctrl) && !cpu_q_dma_wr_pkt_vld;
         local_pkt_stored <= rx_fifo_wr_en && (| cpu_q_dma_wr_ctrl);
      end // else: !if(reset)

   end // always @ (posedge clk)


   // Joint state machine to track queue occupancy
   always @(posedge clk) begin
      if(reset) begin
	 num_pkts_in_q           <= 'h 0;
	 cpu_q_dma_nearly_full   <= 1'b 0;
	 cpu_q_dma_can_wr_pkt    <= 1'b 0;
      end // if (reset)
      else begin
         case ({rx_pkt_removed, rx_pkt_stored})
           2'b 10: num_pkts_in_q <= num_pkts_in_q - 'h 1;
           2'b 01: num_pkts_in_q <= num_pkts_in_q + 'h 1;
         endcase // case({rx_pkt_removed, rx_pkt_stored})

	 cpu_q_dma_nearly_full <= rx_fifo_almost_full ||
                                  pkt_len_nearly_full ||
                                  !rx_queue_en;
	 cpu_q_dma_can_wr_pkt <= !rx_fifo_prog_full &&
                                 !pkt_len_nearly_full &&
                                 rx_queue_en;
      end
   end

   // Register update logic
   always @(posedge clk)
   begin
      rx_q_underrun <= rx_fifo_rd_en && rx_fifo_empty;
      rx_q_overrun <= cpu_q_dma_wr && rx_fifo_full;
   end

endmodule // cpu_dma_rx_queue
