///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: generic_regs_test.v 5695 2009-06-15 16:23:47Z grg $
//
// Module: generic_regs_test.v
// Project: Test generic registers
// Description: Test the generic registers with instances
///////////////////////////////////////////////////////////////////////////////

module generic_regs_test
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter TAG = `REG_TEST_BLOCK_ADDR
   )
   (
      // --- Interface to the previous stage
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      // --- Interface to the next stage
      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,

      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // --- Misc
      input                               reset,
      input                               clk
   );

   `LOG2_FUNC


   //---------------------- Local params -------------------------------

   localparam CNTR_PER_INSTANCE = 3;
   localparam MAX_CNT = `NUM_OUTPUT_QUEUES * CNTR_PER_INSTANCE;
   localparam UPDATE_WIDTH = 5;
   localparam UPDATE_INTERVAL = 8;

   //---------------------- Wires/Regs -------------------------------

   wire                              reg_req_second;
   wire                              reg_ack_second;
   wire                              reg_rd_wr_L_second;
   wire  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_second;
   wire  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_second;
   wire  [UDP_REG_SRC_WIDTH-1:0]     reg_src_second;

   wire [UPDATE_WIDTH-1:0]           update[MAX_CNT-1:0];
   wire [UPDATE_WIDTH*MAX_CNT-1:0]   update_flat;
   reg [UPDATE_WIDTH-1:0]            cnt1;
   reg [UPDATE_WIDTH-1:0]            cnt2;
   reg [UPDATE_WIDTH-1:0]            cnt3;
   wire [`CPCI_NF2_DATA_WIDTH * `NUM_OUTPUT_QUEUES-1:0] hardware_regs;
   reg [6:0]                         wait_cnt;

   //------------------------ Modules ----------------------------------

   generic_regs #(
      .UDP_REG_SRC_WIDTH     (2),                       // identifies which module started this request
      .TAG                   ({TAG, 1'b0}),             // Tag to match against
      .REG_ADDR_WIDTH        (`REG_TEST_REG_ADDR_WIDTH - 1), // Width of block addresses
      .NUM_COUNTERS          (1),                       // How many counters (per instance)
      .NUM_SOFTWARE_REGS     (0),                       // How many sw regs (per instance)
      .NUM_HARDWARE_REGS     (0),                       // How many hw regs (per instance)
      .NUM_INSTANCES         (1)                        // Number of instances
   ) generic_regs_first (
      .reg_req_in                            (reg_req_in),
      .reg_ack_in                            (reg_ack_in),
      .reg_rd_wr_L_in                        (reg_rd_wr_L_in),
      .reg_addr_in                           (reg_addr_in),
      .reg_data_in                           (reg_data_in),
      .reg_src_in                            (reg_src_in),

      .reg_req_out                           (reg_req_second),
      .reg_ack_out                           (reg_ack_second),
      .reg_rd_wr_L_out                       (reg_rd_wr_L_second),
      .reg_addr_out                          (reg_addr_second),
      .reg_data_out                          (reg_data_second),
      .reg_src_out                           (reg_src_second),

      // --- counters interface
      .counter_updates                       (wait_cnt == 0 && cnt1 == 0 && cnt2 == 0 && cnt3 == 0),   // all the counter updates are concatenated
      .counter_decrement                     (1'b0), // if 1 then subtract the update, else add.

      // --- SW regs interface
      .software_regs                         (), // signals from the software

      // --- HW regs interface
      .hardware_regs                         (1'b0), // signals from the hardware

      .clk                                 (clk),
      .reset                               (reset)
    );

   generic_regs #(
      .UDP_REG_SRC_WIDTH     (2),                       // identifies which module started this request
      .TAG                   ({TAG, 1'b1}),             // Tag to match against
      .REG_ADDR_WIDTH        (`REG_TEST_REG_ADDR_WIDTH - 1),// Width of block addresses
      .NUM_COUNTERS          (3),                       // How many counters (per instance)
      .NUM_SOFTWARE_REGS     (0),                       // How many sw regs (per instance)
      .NUM_HARDWARE_REGS     (1),                       // How many hw regs (per instance)
      .NUM_INSTANCES         (`NUM_OUTPUT_QUEUES),             // Number of instances
      .COUNTER_INPUT_WIDTH   (5),                       // Width of each counter update request
      .MIN_UPDATE_INTERVAL   (8)                        // Clocks between successive counter inputs
   ) generic_regs_second (
      .reg_req_in                            (reg_req_second),
      .reg_ack_in                            (reg_ack_second),
      .reg_rd_wr_L_in                        (reg_rd_wr_L_second),
      .reg_addr_in                           (reg_addr_second),
      .reg_data_in                           (reg_data_second),
      .reg_src_in                            (reg_src_second),

      .reg_req_out                           (reg_req_out),
      .reg_ack_out                           (reg_ack_out),
      .reg_rd_wr_L_out                       (reg_rd_wr_L_out),
      .reg_addr_out                          (reg_addr_out),
      .reg_data_out                          (reg_data_out),
      .reg_src_out                           (reg_src_out),

      // --- counters interface
      .counter_updates                       (update_flat),   // all the counter updates are concatenated
      .counter_decrement                     ({MAX_CNT{1'b0}}), // if 1 then subtract the update, else add.

      // --- SW regs interface
      .software_regs                         (), // signals from the software

      // --- HW regs interface
      .hardware_regs                         (hardware_regs), // signals from the hardware

      .clk                                 (clk),
      .reset                               (reset)
    );

   //------------------------ Logic ----------------------------------

   always @(posedge clk)
   begin
      if (reset) begin
         wait_cnt <= - 'h1;
         cnt1 <= 'h0;
         cnt2 <= 'h0;
         cnt3 <= 'h0;
      end
      else begin
         if (wait_cnt == 'h0) begin
            if (cnt1 == UPDATE_INTERVAL - 1)
               cnt1 <= 'h0;
            else
               cnt1 <= cnt1 + 'h1;

            if (cnt1 == UPDATE_INTERVAL - 1) begin
               if (cnt2 == cnt3)
                  cnt2 <= 'h0;
               else
                  cnt2 <= cnt2 + 'h1;
            end

            if (cnt1 == UPDATE_INTERVAL - 1 && cnt2 == cnt3 && cnt3 != MAX_CNT)
               cnt3 <= cnt3 + 'h1;
         end
         else begin
            wait_cnt <= wait_cnt - 'h1;
         end
      end
   end

   generate
      genvar i, j;
      //for (i = 0; i < MAX_CNT; i = i + 1) begin : gen_update
      //   assign update[i] = cnt1 == UPDATE_INTERVAL - 1 && cnt3 == i;
      //   assign update_flat[i*UPDATE_WIDTH +: UPDATE_WIDTH] = update[i];
      //   assign hardware_regs[i*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = {i, 1'b0};
      //end
      for (i = 0; i < `NUM_OUTPUT_QUEUES; i = i + 1) begin : gen_update
         for (j = 0; j < CNTR_PER_INSTANCE; j = j + 1) begin : inner_loop
            assign update[i * CNTR_PER_INSTANCE + j] = cnt1 == UPDATE_INTERVAL - 1 && cnt3 == i * CNTR_PER_INSTANCE + j;
         end
         assign update_flat[i*UPDATE_WIDTH +: UPDATE_WIDTH] = update[i * CNTR_PER_INSTANCE];
         assign update_flat[(i + `NUM_OUTPUT_QUEUES) *UPDATE_WIDTH +: UPDATE_WIDTH] = update[i * CNTR_PER_INSTANCE + 1];
         assign update_flat[(i + 2 * `NUM_OUTPUT_QUEUES) *UPDATE_WIDTH +: UPDATE_WIDTH] = update[i * CNTR_PER_INSTANCE + 2];
         //assign update_flat[i*UPDATE_WIDTH +: UPDATE_WIDTH] = update[i];
         assign hardware_regs[i*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = i;
      end
   endgenerate

   assign out_data = in_data;
   assign out_ctrl = in_ctrl;
   assign out_wr = in_wr;
   assign in_rdy = out_rdy;

endmodule // pipeline_hdr_insert
