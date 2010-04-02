///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: ddr2_test.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: ddr2_test.v
// Project: NetFPGA
// Description: Test the DDR interface
//
// Note:
// - wait_200us is not needed as it's included in the DDR reset signal
// - Signals have been split into the clock domain on which they function
// - Numerical suffixes represent phases!
//
///////////////////////////////////////////////////////////////////////////////

module ddr2_test
            #(
               parameter DRAM_DATA_WIDTH = 64,
               // Total transfer size for the DDR memory (in 64-bit words)
               //
               // 8192 (rows) * 512 (cols) * 4 (banks) / 2 (transfers/word)
               parameter TOTAL_XFER_SIZE = 32'd8388608
            )
            (
               output         done,             // Test is complete
               output         success,          // Test succeeded

               output [3:0]   cmd,              // Command
               input          cmd_ack,          // Command acknowledged

               output [21:0]  addr,             // Rd/Wr address
               output [1:0]   bank_addr,        // Bank address
               output         burst_done,       // Burst complete

               input [63:0]   rd_data,          // Data returned from mem
               input          rd_data_valid,    // Data is valid

               output [63:0]  wr_data,          // Data being written
               output [7:0]   wr_data_mask,     // Write data mask

               output [14:0]  config1,          // Config register 1
               output [12:0]  config2,          // Config register 2
               input          init_val,         // Initialization done

               input          ar_done,          // Auto-refresh done
               input          auto_ref_req,     // Auto-refresh request

               // Control/status registers
               input          ctrl_reg_req,     // Register read request
               input          ctrl_reg_rd_wr_L, // Read (hi) / write (lo)
               input [`DRAM_TEST_REG_ADDR_WIDTH - 1:0] ctrl_reg_addr,    // Register address
               input [`CPCI_NF2_DATA_WIDTH - 1:0] ctrl_reg_wr_data, // Register write data
               output [`CPCI_NF2_DATA_WIDTH - 1:0] ctrl_reg_rd_data, // Register read data
               output         ctrl_reg_ack,     // Register access acknowledgement

               // DRAM direct access registers
               input          dram_reg_req,     // Register read request
               input          dram_reg_rd_wr_L, // Read (hi) / write (lo)
               input [`DRAM_REG_ADDR_WIDTH - 1:0] dram_reg_addr, // Register address
               input [`CPCI_NF2_DATA_WIDTH - 1:0] dram_reg_wr_data, // Register write data
               output [`CPCI_NF2_DATA_WIDTH - 1:0] dram_reg_rd_data, // Register read data
               output         dram_reg_ack,     // Register access acknowledgement

               input          reset,

               input          clk,
               input          clk90,

               input          clk_core_125,
               input          reset_core
            );

// DDR row length
parameter ddr_row_length = 512;

// Number of 64-bit transfers (these goes across as pairs of 32 bit
// transfers)
parameter BLOCK_SIZE = 32'd256;
parameter BLOCK_BITS = 8;
//parameter BLOCK_SIZE = 32'd4;
//parameter BLOCK_BITS = 2;

// Number of tests to run
parameter NUM_TESTS = 5;




// ==============================================
// Configuration registers
// ==============================================

// Input : CONFIG REGISTER FORMAT
// config_register1 = {  Power Down Mode,
// 			 Write Recovery (3),
//                       TM,
//                       Reserved (3),
//                       CAS_latency (3),
//                       Burst type ,
//                       Burst_length (3) }
//
// config_register2 = {  Outputs enabled,
//                       RDQS enable,
//                       DQSn enable,
//                       OCD Operation (3),
//                       Posted CAS Latency (3),
//                       RTT (2),
//                       ODS,
//                       Reserved }
//
// Input : Address format
//   row address = input address(19 downto 8)
//   column addrs = input address( 7 downto 0)
//

