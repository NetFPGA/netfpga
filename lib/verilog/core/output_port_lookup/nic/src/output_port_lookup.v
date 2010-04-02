/////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_port_lookup.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: output_port_lookup.v
// Project: 4-port NIC
// Description: Connects the MAC ports to the CPU DMA ports
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

    output reg                            reg_req_out,
    output reg                            reg_ack_out,
    output reg                            reg_rd_wr_L_out,
    output reg [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output reg [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output reg [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    input                                 clk,
    input                                 reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //--------------------- Internal Parameter-------------------------
   localparam IN_MODULE_HDRS   = 0;
   localparam IN_PACKET        = 1;

   //---------------------- Wires/Regs -------------------------------
   reg [DATA_WIDTH-1:0] in_data_modded;
   reg [15:0]           decoded_src;
   reg                  state, state_nxt;

   //----------------------- Modules ---------------------------------
   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data_modded}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({out_ctrl, out_data}),
         .full          (),
         .prog_full     (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //----------------------- Logic ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;

   /* pkt is from the cpu if it comes in on an odd numbered port */
   assign pkt_is_from_cpu = in_data[`IOQ_SRC_PORT_POS];

   /* Decode the source port */
   always @(*) begin
      decoded_src = 0;
      decoded_src[in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS]] = 1'b1;
   end

   /* modify the IOQ module header */
   always @(*) begin

      in_data_modded   = in_data;
      state_nxt        = state;

      case(state)
         IN_MODULE_HDRS: begin
            if(in_wr && in_ctrl==IO_QUEUE_STAGE_NUM) begin
               if(pkt_is_from_cpu) begin
                  in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = {1'b0, decoded_src[15:1]};
               end
               else begin
                  in_data_modded[`IOQ_DST_PORT_POS+15:`IOQ_DST_PORT_POS] = {decoded_src[14:0], 1'b0};
               end
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

   /* registers unused */
   always @(posedge clk) begin
      reg_req_out        <= reg_req_in;
      reg_ack_out        <= reg_ack_in;
      reg_rd_wr_L_out    <= reg_rd_wr_L_in;
      reg_addr_out       <= reg_addr_in;
      reg_data_out       <= reg_data_in;
      reg_src_out        <= reg_src_in;
   end

endmodule
