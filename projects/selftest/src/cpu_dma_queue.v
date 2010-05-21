///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: cpu_dma_queue.v
// Project: NF2.1
// Description: If enable_dma signal is asserted, supports CPU access to
//              rx_fifo and tx_fifo using DMA. Otherwise,
//              supports CPU access to rx_fifo and tx_fifo using
//              register read and write.
//
//              Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
///////////////////////////////////////////////////////////////////////////////

module cpu_dma_queue
   #(
      parameter DATA_WIDTH = 32,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter DMA_DATA_WIDTH = `CPCI_NF2_DATA_WIDTH,
      parameter DMA_CTRL_WIDTH = DMA_DATA_WIDTH/8
   )
   (
      // --- DMA rd rxfifo interface
      output                               cpu_q_dma_pkt_avail,
      output                               cpu_q_dma_rd_rdy,

      input                                cpu_q_dma_rd,
      output [DMA_DATA_WIDTH-1:0]          cpu_q_dma_rd_data,
      output [DMA_CTRL_WIDTH-1:0]          cpu_q_dma_rd_ctrl,

      // DMA wr txfifo interface
      output                               cpu_q_dma_nearly_full,
      output                               cpu_q_dma_can_wr_pkt,

      input                                cpu_q_dma_wr,
      input                                cpu_q_dma_wr_pkt_vld,
      input [DMA_DATA_WIDTH-1:0]           cpu_q_dma_wr_data,
      input [DMA_CTRL_WIDTH-1:0]           cpu_q_dma_wr_ctrl,

      // --- Misc
      input                                reset,
      input                                clk
    );

   // -------- Internal parameters --------------
   parameter TX_FIFO_DEPTH = 512;

   // ------------- Wires/reg ------------------

   wire                                rx_fifo_rd_en;
   wire                                rx_fifo_wr_en;

   // wires from rx_fifo
   wire                                rx_fifo_full;
   wire                                rx_fifo_almost_full;
   wire                                rx_fifo_prog_full;
   wire                                rx_fifo_empty;

   wire                                pkt_stored;
   wire                                pkt_removed;
   wire                                first_word_removed;

   reg [3:0]                           pkt_count;
   reg                                 input_in_pkt;
   reg                                 output_in_pkt;


   // ------------- Modules -------------------

   // pkt data and ctrl stored in rx_fifo are in little endian
   cdq_rx_fifo_512x36 rx_fifo (
      .din        ({cpu_q_dma_wr_ctrl, cpu_q_dma_wr_data}),
      .wr_en      (rx_fifo_wr_en),

      .dout       ({cpu_q_dma_rd_ctrl, cpu_q_dma_rd_data}),
      .rd_en      (rx_fifo_rd_en),

      .full       (rx_fifo_full),
      .almost_full(rx_fifo_almost_full),
      .prog_full  (rx_fifo_prog_full),
      .empty      (rx_fifo_empty),

      .clk        (clk),
      .rst        (reset)
   );

   // -------------- Logic --------------------

   assign rx_fifo_wr_en = (cpu_q_dma_wr) && (!rx_fifo_full);
   assign rx_fifo_rd_en = (cpu_q_dma_rd) && (!rx_fifo_empty);

   assign cpu_q_dma_can_wr_pkt = !rx_fifo_prog_full;
   assign cpu_q_dma_nearly_full = rx_fifo_almost_full;

   assign cpu_q_dma_rd_rdy = !rx_fifo_empty;
   assign cpu_q_dma_pkt_avail = pkt_count != 'h0;

   assign pkt_stored = input_in_pkt && cpu_q_dma_wr && cpu_q_dma_wr_ctrl != 'h0;
   assign pkt_removed = output_in_pkt && cpu_q_dma_rd && cpu_q_dma_rd_ctrl != 'h0;
   assign first_word_removed = !output_in_pkt && cpu_q_dma_rd;


   // Count the number of packets in the queue
   always @(posedge clk) begin
      if (reset) begin
         pkt_count <= 'h0;
         input_in_pkt <= 0;
         output_in_pkt <= 0;
      end
      else begin
         case (input_in_pkt)
            1'b0: begin
               if (cpu_q_dma_wr && cpu_q_dma_wr_ctrl == 'h0)
                  input_in_pkt <= 1;
            end

            1'b1: begin
               if (cpu_q_dma_wr && cpu_q_dma_wr_ctrl != 'h0)
                  input_in_pkt <= 0;
            end
         endcase

         case (output_in_pkt)
            1'b0: begin
               if (cpu_q_dma_rd && cpu_q_dma_rd_ctrl == 'h0)
                  output_in_pkt <= 1;
            end

            1'b1: begin
               if (cpu_q_dma_rd && cpu_q_dma_rd_ctrl != 'h0)
                  output_in_pkt <= 0;
            end
         endcase

         case ({pkt_stored, first_word_removed})
            2'b10: pkt_count <= pkt_count + 'h1;
            2'b01: pkt_count <= pkt_count - 'h1;
         endcase
      end
   end

   // Verify that only one header word exists on each packet

   // synthesis translate_off
   reg seen_header_word;
   always @(posedge clk) begin
      if (reset)
         seen_header_word <= 0;
      else begin
         if (!input_in_pkt && cpu_q_dma_wr) begin
            if (cpu_q_dma_wr_ctrl != 'h0) begin
               if (!seen_header_word)
                  seen_header_word <= 1;
               else begin
                  $display($time, " ERROR: %m: Saw two header words on an incoming packet. Expecting only one.");
                  $finish;
               end
            end
         end
         else if (input_in_pkt && cpu_q_dma_wr) begin
            seen_header_word <= 1;
         end
      end
   end
   // synthesis translate_on

endmodule // cpu_dma_queue