assign config1 = {1'b0, 3'b010, 1'b0, 3'b000, 3'b011, 1'b0, 3'b010};
assign config2 = {1'b0, 1'b0, 1'b0, 3'b000, 3'b000, 2'b11, 1'b1, 1'b0};


// Input : COMMAND REGISTER FORMAT
//          0000  - NOP
//          0001  - Precharge
//          0010  - Auto Refresh
//          0011  - Self Refresh
//          0100  - Write Request
//          0101  - Load Mode Register
//          0110  - Read request
//          0111  - Burst terminate
localparam CMD_NOP        = 4'b0000;
localparam CMD_PRECHARGE  = 4'b0001;
localparam CMD_AUTO_REF   = 4'b0010;
localparam CMD_SELF_REF   = 4'b0011;
localparam CMD_WRITE      = 4'b0100;
localparam CMD_LD_MODE    = 4'b0101;
localparam CMD_READ       = 4'b0110;
localparam CMD_BURST_TERM = 4'b0111;


// ==============================================
// State machine parameters
// ==============================================

// Main state machine
localparam WAIT = 4'd0;
localparam WAIT1 = 4'd1;
localparam WAIT2 = 4'd2;
localparam INIT = 4'd3;
localparam HOLD = 4'd4;
localparam WRITE = 4'd5;
localparam WRITE_DONE = 4'd6;
localparam WRITE_REFRESH = 4'd7;

localparam READ = 4'd8;
localparam READ_DONE = 4'd9;
localparam READ_REFRESH = 4'd10;

// Test state machine
localparam T_INIT = 4'd0;
localparam T_START = 4'd1;
localparam T_FIND_TEST = 4'd2;
localparam T_WR_START = 4'd4;
localparam T_WR = 4'd5;
localparam T_RD_START = 4'd7;
localparam T_RD = 4'd8;
localparam T_DONE = 4'd9;
localparam T_RANDOM = 4'd10;


// ==============================================
// Local variables
// ==============================================

// Clocks
wire clk_0 = clk;
wire clk_90 = clk90;
wire clk_180 = ~clk;
wire clk_270 = ~clk90;

// Reset
wire reset_0_p1 = reset;
reg reset_0;
reg reset_90;
reg reset_180;
reg reset_270;

// Inputs/outputs
reg [3:0] cmd_180;
wire cmd_ack_180 = cmd_ack;

reg [21:0] addr_0;
reg [1:0] bank_addr_0;
reg burst_done_0;

wire [63:0] rd_data_90 = rd_data;
wire rd_data_valid_90 = rd_data_valid;


wire init_val_180 = init_val;

wire ar_done_180 = ar_done;
wire auto_ref_req_180 = auto_ref_req;


reg [63:0] rd_data_0_d1;
reg [63:0] rd_data_180_d1;
reg [63:0] rd_data_0_d2;
reg rd_data_valid_180;
reg rd_data_valid_180_d1;
reg rd_data_valid_0_d1;
reg rd_data_valid_0_d2;
reg  ar_done_0_d1;
reg  cmd_ack_0_d1;
reg  cmd_ack_90_d1;
reg  auto_ref_req_0_d1;
reg  ar_done_hold_0;
reg  burst_done_0_d1;
reg  burst_done_90;
reg  burst_done_90_d1;
reg  burst_done_180;


// Data to be written
reg [63:0] test_val_90;
reg [63:0] test_val_180_d1;
reg [63:0] test_val_0_d1;
reg [63:0] test_val_0_d2;

// State machines
reg [3:0] state_180;
reg [3:0] state_0_d1;

reg [3:0] test_state_180;
reg [3:0] test_state_0_d1;

// Which test is currently running?
reg [2:0] test_num_180;
reg [2:0] test_num_90_d1;

// How many words transfered in the current read/write section of the test?
reg [31:0] data_xfer_180;
reg [31:0] data_xfer_0;

// Test start
wire test_start_0;
reg test_start_180;

// Test enable
wire [NUM_TESTS - 1:0] test_en_0;
reg [NUM_TESTS - 1:0] test_en_180;

// Read/write done
reg wr_done_180;
reg rd_done_180;



// Read/write addresses
reg [21:0] wr_addr_0;
reg [1:0] wr_bank_0;

reg [21:0] rd_addr_0;
reg [1:0] rd_bank_0;

reg [23:0] addr_0_d2;
reg [23:0] addr_0_d4;
reg [23:0] addr_0_d6;
reg [23:0] addr_0_d8;
reg [23:0] addr_0_d10;
reg [23:0] addr_0_d12;

// Number of 64-bit words (64-bits = 1 FPGA cycle)
reg [8:0] wr_cnt_0;
reg [8:0] wr_cnt_90;
reg [8:0] rd_cnt_0;

reg rd_cnt_b0_0_d1;
reg rd_cnt_b0_0_d2;
reg rd_cnt_b0_0_d3;
reg rd_cnt_b0_0_d4;
reg rd_cnt_b0_0_d5;
reg rd_cnt_b0_0_d6;
reg rd_cnt_b0_0_d7;
reg rd_cnt_b0_0_d8;
reg rd_cnt_b0_0_d9;
reg rd_cnt_b0_0_d10;
reg rd_cnt_b0_0_d11;
reg rd_cnt_b0_0_d12;
reg rd_cnt_b0_0_d13;

// Hold counters prior to changing read/write addresses at the beginning of
// a transation
reg [2:0] wr_pre_cnt_0;
reg [2:0] rd_pre_cnt_0;

// LFSR variables
reg lfsr_reset_90;
wire [31:0] lfsr_out_90;
reg [31:0] lfsr_out_90_d1;
reg [31:0] lfsr_out_90_d2;
reg [31:0] lfsr_out_90_d3;

wire [31:0] rand_seed_0;
reg [31:0] rand_seed_180;
reg [31:0] rand_seed_90_d1;

// Track the current test
reg [2:0] curr_test_num_180;
reg curr_test_done_180;
reg curr_test_fail_180;
reg curr_test_fail_180_d1;

reg [2:0] curr_test_num_0_d1;
reg curr_test_done_0_d1;
reg curr_test_fail_0_d1;

reg cmd_write_90_d1;


reg burst_hold_90;
reg write_almost_done_90;

// Test done + success/failure
reg fail_0;
reg success_0;
reg done_0;

// DRAM direct access interface
wire [`DRAM_REG_ADDR_WIDTH - 1 : 0] dram_addr_0;
wire [`CPCI_NF2_DATA_WIDTH - 1 : 0] dram_wr_data_0;
wire dram_rd_wr_L_0;
reg curr_dram_req_0;
wire dram_req_0;
reg dramfifo_rd_0;
wire dramfifo_empty_0;
reg curr_dram_req_180;
reg [`CPCI_NF2_DATA_WIDTH - 1 : 0] dram_rd_data_0;
reg dram_vld_0;

reg dram_ready_0;

reg curr_dram_rd_wr_L_180;
wire curr_dram_rd_wr_L_0;
wire [`CPCI_NF2_DATA_WIDTH - 1 : 0] curr_dram_wr_data_0;
reg [`CPCI_NF2_DATA_WIDTH - 1:0] curr_dram_wr_data_270;
reg [`CPCI_NF2_DATA_WIDTH - 1:0] curr_dram_wr_data_90_d1;
wire [`DRAM_REG_ADDR_WIDTH - 1 : 0] curr_dram_addr_0;
reg [`DRAM_REG_ADDR_WIDTH - 1 : 0] curr_dram_addr_180;

wire dramfifo_empty_180;

reg [7:0] wr_data_mask_0;
reg [7:0] wr_data_mask_90;

reg rd_error_0;



// ==============================================
// Write to the outputs
// ==============================================

assign wr_data = test_val_90;
assign wr_data_mask = wr_data_mask_90;

assign addr = addr_0;
assign bank_addr = bank_addr_0;
assign cmd = cmd_180;
assign burst_done = burst_done_0;

assign done = done_0;
assign success = success_0;


// ==============================================
// Clock domain crossing and delays
// ==============================================

always @(posedge clk_0)
begin
   // 0->0
   burst_done_0_d1 <= burst_done_0;
   reset_0 <= reset_0_p1;

   rd_error_0 <= rd_data_0_d1 != test_val_0_d1 &&
               rd_data_valid_0_d1 && test_state_0_d1 != T_RANDOM;

   // 180->0
   cmd_ack_0_d1 <= cmd_ack_180;

   auto_ref_req_0_d1 <= auto_ref_req_180;
   ar_done_0_d1 <= ar_done_180;

   curr_test_num_0_d1 <= curr_test_num_180;
   curr_test_done_0_d1 <= curr_test_done_180;
   curr_test_fail_0_d1 <= curr_test_fail_180;

   state_0_d1 <= state_180;
   test_state_0_d1 <= test_state_180;

   // TODO: this might need to incorporate data about auto refresh
   dram_ready_0 <= test_state_180 == T_RANDOM;

   // 90 -> 0
   rd_data_valid_0_d1 <= rd_data_valid_90;
   rd_data_0_d1 <= rd_data_90;
   test_val_0_d1 <= test_val_90;
   test_val_0_d2 <= test_val_0_d1;

   rd_data_valid_0_d2 <= rd_data_valid_0_d1;
   rd_data_0_d2 <= rd_data_0_d1;


   // 180->0
   //ar_done_hold_0 <= cmd_ack_180 & (ar_done_hold_0 | ar_done_180);


   ar_done_hold_0 <= cmd_ack_0_d1 & (ar_done_hold_0 | ar_done_0_d1);
end

always @(posedge clk_0)
begin
   if (!cmd_ack_0_d1) begin
      bank_addr_0 <= (state_0_d1 == READ || state_0_d1 == READ_DONE || state_0_d1 == READ_REFRESH) ?
            rd_bank_0 : wr_bank_0;
   end
   addr_0 <= (state_0_d1 == READ || state_0_d1 == READ_DONE || state_0_d1 == READ_REFRESH) ?
         rd_addr_0 : wr_addr_0;

   // Delay the address
   if (rd_cnt_b0_0_d1)
      addr_0_d2 <= {bank_addr_0, addr_0};
   if (rd_cnt_b0_0_d3)
      addr_0_d4 <= addr_0_d2;
   if (rd_cnt_b0_0_d5)
      addr_0_d6 <= addr_0_d4;
   if (rd_cnt_b0_0_d7)
      addr_0_d8 <= addr_0_d6;
   if (rd_cnt_b0_0_d9)
      addr_0_d10 <= addr_0_d8;
   if (rd_cnt_b0_0_d11)
      addr_0_d12 <= addr_0_d10;

   // Delay bit 0 of rd_cnt
   rd_cnt_b0_0_d1 <= rd_cnt_0[0];
   rd_cnt_b0_0_d2 <= rd_cnt_b0_0_d1;
   rd_cnt_b0_0_d3 <= rd_cnt_b0_0_d2;
   rd_cnt_b0_0_d4 <= rd_cnt_b0_0_d3;
   rd_cnt_b0_0_d5 <= rd_cnt_b0_0_d4;
   rd_cnt_b0_0_d6 <= rd_cnt_b0_0_d5;
   rd_cnt_b0_0_d7 <= rd_cnt_b0_0_d6;
   rd_cnt_b0_0_d8 <= rd_cnt_b0_0_d7;
   rd_cnt_b0_0_d9 <= rd_cnt_b0_0_d8;
   rd_cnt_b0_0_d10 <= rd_cnt_b0_0_d9;
   rd_cnt_b0_0_d11 <= rd_cnt_b0_0_d10;
   rd_cnt_b0_0_d12 <= rd_cnt_b0_0_d11;
   rd_cnt_b0_0_d13 <= rd_cnt_b0_0_d12;
end


always @(posedge clk_90)
begin
   // 90->90
   burst_hold_90 <= (burst_hold_90 && cmd_ack_90_d1) || burst_done_90;
   write_almost_done_90 <= (wr_cnt_90 + 'd4 >= BLOCK_SIZE);

   lfsr_out_90_d1 <= lfsr_out_90;
   lfsr_out_90_d2 <= lfsr_out_90_d1;
   lfsr_out_90_d3 <= lfsr_out_90_d2;

   // 0 -> 90
   reset_90 <= reset_0;
   burst_done_90 <= burst_done_0;
   burst_done_90_d1 <= burst_done_90;
   wr_cnt_90 <= wr_cnt_0;

   wr_data_mask_90 <= wr_data_mask_0;

   // 180 -> 90
   test_num_90_d1 <= test_num_180;
   cmd_ack_90_d1 <= cmd_ack_180;
   cmd_write_90_d1 <= cmd_180 == CMD_WRITE && cmd_ack_180;
   lfsr_reset_90 <= test_state_180 == T_RD_START || test_state_180 == T_WR_START;
   curr_dram_wr_data_90_d1 <= curr_dram_wr_data_270;
   rand_seed_90_d1 <= rand_seed_180;
end

always @(posedge clk_180)
begin
   // 90 -> 180
   reset_180 <= reset_90;
   rd_data_valid_180 <= rd_data_valid_90;
   rd_data_valid_180_d1 <= rd_data_valid_180;

   // 0 -> 180
   burst_done_180 <= burst_done_0;
   test_en_180 <= test_en_0;
   test_start_180 <= test_start_0;

   wr_done_180 <= wr_cnt_0 == BLOCK_SIZE || test_state_0_d1 == T_RANDOM;
   rd_done_180 <= rd_cnt_0 == BLOCK_SIZE || test_state_0_d1 == T_RANDOM;

   data_xfer_180 <= data_xfer_0;

   test_val_180_d1 <= test_val_0_d1;
   rd_data_180_d1 <= rd_data_0_d1;

   curr_dram_rd_wr_L_180 <= curr_dram_rd_wr_L_0;
   curr_dram_addr_180 <= curr_dram_addr_0;

   curr_dram_req_180 <= curr_dram_req_0;

   rand_seed_180 <= rand_seed_0;

end

always @(posedge clk_270)
begin
   // 180 -> 270
   reset_270 <= reset_180;
   curr_dram_wr_data_270 <= curr_dram_wr_data_0;
end



// ====================================
// Test status (ie. done + pass/fail)
// ====================================

// Global status for all tests
always @(posedge clk_0)
begin
   if (reset_0 || test_state_0_d1 == T_START) begin
      fail_0 <= 1'b0;
      done_0 <= 1'b0;
      success_0 <= 1'b0;
   end
   else if (!done_0) begin
      if (test_state_0_d1 == T_DONE) begin
         done_0 <= 1'b1;
         success_0 <= !fail_0;
      end
      else if (rd_error_0)
         fail_0 <= 1'b1;
   end
end

// Local status for current test
always @(posedge clk_180)
begin
   if (reset_180 || test_state_180 == T_RANDOM) begin
      curr_test_num_180 <= 'h0;
      curr_test_done_180 <= 1'b0;
      curr_test_fail_180 <= 1'b0;
      curr_test_fail_180_d1 <= 1'b0;
   end
   else begin
      // Check if the test has finished
      if (test_state_180 == T_RD && state_180 == HOLD &&
            !rd_data_valid_180 && !rd_data_valid_180_d1) begin
         curr_test_num_180 <= test_num_180;
         curr_test_done_180 <= 1'b1;
         curr_test_fail_180_d1 <= 1'b0;
      end
      else begin
         // Test hasn't yet finished
         curr_test_done_180 <= 1'b0;

         // Check if we detect an error
         if (rd_data_valid_180_d1 && rd_data_180_d1 != test_val_180_d1) begin
            curr_test_fail_180 <= 1'b1;
            curr_test_fail_180_d1 <= 1'b1;
         end
         else begin
            curr_test_fail_180 <= curr_test_fail_180_d1;
         end
      end
   end
end


// ====================================
// Test state machine
// ====================================

always @(posedge clk_180)
begin
   if (reset_180) begin
      test_state_180 <= T_INIT;
      test_num_180 <= 'h0;
   end
   else
      case (test_state_180)
         T_INIT : begin
            if (init_val_180) begin
               test_state_180 <= T_DONE;
            end
         end

         T_START : begin
            test_state_180 <= T_FIND_TEST;
         end

         T_FIND_TEST : begin
            if (test_en_180[test_num_180])
               test_state_180 <= T_WR_START;
            else begin
               if (test_num_180 == NUM_TESTS - 1)
                  test_state_180 <= T_DONE;
               else
                  test_num_180 <= test_num_180 + 'h1;
            end
         end

         T_WR_START : begin
            if (state_180 != HOLD) begin
               test_state_180 <= T_WR;
            end
         end

         T_WR : begin
            if (state_180 == WRITE_DONE && data_xfer_180 == TOTAL_XFER_SIZE) begin
               test_state_180 <= T_RD_START;
            end
         end

         T_RD_START : begin
            if (!cmd_ack_180) begin
               test_state_180 <= T_RD;
            end
         end

         T_RD : begin
            if (state_180 == HOLD && !rd_data_valid_180 && !rd_data_valid_180_d1) begin
               test_num_180 <= test_num_180 + 'h1;
               if (test_num_180 != NUM_TESTS - 1) begin
                  test_state_180 <= T_WR_START;
               end
               else
                  test_state_180 <= T_DONE;
            end
         end

         T_DONE : begin
            if (test_start_180) begin
               test_state_180 <= T_START;
               test_num_180 <= 'h0;
            end
            else
               test_state_180 <= T_RANDOM;
         end

         T_RANDOM : begin
            if (test_start_180) begin
               test_state_180 <= T_START;
               test_num_180 <= 'h0;
            end
            else
               test_state_180 <= T_RANDOM;
         end
      endcase
end

// ==============================================
// Main state machine
//  - responsible for asserting the correct command
//  - NEG edge clock!
// ==============================================
always @(posedge clk_180)
begin
   if (reset_180) begin
      state_180 <= WAIT;
      cmd_180 <= 4'b0000;
   end
   else
      case (state_180)
         // Wait a few cycles before coming out of the wait
         // state
         WAIT: begin
            state_180 <= WAIT1;
         end
         WAIT1: begin
            state_180 <= WAIT2;
         end
         WAIT2: begin
            state_180 <= INIT;
         end

         INIT: begin
            // Instruct the controller to initialize the
            // memory
            state_180 <= HOLD;
            cmd_180 <= CMD_AUTO_REF;
         end

         HOLD: begin
            // Wait until we need to read or write
            //if (test_state == T_RDWR_START || test_state == T_WR_START)
            if (test_state_180 == T_WR_START)
               state_180 <= WRITE;
            else if (test_state_180 == T_RD_START)
               state_180 <= READ;
            else if (test_state_180 == T_RANDOM) begin
               if (curr_dram_req_180 && curr_dram_rd_wr_L_180)
                  state_180 <= READ;
               else if (curr_dram_req_180)
                  state_180 <= WRITE;
            end
            else
               state_180 <= HOLD;

            cmd_180 <= CMD_NOP;
         end

         WRITE: begin
            if (burst_done_180)
            begin
               if (auto_ref_req_180 && !wr_done_180)
                  state_180 <= WRITE_REFRESH;
               else
                  state_180 <= WRITE_DONE;
            end
            else
               state_180 <= WRITE;

            cmd_180 <= CMD_WRITE;
         end

         WRITE_DONE: begin
            // Wait until the command has completed
            // and only move on if we've written the
            // required number of words
            if (!cmd_ack_180) begin
               if (test_state_180 == T_RANDOM)
                  state_180 <= HOLD;
               else if (data_xfer_180 == TOTAL_XFER_SIZE)
                  state_180 <= READ;
               else
                  state_180 <= WRITE;
            end
            else
               state_180 <= WRITE_DONE;

            if (!burst_done_180)
               cmd_180 <= CMD_NOP;
         end

         WRITE_REFRESH: begin
            // Wait here while the Auto-Refresh is
            // occuring
            if (ar_done_180)
               state_180 <= WRITE;
            else
               state_180 <= WRITE_REFRESH;

            if (!burst_done_180)
               cmd_180 <= CMD_NOP;
         end

         READ: begin
            if (burst_done_180) begin
               if (auto_ref_req_180 && !rd_done_180)
                  state_180 <= READ_REFRESH;
               else
                  state_180 <= READ_DONE;
            end
            else
               state_180 <= READ;

            cmd_180 <= CMD_READ;
         end

         READ_DONE: begin
            // Wait until the command has completed
            // and only move on if we've read the
            // required number of words
            if (!cmd_ack_180) begin
               if (test_state_180 == T_RANDOM)
                  state_180 <= HOLD;
               else if (data_xfer_180 == TOTAL_XFER_SIZE)
                  state_180 <= HOLD;
               else
                  state_180 <= READ;
            end
            else
               state_180 <= READ_DONE;

            if (!burst_done_180)
               cmd_180 <= CMD_NOP;
         end

         READ_REFRESH: begin
            // Wait here while the Auto-Refresh is
            // occuring
            if (ar_done_180)
               state_180 <= READ;
            else
               state_180 <= READ_REFRESH;

            if (!burst_done_180)
               cmd_180 <= CMD_NOP;
         end

         default: begin
            // We should never get here
            state_180 <= HOLD;

// synthesis translate_off
            if ($time > 0)
               $display($time, " ERROR: %m: Enterered unknown state %x", state_180);
// synthesis translate_on
         end
      endcase
end


// =================================================
// Control read/write address
// =================================================

always @(posedge clk_0)
begin
   if (reset_0) begin
      burst_done_0 <= 'h0;

      rd_addr_0 <= 'h0;
      rd_bank_0 <= 'h0;

      wr_addr_0 <= 'h0;
      wr_bank_0 <= 'h0;

      data_xfer_0 <= 'h0;
      wr_data_mask_0 <= 'h0;
   end
   else begin
      case (state_0_d1)
         WRITE: begin
            // Data is only provided AFTER the command is
            // ACKed. Wait a cycle after the command is
            // ACKed before we adjust counters etc.
            if (cmd_ack_0_d1 && !ar_done_hold_0) begin
               if (!burst_done_0 && (wr_pre_cnt_0 == 3'b011 || wr_pre_cnt_0 == 3'b100))
               //if (!burst_done_0 && (wr_pre_cnt_0 == 3'b001 || wr_pre_cnt_0 == 3'b010))
                  wr_cnt_0 <= wr_cnt_0 + 'h1;

               // Terminate a burst when we've written the last word or when an
               // Auto-Refresh is initiated.
               if (wr_cnt_0 == BLOCK_SIZE - 'h1 ||
                        auto_ref_req_0_d1 && wr_cnt_0[0] == 1'b1 ||
                        test_state_0_d1 == T_RANDOM && wr_cnt_0[0] == 1'b1)
                  burst_done_0 <= 1'b1;

               // TODO:
               // Note: This should theoretically be 'b11 (4 cycles delay)
               // but seems to require 5 cycles delay
               if (wr_pre_cnt_0 != 3'b100)
               //if (wr_pre_cnt_0 != 3'b010)
                  wr_pre_cnt_0 <= wr_pre_cnt_0 + 'h1;
               else begin
                  if (wr_cnt_0[0]) begin
                     wr_addr_0 <= wr_addr_0 + 'h4;
                     //if (wr_addr_0 + 'h4 == 'h0)
                     if (wr_addr_0 == {{20{1'b1}}, 2'b0})
                        wr_bank_0 <= wr_bank_0 + 'h1;
                     data_xfer_0 <= data_xfer_0 + 'd2;
                  end
               end
            end
            else begin
               // Pick up the write where we left off
               wr_cnt_0 <= {{(9 - BLOCK_BITS){1'b0}}, wr_addr_0[BLOCK_BITS:1]};
               wr_pre_cnt_0 <= 'h0;
            end

            // Set the write data mask
            if (test_state_0_d1 != T_RANDOM)
               // No mask if we're not in random access mode
               wr_data_mask_0 <= 'h0;
            else if (cmd_ack_0_d1 && !ar_done_hold_0 &&
                     !burst_done_0 && (wr_pre_cnt_0 == 3'b000))
               // Have to set the mask *really* early due to the propagation
               // through the design
               wr_data_mask_0 <= {
                     ~{4{curr_dram_addr_0[1] & ~curr_dram_addr_0[0]}},
                     ~{4{curr_dram_addr_0[1] & curr_dram_addr_0[0]}}};
            else
               wr_data_mask_0 <= {
                     ~{4{~curr_dram_addr_0[1] & ~curr_dram_addr_0[0]}},
                     ~{4{~curr_dram_addr_0[1] & curr_dram_addr_0[0]}}};

         end

         WRITE_DONE, WRITE_REFRESH, READ_DONE, READ_REFRESH: begin
            // Hold burst_done for two clocks
            if (burst_done_0_d1) begin
               burst_done_0 <= 1'b0;
            end

            // Reset the read/write addresses
            if (state_0_d1 == WRITE_DONE) begin
               rd_addr_0 <= 'h0;
               rd_bank_0 <= 'h0;
            end
            else if (state_0_d1 == READ_DONE) begin
               wr_addr_0 <= 'h0;
               wr_bank_0 <= 'h0;
            end

            // Reset the data xfer ctr
            if ((state_0_d1 == WRITE_DONE || state_0_d1 == READ_DONE) &&
                !cmd_ack_0_d1 && data_xfer_0 == TOTAL_XFER_SIZE)
                data_xfer_0 <= 'h0;
         end

         HOLD: begin
            // Reset the read/write addresses
            if (test_state_0_d1 == T_RANDOM) begin
               // The top two bits go to the bank, all the other bits except
               // bits 2 and 3 (which select which block to read and which
               // half of the 64-bit word to return)
               if (curr_dram_rd_wr_L_0) begin
                  rd_addr_0 <= {curr_dram_addr_0[`DRAM_REG_ADDR_WIDTH - 3 : 2], 2'b0};
                  rd_bank_0 <= curr_dram_addr_0[`DRAM_REG_ADDR_WIDTH - 1 : `DRAM_REG_ADDR_WIDTH - 2];
               end
               else begin
                  wr_addr_0 <= {curr_dram_addr_0[`DRAM_REG_ADDR_WIDTH - 3 : 2], 2'b0};
                  wr_bank_0 <= curr_dram_addr_0[`DRAM_REG_ADDR_WIDTH - 1 : `DRAM_REG_ADDR_WIDTH - 2];
               end

               // Reset the data_xfer counter
               data_xfer_0 <= 'h0;
            end
         end

         READ: begin
            // Data is only provided AFTER the command is
            // ACKed. Wait a cycle after the command is
            // ACKed before we adjust counters etc.
            if (cmd_ack_0_d1 && !ar_done_hold_0) begin
               if (!burst_done_0 && (rd_pre_cnt_0 == 3'b011 || rd_pre_cnt_0 == 3'b100))
               //if (!burst_done_0 && (rd_pre_cnt_0 == 3'b001 || rd_pre_cnt_0 == 3'b010))
                  rd_cnt_0 <= rd_cnt_0 + 'h1;

               // Terminate a burst when we've written the last word or when an
               // Auto-Refresh is initiated.
               if (rd_cnt_0 == BLOCK_SIZE - 'h1 ||
                        auto_ref_req_0_d1 && rd_cnt_0[0]  == 1'b1 ||
                        test_state_0_d1 == T_RANDOM && rd_cnt_0[0] == 1'b1)
                  burst_done_0 <= 1'b1;

               if (rd_pre_cnt_0 != 3'b100)
               //if (rd_pre_cnt_0 != 3'b010)
                  rd_pre_cnt_0 <= rd_pre_cnt_0 + 'h1;
               else begin
                  if (rd_cnt_0[0]) begin
                     rd_addr_0 <= rd_addr_0 + 'h4;
                     //if (rd_addr_0 + 'h4 == 'h0)
                     if (rd_addr_0 == {{20{1'b1}}, 2'b0})
                        rd_bank_0 <= rd_bank_0 + 'h1;
                     data_xfer_0 <= data_xfer_0 + 'd2;
                  end
               end
            end
            else begin
               // Pick up the read where we left off
               rd_cnt_0 <= {{(9 - BLOCK_BITS){1'b0}}, rd_addr_0[BLOCK_BITS:1]};
               rd_pre_cnt_0 <= 'h0;
            end
         end
      endcase
   end
end



// ==============================================
// LFSR to generate random test patterns
// ==============================================

lfsr32 lfsr(
            .val(lfsr_out_90),
            .rd((cmd_ack_90_d1 && !burst_done_90 && !burst_hold_90 && cmd_write_90_d1) || rd_data_valid_90),
            .seed(lfsr_reset_90 ? rand_seed_90_d1 : lfsr_out_90_d3),
            .reset(lfsr_reset_90 || (cmd_write_90_d1 && burst_done_90 && !burst_done_90_d1)),
            .clk(clk90)
         );


// ====================================
// Mux to select the test output
// ====================================

always @*
begin
   case (test_num_90_d1)
      3'd0: test_val_90 = 64'd0;
      3'd1: test_val_90 = 64'hffffffff_ffffffff;
      3'd2: test_val_90 = 64'h55555555_55555555;
      3'd3: test_val_90 = 64'haaaaaaaa_aaaaaaaa;
      3'd4: test_val_90 = {lfsr_out_90[31:16], lfsr_out_90[31:16], lfsr_out_90[15:0], lfsr_out_90[15:0]};
      3'd5: test_val_90 = {curr_dram_wr_data_90_d1, curr_dram_wr_data_90_d1};
      default: test_val_90 = 64'd0;
   endcase
end


// ==============================================
// DRAM direct access FIFO
// ==============================================

dramfifo_16x57 dramfifo_16x57
   (
      .din ({dram_rd_wr_L_0, dram_wr_data_0, dram_addr_0}),
      .wr_en (dram_req_0),
      .full (),

      .rd_en (dramfifo_rd_0),
      .dout ({curr_dram_rd_wr_L_0, curr_dram_wr_data_0, curr_dram_addr_0}),
      .empty (dramfifo_empty_0),

      .clk (clk_0),
      .rst (reset_0)
   );


always @(posedge clk_0)
begin
   if (reset_0) begin
      dramfifo_rd_0 <= 1'b0;
      curr_dram_req_0 <= 1'b0;
   end
   else begin
      if (!dramfifo_empty_0 && !curr_dram_req_0 && test_state_0_d1 == T_RANDOM)
         dramfifo_rd_0 <= 1'b1;
      else
         dramfifo_rd_0 <= 1'b0;

      if (dramfifo_rd_0)
         curr_dram_req_0 <= 1'b1;
      else if (rd_data_valid_0_d2 || state_0_d1 == WRITE)
         curr_dram_req_0 <= 1'b0;
   end
end

always @(posedge clk_0)
begin
   if (reset_0 || test_state_0_d1 != T_RANDOM || !rd_data_valid_0_d2 || dram_vld_0) begin
      dram_vld_0 <= 1'b0;
      dram_rd_data_0 <= 'h0;
   end
   else if (test_state_0_d1 == T_RANDOM && rd_data_valid_0_d2) begin
      dram_vld_0 <= 1'b1;
      case (curr_dram_addr_0[1:0])
         2'b00: dram_rd_data_0 <= rd_data_0_d2[`CPCI_NF2_DATA_WIDTH * 2 - 1 : `CPCI_NF2_DATA_WIDTH];
         2'b01: dram_rd_data_0 <= rd_data_0_d2[`CPCI_NF2_DATA_WIDTH - 1 : 0];
         2'b10: dram_rd_data_0 <= rd_data_0_d1[`CPCI_NF2_DATA_WIDTH * 2 - 1 : `CPCI_NF2_DATA_WIDTH];
         2'b11: dram_rd_data_0 <= rd_data_0_d1[`CPCI_NF2_DATA_WIDTH - 1 : 0];
      endcase
   end
end

// =========================
// Instantiate the registers
// =========================

ddr2_test_reg ddr2_test_reg
    (
      .reg_req (ctrl_reg_req),
      .reg_rd_wr_L (ctrl_reg_rd_wr_L),
      .reg_addr (ctrl_reg_addr),
      .reg_wr_data (ctrl_reg_wr_data),
      .reg_rd_data (ctrl_reg_rd_data),
      .reg_ack (ctrl_reg_ack),
      .log_wr (log_rdy_0 && rd_error_0),
      .log_rdy (log_rdy_0),
      .log_addr ({addr_0_d12[23:2], rd_cnt_b0_0_d12, 1'b0}),
      .log_exp_data (test_val_0_d2),
      .log_rd_data (rd_data_0_d2),
      .rand_seed (rand_seed_0),
      .test_start (test_start_0),
      .test_en (test_en_0),
      .curr_test_done (curr_test_done_0_d1),
      .curr_test_pass (!curr_test_fail_0_d1),
      .curr_test_idx (curr_test_num_0_d1),
      .done (done_0),
      .success (success_0),
      .idle (dram_ready_0),
      .clk_core_125 (clk_core_125),
      .clk_ddr_200 (clk_0),
      .reset_ddr (reset_0),
      .reset_core (reset_core)
   );

ddr2_dram_access_reg ddr2_dram_access_reg
    (
      .reg_req (dram_reg_req),
      .reg_rd_wr_L (dram_reg_rd_wr_L),
      .reg_addr (dram_reg_addr),
      .reg_wr_data (dram_reg_wr_data),
      .reg_rd_data (dram_reg_rd_data),
      .reg_ack (dram_reg_ack),
      .dram_addr (dram_addr_0),
      .dram_wr_data (dram_wr_data_0),
      .dram_rd_wr_L (dram_rd_wr_L_0),
      .dram_req (dram_req_0),
      .dram_rd_data (dram_rd_data_0),
      .dram_vld (dram_vld_0),
      .dram_ready (dram_ready_0),
      .clk_core_125 (clk_core_125),
      .clk_ddr_200 (clk_0),
      .reset_ddr (reset_0),
      .reset_core (reset_core)
   );



endmodule // ddr2_test

