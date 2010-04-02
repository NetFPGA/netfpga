//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: serial_tst_regs.v 5963 2010-03-06 04:24:06Z grg $
//
// Module: serial_tst_regs.v
// Project: NetFPGA
// Description: handles requests for regs
//
//
///////////////////////////////////////////////////////////////////////////////

module serial_tst_regs
   #(
      parameter COUNT_WIDTH = 31
   )

   ( // --- Interface to register demux in core clk domain
     input       serial_tst_reg_req,
     input       serial_tst_reg_rd_wr_L,
     output reg  serial_tst_reg_ack,
     input  [`SERIAL_TEST_REG_ADDR_WIDTH-1:0] serial_tst_reg_addr,
     input  [`CPCI_NF2_DATA_WIDTH-1:0] serial_tst_reg_wr_data,
     output reg [`CPCI_NF2_DATA_WIDTH-1:0] serial_tst_reg_rd_data,

     input       test_running,
     input       test_done,
     input       test_successful,

     input [15:0] serial_error_count_0,
     input       channel_up_0,
     input       lane_up_0,
     input       hard_error_0,
     input       soft_error_0,
     input       frame_error_0,
     input       serial_frame_sent_0,
     input       serial_frame_rcvd_0,

     input [15:0] serial_error_count_1,
     input       channel_up_1,
     input       lane_up_1,
     input       hard_error_1,
     input       soft_error_1,
     input       frame_error_1,
     input       serial_frame_sent_1,
     input       serial_frame_rcvd_1,

     output      usr_reset_0,
     output      usr_reset_1,
     output      restart_test,
     output      nonstop_test,
     input [COUNT_WIDTH-1:0] count,
     output [1:0] loopback_0,
     output [1:0] loopback_1,

     // --- misc
     input       clk,
     input       reset);

   // ----------------- Internal parameters ---------------------
   parameter     NUM_REGS_USED = 14;
   parameter     REG_ADDR_WIDTH = 4;

   // ------------------- Wires/Regs ---------------------------

   wire [`CPCI_NF2_DATA_WIDTH-1:0]              reg_file[0:NUM_REGS_USED-1];
   reg [`CPCI_NF2_DATA_WIDTH-1:0]               reg_file_next[0:NUM_REGS_USED-1];

   reg [`CPCI_NF2_DATA_WIDTH*NUM_REGS_USED-1:0] reg_file_linear;
   wire [`CPCI_NF2_DATA_WIDTH*NUM_REGS_USED-1:0] reg_file_linear_next;

   wire [`CPCI_NF2_DATA_WIDTH-1:0]              ctrl_reg_0;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]              ctrl_reg_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]              test_ctrl;

   wire [REG_ADDR_WIDTH-1:0]                    addr;

   wire                                         addr_good;

   reg [63:0]                                   num_frames_sent_0;
   reg [63:0]                                   num_frames_rcvd_0;
   reg [63:0]                                   num_frames_sent_1;
   reg [63:0]                                   num_frames_rcvd_1;

   reg                                          reg_acked;

   // -------------------- Logic ------------------------------
