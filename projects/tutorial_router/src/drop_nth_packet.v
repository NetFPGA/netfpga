///////////////////////////////////////////////////////////////////////////////
// $Id: drop_nth_packet 2008-03-13 gac1 $
//
// Module: drop_nth_packet.v
// Project: NF2.1
// Description: defines a module that drops the nth packet
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`include "NF_2.1_defines.v"

  module drop_nth_packet
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = 8,
    parameter UDP_REG_SRC_WIDTH = 3,
    parameter SW_REGS_TAG = 4,
    parameter CNTR_REGS_TAG = 5)
   (
    input  [DATA_WIDTH-1:0]              in_data,
    input  [CTRL_WIDTH-1:0]              in_ctrl,
    input                                in_wr,
    output                               in_rdy,

    output [DATA_WIDTH-1:0]              out_data,
    output [CTRL_WIDTH-1:0]              out_ctrl,
    output                               out_wr,
    input                                out_rdy,

    // --- Register interface
    input                                reg_req_in,
    input                                reg_ack_in,
    input                                reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]     reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]    reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]       reg_src_in,

    output                               reg_req_out,
    output                               reg_ack_out,
    output                               reg_rd_wr_L_out,
    output  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
    output  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
    output  [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

    // misc
    input                                reset,
    input                                clk);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

  //------------------------- Internal paremeters -------------------------------

  parameter IDLE 			= 'h0;
  parameter WAIT_END_PKT 		= 'h1;

  parameter NUM_STATES 			= 2;

  reg [NUM_STATES-1:0] 			state;
  reg [NUM_STATES-1:0] 			next_state;

  wire [DATA_WIDTH-1:0]			in_fifo_data;
  wire [CTRL_WIDTH-1:0]			in_fifo_ctrl;

  wire 					in_fifo_nearly_full;
  wire 					in_fifo_empty;

  reg 					in_fifo_rd_en;
  reg 					in_fifo_rd_en_2;
  reg 					out_wr_int;

  wire [`CPCI_NF2_DATA_WIDTH-1:0] 	drop_nth_packet_en_reg;
  wire [`CPCI_NF2_DATA_WIDTH-1:0] 	drop_nth_packet_reg; //software register

  reg [`CPCI_NF2_DATA_WIDTH-1:0] 	drop_nth_packet_en_reg_prev;
  reg [`CPCI_NF2_DATA_WIDTH-1:0] 	drop_nth_packet_reg_prev;

  wire [15:0] 				drop_nth_packet;

  wire 					rst_counter;
  reg 					inc_counter;
  reg [15:0] 				counter;

  reg 					rst_counter_state;
  reg 					rst_counter_reg;

  assign   	in_rdy = !in_fifo_nearly_full && out_rdy;
  assign 	out_wr = out_wr_int;
  assign 	out_data = in_fifo_data;
  assign 	out_ctrl = in_fifo_ctrl;
  assign 	drop_nth_packet = 'h3;
  assign 	rst_counter = rst_counter_state || rst_counter_reg;

  //------------------------- Modules-------------------------------

  small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(5), .PROG_FULL_THRESHOLD(31))
    input_fifo
      (.din           ({in_ctrl, in_data}),  // Data in
       .wr_en         (in_wr),             // Write enable
       .rd_en         (in_fifo_rd_en),    // Read the next word
       .dout          ({in_fifo_ctrl, in_fifo_data}),
       .full          (),
       .nearly_full   (in_fifo_nearly_full),
       .empty         (in_fifo_empty),
       .reset         (reset),
       .clk           (clk)
       );

  generic_sw_regs
    #(
    .UDP_REG_SRC_WIDTH 	(UDP_REG_SRC_WIDTH),
    .TAG 	       	(`DROP_NTH_BLOCK_ADDR),
    .REG_ADDR_WIDTH    	(`DROP_NTH_REG_ADDR_WIDTH),
    .NUM_REGS_USED 	(2))
    generic_sw_regs
    (
    .reg_req_in       (reg_req_in),
    .reg_ack_in       (reg_ack_in),
    .reg_rd_wr_L_in   (reg_rd_wr_L_in),
    .reg_addr_in      (reg_addr_in),
    .reg_data_in      (reg_data_in),
    .reg_src_in       (reg_src_in),

    .reg_req_out      (reg_req_out),
    .reg_ack_out      (reg_ack_out),
    .reg_rd_wr_L_out  (reg_rd_wr_L_out),
    .reg_addr_out     (reg_addr_out),
    .reg_data_out     (reg_data_out),
    .reg_src_out      (reg_src_out),

    .software_regs ({drop_nth_packet_reg, drop_nth_packet_en_reg}),

    .clk (clk),
    .reset (reset));

  //------------------------- Logic-------------------------------

   //latch the state
   always @(posedge clk) begin
      if(reset) begin
         state <= IDLE;
	drop_nth_packet_reg_prev <= 0;
	drop_nth_packet_en_reg_prev <= 0;
      end
      else begin
         state <= next_state;
	drop_nth_packet_reg_prev <= drop_nth_packet_reg;
	drop_nth_packet_en_reg_prev <= drop_nth_packet_en_reg;
      end
   end

  //--- State Machine
  always @(*) begin
    //default assignments
    next_state    = state;

    //out_wr_int = 0;
    in_fifo_rd_en = 0;
    rst_counter_state = 0;
    inc_counter = 0;

    case(state)
      IDLE: begin
	if (!in_fifo_empty && out_rdy) begin
	  in_fifo_rd_en = 1;

	  if (in_fifo_ctrl == 0) begin
	    next_state = WAIT_END_PKT;
	  end
	end
      end

      WAIT_END_PKT: begin
	if (!in_fifo_empty && out_rdy) begin
	  in_fifo_rd_en = 1;
	end

	if (in_fifo_ctrl != 0) begin
	  next_state = IDLE;
	  if (counter == drop_nth_packet_reg[15:0]) begin
	    rst_counter_state = 1;
	  end
	  else begin
	    inc_counter = 1;
	  end
	end
      end

    endcase
  end

  // Counter
  always @(posedge clk) begin
    if (reset) begin
      counter <= 0;
    end
    else begin
      //insert counter code

    end
  end

  always @(posedge clk) begin
    if (reset) begin
      in_fifo_rd_en_2 <= 0;
      rst_counter_reg <= 0;
    end
    else begin
      in_fifo_rd_en_2 <= in_fifo_rd_en;
      rst_counter_reg <= 0;

	if ((drop_nth_packet_en_reg != drop_nth_packet_en_reg_prev) ||
	  (drop_nth_packet_reg != drop_nth_packet_reg_prev)) begin
	rst_counter_reg <= 1;
      end
    end
  end

  always @(*) begin
    if (reset) begin
      out_wr_int = 0;
    end
    else begin
      out_wr_int = 0;

    	if (drop_nth_packet_en_reg[0]) begin
	  		if (counter != drop_nth_packet_reg[16:0]) begin
	    		out_wr_int = in_fifo_rd_en_2;
	  		end
     	end
      else begin
				out_wr_int = in_fifo_rd_en_2;
      end
    end
  end

endmodule
