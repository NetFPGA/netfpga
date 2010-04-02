///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: output_port_lookup.v
// Author: Jad Naous
// Project: Hardwired switch
// Description: This will basically connect links together.
//              Via registers, the user can choose where packets from each input
//              port go.
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module output_port_lookup
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter INPUT_ARBITER_STAGE_NUM = 2,
      parameter IO_QUEUE_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter NUM_IQ_BITS = 3,
      parameter STAGE_NUM = 4,
      parameter CPU_QUEUE_NUM = 0)

   (// --- data path interface
    output     [DATA_WIDTH-1:0]           out_data,
    output     [CTRL_WIDTH-1:0]           out_ctrl,
    output reg                            out_wr,
    input                                 out_rdy,

    input  [DATA_WIDTH-1:0]               in_data,
    input  [CTRL_WIDTH-1:0]               in_ctrl,
    input                                 in_wr,
    output                                in_rdy,

    // --- Register interface
    input                                 reg_req_in,
    input                                 reg_ack_in,
    input                                 reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]      reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]     reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]        reg_src_in,

    output                                reg_req_out,
    output                                reg_ack_out,
    output                                reg_rd_wr_L_out,
    output     [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output     [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output     [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    input                                 clk,
    input                                 reset);

   `LOG2_FUNC
   //--------------------- Internal Parameter-------------------------
   localparam IN_MODULE_HDRS   = 0;
   localparam IN_PACKET        = 1;

   //---------------------- Wires/Regs -------------------------------
   wire [`CPCI_NF2_DATA_WIDTH*NUM_OUTPUT_QUEUES-1:0] sw_regs;
   wire [NUM_OUTPUT_QUEUES-1:0]                      output_ports[NUM_OUTPUT_QUEUES-1:0];
   reg [DATA_WIDTH-1:0]                              in_data_modded;
   reg                                               state, state_nxt;
   wire [log2(NUM_OUTPUT_QUEUES)-1:0]                src_port;
   wire [NUM_OUTPUT_QUEUES-1:0]                      output_port;

   //----------------------- Modules ---------------------------------
   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data_modded}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({out_ctrl, out_data}),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (`HARDWIRE_LOOKUP_BLOCK_ADDR),
       .REG_ADDR_WIDTH (`HARDWIRE_LOOKUP_REG_ADDR_WIDTH),
       .NUM_COUNTERS (0),
       .NUM_SOFTWARE_REGS (NUM_OUTPUT_QUEUES),
       .NUM_HARDWARE_REGS (0)
       )
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
      .counter_updates   (),
      .counter_decrement (),

      // --- SW regs interface
      .software_regs     (sw_regs),

      // --- HW regs interface
      .hardware_regs     (),

      .clk               (clk),
      .reset             (reset));


   //----------------------- Logic ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;

   assign src_port = in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS];

   generate
      genvar i;
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin:gen_sw_regs
         assign output_ports[i] = sw_regs[`CPCI_NF2_DATA_WIDTH*i+NUM_OUTPUT_QUEUES-1:`CPCI_NF2_DATA_WIDTH*i];
      end
   endgenerate

   assign output_port = output_ports[src_port];

   /* modify the IOQ module header */
   always @(*) begin

      in_data_modded   = in_data;
      state_nxt        = state;

      case(state)
         IN_MODULE_HDRS: begin
            if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
               in_data_modded[`IOQ_DST_PORT_POS+NUM_OUTPUT_QUEUES-1:`IOQ_DST_PORT_POS] = output_port;
            end
            if(in_wr && in_ctrl==0) begin
               state_nxt = IN_PACKET;
            end
         end // case: IN_MODULE_HDRS

         IN_PACKET: begin
            if(in_wr && in_ctrl!=0) begin
               state_nxt = IN_MODULE_HDRS;
            end
         end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state <= IN_MODULE_HDRS;
      end
      else begin
         state <= state_nxt;
      end
   end

   /* handle outputs */
   assign in_fifo_rd_en = out_rdy && !in_fifo_empty;
   always @(posedge clk) begin
      out_wr <= reset ? 0 : in_fifo_rd_en;
   end

endmodule
