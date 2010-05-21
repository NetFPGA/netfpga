///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_dma_bus_fsm.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_dma_bus_fsm.v
// Project: NetFPGA-1G
// Description: bus state machine for the DMA interface to CPCI chip
//
//
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// txfifo_data includes:
//  1 bit. 1'b 0 for "data format"; 1'b 1 for "req format"
//  1 bit. EOP in "data format". 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//         in "req format", 1'b 0 for "dma tx", 1'b 1 for "dma rx"
//  2 bits. bytecnt in "data format". 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
//          always 2'b 00 in "req format"
// 32 bits. pkt data in "data format".
//         {28'b 0, 4-bits queue_id} in "req format"
//
// rxfifo_data includes:
//  1 bit. EOP. 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//  2 bits. bytecnt. 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
// 32 bits. pkt data .
//
///////////////////////////////////////////////////////////////////////////////

module nf2_dma_bus_fsm
   #(
      parameter DMA_DATA_WIDTH      = 32,
      parameter NUM_CPU_QUEUES      = 4,
      parameter PKT_LEN_CNT_WIDTH   = 11,
      parameter WATCHDOG_TIMEOUT    = 625000
   )
    (
     // -- signals to cpci pins
     input [1:0] dma_op_code_req,
     input [3:0] dma_op_queue_id,
     output reg [1:0] dma_op_code_ack,

     input dma_vld_c2n,
     input [DMA_DATA_WIDTH-1:0] dma_data_c2n,
     output reg dma_dest_q_nearly_full_n2c,

     output reg dma_vld_n2c,
     output reg [DMA_DATA_WIDTH-1:0] dma_data_n2c,
     input dma_dest_q_nearly_full_c2n,

     output reg dma_data_tri_en,

     // -- signals from/to NetFPGA core logic
     // through async fifo
     input [NUM_CPU_QUEUES-1:0] cpu_q_dma_pkt_avail,
     input [NUM_CPU_QUEUES-1:0] cpu_q_dma_can_wr_pkt,

     // -- signals to cpu queues
     input txfifo_full,
     input txfifo_nearly_full,
     output reg txfifo_wr,
     output reg txfifo_wr_is_req,
     output reg txfifo_wr_pkt_vld,
     output reg txfifo_wr_type_eop,
     output reg [1:0] txfifo_wr_valid_bytes,
     output reg [DMA_DATA_WIDTH-1:0] txfifo_wr_data,

     input rxfifo_empty,
     output reg rxfifo_rd_inc,
     input rxfifo_rd_eop,
     input [1:0] rxfifo_rd_valid_bytes,
     input [DMA_DATA_WIDTH-1:0] rxfifo_rd_data,

     // --- enable DMA
     input enable_dma,

     // --- register interface signals
     output reg timeout,

     // -- misc
     input cpci_clk,
     input cpci_reset
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

   localparam WATCHDOG_TIMER_WIDTH = log2(WATCHDOG_TIMEOUT);
   localparam PKT_LEN_MAX = (1 << PKT_LEN_CNT_WIDTH) - 1;
   localparam PKT_LEN_THRESHOLD = PKT_LEN_MAX - (DMA_DATA_WIDTH / 8);

   reg [1:0] dma_op_code_req_d;
   reg [3:0] dma_op_queue_id_d;
   reg dma_vld_c2n_d;
   reg [DMA_DATA_WIDTH-1:0] dma_data_c2n_d;
   reg dma_dest_q_nearly_full_c2n_d;

   always @(posedge cpci_clk) begin
      dma_op_code_req_d <= dma_op_code_req;
      dma_op_queue_id_d <= dma_op_queue_id;
      dma_vld_c2n_d <= dma_vld_c2n;
      dma_data_c2n_d <= dma_data_c2n;
      dma_dest_q_nearly_full_c2n_d <= dma_dest_q_nearly_full_c2n;
   end


   reg [1:0] dma_op_code_ack_nxt, dma_op_code_ack_int;
   reg [3:0] queue_id, queue_id_nxt;
   reg 	     dma_vld_n2c_nxt;
   wire      dma_dest_q_nearly_full_n2c_nxt;
   reg [DMA_DATA_WIDTH -1:0] dma_data_n2c_nxt;
   reg dma_data_tri_en_nxt;


   parameter OP_CODE_IDLE = 2'b 00,
	     OP_CODE_STATUS_QUERY = 2'b 01,
	     OP_CODE_TRANSF_C2N = 2'b 10,
	     OP_CODE_TRANSF_N2C = 2'b 11;

   assign    dma_dest_q_nearly_full_n2c_nxt = txfifo_nearly_full;

   reg [PKT_LEN_CNT_WIDTH-1:0] tx_pkt_len, tx_pkt_len_nxt;
   reg [PKT_LEN_CNT_WIDTH-1:0] rx_pkt_len, rx_pkt_len_nxt;

   wire tx_last_word;
   wire rx_last_word;

   assign tx_last_word = tx_pkt_len <= 4;
   assign rx_last_word = rx_pkt_len <= 4;

   // Watchdog signals
   reg reset_watchdog;
   reg [WATCHDOG_TIMER_WIDTH-1:0]   watchdog_timer;

   reg [3:0] state, state_nxt;
   parameter IDLE_STATE = 4'h 0,
	     QUERY_STATE = 4'h 1,
	     TRANSF_C2N_QID_STATE = 4'h 2,
	     TRANSF_C2N_LEN_STATE = 4'h 3,
	     TRANSF_C2N_DATA_STATE = 4'h 4,
	     TRANSF_C2N_DONE_STATE = 4'h 5,
	     TRANSF_N2C_QID_STATE = 4'h 6,
	     TRANSF_N2C_LEN_STATE = 4'h 7,
	     TRANSF_N2C_DATA_STATE = 4'h 8,
	     TRANSF_N2C_DONE_STATE = 4'h 9,
	     TIMEOUT_HOLD = 4'h A,
	     TIMEOUT_QUERY = 4'h B,
	     TIMEOUT_C2N = 4'h C,
	     TIMEOUT_N2C = 4'h D;

   always @(*) begin
      state_nxt = state;
      dma_op_code_ack_nxt = dma_op_code_ack_int;
      queue_id_nxt = queue_id;
      dma_vld_n2c_nxt = 0;
      dma_data_n2c_nxt = 'h 0;
      dma_data_tri_en_nxt = dma_data_tri_en;
      tx_pkt_len_nxt = tx_pkt_len;
      rx_pkt_len_nxt = rx_pkt_len;

      txfifo_wr = 1'b 0;
      txfifo_wr_is_req = 1'b0;
      txfifo_wr_pkt_vld = 1'b0;
      txfifo_wr_type_eop = 1'b0;
      txfifo_wr_valid_bytes = 'h0;
      txfifo_wr_data = 'h 0;

      rxfifo_rd_inc = 1'b 0;

      reset_watchdog = 1'b0;

      case (state)

	IDLE_STATE:
	  if (enable_dma) begin

	     case (dma_op_code_req_d)
	       OP_CODE_STATUS_QUERY: begin
		  state_nxt = QUERY_STATE;
	       end

	       OP_CODE_TRANSF_C2N: begin
		  state_nxt = TRANSF_C2N_QID_STATE;
	       end

	       OP_CODE_TRANSF_N2C: begin
		  state_nxt = TRANSF_N2C_QID_STATE;
	       end
	     endcase // case(dma_op_code_req_d)

	  end // if (enable_dma)

	QUERY_STATE: begin
	   dma_op_code_ack_nxt = OP_CODE_STATUS_QUERY;
	   dma_data_tri_en_nxt = 1'b 1;
	   dma_vld_n2c_nxt = 1'b 1;

           if (enable_dma) begin
              dma_data_n2c_nxt = {
                                  {12 {1'b 0}},
                                  cpu_q_dma_pkt_avail, //[NUM_CPU_QUEUES-1:0]
                                  {12 {1'b 0}},
                                  cpu_q_dma_can_wr_pkt //[NUM_CPU_QUEUES-1:0]
                                  };
	      if (dma_op_code_req_d == OP_CODE_TRANSF_C2N) begin
	         state_nxt = TRANSF_C2N_QID_STATE;
	      end

	      else if (dma_op_code_req_d == OP_CODE_TRANSF_N2C) begin
                 state_nxt = TRANSF_N2C_QID_STATE;
              end
           end
           else
	      dma_data_n2c_nxt = {
			          {(16 - NUM_CPU_QUEUES) {1'b 0}},
			          {NUM_CPU_QUEUES {1'b 0}}, // Pkt avail
			          {(16 - NUM_CPU_QUEUES) {1'b 0}},
			          {NUM_CPU_QUEUES {1'b 1}} // Nearly full
			         };
	end // case: QUERY_STATE

	TRANSF_C2N_QID_STATE: begin
	   dma_op_code_ack_nxt = OP_CODE_TRANSF_C2N;
	   dma_data_tri_en_nxt = 1'b 0;
	   queue_id_nxt = dma_op_queue_id_d;

	   txfifo_wr = 1'b 1;
	   txfifo_wr_is_req=1'b 1;//0: pkt data; 1: req code
	   txfifo_wr_type_eop=1'b 0;//0:dma tx; 1: dma rx
	   txfifo_wr_valid_bytes=2'b 0;//unused
	   txfifo_wr_data={{(DMA_DATA_WIDTH-4) {1'b 0}}, queue_id_nxt};

           reset_watchdog = 1'b1;

	   state_nxt = TRANSF_C2N_LEN_STATE;

	end // case: TRANSF_C2N_0_STATE

	TRANSF_C2N_LEN_STATE: begin
           if (watchdog_timer == 'h0) begin
              // If we're waiting for the length then we haven't sent anything
              // into the NetFPGA, so no need to try to clear the DMA fifo.
              state_nxt = TIMEOUT_HOLD;
           end
	   else if (dma_vld_c2n_d) begin
	      tx_pkt_len_nxt = dma_data_c2n_d[PKT_LEN_CNT_WIDTH-1:0];

              txfifo_wr = 1'b 1;
              txfifo_wr_is_req=1'b 0;//0:pkt data;1:req code
              txfifo_wr_valid_bytes='h0;
              txfifo_wr_data = dma_data_c2n_d;

	      if (| tx_pkt_len_nxt) begin
		 state_nxt = TRANSF_C2N_DATA_STATE;
                 txfifo_wr_type_eop=1'b 0;//0:not EOP; 1:EOP
	      end
              else begin
		 state_nxt = TRANSF_C2N_DONE_STATE;
                 txfifo_wr_type_eop=1'b 1;//0:not EOP; 1:EOP
              end
	   end // if (dma_vld_c2n_d)

	   //TODO: add transaction aborted by CPCI

	end // case: TRANSF_C2N_LEN_STATE

	TRANSF_C2N_DATA_STATE: begin
           if (watchdog_timer == 'h0) begin
              state_nxt = TIMEOUT_C2N;
           end
	   else if (dma_vld_c2n_d) begin
              txfifo_wr = 1'b 1;
              txfifo_wr_is_req=1'b 0;//0:pkt data;1:req code
              txfifo_wr_data = dma_data_c2n_d;


              if (tx_last_word) begin
		 state_nxt = TRANSF_C2N_DONE_STATE;

                 tx_pkt_len_nxt = 'h 0;
                 txfifo_wr_pkt_vld=1'b 1;
                 txfifo_wr_type_eop=1'b 1;//0:not EOP; 1:EOP
                 txfifo_wr_valid_bytes=tx_pkt_len[1:0];
              end
              else begin
		 tx_pkt_len_nxt = tx_pkt_len - 'h 4;
                 txfifo_wr_type_eop=1'b 0;//0:not EOP; 1:EOP
                 txfifo_wr_valid_bytes=2'h 4;//1 byte of pkt data
              end


	   end // if (dma_vld_c2n_d)

	   //TODO: add transaction aborted by CPCI

	end // case: TRANSF_C2N_DATA_STATE

	TRANSF_C2N_DONE_STATE: begin
           if (enable_dma) begin
              case (dma_op_code_req_d)
                OP_CODE_STATUS_QUERY: begin
                   state_nxt = QUERY_STATE;
                end

                OP_CODE_TRANSF_N2C: begin
                   state_nxt = TRANSF_N2C_QID_STATE;
                end
              endcase
           end
           else
              state_nxt = QUERY_STATE;

	end // case: TRANSF_C2N_DONE_STATE

	TRANSF_N2C_QID_STATE: begin

	   dma_op_code_ack_nxt = OP_CODE_TRANSF_N2C;
	   dma_data_tri_en_nxt = 1'b 1;

           queue_id_nxt = dma_op_queue_id_d;

	   txfifo_wr = 1'b 1;
	   txfifo_wr_is_req=1'b 1;//0: pkt data; 1: req code
	   txfifo_wr_type_eop=1'b 1;//0:dma tx; 1:dma rx
	   txfifo_wr_valid_bytes=2'b 0;//unused
	   txfifo_wr_data={{(DMA_DATA_WIDTH-4) {1'b 0}}, queue_id_nxt};

	   rx_pkt_len_nxt = 'h 0;

           reset_watchdog = 1'b1;

	   state_nxt = TRANSF_N2C_LEN_STATE;

	end // case: TRANSF_N2C_QID_STATE

	TRANSF_N2C_LEN_STATE:
           if (watchdog_timer == 'h0) begin
              // If we're waiting for the length then we haven't read anything
              // from the NetFPGA, so no need to try to clear the DMA fifo.
              state_nxt = TIMEOUT_HOLD;
           end
	   else if (!rxfifo_empty && !dma_dest_q_nearly_full_c2n_d) begin
	     rxfifo_rd_inc = 1'b 1;

	     dma_vld_n2c_nxt = 1'b 1;
	     dma_data_n2c_nxt = rxfifo_rd_data;
	     rx_pkt_len_nxt = rxfifo_rd_data[PKT_LEN_CNT_WIDTH-1:0];

	     state_nxt = TRANSF_N2C_DATA_STATE;

             //TODO: add transaction aborted by CPCI
	  end

	TRANSF_N2C_DATA_STATE: begin
           if (watchdog_timer == 'h0) begin
              state_nxt = TIMEOUT_N2C;
           end
	   else if (!rxfifo_empty && !dma_dest_q_nearly_full_c2n_d) begin
	      rxfifo_rd_inc = 1'b 1;

	      dma_vld_n2c_nxt = 1'b 1;
	      dma_data_n2c_nxt = rxfifo_rd_data;

              if (rx_last_word) begin
		 rx_pkt_len_nxt = 'h 0;

		 state_nxt = TRANSF_N2C_DONE_STATE;
              end
              else
		rx_pkt_len_nxt = rx_pkt_len - 4;

              //TODO: add transaction aborted by CPCI

	   end // if (!rxfifo_empty && !dma_dest_q_nearly_full_c2n_d)
	end // case: TRANSF_N2C_DATA_DEQ_STATE

	TRANSF_N2C_DONE_STATE: begin
           if (enable_dma) begin
              case (dma_op_code_req_d)
                OP_CODE_STATUS_QUERY: begin
                   state_nxt = QUERY_STATE;
                end

                OP_CODE_TRANSF_C2N: begin
                   state_nxt = TRANSF_C2N_QID_STATE;
                end
              endcase // case(dma_op_code_req_d)
           end
           else
              state_nxt = QUERY_STATE;

	end // case: TRANSF_N2C_DONE_STATE

        TIMEOUT_HOLD: begin
            // A DMA timeout has occured. Remain in a timeout state until
            // reset.
            if (enable_dma) begin
	       case (dma_op_code_req_d)
	          OP_CODE_STATUS_QUERY: begin
	             state_nxt = TIMEOUT_QUERY;
	          end
	       endcase // case(dma_op_code_req_d)
            end // if (enable_dma)
        end // case: TIMEOUT_HOLD

        TIMEOUT_QUERY: begin
            // Timeout state in which to return query information
            //
            // Sit in this state forever
	    dma_op_code_ack_nxt = OP_CODE_STATUS_QUERY;
	    dma_data_tri_en_nxt = 1'b 1;
	    dma_vld_n2c_nxt = 1'b 1;

	    dma_data_n2c_nxt = {
			        {(16 - NUM_CPU_QUEUES) {1'b 0}},
			        {NUM_CPU_QUEUES {1'b 0}}, // Pkt avail
			        {(16 - NUM_CPU_QUEUES) {1'b 0}},
			        {NUM_CPU_QUEUES {1'b 1}} // Nearly full
			       };

        end // case: TIMEOUT_QUERY

        TIMEOUT_C2N: begin
           // Send data of the correct length but indicate that the packet is
           // invalid
           txfifo_wr = 1'b 1;
           txfifo_wr_is_req=1'b 0;//0:pkt data;1:req code
           txfifo_wr_data = 'h0;

           if (tx_last_word) begin
	      state_nxt = TIMEOUT_HOLD;

              tx_pkt_len_nxt = 'h 0;
              txfifo_wr_pkt_vld=1'b 0;
              txfifo_wr_type_eop=1'b 1;//0:not EOP; 1:EOP
              txfifo_wr_valid_bytes=tx_pkt_len[1:0];
           end
           else begin
	      tx_pkt_len_nxt = tx_pkt_len - 'h 4;
              txfifo_wr_type_eop=1'b 0;//0:not EOP; 1:EOP
              txfifo_wr_valid_bytes=2'h 4;//1 byte of pkt data
           end
        end

        TIMEOUT_N2C: begin
           // Retrieve the current packet and then sit idle
	   if (!rxfifo_empty) begin
	      rxfifo_rd_inc = 1'b 1;

              if (rx_last_word) begin
		 rx_pkt_len_nxt = 'h 0;

		 state_nxt = TIMEOUT_HOLD;
              end
              else
		rx_pkt_len_nxt = rx_pkt_len - 4;
	   end // if (!rxfifo_empty)
        end

      endcase // case(state)

   end // always @ (*)

   always @(posedge cpci_clk) begin
     if (cpci_reset) begin
	state <= IDLE_STATE;

	dma_op_code_ack <= OP_CODE_IDLE;
	dma_op_code_ack_int <= OP_CODE_IDLE;
	dma_vld_n2c <= 1'b 0;

	dma_data_tri_en <= 1'b 0;
	dma_data_n2c <= 'h 0;

	dma_dest_q_nearly_full_n2c <= 1'b 0;

	queue_id <= 'h 0;
	tx_pkt_len <= 'h 0;
	rx_pkt_len <= 'h 0;

     end
     else begin
	state <= state_nxt;

	dma_op_code_ack <= dma_op_code_ack_nxt;
	dma_op_code_ack_int <= dma_op_code_ack_nxt;
	dma_vld_n2c <= dma_vld_n2c_nxt;

	dma_data_tri_en <= dma_data_tri_en_nxt;
	dma_data_n2c <= dma_data_n2c_nxt;

	dma_dest_q_nearly_full_n2c <= dma_dest_q_nearly_full_n2c_nxt;

	queue_id <= queue_id_nxt;
	tx_pkt_len <= tx_pkt_len_nxt;
	rx_pkt_len <= rx_pkt_len_nxt;

     end

   end // always @ (posedge cpci_clk)

   // Watchdog timer logic
   //
   // Monitors for DMA timeout conditions in which a DMA transaction is
   // partially complete but no forward progress is made.
   //
   // Note: When a timeout occurs, the state machine goes into a DISABLED
   // state until reset by the user.
   always @(posedge cpci_clk)
   begin
      // Reset the timer on reset or when some data is being transferred
      if (cpci_reset || reset_watchdog || txfifo_wr || dma_vld_n2c_nxt) begin
         watchdog_timer <= WATCHDOG_TIMEOUT;
         timeout <= 1'b0;
      end
      else begin
         if (watchdog_timer != 'h0) begin
            watchdog_timer <= watchdog_timer - 'h1;
         end

         // Generate a time-out if the timer has expired and we are in one of
         // the transfer states.
         if (watchdog_timer == 'h0 &&
             (state == TRANSF_C2N_LEN_STATE ||
              state == TRANSF_C2N_DATA_STATE ||
              state == TRANSF_N2C_LEN_STATE ||
              state == TRANSF_N2C_DATA_STATE))
            timeout <= 1'b1;
         else
            timeout <= 1'b0;
      end
   end

endmodule // nf2_dma_bus_fsm
