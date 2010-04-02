///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: rate_limiter.v 5606 2009-05-29 18:54:40Z g9coving $
//
// Module: rate_limiter.v
// Project: rate_limiter
// Description: Limits the rate at which packets pass through
//
///////////////////////////////////////////////////////////////////////////////

module rate_limiter
  #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter RATE_LIMIT_BLOCK_TAG = `RATE_LIMIT_0_BLOCK_ADDR
   )

   (output reg [DATA_WIDTH-1:0]        out_data,
    output reg [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                         out_wr,
    input                              out_rdy,

    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output reg                         in_rdy,

    // --- Register interface
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    input                              clk,
    input                              reset);



   //----------------------- local parameter ---------------------------
   parameter WAIT_FOR_PKT       = 0;
   parameter READ_PKT           = 1;
   parameter WAIT_INTER_PKT_GAP = 2;


   //----------------------- wires/regs---------------------------------
   wire                                enable_rate_limit;
   wire [3:0]                          thruput_shift;

   wire                                eop;
   reg [23:0]                          count, count_next;
   wire [23:0]                         count_plus_1;
   wire [23:0]                         count_minus_1;
   reg                                 out_ctrl_prev_is_0;

   reg                                 in_fifo_rd_en;

   reg [1:0]                           state, state_next;

   reg                                 limiter_in_wr;
   reg                                 limiter_out_wr;
   wire [CTRL_WIDTH-1:0]               limiter_out_ctrl;
   wire [DATA_WIDTH-1:0]               limiter_out_data;
   wire                                limiter_in_rdy;

   //------------------------ Modules ----------------------------------
   rate_limiter_regs
     #(.UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
       .RATE_LIMIT_BLOCK_TAG (RATE_LIMIT_BLOCK_TAG)
   ) rate_limiter_regs
   (
      // Registers
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

      // Outputs
      .thruput_shift                    (thruput_shift),
      .enable_rate_limit                (enable_rate_limit),

      // Inputs
      .clk                              (clk),
      .reset                            (reset)
   );

   small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(2))
      input_fifo
        (.din           ({in_ctrl, in_data}),  // Data in
         .wr_en         (limiter_in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({limiter_out_ctrl, limiter_out_data}),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .prog_full     (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //----------------------- Mux logic -----------------------
   always @(*) begin
      if(!enable_rate_limit) begin
         /* mux the output */
         out_wr = in_wr;
         out_data = in_data;
         out_ctrl = in_ctrl;
         in_rdy = out_rdy;

         /* mux the input */
         limiter_in_wr = 0;
      end
      else begin
         /* output */
         out_wr = limiter_out_wr;
         out_data = limiter_out_data;
         out_ctrl = limiter_out_ctrl;
         in_rdy = limiter_in_rdy;

         /* input */
         limiter_in_wr = in_wr;
      end // else: !if(enable_rate_limit)
   end // always @ (*)

   //----------------------- Rate limiting logic -----------------------

   assign eop = (limiter_out_ctrl!=0) && out_ctrl_prev_is_0;
   assign count_plus_1 = count + 1'b1;
   assign count_minus_1 = count - 1'b1;

   assign limiter_in_rdy = !in_fifo_nearly_full;

   /*
    * Wait until a packet starts arriving, then count its
    * length. When the packet is done, wait the pkt's length
    * shifted by the user specified amount
    */
   always @(*) begin
      state_next = state;
      in_fifo_rd_en = 0;
      count_next = count;

      case(state)
         WAIT_FOR_PKT: begin
            if(!enable_rate_limit) begin
               in_fifo_rd_en = out_rdy & !in_fifo_empty;
               count_next = 0;
            end
            else if(!in_fifo_empty) begin
               state_next = READ_PKT;
               if(out_rdy) begin
                  in_fifo_rd_en = 1;
                  count_next = count_plus_1;
               end
            end
         end // case: WAIT_FOR_PKT

         READ_PKT: begin
            if(eop & out_wr) begin
               count_next = (count_plus_1<<thruput_shift);
               state_next = WAIT_INTER_PKT_GAP;
            end
            else if(!eop & out_rdy & !in_fifo_empty) begin
               in_fifo_rd_en = 1;
               count_next = count_plus_1;
            end
         end // case: READ_PKT

         WAIT_INTER_PKT_GAP: begin
            if(count > 0) begin
               count_next = count_minus_1;
            end
            else begin
               state_next = WAIT_FOR_PKT;
            end
         end
      endcase // case(state)
   end // always @ (*)


   always @(posedge clk) begin
      if(reset) begin
         out_ctrl_prev_is_0    <= 0;
         count                 <= 0;
         state                 <= WAIT_FOR_PKT;
      end
      else begin
         // monitor the ctrl lines to determine end-of-pkt
         if(limiter_out_wr) begin
            out_ctrl_prev_is_0 <= (limiter_out_ctrl==0);
         end

         count <= count_next;
         state <= state_next;

         limiter_out_wr <= in_fifo_rd_en;

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // rate_limiter
