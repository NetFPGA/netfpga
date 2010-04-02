///////////////////////////////////////////////////////////////////////////////
// $Id: testbench.v 1969 2007-07-18 21:59:27Z jnaous $
//
// Module: testbench.v
// Project: rate_limiter
// Description: instantiate module under test and set the stimuli
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps
`include "udp_defines.v"

  module testbench();

   parameter CPCI_NF2_DATA_WIDTH = 32;
   parameter DATA_WIDTH = 64;
   parameter CTRL_WIDTH = DATA_WIDTH/8;
   parameter MAX_PKT_SIZE = 2048;

   reg [CPCI_NF2_DATA_WIDTH-1:0]  reg_wr_data;
   reg                            reg_req;
   reg                            reg_rd_wr_L;
   reg [31:0]                     reg_addr;

   wire [CPCI_NF2_DATA_WIDTH-1:0] reg_rd_data;
   wire                           reg_ack;

   reg                            clk;
   reg                            reset;

   reg [DATA_WIDTH-1:0]           in_data;
   reg [CTRL_WIDTH-1:0]           in_ctrl;
   reg                            in_wr;
   wire                           in_rdy;

   wire [DATA_WIDTH-1:0]          out_data;
   wire [CTRL_WIDTH-1:0]          out_ctrl;
   wire                           out_wr;
   reg                            out_rdy;

   reg [CTRL_WIDTH+DATA_WIDTH-1:0] pkt[MAX_PKT_SIZE/CTRL_WIDTH-1:0];
   reg [CTRL_WIDTH+DATA_WIDTH-1:0] exp_pkt[MAX_PKT_SIZE/CTRL_WIDTH-1:0];

   reg [63:0]                      i, j;

`include "module_sim_tasks.v"

   rate_limiter #(.CPCI_NF2_DATA_WIDTH(CPCI_NF2_DATA_WIDTH)) rate_limiter
     (// Outputs
      .out_data                         (out_data[DATA_WIDTH-1:0]),
      .out_ctrl                         (out_ctrl[CTRL_WIDTH-1:0]),
      .out_wr                           (out_wr),
      .in_rdy                           (in_rdy),
      .rate_lim_reg_rd_data             (reg_rd_data[CPCI_NF2_DATA_WIDTH-1:0]),
      .rate_lim_reg_ack                 (reg_ack),
      // Inputs
      .out_rdy                          (out_rdy),
      .in_data                          (in_data[DATA_WIDTH-1:0]),
      .in_ctrl                          (in_ctrl[CTRL_WIDTH-1:0]),
      .in_wr                            (in_wr),
      .rate_lim_reg_req                 (reg_req),
      .rate_lim_reg_rd_wr_L             (reg_rd_wr_L),
      .rate_lim_reg_addr                (reg_addr[`RATE_LIMIT_REG_ADDR_WIDTH-1:0]),
      .rate_lim_reg_wr_data             (reg_wr_data[CPCI_NF2_DATA_WIDTH-1:0]),
      .clk                              (clk),
      .reset                            (reset));

   always #4 clk = ~clk;
   initial begin
      clk = 0;
      reset = 1;
      reg_wr_data = 0;
      reg_req = 0;
      reg_rd_wr_L = 1;
      reg_addr = 0;
      in_data = 0;
      in_ctrl = 0;
      in_wr = 0;
      out_rdy = 1;

      repeat(4) begin
         @(posedge clk) begin end
      end
      reset = 0;
      repeat(10) begin
         @(posedge clk) begin end
      end

      /* test the module without enabling delays */
      /* 1- test pkts without module hdrs */
      for(i=0; i<9; i=i+1) begin
         pkt[i] = {8'h0, i};
         exp_pkt[i] = {8'h0, i};
      end
      pkt[9] = {8'h1, 64'd9};
      exp_pkt[9] = {8'h1, 64'd9};

      for(i=1; i<=10; i=i+1) begin
         pkt[9] = {i[7:0], 64'd9};
         exp_pkt[9] = {i[7:0], 64'd9};
         fork
            inject_pkt(10);
//            expect_pkt(10, 0, 6);
         join
      end

      /* 2- test pkts with module hdrs */
      for(i=1; i<=4; i=i+1) begin
         pkt[i-1] = {i[7:0], i-64'h1};
         exp_pkt[i-1] = {i[7:0], i-64'h1};
      end
      for(i=4; i<15; i=i+1) begin
         pkt[i] = {8'h0, i};
         exp_pkt[i] = {8'h0, i};
      end
      pkt[15] = {8'h1, 64'd15};
      exp_pkt[15] = {8'h1, 64'd15};

      for(i=0; i<10; i=i+1) begin
         pkt[15] = {i[7:0]+8'h1, 64'd15};
         exp_pkt[15] = {i[7:0]+8'h1, 64'd15};
         fork
            inject_pkt(16);
//            expect_pkt(16, 0, 6);
         join
      end

      /* set the delay in number of cycles */
      writeReg(`RATE_LIMIT_ENABLE, 1);
      writeReg(`RATE_LIMIT_SHIFT, 0);

      /* send packets and check that they come out later as expected */
      /* 1- test pkts without module hdrs */
      for(i=0; i<9; i=i+1) begin
         pkt[i] = {8'h0, i};
         exp_pkt[i] = {8'h0, i};
      end
      pkt[9] = {8'h1, 64'd9};
      exp_pkt[9] = {8'h1, 64'd9};

      for(i=1; i<=10; i=i+1) begin
         pkt[9] = {i[7:0], 64'd9};
         exp_pkt[9] = {i[7:0], 64'd9};
         fork
            inject_pkt(10);
//            expect_pkt(10, 50, 55);
         join
      end

      writeReg(`RATE_LIMIT_SHIFT, 1);

      /* 2- test pkts with module hdrs */
      for(i=1; i<=4; i=i+1) begin
         pkt[i-1] = {i[7:0], i-64'h1};
         exp_pkt[i-1] = {i[7:0], i-64'h1};
      end
      for(i=4; i<15; i=i+1) begin
         pkt[i] = {8'h0, i};
         exp_pkt[i] = {8'h0, i};
      end
      pkt[15] = {8'h1, 64'd15};
      exp_pkt[15] = {8'h1, 64'd15};

      for(i=0; i<10; i=i+1) begin
         pkt[15] = {i[7:0]+8'h1, 64'd15};
         exp_pkt[15] = {i[7:0]+8'h1, 64'd15};
         fork
            inject_pkt(16);
//            expect_pkt(16, 48, 55);
         join
      end

   end // initial begin
endmodule // testbench

