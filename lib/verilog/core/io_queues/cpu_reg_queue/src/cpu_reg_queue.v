///////////////////////////////////////////////////////////////////////////////
// $Id: cpu_reg_queue.v 2102 2007-08-10 23:26:46Z jyluo $
//
// Module: cpu_reg_queue.v
// Project: NF2.1
// Description:
//    supports CPU access to rx_fifo and tx_fifo using
//    register read and write.
//
//    Note that both rx_fifo and tx_fifo are first-word-fall-through FIFOs.
//
///////////////////////////////////////////////////////////////////////////////

  module cpu_reg_queue
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter CPCI_NF2_DATA_WIDTH = 32
      )
   (output [DATA_WIDTH-1:0]              out_data,
    output [CTRL_WIDTH-1:0]              out_ctrl,
    output                               out_wr,
    input                                out_rdy,

    input  [DATA_WIDTH-1:0]              in_data,
    input  [CTRL_WIDTH-1:0]              in_ctrl,
    input                                in_wr,
    output                               in_rdy,

    // --- Register interface
    input                                cpu_queue_reg_req,
    input                                cpu_queue_reg_rd_wr_L,
    input  [`CPU_QUEUE_REG_ADDR_WIDTH-1:0] cpu_queue_reg_addr,
    input  [CPCI_NF2_DATA_WIDTH-1:0]     cpu_queue_reg_wr_data,

    output reg [CPCI_NF2_DATA_WIDTH-1:0] cpu_queue_reg_rd_data,
    output reg                           cpu_queue_reg_ack,

    // --- Misc
    input                                reset,
    input                                clk
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
   parameter NUM_REGS_USED = 14; /* don't forget to update this when adding regs */
   parameter ADDR_WIDTH_USED = log2(NUM_REGS_USED);
   parameter TX_FIFO_DEPTH = 10'd 512;

   // ------------- Wires/reg ------------------

   reg [CPCI_NF2_DATA_WIDTH-1:0]       reg_file [0:NUM_REGS_USED-1];
   reg [NUM_REGS_USED-1 : 0] 	       reg_sel;

   wire [ADDR_WIDTH_USED-1:0]           addr;

   reg  [log2(CTRL_WIDTH):0]            out_increment;
   reg  [log2(CTRL_WIDTH):0]            in_increment;

   reg                                  out_ctrl_prev_is_0;
   reg                                  in_ctrl_prev_is_0;

   wire                                 rx_fifo_rd_en;
   wire                                 rx_pkt_read;
   reg                                  rx_pkt_written;
   wire [CPCI_NF2_DATA_WIDTH/8-1:0]     rx_fifo_rd_eop;

   wire                                 tx_fifo_rd_en;
   wire                                 tx_fifo_wr_en;
   wire                                 tx_pkt_read;
   reg                                  tx_pkt_written;
   wire [CPCI_NF2_DATA_WIDTH*9/8-1:0]   tx_fifo_din;
   reg                                  tx_fifo_wr_odd_word;
   reg                                  tx_fifo_wr_eop_d1;
   wire [CPCI_NF2_DATA_WIDTH/8-1:0]     tx_fifo_wr_eop;

   // wires from endianness reordering
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     rx_fifo_din;
   wire [CTRL_WIDTH-1:0]                reordered_in_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_in_data;
   wire [CTRL_WIDTH-1:0]                reordered_out_ctrl;
   wire [DATA_WIDTH-1:0]                reordered_out_data;

   // wires from rx_fifo
   wire [CPCI_NF2_DATA_WIDTH*9/8-1:0]   rx_fifo_dout;
   wire [CPCI_NF2_DATA_WIDTH/8-1:0] 	cpu_q_reg_rd_ctrl;
   wire [CPCI_NF2_DATA_WIDTH-1:0] 	cpu_q_reg_rd_data;
   wire [8:0] 				rx_fifo_rd_data_count;
   wire                                 rx_fifo_almost_full;
   wire 				rx_fifo_empty;
   reg 					rx_fifo_rd_odd_word;
   reg 					rx_fifo_rd_eop_d1;

   // wires from tx_fifo
   wire [CTRL_WIDTH+DATA_WIDTH-1:0]     tx_fifo_dout;
   wire [8:0] 				tx_fifo_wr_data_count;
   wire                                 tx_fifo_full, tx_fifo_almost_full;
   wire 				tx_fifo_empty;

   // wires for fifo write and read because of cpu register interface access
   reg 					cpu_q_reg_rd, cpu_q_reg_wr;

   reg [CPCI_NF2_DATA_WIDTH-1:0] 	cpu_queue_reg_rd_data_nxt;
   reg 					cpu_queue_reg_ack_nxt;

   reg					cpu_queue_reg_req_d1;

   // ------------- Modules -------------------
   generate
      genvar k;

      if(DATA_WIDTH == 32) begin: cpu_fifos32
         // reorder the input and outputs: CPU uses little endian, the User Data Path uses big endian
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign rx_fifo_din[CTRL_WIDTH+DATA_WIDTH-1-k] = in_ctrl[k];
            assign rx_fifo_din[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
            assign out_ctrl[k] = tx_fifo_dout[CTRL_WIDTH+DATA_WIDTH-1-k];
            assign out_data[8*k+7:8*k] = tx_fifo_dout[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)];
         end

	 // pkt data and ctrl stored in rx_fifo are in little endian
         async_fifo_512x36_progfull_500 rx_fifo
           (.din(rx_fifo_din),
	    .dout(rx_fifo_dout),
            .clk(clk),
            .rst(reset),
            .rd_data_count(rx_fifo_rd_data_count),
	    .wr_data_count(  ),
            .wr_en(in_wr),
            .rd_en(rx_fifo_rd_en),
            .full(  ),
            .prog_full(rx_fifo_almost_full),
            .empty(rx_fifo_empty)
	    );

	 // pkt data and ctrl stored in tx_fifo are in little endian
         async_fifo_512x36_progfull_500 tx_fifo
           (.din(tx_fifo_din),
            .dout(tx_fifo_dout),
            .clk(clk),
            .wr_en(tx_fifo_wr_en),
            .rd_en(tx_fifo_rd_en),
            .rst(reset),
	    .rd_data_count(  ),
            .wr_data_count(tx_fifo_wr_data_count),
            .full(tx_fifo_full),
            .prog_full(tx_fifo_almost_full),
            .empty(tx_fifo_empty)
	    );

      end // block: cpu_rx_fifo32

      else if(DATA_WIDTH == 64) begin: cpu_fifos64
         /* need to reorder for endianness and so that ctrl is next to data on the cpu side*/
         for(k=0; k<CTRL_WIDTH; k=k+1) begin: reorder_endianness
            assign reordered_in_ctrl[CTRL_WIDTH-1-k] = in_ctrl[k];
            assign reordered_in_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = in_data[8*k+7:8*k];
            assign out_ctrl[CTRL_WIDTH-1-k] = reordered_out_ctrl[k];
            assign out_data[DATA_WIDTH-1-8*k:DATA_WIDTH-8*(k+1)] = reordered_out_data[8*k+7:8*k];
         end
         assign rx_fifo_din = {reordered_in_ctrl[3:0], reordered_in_data[31:0],
                               reordered_in_ctrl[7:4], reordered_in_data[63:32]};
         assign reordered_out_ctrl = {tx_fifo_dout[35:32], tx_fifo_dout[71:68]};
         assign reordered_out_data = {tx_fifo_dout[31:0], tx_fifo_dout[67:36]};

         // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_256x72_to_36 rx_fifo
           (.din(rx_fifo_din),
            .rd_clk(clk),
            .rd_en(rx_fifo_rd_en),
            .rst(reset),
            .wr_clk(clk),
            .wr_en(in_wr),
            .almost_full(rx_fifo_almost_full),
	    .dout(rx_fifo_dout),
            .empty(rx_fifo_empty),
            .full(),
            .rd_data_count(rx_fifo_rd_data_count)
	    );

	 // stored in little endian for each 32-bit data and 4-bit ctrl
         async_fifo_512x36_to_72_progfull_500 tx_fifo
           (.din(tx_fifo_din), // Bus [35 : 0]
            .rd_clk(clk),
            .rd_en(tx_fifo_rd_en),
            .rst(reset),
            .wr_clk(clk),
            .wr_en(tx_fifo_wr_en),
            .prog_full(tx_fifo_almost_full),
            .dout(tx_fifo_dout), // Bus [71 : 0]
            .empty(tx_fifo_empty),
            .full(tx_fifo_full),
	    .rd_data_count(),
            .wr_data_count(tx_fifo_wr_data_count) // Bus [8 : 0]
	    );

     end // block: cpu_fifos64

   endgenerate

   // -------------- Logic --------------------
   assign rx_fifo_rd_eop = cpu_q_reg_rd_ctrl;

   wire [CPCI_NF2_DATA_WIDTH-1:0] cpu_q_reg_tx_fifo_wr_ctrl = reg_file[`CPU_REG_Q_WR_CTRL_WORD];

   assign tx_fifo_wr_eop = cpu_q_reg_tx_fifo_wr_ctrl[CPCI_NF2_DATA_WIDTH/8-1:0];

   assign tx_fifo_din =
	  {cpu_q_reg_tx_fifo_wr_ctrl[CPCI_NF2_DATA_WIDTH/8-1:0], cpu_queue_reg_wr_data};

   assign {cpu_q_reg_rd_ctrl, cpu_q_reg_rd_data} = rx_fifo_dout;

   // select the byte increment values for counters.
   // out_data is in big endian. out_data[7:0] is the last byte
   always @(*) begin
      if(tx_fifo_rd_en) begin
	 //default value
         out_increment = CTRL_WIDTH;

         case(out_ctrl)
            'h 01: out_increment = 8;
            'h 02: out_increment = 7;
            'h 04: out_increment = 6;
            'h 08: out_increment = 5;
            'h 10: out_increment = 4;
            'h 20: out_increment = 3;
            'h 40: out_increment = 2;
            'h 80: out_increment = 1;
         endcase // case(out_ctrl)
      end // if (tx_fifo_rd_en)

      else begin
         out_increment = 'h 0;
      end // else: !if(tx_fifo_rd_en)
   end // always @ (*)

   // data is in little endian. rd_data[7:0] is the first byte.
   always @(*) begin
      if(rx_fifo_rd_en) begin
         in_increment = CPCI_NF2_DATA_WIDTH/8;

         case(rx_fifo_rd_eop[CPCI_NF2_DATA_WIDTH/8-1:0])
            'h 01: in_increment = 'h 1;
            'h 02: in_increment = 'h 2;
            'h 04: in_increment = 'h 3;
            'h 08: in_increment = 'h 4;
         endcase // case(rx_fifo_rd_eop[CPCI_NF2_DATA_WIDTH/8-1:0])

	 if (rx_fifo_rd_eop_d1)
	   in_increment = 'h 0;

      end // if(rx_fifo_rd_en)

      else begin
         in_increment = 'h 0;
      end
   end // always @ (*)

   /* monitor pkt padding */
   always @(posedge clk) begin
      if(reset) begin
         tx_pkt_written <= 1'b 0;
         tx_fifo_wr_odd_word <= 1'b 0;
         tx_fifo_wr_eop_d1 <= 1'b 0;

         rx_pkt_written <= 1'b 0;
	 rx_fifo_rd_odd_word <= 1'b 0;
	 rx_fifo_rd_eop_d1 <= 1'b 0;

      end
      else begin
         rx_pkt_written <= (in_wr && (|in_ctrl) && in_ctrl_prev_is_0);

         if (DATA_WIDTH==64) begin

            if (tx_fifo_wr_en) begin

	       tx_fifo_wr_odd_word <= ~tx_fifo_wr_odd_word;

	       if(!tx_fifo_wr_odd_word && tx_fifo_wr_eop) begin
                  tx_fifo_wr_eop_d1 <= 1;
	       end
	       else if(tx_fifo_wr_odd_word && (tx_fifo_wr_eop || tx_fifo_wr_eop_d1)) begin
                  tx_pkt_written <= 1;
                  tx_fifo_wr_eop_d1 <= 0;
	       end

            end // if (tx_fifo_wr_en)

            else begin
	       tx_pkt_written <= 0;
            end

	    if (rx_fifo_rd_en) begin
	       rx_fifo_rd_odd_word <= ~ rx_fifo_rd_odd_word;

	       if (!rx_fifo_rd_odd_word && rx_fifo_rd_eop) begin
		  rx_fifo_rd_eop_d1 <= 1'b 1;
	       end
	       else if (rx_fifo_rd_eop_d1) begin
		  rx_fifo_rd_eop_d1 <= 1'b 0;

	       end
	    end // if (rx_fifo_rd_en)


         end // if (DATA_WIDTH==64)

         else begin
            tx_pkt_written <= tx_fifo_wr_en && tx_fifo_wr_eop;
         end

      end // else: !if(reset)
   end // always @ (posedge clk)


   /* monitor when pkts are read */
   assign tx_pkt_read = (tx_fifo_rd_en && (|out_ctrl) && out_ctrl_prev_is_0);
   assign rx_pkt_read = (|cpu_q_reg_rd_ctrl) && rx_fifo_rd_en;

   /* if a packet is ready to be sent to the user data
    * path from the CPU, then pipe it out */
   assign tx_fifo_rd_en = (reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] != 0) & out_rdy ;
   assign out_wr = tx_fifo_rd_en;

   assign in_rdy = !rx_fifo_almost_full;

   assign tx_fifo_wr_en = cpu_q_reg_wr && (!tx_fifo_full);
   assign rx_fifo_rd_en = cpu_q_reg_rd && (!rx_fifo_empty);

   assign addr = cpu_queue_reg_addr[ADDR_WIDTH_USED-1:0];

   wire [CPCI_NF2_DATA_WIDTH-1:0] reg_unit_data = reg_file[addr];

   always @(*) begin

      cpu_q_reg_rd = 1'b 0;
      cpu_q_reg_wr = 1'b 0;

      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_data;
      cpu_queue_reg_ack_nxt = 1'b 0;

      reg_sel = {NUM_REGS_USED {1'b 0}};

      cpu_queue_reg_ack_nxt = cpu_queue_reg_req && !cpu_queue_reg_req_d1;

      if (cpu_queue_reg_req && (!cpu_queue_reg_req_d1)) begin

	 cpu_queue_reg_rd_data_nxt = 'h 0;

	 case (addr)

	   `CPU_REG_Q_RD_CTRL_WORD: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_RD_CTRL_WORD] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_RD_DATA_WORD: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_RD_DATA_WORD] = 1'b 1;

	      if (cpu_queue_reg_rd_wr_L) begin
		 cpu_queue_reg_rd_data_nxt = cpu_q_reg_rd_data;
		 cpu_q_reg_rd = 1'b 1; //trigger rx_fifo_rd
	      end

	   end

	   `CPU_REG_Q_WR_CTRL_WORD: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_WR_CTRL_WORD] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_WR_DATA_WORD: begin
	      // write only register
	      reg_sel[`CPU_REG_Q_WR_DATA_WORD] = 1'b 1;

	      if (~ cpu_queue_reg_rd_wr_L)
		cpu_q_reg_wr = 1'b 1; //trigger tx_fifo_wr
	   end

	   `CPU_REG_Q_RX_NUM_PKTS_RCVD: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_RX_NUM_PKTS_RCVD] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_RX_NUM_WORDS_RCVD: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_RX_NUM_WORDS_RCVD] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_RX_NUM_BYTES_RCVD: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_RX_NUM_BYTES_RCVD] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_TX_NUM_PKTS_SENT: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_TX_NUM_PKTS_SENT] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_TX_NUM_WORDS_SENT: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_TX_NUM_WORDS_SENT] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_TX_NUM_BYTES_SENT: begin
	      // read and write register
	      reg_sel[`CPU_REG_Q_TX_NUM_BYTES_SENT] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_WR_NUM_PKTS_IN_Q: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_WR_NUM_WORDS_LEFT: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_WR_NUM_WORDS_LEFT] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_RD_NUM_WORDS_AVAIL: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_RD_NUM_WORDS_AVAIL] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	   `CPU_REG_Q_RD_NUM_PKTS_IN_Q: begin
	      // read only register
	      reg_sel[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] = 1'b 1;
	      cpu_queue_reg_rd_data_nxt = cpu_queue_reg_rd_wr_L ?
					  reg_unit_data : 'h 0;
	   end

	 endcase // case(addr)

      end // if (cpu_queue_reg_req)

   end // always @ (*)


   always @(posedge clk) begin
      // This can be in an SRL
      //
      // Don't care about reset
      cpu_queue_reg_req_d1                      <= cpu_queue_reg_req;
   end

   /* run the counters and mux between write and update */
   always @(posedge clk) begin
      if(reset) begin
         out_ctrl_prev_is_0       <= 1'b 0;
         in_ctrl_prev_is_0        <= 1'b 0;

         cpu_queue_reg_rd_data    <= 'h 0;
         cpu_queue_reg_ack        <= 1'b 0;

	 reg_file[`CPU_REG_Q_RD_CTRL_WORD] <= 'h 0;
	 reg_file[`CPU_REG_Q_RD_DATA_WORD] <= 'h 0;

	 reg_file[`CPU_REG_Q_WR_CTRL_WORD] <= 'h 0;
	 reg_file[`CPU_REG_Q_WR_DATA_WORD] <= 'h 0;

	 reg_file[`CPU_REG_Q_RX_NUM_PKTS_RCVD] <= 'h 0;
	 reg_file[`CPU_REG_Q_RX_NUM_WORDS_RCVD] <= 'h 0;
	 reg_file[`CPU_REG_Q_RX_NUM_BYTES_RCVD] <= 'h 0;

	 reg_file[`CPU_REG_Q_TX_NUM_PKTS_SENT] <= 'h 0;
	 reg_file[`CPU_REG_Q_TX_NUM_WORDS_SENT] <= 'h 0;
	 reg_file[`CPU_REG_Q_TX_NUM_BYTES_SENT] <= 'h 0;

	 reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] <= 'h 0;
	 reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT] <= {22'h 0, TX_FIFO_DEPTH};

	 reg_file[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] <= 'h 0;
	 reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL] <= 'h 0;

      end // if (reset)

      else begin
         out_ctrl_prev_is_0 <= tx_fifo_rd_en ? (out_ctrl==0) : out_ctrl_prev_is_0;
         in_ctrl_prev_is_0  <= in_wr ? (in_ctrl==0) : in_ctrl_prev_is_0;

	 cpu_queue_reg_rd_data <= cpu_queue_reg_rd_data_nxt;
	 cpu_queue_reg_ack     <= cpu_queue_reg_ack_nxt;

	 if (cpu_q_reg_rd )
	   reg_file[`CPU_REG_Q_RD_CTRL_WORD] <= cpu_q_reg_rd_ctrl;

	 if (reg_sel[`CPU_REG_Q_WR_CTRL_WORD] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_WR_CTRL_WORD] <= { {(CPCI_NF2_DATA_WIDTH - CTRL_WIDTH) {1'b 0}},
						  cpu_queue_reg_wr_data[CTRL_WIDTH-1:0]};

	 if (reg_sel[`CPU_REG_Q_RX_NUM_PKTS_RCVD] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_RX_NUM_PKTS_RCVD] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_RX_NUM_PKTS_RCVD] <= reg_file[`CPU_REG_Q_RX_NUM_PKTS_RCVD] +
						    rx_pkt_read;

	 if (reg_sel[`CPU_REG_Q_RX_NUM_WORDS_RCVD] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_RX_NUM_WORDS_RCVD] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_RX_NUM_WORDS_RCVD] <= reg_file[`CPU_REG_Q_RX_NUM_WORDS_RCVD] +
						     ( | in_increment );

	 if (reg_sel[`CPU_REG_Q_RX_NUM_BYTES_RCVD] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_RX_NUM_BYTES_RCVD] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_RX_NUM_BYTES_RCVD] <= reg_file[`CPU_REG_Q_RX_NUM_BYTES_RCVD] +
						     in_increment;

	 if (reg_sel[`CPU_REG_Q_TX_NUM_PKTS_SENT] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_TX_NUM_PKTS_SENT] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_TX_NUM_PKTS_SENT] <= reg_file[`CPU_REG_Q_TX_NUM_PKTS_SENT] +
						    tx_pkt_read;

	 if (reg_sel[`CPU_REG_Q_TX_NUM_WORDS_SENT] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_TX_NUM_WORDS_SENT] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_TX_NUM_WORDS_SENT] <= reg_file[`CPU_REG_Q_TX_NUM_WORDS_SENT] +
						     tx_fifo_rd_en;

	 if (reg_sel[`CPU_REG_Q_TX_NUM_BYTES_SENT] && ~cpu_queue_reg_rd_wr_L)
	   reg_file[`CPU_REG_Q_TX_NUM_BYTES_SENT] <= cpu_queue_reg_wr_data;
	 else
	   reg_file[`CPU_REG_Q_TX_NUM_BYTES_SENT] <= reg_file[`CPU_REG_Q_TX_NUM_BYTES_SENT] +
						     out_increment;

	 case ({tx_pkt_read, tx_pkt_written})
           2'b 10: reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] <= reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] - 1;
           2'b 01: reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] <= reg_file[`CPU_REG_Q_WR_NUM_PKTS_IN_Q] + 1;
	 endcase // case({tx_pkt_read, tx_pkt_written})

         case ({tx_fifo_wr_en, tx_fifo_rd_en})
           2'b10: reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT]  <= reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT] - 1'b1;
           2'b01: reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT]  <= reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT] + DATA_WIDTH/32;
           2'b11: reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT]  <= reg_file[`CPU_REG_Q_WR_NUM_WORDS_LEFT] - 1'b1 + DATA_WIDTH/32;
         endcase // case({rx_fifo_rd_en, in_wr})

	 case ({rx_pkt_read, rx_pkt_written})
           2'b10: reg_file[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] <= reg_file[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] - 1;
           2'b01: reg_file[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] <= reg_file[`CPU_REG_Q_RD_NUM_PKTS_IN_Q] + 1;
         endcase // case({rx_pkt_read, rx_pkt_written})

	 case ({rx_fifo_rd_en, in_wr})
           2'b10: reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL]  <= reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL] - 1'b1;
           2'b01: reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL]  <= reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL] + DATA_WIDTH/32;
           2'b11: reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL]  <= reg_file[`CPU_REG_Q_RD_NUM_WORDS_AVAIL] - 1'b1 + DATA_WIDTH/32;
         endcase // case({rx_fifo_rd_en, in_wr})

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // cpu_reg_queue