`define REG_END(addr_num) `CPCI_NF2_DATA_WIDTH*((addr_num)+1)-1
`define REG_START(addr_num) `CPCI_NF2_DATA_WIDTH*(addr_num)



   assign ctrl_reg_0 = reg_file[`SERIAL_TEST_CTRL_0];
   assign ctrl_reg_1 = reg_file[`SERIAL_TEST_CTRL_1];
   assign test_ctrl  = reg_file[`SERIAL_TEST_CTRL];

   assign usr_reset_0 = ctrl_reg_0[`SERIAL_TEST_IFACE_CTRL_RESET_POS];
   assign usr_reset_1 = ctrl_reg_1[`SERIAL_TEST_IFACE_CTRL_RESET_POS];

   assign loopback_0  = ctrl_reg_0[`SERIAL_TEST_IFACE_CTRL_LOOPBACK_POS_HI:`SERIAL_TEST_IFACE_CTRL_LOOPBACK_POS_LO];
   assign loopback_1  = ctrl_reg_1[`SERIAL_TEST_IFACE_CTRL_LOOPBACK_POS_HI:`SERIAL_TEST_IFACE_CTRL_LOOPBACK_POS_LO];

   assign restart_test = test_ctrl[`SERIAL_TEST_GLBL_CTRL_RESTART_POS];
   assign nonstop_test = test_ctrl[`SERIAL_TEST_GLBL_CTRL_NONSTOP_POS];

   assign addr = serial_tst_reg_addr[REG_ADDR_WIDTH-1:0];

   assign addr_good = (serial_tst_reg_addr<(NUM_REGS_USED*4));

   generate
   genvar j;
   for(j=0; j<NUM_REGS_USED; j=j+1) begin:linear_reg
      assign reg_file_linear_next[`REG_END(j):`REG_START(j)] = reg_file_next[j];
      assign reg_file[j] = reg_file_linear[`REG_END(j):`REG_START(j)];
   end
   endgenerate

   always @(*) begin
      // writable regs go here
      reg_file_next[`SERIAL_TEST_CTRL_0] = reg_file_linear[`REG_END(`SERIAL_TEST_CTRL_0):`REG_START(`SERIAL_TEST_CTRL_0)];
      reg_file_next[`SERIAL_TEST_CTRL_1] = reg_file_linear[`REG_END(`SERIAL_TEST_CTRL_1):`REG_START(`SERIAL_TEST_CTRL_1)];
      reg_file_next[`SERIAL_TEST_CTRL]   = reg_file_linear[`REG_END(`SERIAL_TEST_CTRL):`REG_START(`SERIAL_TEST_CTRL)];
      // perform the write
      if(serial_tst_reg_req && !serial_tst_reg_rd_wr_L && !reg_acked && addr_good) begin
         reg_file_next[addr] = serial_tst_reg_wr_data;
      end
      // write protected regs go here
      reg_file_next[`SERIAL_TEST_STATUS_0]  = {8'h0, serial_error_count_0, 3'h0, frame_error_0, soft_error_0, hard_error_0, channel_up_0, lane_up_0};
      reg_file_next[`SERIAL_TEST_STATUS_1]  = {8'h0, serial_error_count_1, 3'h0, frame_error_1, soft_error_1, hard_error_1, channel_up_1, lane_up_1};
      reg_file_next[`SERIAL_TEST_STATUS]    = {{(32-COUNT_WIDTH){1'b0}},count[COUNT_WIDTH-1:3], test_running, test_done, test_successful};

      reg_file_next[`SERIAL_TEST_NUM_FRAMES_SENT_0_HI] = num_frames_sent_0[63:32];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_SENT_0_LO] = num_frames_sent_0[31:0];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_SENT_1_HI] = num_frames_sent_1[63:32];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_SENT_1_LO] = num_frames_sent_1[31:0];

      reg_file_next[`SERIAL_TEST_NUM_FRAMES_RCVD_0_HI] = num_frames_rcvd_0[63:32];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_RCVD_0_LO] = num_frames_rcvd_0[31:0];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_RCVD_1_HI] = num_frames_rcvd_1[63:32];
      reg_file_next[`SERIAL_TEST_NUM_FRAMES_RCVD_1_LO] = num_frames_rcvd_1[31:0];
   end

   always @(posedge clk) begin
      if(reset) begin
         serial_tst_reg_ack <= 0;
         serial_tst_reg_rd_data <= 0;

         reg_file_linear <= {(NUM_REGS_USED*`CPCI_NF2_DATA_WIDTH){1'b0}};

         num_frames_rcvd_0 <= 0;
         num_frames_rcvd_1 <= 0;
         num_frames_sent_0 <= 0;
         num_frames_sent_1 <= 0;

         reg_acked <= 0;
      end
      else begin
         if(serial_tst_reg_req) begin
            if (!reg_acked) begin
               serial_tst_reg_ack <= 1;
               reg_acked <= 1'b1;
            end
            else begin
               serial_tst_reg_ack <= 0;
            end
         end
         else begin
            serial_tst_reg_ack <= 0;
            reg_acked <= 1'b0;
         end

         if(serial_tst_reg_rd_wr_L && serial_tst_reg_req) begin
            if(addr_good) begin
               serial_tst_reg_rd_data <= reg_file[addr];
            end
            else begin
               serial_tst_reg_rd_data <= 32'hdead_beef;
            end
         end

         reg_file_linear <= reg_file_linear_next;

         if(restart_test) begin
            num_frames_rcvd_0 <= 0;
            num_frames_rcvd_1 <= 0;
            num_frames_sent_0 <= 0;
            num_frames_sent_1 <= 0;
         end
         else begin
            if(serial_frame_rcvd_0 && !(&num_frames_rcvd_0))
               num_frames_rcvd_0 <= num_frames_rcvd_0 + 1'b1;
            if(serial_frame_rcvd_1 && !(&num_frames_rcvd_1))
               num_frames_rcvd_1 <= num_frames_rcvd_1 + 1'b1;
            if(serial_frame_sent_0 && !(&num_frames_sent_0))
               num_frames_sent_0 <= num_frames_sent_0 + 1'b1;
            if(serial_frame_sent_1 && !(&num_frames_sent_1))
               num_frames_sent_1 <= num_frames_sent_1 + 1'b1;
         end

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule











