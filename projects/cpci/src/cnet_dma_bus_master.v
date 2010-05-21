///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_dma_bus_master.v 3617 2008-04-16 23:16:30Z grg $
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: cnet_dma_bus_master.v
// Project: CPCI (PCI Control FPGA)
// Description: DMA interface module to the CNET.
//              Manages the crossing of data between the PCI clock domain
//              and the *NET core clock domain.
//              Performs chip to chip communication
//
//              Note: logic in this module is kept to a minimum. Assumes
//              that dma_rd_request will NOT be asserted until the current
//              transfer completes.
//
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module cnet_dma_bus_master
  (
   // CPCI internal signals
   output reg [15:0] dma_pkt_avail,  // Packets available in which buffers in CNET
   input          dma_rd_request,   // Request packet from buffer
   input  [3:0]   dma_rd_request_q,   // Request packet from buffer X

   output [31:0]  dma_rd_data,      // DMA data to be transfered
   input          dma_rd_en,        // Read a word from the buffer

   output reg [15:0] dma_can_wr_pkt, // Space in the Virtex for a full packet

   output reg     dma_queue_info_avail, // Queue information is currently being output

   output         dma_nearly_empty, // Three words or less left in the buffer
   output         dma_empty,        // Is the buffer empty?
   output reg     dma_all_in_buf,   // All data for the packet is in the buffer
   output reg     overflow,         // Indicates a buffer overflow

   input          cnet_reprog,      // Is the CNET being reprogrammed?

   input [31:0]   dma_wr_data,      // DMA data to be transferred
   input          dma_wr_en,        // DMA write data is valid
   output         dma_wr_rdy,       // DMA write interface is ready

   // CNET interface signals

   // --- CPCI DMA handshake signals
   output reg [1:0] cpci_dma_op_code_req,
   output reg [3:0] cpci_dma_op_queue_id,
   input [1:0] cpci_dma_op_code_ack,

   // DMA data and flow control
   // data transfer in:
   input cpci_dma_vld_n2c,
   input [31:0] cpci_dma_data_n2c,
   output reg cpci_dma_q_nearly_full_c2n,

   // data transfer out:
   output reg cpci_dma_vld_c2n,
   output reg [31:0] cpci_dma_data_c2n,
   output reg cpci_dma_data_tri_en,
   input cpci_dma_q_nearly_full_n2c,

   // misc
   input          reset,
   input          pclk,          // PCI clock
   input          nclk           // *NET clock
   );

   // as of now DMA transfer from CPCI to NetFPGA is thru register
   // access interface
   //assign cpci_dma_data_tri_en = 1'b 0;
   //assign cpci_dma_data_c2n = fifo_data;

   wire p2n_dma_full;
   wire p2n_dma_prog_full;

   wire [31:0] fifo_data;
   reg fifo_rd_en;
   wire fifo_empty;


   reg cpci_dma_vld_c2n_nxt;
   reg [31:0] cpci_dma_data_c2n_nxt;
   reg cpci_dma_data_tri_en_nxt;


   //reg for flopping the input signals
   reg [1:0] cpci_dma_op_code_ack_d1;
   reg       cpci_dma_vld_n2c_d1;
   reg [31:0] cpci_dma_data_n2c_d1;
   reg cpci_dma_q_nearly_full_n2c_d1;

   //wires from dma bus master
   reg [31:0] dma_rx_fifo_wr_data;
   reg dma_rx_fifo_wr_en;
   reg [1:0] cpci_dma_op_code_req_nxt;
   reg [3:0] cpci_dma_op_queue_id_nxt;
   reg [15:0] cpci_dma_pkt_avail_nxt, cpci_dma_pkt_avail;
   reg [15:0] cpci_can_wr_pkt_nxt, cpci_can_wr_pkt;
   reg       cpci_dma_queue_info_avail_nxt, cpci_dma_queue_info_avail;
   reg 	     clr_cpci_dma_rx_req;
   reg 	     clr_cpci_dma_tx_req;
   reg 	     ld_rx_expect;
   reg 	     ld_tx_expect;
   reg 	     inc_rx_count;
   reg 	     inc_tx_count;
   reg 	     see_dma_rx_fifo_overflow;
   wire 	     cpci_dma_q_nearly_full_c2n_nxt;

   //wires from dma_rd_request sync logc
   reg cpci_dma_rx_req;
   reg [3:0] cpci_dma_rx_req_q;
   reg cpci_dma_tx_req;

   // Convert the cpci_dma_pkt_avail and cpci_can_wr_pkt signals
   // to the PCI clock domain
   reg [15:0] dma_pkt_avail_p1;
   reg [15:0] dma_can_wr_pkt_p1;
   reg        dma_queue_info_avail_p1;

   // Local signals to propagate the dma_rd_request signals
   reg dma_rd_request_toggle;
   reg [3:0] dma_rd_request_q_held;
   reg n_dma_rd_rq_tgl_p1, n_dma_rd_rq_tgl_p2, n_dma_rd_rq_tgl_p3; // CNET clock domain

   // Is there a new DMA request?
   wire      new_request;

   // Is all of the data in the buffer
   wire      n_all_in_buf;
   wire      n_nearly_all_in_buf;
   reg 	     dma_all_in_buf_p1;

   // N-Clock reset
   reg 	     nreset_1, nreset;

   // Overflow propagation
   reg 	     n_overflow, p_overflow_p1;
   reg [2:0] n_overflow_cnt;

   wire dma_rx_fifo_nearly_full, dma_rx_fifo_full;

   parameter OP_CODE_IDLE = 2'b 00,
             OP_CODE_STATUS_QUERY = 2'b 01,
             OP_CODE_TRANSF_CPCI_2_NETFPGA = 2'b 10,
             OP_CODE_TRANSF_NETFPGA_2_CPCI = 2'b 11;

   reg [3:0] cpci_state, cpci_state_nxt;
   parameter QUERY_REQ_STATE                       = 3'h 0,
	     QUERY_ACK_STATE                       = 3'h 1,
	     TRANSF_NETFPGA_2_CPCI_REQ_STATE       = 3'h 2,
	     TRANSF_NETFPGA_2_CPCI_LEN_STATE       = 3'h 3,
	     TRANSF_NETFPGA_2_CPCI_DATA_STATE      = 3'h 4,
	     TRANSF_CPCI_2_NETFPGA_REQ_STATE       = 3'h 5,
	     TRANSF_CPCI_2_NETFPGA_LEN_DATA_STATE  = 3'h 6;

   assign dma_wr_rdy = !p2n_dma_prog_full;

   //flop the input signals to improve timing
   always @(posedge nclk) begin
      cpci_dma_op_code_ack_d1 <= cpci_dma_op_code_ack;
      cpci_dma_vld_n2c_d1 <= cpci_dma_vld_n2c;
      cpci_dma_data_n2c_d1 <= cpci_dma_data_n2c;
      cpci_dma_q_nearly_full_n2c_d1 <= cpci_dma_q_nearly_full_n2c;
   end

   assign cpci_dma_q_nearly_full_c2n_nxt = dma_rx_fifo_nearly_full;

   always @(*) begin
      cpci_state_nxt = cpci_state;
      cpci_dma_op_code_req_nxt = cpci_dma_op_code_req;
      cpci_dma_pkt_avail_nxt = cpci_dma_pkt_avail;
      cpci_can_wr_pkt_nxt = cpci_can_wr_pkt;
      cpci_dma_op_queue_id_nxt = cpci_dma_op_queue_id;
      cpci_dma_queue_info_avail_nxt = 1'b 0;

      cpci_dma_vld_c2n_nxt = cpci_dma_vld_c2n;
      cpci_dma_data_c2n_nxt = cpci_dma_data_c2n;
      cpci_dma_data_tri_en_nxt = cpci_dma_data_tri_en;

      clr_cpci_dma_rx_req = 1'b 0;
      clr_cpci_dma_tx_req = 1'b 0;
      ld_rx_expect = 1'b 0;
      ld_tx_expect = 1'b 0;
      dma_rx_fifo_wr_en = 1'h 0;
      dma_rx_fifo_wr_data = 'h 0;
      see_dma_rx_fifo_overflow = 1'b 0;
      inc_rx_count = 1'b 0;
      inc_tx_count = 1'b 0;
      fifo_rd_en = 1'b 0;

      case (cpci_state)
	QUERY_REQ_STATE: begin
	   cpci_dma_op_code_req_nxt = OP_CODE_STATUS_QUERY;
	   cpci_state_nxt = QUERY_ACK_STATE;

           // Don't drive the tri-state
           // and reset the c2n valid signal
           cpci_dma_data_tri_en_nxt = 1'b 0;
           cpci_dma_vld_c2n_nxt = 1'b 0;
	end

	QUERY_ACK_STATE: begin
	   if (cpci_dma_op_code_ack_d1 == OP_CODE_STATUS_QUERY &&
              cpci_dma_vld_n2c_d1) begin

	      //----------------------------------
	      // data format is as follows:
              // cpci_dma_data_n2c = {
              //              {12 {1'b 0}},
              //               cpu_q_dma_pkt_avail, //[NUM_CPU_QUEUES-1:0]
              //               {12 {1'b 0}},
              //               cpu_q_dma_nearly_full //[NUM_CPU_QUEUES-1:0]
              //               };
	      //----------------------------------

	      cpci_dma_pkt_avail_nxt = cpci_dma_data_n2c_d1[31:16];
	      cpci_can_wr_pkt_nxt = cpci_dma_data_n2c_d1[15:0];
	      cpci_dma_queue_info_avail_nxt = 1'b 1;

	   end // if (cpci_dma_vld_n2c_d1)

	   if (cpci_dma_rx_req) begin
	      cpci_dma_op_queue_id_nxt = dma_rd_request_q_held;

	      cpci_state_nxt = TRANSF_NETFPGA_2_CPCI_REQ_STATE;
	   end

	   else if (cpci_dma_tx_req) begin
	      cpci_dma_op_queue_id_nxt = fifo_data[31:16];

	      cpci_state_nxt = TRANSF_CPCI_2_NETFPGA_REQ_STATE;
	   end

	end // case: QUERY_ACK_STATE

	TRANSF_NETFPGA_2_CPCI_REQ_STATE: begin
	   cpci_dma_op_code_req_nxt = OP_CODE_TRANSF_NETFPGA_2_CPCI;

	   if (cpci_dma_op_code_ack_d1 == OP_CODE_TRANSF_NETFPGA_2_CPCI) begin
	      clr_cpci_dma_rx_req = 1'b 1;

	      cpci_state_nxt = TRANSF_NETFPGA_2_CPCI_LEN_STATE;
	   end
	end

	TRANSF_NETFPGA_2_CPCI_LEN_STATE:
	  if (cpci_dma_vld_n2c_d1) begin
	     ld_rx_expect = 1'b 1;
	     dma_rx_fifo_wr_en = !dma_rx_fifo_full;
	     dma_rx_fifo_wr_data = !dma_rx_fifo_full ? cpci_dma_data_n2c_d1 : 'h 0;

	     see_dma_rx_fifo_overflow = dma_rx_fifo_full;

	     cpci_state_nxt = TRANSF_NETFPGA_2_CPCI_DATA_STATE;

	  end

	TRANSF_NETFPGA_2_CPCI_DATA_STATE: begin

	   if (cpci_dma_vld_n2c_d1) begin
	      dma_rx_fifo_wr_en = !dma_rx_fifo_full;
	      dma_rx_fifo_wr_data = !dma_rx_fifo_full ? cpci_dma_data_n2c_d1 : 'h 0;

	      see_dma_rx_fifo_overflow = dma_rx_fifo_full;

	      inc_rx_count = 1'b 1;
	   end

	   if (n_all_in_buf) begin
	      //transfer completed
	      cpci_state_nxt = QUERY_REQ_STATE;
	   end

	end // case: TRANSF_NETFPGA_2_CPCI_ACK_STATE

	 TRANSF_CPCI_2_NETFPGA_REQ_STATE: begin
	    cpci_dma_op_code_req_nxt = OP_CODE_TRANSF_CPCI_2_NETFPGA;

	    if (cpci_dma_op_code_ack_d1 == OP_CODE_TRANSF_CPCI_2_NETFPGA) begin
	       clr_cpci_dma_tx_req = 1'b 1;

	       cpci_state_nxt = TRANSF_CPCI_2_NETFPGA_LEN_DATA_STATE;

               cpci_dma_data_c2n_nxt = {16'b0, fifo_data[15:0]};
               cpci_dma_vld_c2n_nxt = 1'b 1;
               cpci_dma_data_tri_en_nxt = 1'b 1;

               ld_tx_expect = 1'b 1;

               fifo_rd_en = 1'b 1;
	    end
	 end

         TRANSF_CPCI_2_NETFPGA_LEN_DATA_STATE: begin
            if (cpci_dma_q_nearly_full_n2c_d1) begin
               cpci_dma_vld_c2n_nxt = 1'b 0;
            end
            else begin
               cpci_dma_data_c2n_nxt = fifo_data;
               cpci_dma_vld_c2n_nxt = !fifo_empty;
               cpci_dma_data_tri_en_nxt = 1'b 1;

               fifo_rd_en = !fifo_empty;
               inc_tx_count = !fifo_empty;

               if (n_nearly_all_in_buf && !fifo_empty) begin
                  //transfer completed
                  cpci_state_nxt = QUERY_REQ_STATE;
               end
            end
	end // case: TRANSF_CPCI_2_NETFPGA_ACK_STATE

      endcase // case(state)

   end // always @ (*)


   always @(posedge nclk)
      if (nreset) begin
	 cpci_state <= QUERY_REQ_STATE;
	 cpci_dma_op_code_req <= OP_CODE_STATUS_QUERY;
	 cpci_dma_op_queue_id <= 'h 0;
	 cpci_dma_pkt_avail <= 'h 0;
	 cpci_can_wr_pkt <= 'h 0;

	 cpci_dma_q_nearly_full_c2n <= 1'h 0;
	 cpci_dma_vld_c2n <= 1'b 0;
         cpci_dma_data_c2n <= 'h 0;
         cpci_dma_data_tri_en <= 1'b 0;
      end
      else begin
	 cpci_state <= cpci_state_nxt;
	 cpci_dma_op_code_req <= cpci_dma_op_code_req_nxt;
	 cpci_dma_op_queue_id <= cpci_dma_op_queue_id_nxt;
	 cpci_dma_pkt_avail <= cpci_dma_pkt_avail_nxt;
	 cpci_can_wr_pkt <= cpci_can_wr_pkt_nxt;
	 cpci_dma_queue_info_avail <= cpci_dma_queue_info_avail_nxt;

	 cpci_dma_q_nearly_full_c2n <= cpci_dma_q_nearly_full_c2n_nxt;
	 cpci_dma_vld_c2n <= cpci_dma_vld_c2n_nxt;
         cpci_dma_data_c2n <= cpci_dma_data_c2n_nxt;
         cpci_dma_data_tri_en <= cpci_dma_data_tri_en_nxt;
      end

// ==================================================================
// N-Reset generation
// ==================================================================

always @(posedge nclk)
begin
   nreset_1 <= reset || cnet_reprog;
   nreset <= nreset_1;
end

// ==================================================================
// Logic to work out when the entire packet is in the buffer
// ==================================================================

reg [8:0] expect, expect_nxt;
reg [8:0] count, count_nxt;

always @(posedge nclk)
begin
   expect <= expect_nxt;
   count <= count_nxt;
end

always @(*)
begin
   expect_nxt = expect;
   count_nxt = count;

   if (nreset || new_request) begin
      expect_nxt = - 'h1;
      count_nxt = 'h0;
   end
   else if (ld_rx_expect) begin
      // The logic below calculates the expected number of words
      // and the starting count.
      //
      // The expected number of words should be:
      //   expected = cpci_dma_data[10:2] +
      //              (cpci_dma_data[1:0] != 'h0) ? 1 : 0
      // ie. if the 2 LSBs are not 0 then we would expect one additional
      // word.
      //
      // However, as cpci_dma_data is likely to arrive on the late side we
      // set expected to cpci_dma_data[10:2] and set the initial count to
      // either 0 or -1 as the -1 is relatively quick to calculate.
      /*
      expect_nxt = cpci_dma_data[10:2];
      count_nxt = {9{|(cpci_dma_data[1:0])}};
      */
      expect_nxt = cpci_dma_data_n2c_d1[10:2] +
                 (cpci_dma_data_n2c_d1[1:0] != 'h0 ? 1 : 0);
      count_nxt = 'h0;
   end
   else if (ld_tx_expect) begin
      // The logic below calculates the expected number of words
      // and the starting count.
      //
      // The expected number of words should be:
      //   expected = cpci_dma_data[10:2] +
      //              (cpci_dma_data[1:0] != 'h0) ? 1 : 0
      // ie. if the 2 LSBs are not 0 then we would expect one additional
      // word.
      //
      // However, as cpci_dma_data is likely to arrive on the late side we
      // set expected to cpci_dma_data[10:2] and set the initial count to
      // either 0 or -1 as the -1 is relatively quick to calculate.
      /*
      expect_nxt = cpci_dma_data[10:2];
      count_nxt = {9{|(cpci_dma_data[1:0])}};
      */
      expect_nxt = fifo_data[10:2] +
                 (fifo_data[1:0] != 'h0 ? 1 : 0);
      count_nxt = 'h0;
   end
   else if (inc_rx_count) begin
      count_nxt = count + 'h1;
   end
   else if (inc_tx_count) begin
      count_nxt = count + 'h1;
   end
end

// Work out if all of the data is in the buffer
assign n_all_in_buf = (count == expect);

assign n_nearly_all_in_buf = (count == expect - 'h1);

// ==================================================================
// Asynchronous FIFO
// ==================================================================

// Note: There better not be any data coming from the small write fifo when
// ld_xfer_cnt is asserted. Equally, this FIFO better not be full!

// Note: this FIFO uses first-word fall through
//
// Programmable full threshold set to allow PCI DMA transactions to be
// aborted before the FIFO fills up
pci2net_dma_32x32 pci2net_dma_fifo (
         .din (dma_wr_data),
	 .rd_clk (nclk),
	 .rd_en (fifo_rd_en),
	 .rst (reset || cnet_reprog),
	 .wr_clk (pclk),
	 .wr_en (dma_wr_en),
	 .prog_full (p2n_dma_prog_full),
	 .dout (fifo_data),
	 .empty (fifo_empty),
	 .full (p2n_dma_full)
      );

   //dma rx_fifo
   net2pci_dma_512x32 dma_rx_fifo
     (
      //wr intfc
      .din (dma_rx_fifo_wr_data),
      .wr_en (dma_rx_fifo_wr_en),
      .prog_full (dma_rx_fifo_nearly_full),
      .full (dma_rx_fifo_full),
      .wr_clk (nclk),

      //rd intfc
      .rd_en (dma_rd_en),
      .dout (dma_rd_data),
      .empty (dma_empty),
      .prog_empty (dma_nearly_empty),
      .rd_clk (pclk),

      //misc:
      .rst (reset || cnet_reprog)
      );

// ==================================================================
// Overflow detection
// ==================================================================

always @(posedge nclk)
begin
   if (nreset) begin
      n_overflow <= 1'b0;
      n_overflow_cnt <= 'h0;
   end
   else begin
      if (see_dma_rx_fifo_overflow) begin
	 n_overflow <= 1'b1;
	 n_overflow_cnt <= 'h 3;
      end
      else if (n_overflow_cnt == 'h 0) begin
	 n_overflow <= 1'b0;
      end
      else begin
	 n_overflow_cnt <= n_overflow_cnt - 'h1;
      end

   end // else: !if(nreset)

end // always @ (posedge nclk)



// ==================================================================
// Propagate signals from one clock domain to the other
// ==================================================================

// Although these are buses it's okay because they are
// independent signals.
always @(posedge pclk)
begin
   dma_pkt_avail_p1 <= cpci_dma_pkt_avail;
   dma_pkt_avail <= dma_pkt_avail_p1;

   dma_can_wr_pkt_p1 <= cpci_can_wr_pkt;
   dma_can_wr_pkt <= dma_can_wr_pkt_p1;

   dma_queue_info_avail_p1 <= cpci_dma_queue_info_avail;
   dma_queue_info_avail <= dma_queue_info_avail_p1;
end

// all in buffer signal
always @(posedge pclk)
begin
   dma_all_in_buf <= dma_all_in_buf_p1;
   dma_all_in_buf_p1 <= n_all_in_buf;
end

// Propagate the dma_rd_request signal
always @(posedge pclk)
begin
   if (reset || cnet_reprog)
      dma_rd_request_toggle <= 'h0;
   else
      dma_rd_request_toggle <= dma_rd_request_toggle ^ dma_rd_request;

   if (dma_rd_request)
      dma_rd_request_q_held <= dma_rd_request_q;
end

always @(posedge nclk)
begin
   if (nreset) begin
      n_dma_rd_rq_tgl_p1 <= 'h 0;
      n_dma_rd_rq_tgl_p2 <= 'h 0;
      n_dma_rd_rq_tgl_p3 <= 'h 0;
   end
   else begin
      n_dma_rd_rq_tgl_p1 <= dma_rd_request_toggle;
      n_dma_rd_rq_tgl_p2 <= n_dma_rd_rq_tgl_p1;
      n_dma_rd_rq_tgl_p3 <= n_dma_rd_rq_tgl_p2;
   end
end

// Propagate the overflow signal
always @(posedge pclk)
begin
   if (reset || cnet_reprog) begin
      overflow <= 1'b0;
      p_overflow_p1 <= 1'b0;
   end
   else begin
      overflow <= p_overflow_p1;
      p_overflow_p1 <= n_overflow;
   end
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

// Generate the cpci_dma_rx_req signal
//
// Generate when the tgl signal changes.
// Reset when clr_cpci_dma_rx_req signal is asserted

always @(posedge nclk)
begin
   if (nreset || clr_cpci_dma_rx_req)
      cpci_dma_rx_req <= 4'h0;
   else
      cpci_dma_rx_req <= cpci_dma_rx_req | (n_dma_rd_rq_tgl_p2 ^ n_dma_rd_rq_tgl_p3);
end

// Generate the cpci_dma_tx_req signal
//
// Generate when the tgl signal changes.
// Reset when clr_cpci_dma_tx_req signal is asserted

always @(posedge nclk)
begin
   if (nreset || clr_cpci_dma_tx_req)
      cpci_dma_tx_req <= 1'b0;
   else if (cpci_state != TRANSF_CPCI_2_NETFPGA_REQ_STATE &&
            cpci_state != TRANSF_CPCI_2_NETFPGA_LEN_DATA_STATE &&
            !fifo_empty)
      cpci_dma_tx_req <= 1'b1;
end

// Work out if there is a new request
assign new_request = |(n_dma_rd_rq_tgl_p2 ^ n_dma_rd_rq_tgl_p3) ||
                     (cpci_state != TRANSF_CPCI_2_NETFPGA_REQ_STATE &&
                      cpci_state != TRANSF_CPCI_2_NETFPGA_LEN_DATA_STATE &&
                      !fifo_empty);

// ==================================================================
// Debuging
// ==================================================================

// synthesis translate_off
reg xfer_in_progress;

always @(posedge nclk)
begin
   if (nreset || n_all_in_buf)
      xfer_in_progress <= 1'b0;
   else if (ld_rx_expect)
      xfer_in_progress <= 1'b1;
end

always @*
begin
   if (new_request && xfer_in_progress)
      $display($time, " ERROR: Saw DMA request for packet while transfer in progress");
end

always @(posedge nclk)
begin
   if (see_dma_rx_fifo_overflow)
      $display($time, " ERROR: Attempt to write to a full DMA RX buffer in %m");
end

// synthesis translate_on

endmodule
