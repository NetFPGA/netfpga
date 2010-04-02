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
  #(parameter DMA_DATA_WIDTH=32,
    parameter NUM_CPU_QUEUES = 4,
    parameter PKT_LEN_CNT_WIDTH=11)
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
     input [NUM_CPU_QUEUES-1:0] cpu_q_dma_nearly_full,

     // -- signals to cpu queues
     input txfifo_full,
     input txfifo_nearly_full,
     output reg txfifo_wr,
     output reg [DMA_DATA_WIDTH +3:0] txfifo_wr_data,

     input rxfifo_empty,
     output reg rxfifo_rd_inc,
     input [DMA_DATA_WIDTH +2:0] rxfifo_rd_data,

     // --- enable DMA
     input enable_dma,

     // -- misc
     input cpci_clk,
     input cpci_reset
     );

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
   reg 	     dma_vld_n2c_nxt, dma_vld_n2c_int;
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

   reg rxbuf_srst, rxbuf_rd_en, rxbuf_rd_en_d, rxbuf_wr_en;
   reg [31:0] rxbuf_wr_data;
   wire rxbuf_empty, rxbuf_full;

   //wires from rxbuf
   wire [31:0] rxbuf_rd_data;

   reg [3:0] state, state_nxt;
   parameter IDLE_STATE = 4'h 0,
	     QUERY_STATE = 4'h 1,
	     TRANSF_C2N_QID_STATE = 4'h 2,
	     TRANSF_C2N_LEN_STATE = 4'h 3,
	     TRANSF_C2N_DATA_STATE = 4'h 4,
	     TRANSF_C2N_DONE_STATE = 4'h 5,
	     TRANSF_N2C_QID_STATE = 4'h 6,
	     TRANSF_N2C_DATA_ENQ_STATE = 4'h 7,
	     TRANSF_N2C_LEN_STATE = 4'h 8,
	     TRANSF_N2C_DATA_DEQ_STATE = 4'h 9,
	     TRANSF_N2C_DONE_STATE = 4'h A;

   always @(*) begin
      state_nxt = state;
      dma_op_code_ack_nxt = dma_op_code_ack_int;
      queue_id_nxt = queue_id;
      dma_vld_n2c_nxt = dma_vld_n2c_int;
      dma_data_n2c_nxt = 'h 0;
      dma_data_tri_en_nxt = dma_data_tri_en;
      tx_pkt_len_nxt = tx_pkt_len;
      rx_pkt_len_nxt = rx_pkt_len;

      txfifo_wr = 1'b 0;
      txfifo_wr_data = 'h 0;

      rxbuf_srst = 1'b 0;
      rxbuf_wr_en = 1'b 0;
      rxbuf_wr_data = 'h 0;
      rxbuf_rd_en = 1'b 0;

      rxfifo_rd_inc = 1'b 0;

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

	   dma_data_n2c_nxt = {
			       {12 {1'b 0}},
			       cpu_q_dma_pkt_avail, //[NUM_CPU_QUEUES-1:0]
			       {12 {1'b 0}},
			       cpu_q_dma_nearly_full //[NUM_CPU_QUEUES-1:0]
			       };

	   if (dma_op_code_req_d == OP_CODE_TRANSF_C2N) begin
	      state_nxt = TRANSF_C2N_QID_STATE;
	   end

	   else
	     if (dma_op_code_req_d == OP_CODE_TRANSF_N2C) begin
		state_nxt = TRANSF_N2C_QID_STATE;
	     end

	end // case: QUERY_STATE

	TRANSF_C2N_QID_STATE: begin
	   dma_op_code_ack_nxt = OP_CODE_TRANSF_C2N;
	   dma_data_tri_en_nxt = 1'b 0;
	   queue_id_nxt = dma_op_queue_id_d;

	   txfifo_wr = 1'b 1;
	   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 1;//0: pkt data; 1: req code
	   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 0;//0:dma tx; 1: dma rx
	   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'b 0;//unused
	   txfifo_wr_data[DMA_DATA_WIDTH-1:0]={{(DMA_DATA_WIDTH-4) {1'b 0}},
					    queue_id_nxt};

	   state_nxt = TRANSF_C2N_LEN_STATE;

	end // case: TRANSF_C2N_0_STATE

	TRANSF_C2N_LEN_STATE: begin
	   if (dma_vld_c2n_d) begin
	      tx_pkt_len_nxt = dma_data_c2n_d[PKT_LEN_CNT_WIDTH-1:0];

	      if (| tx_pkt_len_nxt) begin
		 state_nxt = TRANSF_C2N_DATA_STATE;
	      end
	      else
		state_nxt = TRANSF_C2N_DONE_STATE;
	   end // if (dma_vld_c2n_d)

	   //TODO: add transaction aborted by CPCI

	end // case: TRANSF_C2N_LEN_STATE

	TRANSF_C2N_DATA_STATE: begin

	   if (dma_vld_c2n_d) begin

	      case (tx_pkt_len)
		'h 1: begin
		   tx_pkt_len_nxt = 'h 0;

		   txfifo_wr = 1'b 1;
		   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 0;//0:pkt data;1:req code
		   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 1;//0:not EOP; 1:EOP
		   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'h 1;//1 byte of pkt data
		   txfifo_wr_data[DMA_DATA_WIDTH -1:0]=dma_data_c2n_d;

		end

		'h 2: begin
		   tx_pkt_len_nxt = 'h 0;

		   txfifo_wr = 1'b 1;
		   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 0;//0:pkt data;1:req code
		   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 1;//0:not EOP; 1:EOP
		   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'h 2;//2 byte of pkt data
		   txfifo_wr_data[DMA_DATA_WIDTH -1:0]=dma_data_c2n_d;

		end

		'h 3: begin
		   tx_pkt_len_nxt = 'h 0;

		   txfifo_wr = 1'b 1;
		   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 0;//0:pkt data;1:req code
		   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 1;//0:not EOP; 1:EOP
		   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'h 3;//3 byte of pkt data
		   txfifo_wr_data[DMA_DATA_WIDTH -1:0]=dma_data_c2n_d;

		end

		'h 4: begin
		   tx_pkt_len_nxt = 'h 0;

		   txfifo_wr = 1'b 1;
		   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 0;//0:pkt data;1:req code
		   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 1;//0:not EOP; 1:EOP
		   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'h 0;//4 byte of pkt data
		   txfifo_wr_data[DMA_DATA_WIDTH -1:0]=dma_data_c2n_d;

		end

		default: begin
		   tx_pkt_len_nxt = tx_pkt_len - 'h 4;

		   txfifo_wr = 1'b 1;
		   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 0;//0:pkt data;1:req code
		   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 0;//0:not EOP; 1:EOP
		   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'h 0;//4 byte of pkt data
		   txfifo_wr_data[DMA_DATA_WIDTH -1:0]=dma_data_c2n_d;

		end

	      endcase // case(tx_pkt_len)

	      if (~(| tx_pkt_len_nxt)) begin
		 //tx_pkt_len_nxt == 0
		 state_nxt = TRANSF_C2N_DONE_STATE;
	      end

	   end // if (dma_vld_c2n_d)

	   //TODO: add transaction aborted by CPCI

	end // case: TRANSF_C2N_DATA_STATE

	TRANSF_C2N_DONE_STATE: begin
	   case (dma_op_code_req_d)
	     OP_CODE_STATUS_QUERY: begin
		state_nxt = QUERY_STATE;
             end

             OP_CODE_TRANSF_N2C: begin
                state_nxt = TRANSF_N2C_QID_STATE;
             end

	   endcase

	end // case: TRANSF_C2N_DONE_STATE

	TRANSF_N2C_QID_STATE: begin

	   dma_op_code_ack_nxt = OP_CODE_TRANSF_N2C;
	   dma_data_tri_en_nxt = 1'b 1;
	   dma_vld_n2c_nxt = 1'b 0;

           queue_id_nxt = dma_op_queue_id_d;

	   txfifo_wr = 1'b 1;
	   txfifo_wr_data[DMA_DATA_WIDTH +3]=1'b 1;//0: pkt data; 1: req code
	   txfifo_wr_data[DMA_DATA_WIDTH +2]=1'b 1;//0:dma tx; 1:dma rx
	   txfifo_wr_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH]=2'b 0;//unused
	   txfifo_wr_data[DMA_DATA_WIDTH-1:0]={{(DMA_DATA_WIDTH-4) {1'b 0}},
					       queue_id_nxt};

	   rx_pkt_len_nxt = 'h 0;
	   rxbuf_srst = 1'b 1;

	   state_nxt = TRANSF_N2C_DATA_ENQ_STATE;

	end // case: TRANSF_N2C_QID_STATE

	TRANSF_N2C_DATA_ENQ_STATE: begin
	   if (!rxfifo_empty) begin
	      rxfifo_rd_inc = 1'b 1;

	      rxbuf_wr_en = 1'b 1;
	      rxbuf_wr_data = rxfifo_rd_data[DMA_DATA_WIDTH -1:0];

	      case (rxfifo_rd_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH])
		2'h 0:
		  rx_pkt_len_nxt = rx_pkt_len + 'h 4;
		2'h 1:
		  rx_pkt_len_nxt = rx_pkt_len + 'h 1;
		2'h 2:
		  rx_pkt_len_nxt = rx_pkt_len + 'h 2;
		2'h 3:
		  rx_pkt_len_nxt = rx_pkt_len + 'h 3;
	      endcase // case(rxfifo_rd_data[DMA_DATA_WIDTH +1:DMA_DATA_WIDTH])

	      if ( (rx_pkt_len_nxt > PKT_LEN_THRESHOLD) ||
		   (rxfifo_rd_data[DMA_DATA_WIDTH +2] ) ) //EOP
		state_nxt = TRANSF_N2C_LEN_STATE;

	   end // if (!rxfifo_empty)

           //TODO: add transaction aborted by CPCI

	end // case: TRANSF_N2C_DATA_ENQ_STATE

	TRANSF_N2C_LEN_STATE:
	  if (! dma_dest_q_nearly_full_c2n_d) begin
	     dma_vld_n2c_nxt = 1'b 1;
	     dma_data_n2c_nxt = { { (DMA_DATA_WIDTH-PKT_LEN_CNT_WIDTH) {1'b 0}},
				  rx_pkt_len };

	     state_nxt = TRANSF_N2C_DATA_DEQ_STATE;

             //TODO: add transaction aborted by CPCI

	  end

	TRANSF_N2C_DATA_DEQ_STATE: begin
	   if (! dma_dest_q_nearly_full_c2n_d) begin
	      rxbuf_rd_en = 1'b 1;
	   end

	   if (rxbuf_rd_en_d) begin
	      dma_vld_n2c_nxt = 1'b 1;
	      dma_data_n2c_nxt = rxbuf_rd_data;

	      if (rx_pkt_len > 4)
		rx_pkt_len_nxt = rx_pkt_len - 4;
	      else begin
		 rx_pkt_len_nxt = 'h 0;

		 state_nxt = TRANSF_N2C_DONE_STATE;
	      end

              //TODO: add transaction aborted by CPCI

	   end // if (rxbuf_rd_en_d)
	   else
	     dma_vld_n2c_nxt = 1'b 0;

	end // case: TRANSF_N2C_DATA_DEQ_STATE

	TRANSF_N2C_DONE_STATE: begin
	   dma_vld_n2c_nxt = 1'b 0;

           case (dma_op_code_req_d)
             OP_CODE_STATUS_QUERY: begin
                state_nxt = QUERY_STATE;
             end

             OP_CODE_TRANSF_C2N: begin
                state_nxt = TRANSF_C2N_QID_STATE;
             end
	   endcase // case(dma_op_code_req_d)

	end // case: TRANSF_N2C_DONE_STATE

      endcase // case(state)

   end // always @ (*)

   always @(posedge cpci_clk) begin
     if (cpci_reset) begin
	state <= IDLE_STATE;

	dma_op_code_ack <= OP_CODE_IDLE;
	dma_op_code_ack_int <= OP_CODE_IDLE;
	dma_vld_n2c <= 1'b 0;
	dma_vld_n2c_int <= 1'b 0;

	dma_data_tri_en <= 1'b 0;
	dma_data_n2c <= 'h 0;

	dma_dest_q_nearly_full_n2c <= 1'b 0;

	queue_id <= 'h 0;
	tx_pkt_len <= 'h 0;
	rx_pkt_len <= 'h 0;
	rxbuf_rd_en_d <= 1'b 0;

     end
     else begin
	state <= state_nxt;

	dma_op_code_ack <= dma_op_code_ack_nxt;
	dma_op_code_ack_int <= dma_op_code_ack_nxt;
	dma_vld_n2c <= dma_vld_n2c_nxt;
	dma_vld_n2c_int <= dma_vld_n2c_nxt;

	dma_data_tri_en <= dma_data_tri_en_nxt;
	dma_data_n2c <= dma_data_n2c_nxt;

	dma_dest_q_nearly_full_n2c <= dma_dest_q_nearly_full_n2c_nxt;

	queue_id <= queue_id_nxt;
	tx_pkt_len <= tx_pkt_len_nxt;
	rx_pkt_len <= rx_pkt_len_nxt;
	rxbuf_rd_en_d <= rxbuf_rd_en;

     end

   end // always @ (posedge cpci_clk)

   //------------------------------------------------
   // Instantiations

   // rxbuf is a standard FIFO (not first-word-fall-through FIFO)

   syncfifo_512x32 rxbuf
     (
      .clk ( cpci_clk ),
      .srst ( rxbuf_srst ),

      //rd intfc
      .empty ( rxbuf_empty ),
      .rd_en ( rxbuf_rd_en ),
      .dout ( rxbuf_rd_data ),

      //wr intfc
      .full ( rxbuf_full ),
      .wr_en ( rxbuf_wr_en ),
      .din ( rxbuf_wr_data )
      );

endmodule // nf2_dma_bus_fsm
