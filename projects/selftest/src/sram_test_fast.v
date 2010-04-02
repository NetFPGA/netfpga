//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: sram_test_fast.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: sram_test_fast.v
// Project: NetFPGA
// Description: the top module for external SRAM test
//
// This is the top level module for external SRAM test.
// It performs a number of fixed pattern tests and a number of
// pseudo-random pattern testss to the external SRAM chip(s).
//
// While the test is running, the running signal is asserted.
//
// Upon test completion, the running signal is deasserted,
// the done signal is asserted, and the fail signal is asserted
// if at least one error is detected.
//
// The test status and error logs are stored in the registers
// instantiated by this module. CPU can read them out for further
// analysis.
//
///////////////////////////////////////////////////////////////////////////////


module sram_test_fast
   #(parameter
      SRAM_ADDR_WIDTH = 19,
      SRAM_DATA_WIDTH = 36
    )

    (
     //intfc to test console
     output running,
     output reg done,
     output reg fail,

     //intfc to cpu
     input                             reg_req,
     input                             reg_rd_wr_L,
     input [`SRAM_TEST_REG_ADDR_WIDTH-1:0] reg_addr,
     input [`CPCI_NF2_DATA_WIDTH -1:0] reg_wr_data,

     output                            reg_ack,
     output [`CPCI_NF2_DATA_WIDTH -1:0] reg_rd_data,

     //intfc to sram 1
     output reg [SRAM_ADDR_WIDTH-1:0]  sram_addr_1,
     output reg [SRAM_DATA_WIDTH-1:0]  sram_wr_data_1,
     input      [SRAM_DATA_WIDTH-1:0]  sram_rd_data_1,
     output reg                        sram_tri_en_1,
     output reg                        sram_we_bw_1,

     //intfc to sram 2
     output reg [SRAM_ADDR_WIDTH-1:0]  sram_addr_2,
     output reg [SRAM_DATA_WIDTH-1:0]  sram_wr_data_2,
     input      [SRAM_DATA_WIDTH-1:0]  sram_rd_data_2,
     output reg                        sram_tri_en_2,
     output reg                        sram_we_bw_2,

     //intfc to misc
     input clk,
     input reset
     );

   parameter
             PATTERN_0 = 36'h 0,
             PATTERN_1 = 36'h F_FF_FF_FF_FF,
             PATTERN_2 = 36'h 5_55_55_55_55,
             PATTERN_3 = 36'h A_AA_AA_AA_AA;

   parameter TOTAL_TEST_NUM = 5;

   //---------------------------------------
   //reg, wire from fixed_pat
   wire f_p_ram_tri_en, f_p_ram_we_bw;
   wire [SRAM_ADDR_WIDTH -1:0] f_p_ram_addr;
   wire [SRAM_DATA_WIDTH -1:0] f_p_ram_wr_data;

   wire fixed_pat_test_done, fixed_pat_test_fail;

   wire f_p_log_vld;
   wire [SRAM_ADDR_WIDTH -1:0] f_p_log_addr;
   wire [SRAM_DATA_WIDTH -1:0] f_p_log_exp_data, f_p_log_rd_data;

   //---------------------------------------
   //reg, wire from rand_pat
   wire r_p_ram_tri_en, r_p_ram_we_bw;
   wire [SRAM_ADDR_WIDTH -1:0] r_p_ram_addr;
   wire [SRAM_DATA_WIDTH -1:0] r_p_ram_wr_data;

   wire rand_pat_test_done, rand_pat_test_fail;

   wire r_p_log_vld;
   wire [SRAM_ADDR_WIDTH -1:0] r_p_log_addr;
   wire [SRAM_DATA_WIDTH -1:0] r_p_log_exp_data, r_p_log_rd_data;


   //---------------------------------------
   //reg, wire from chip_iter_sm
   reg [1:0] chip_iter_state, chip_iter_state_nxt;
   reg chip_iter_start;
   reg sram_idx, sram_idx_nxt;
   reg sram_en_r, sram_en_r_nxt;
   reg done_nxt, fail_nxt;

   parameter
             CHIP_ITER_IDLE_STATE = 2'h 0,
             CHIP_ITER_WAIT_STATE = 2'h 1,
             CHIP_ITER_NXT_STATE  = 2'h 2,
             CHIP_ITER_DONE_STATE = 2'h 3;

   assign running = (chip_iter_state != CHIP_ITER_IDLE_STATE);

   //---------------------------------------
   //reg, wire from chip_intra_sm
   reg [1:0] chip_intra_test_state, chip_intra_test_state_nxt;
   reg chip_intra_test_done, chip_intra_test_done_nxt;
   reg chip_intra_test_fail, chip_intra_test_fail_nxt;
   reg fixed_pat_test_start, rand_pat_test_start;
   reg [2:0] test_idx, test_idx_nxt;
   reg [SRAM_DATA_WIDTH -1:0] pattern;
   reg one_test_done, one_test_fail;
   reg [TOTAL_TEST_NUM -2:0] test_en_r, test_en_r_nxt;

   parameter
             CHIP_INTRA_IDLE_STATE = 2'h 0,
             CHIP_INTRA_WAIT_STATE = 2'h 1,
             CHIP_INTRA_NXT_STATE  = 2'h 2;

   //---------------------------------------
   //wires from mem mux

   reg [SRAM_DATA_WIDTH -1:0] ram_rd_data;

   //---------------------------------------
   //wires from mem demux


   //---------------------------------------
   //wires from tester mux
   reg ram_tri_en, ram_we_bw;
   reg [SRAM_ADDR_WIDTH -1:0] ram_addr;
   reg [SRAM_DATA_WIDTH -1:0] ram_wr_data;

   reg log_vld;
   reg [SRAM_ADDR_WIDTH   :0] log_addr;
   reg [SRAM_DATA_WIDTH -1:0] log_exp_data, log_rd_data;


   //---------------------------------------
   //wires from tester demux


   //------------------------------------------
   //wires from register block
   wire [SRAM_DATA_WIDTH -1:0] rand_seed;
   wire test_start;
   wire [TOTAL_TEST_NUM -1:0] test_en;
   wire [1:0] sram_en;

   //---------------------------------------
   // iterate thru two sram chips

   //synthesis attribute SIGNAL_ENCODING of chip_iter_state is user;

   always @(*) begin
      done_nxt = done;
      fail_nxt = fail;
      sram_idx_nxt = sram_idx;
      sram_en_r_nxt = sram_en_r;
      chip_iter_start = 1'b 0;

      chip_iter_state_nxt = chip_iter_state;

      case (chip_iter_state)
        CHIP_ITER_IDLE_STATE:
          if (test_start) begin
             done_nxt = 1'b 0;
             fail_nxt = 1'b 0;
             sram_idx_nxt = 1'b 0;
             sram_en_r_nxt = sram_en[1];

             if (sram_en[0]) begin
                chip_iter_start = 1'b 1;

                chip_iter_state_nxt = CHIP_ITER_WAIT_STATE;
             end
             else begin
                chip_iter_state_nxt = CHIP_ITER_NXT_STATE;

             end
          end

        CHIP_ITER_WAIT_STATE:
          if (chip_intra_test_done) begin
             fail_nxt = fail | chip_intra_test_fail;

             chip_iter_state_nxt = CHIP_ITER_NXT_STATE;
          end

        CHIP_ITER_NXT_STATE: begin
           sram_idx_nxt = sram_idx + 1'b 1;
           sram_en_r_nxt = 1'b 0;

           if (sram_idx_nxt == 1'b 0) begin
              //done testing two sram chips
              done_nxt = 1'b 1;
              chip_iter_state_nxt = CHIP_ITER_DONE_STATE;
           end

           else begin
              if (sram_en_r) begin
                 chip_iter_start = 1'b 1;

                 chip_iter_state_nxt = CHIP_ITER_WAIT_STATE;
              end
              else begin

                 chip_iter_state_nxt = CHIP_ITER_NXT_STATE;

              end

           end // else: !if(sram_idx_nxt == 1'b 0)

        end // case: CHIP_ITER_NXT_STATE


        CHIP_ITER_DONE_STATE:
          chip_iter_state_nxt = CHIP_ITER_IDLE_STATE;

      endcase // case(loop_state)

   end // always @ (*)


   always @(posedge clk) begin
      if (reset) begin
         done <= 1'b 0;
         fail <= 1'b 0;
         sram_idx <= 1'b 0;
         sram_en_r <= 1'h 0;
         chip_iter_state <= CHIP_ITER_IDLE_STATE;

      end
      else begin
         done <= done_nxt;
         fail <= fail_nxt;
         sram_idx <= sram_idx_nxt;
         sram_en_r <= sram_en_r_nxt;
         chip_iter_state <= chip_iter_state_nxt;

      end
   end // always @ (posedge clk)

   //-----------------------------------------------------
   // for each sram, iterate all tests
   always @(*)  begin

      fixed_pat_test_start = 1'b 0;
      rand_pat_test_start = 1'b 0;

      chip_intra_test_done_nxt = 1'b 0;
      chip_intra_test_fail_nxt = chip_intra_test_fail;
      test_idx_nxt = test_idx;
      test_en_r_nxt = test_en_r;

      chip_intra_test_state_nxt = chip_intra_test_state;

      one_test_done = 1'b 0;
      one_test_fail = 1'b 0;

      case (chip_intra_test_state)
        CHIP_INTRA_IDLE_STATE:
          if (chip_iter_start) begin
             test_idx_nxt = 3'h 0;
             test_en_r_nxt = test_en[TOTAL_TEST_NUM -1:1];

             if (test_en[0]) begin
                fixed_pat_test_start = 1'b 1;
                chip_intra_test_state_nxt = CHIP_INTRA_WAIT_STATE;
             end
             else begin
                chip_intra_test_state_nxt = CHIP_INTRA_NXT_STATE;

             end
          end

        CHIP_INTRA_WAIT_STATE:
          if ( (test_idx < 3'h 4) && fixed_pat_test_done ||
               (test_idx == 3'h 4) && rand_pat_test_done ) begin

             chip_intra_test_state_nxt = CHIP_INTRA_NXT_STATE;
             one_test_done = 1'b 1;

             if (test_idx < 3'h 4) begin
                one_test_fail = fixed_pat_test_fail;
                chip_intra_test_fail_nxt = chip_intra_test_fail | fixed_pat_test_fail;
             end
             else begin
              one_test_fail = rand_pat_test_fail;
              chip_intra_test_fail_nxt = chip_intra_test_fail | rand_pat_test_fail;
             end

          end // if ( (test_idx < 3'h 4) && fixed_pat_test_done ||...

        CHIP_INTRA_NXT_STATE: begin
           test_idx_nxt = test_idx + 3'h 1;
           test_en_r_nxt = {1'b 0, test_en_r[TOTAL_TEST_NUM -2:1]};

           if (test_idx_nxt == TOTAL_TEST_NUM) begin
              //done all tests

              test_idx_nxt = 3'h 0;
              chip_intra_test_done_nxt = 1'b 1;
              chip_intra_test_state_nxt = CHIP_INTRA_IDLE_STATE;
           end

           else begin
              if (test_en_r[0]) begin
                 if (test_idx_nxt < 3'h 4)
                   fixed_pat_test_start = 1'b 1;
                 else
                   rand_pat_test_start = 1'b 1;

                 chip_intra_test_state_nxt = CHIP_INTRA_WAIT_STATE;
              end
              else begin
                 chip_intra_test_state_nxt = CHIP_INTRA_NXT_STATE;
              end

           end // else: !if(test_idx_nxt == TOTAL_TEST_NUM)

        end // case: CHIP_INTRA_NXT_STATE

      endcase // case(tests_state)

   end // always @ (*)

   always @(*) begin
      case (test_idx_nxt)
        3'h 0: pattern = PATTERN_0;
        3'h 1: pattern = PATTERN_1;
        3'h 2: pattern = PATTERN_2;
        3'h 3: pattern = PATTERN_3;
        default: pattern = PATTERN_0;
      endcase // case(test_idx_nxt)
   end

   always @(posedge clk) begin
      if (reset) begin
         chip_intra_test_done <= 1'b 0;
         chip_intra_test_fail <= 1'b 0;
         test_idx <= 3'h 0;
         test_en_r <= { (TOTAL_TEST_NUM -1) {1'b 0}};
         chip_intra_test_state <= CHIP_INTRA_IDLE_STATE;

      end

      else begin
         chip_intra_test_done <= chip_intra_test_done_nxt;
         chip_intra_test_fail <= chip_intra_test_fail_nxt;
         test_idx <= test_idx_nxt;
         test_en_r <= test_en_r_nxt;
         chip_intra_test_state <= chip_intra_test_state_nxt;

      end

   end // always @ (posedge clk)

   //------------------------------------------------------
   // mux fixed_pat test output and rand_pat test output

   always @(*) begin

      case (test_idx)
        3'h 0: begin
           ram_tri_en = f_p_ram_tri_en;
           ram_we_bw = f_p_ram_we_bw;
           ram_addr = f_p_ram_addr;
           ram_wr_data = f_p_ram_wr_data;

           log_vld = f_p_log_vld;
           log_addr = {sram_idx, f_p_log_addr};
           log_exp_data = f_p_log_exp_data;
           log_rd_data = f_p_log_rd_data;

        end

        3'h 1: begin
           ram_tri_en = f_p_ram_tri_en;
           ram_we_bw = f_p_ram_we_bw;
           ram_addr = f_p_ram_addr;
           ram_wr_data = f_p_ram_wr_data;

           log_vld = f_p_log_vld;
           log_addr = {sram_idx, f_p_log_addr};
           log_exp_data = f_p_log_exp_data;
           log_rd_data = f_p_log_rd_data;

        end

        3'h 2: begin
           ram_tri_en = f_p_ram_tri_en;
           ram_we_bw = f_p_ram_we_bw;
           ram_addr = f_p_ram_addr;
           ram_wr_data = f_p_ram_wr_data;

           log_vld = f_p_log_vld;
           log_addr = {sram_idx, f_p_log_addr};
           log_exp_data = f_p_log_exp_data;
           log_rd_data = f_p_log_rd_data;

        end

        3'h 3: begin
           ram_tri_en = f_p_ram_tri_en;
           ram_we_bw = f_p_ram_we_bw;
           ram_addr = f_p_ram_addr;
           ram_wr_data = f_p_ram_wr_data;

           log_vld = f_p_log_vld;
           log_addr = {sram_idx, f_p_log_addr};
           log_exp_data = f_p_log_exp_data;
           log_rd_data = f_p_log_rd_data;

        end

        3'h 4: begin
           ram_tri_en = r_p_ram_tri_en;
           ram_we_bw = r_p_ram_we_bw;
           ram_addr = r_p_ram_addr;
           ram_wr_data = r_p_ram_wr_data;

           log_vld = r_p_log_vld;
           log_addr = {sram_idx, r_p_log_addr};
           log_exp_data = r_p_log_exp_data;
           log_rd_data = r_p_log_rd_data;

        end

        default: begin
           ram_tri_en = f_p_ram_tri_en;
           ram_we_bw = f_p_ram_we_bw;
           ram_addr = f_p_ram_addr;
           ram_wr_data = f_p_ram_wr_data;

           log_vld = f_p_log_vld;
           log_addr = {sram_idx, f_p_log_addr};
           log_exp_data = f_p_log_exp_data;
           log_rd_data = f_p_log_rd_data;

        end

      endcase // case(test_idx)

   end // always @ (*)

   //------------------------------------------
   // mux/demux mem_1 and mem_2

   always @(*) begin

      ram_rd_data = {SRAM_DATA_WIDTH {1'b 0}};

      sram_addr_1 = {SRAM_ADDR_WIDTH {1'b 0}};
      sram_wr_data_1 = {SRAM_DATA_WIDTH {1'b 0}};
      sram_tri_en_1 = 1'b 0;
      sram_we_bw_1 = 1'b 1;

      sram_addr_2 = {SRAM_ADDR_WIDTH {1'b 0}};
      sram_wr_data_2 = {SRAM_DATA_WIDTH {1'b 0}};
      sram_tri_en_2 = 1'b 0;
      sram_we_bw_2 = 1'b 1;

      case (sram_idx)
        1'b 0: begin
	   sram_addr_1 = ram_addr;
	   sram_wr_data_1 = ram_wr_data;
	   sram_tri_en_1 = ram_tri_en;
	   sram_we_bw_1 = ram_we_bw;

           ram_rd_data = sram_rd_data_1;

        end

        1'b 1: begin
	   sram_addr_2 = ram_addr;
	   sram_wr_data_2 = ram_wr_data;
	   sram_tri_en_2 = ram_tri_en;
	   sram_we_bw_2 = ram_we_bw;

           ram_rd_data = sram_rd_data_2;

        end

      endcase // case(sram_idx)

   end // always @ (*)


   //------------------------------------------
   // instantiations

   sram_test_fixed_pat_fast sram_test_fixed_pat_u
     (
      //intfc to sram_ctrl
      //output:
      .addr ( f_p_ram_addr ),//[SRAM_ADDR_WIDTH -1:0]
      .wr_data ( f_p_ram_wr_data ),//[SRAM_DATA_WIDTH -1:0]
      .tri_en ( f_p_ram_tri_en ),
      .we_bw ( f_p_ram_we_bw ),

      //input:
      .rd_data ( ram_rd_data ), //[SRAM_DATA_WIDTH -1:0]

      //intfc to test wrapper
      //input:
      .start ( fixed_pat_test_start ),
      .pattern ( pattern ), //[SRAM_DATA_WIDTH -1:0]

      //output:
      .done ( fixed_pat_test_done ),
      .fail ( fixed_pat_test_fail ),

      //to log registers
      //output:
      .log_vld ( f_p_log_vld ),
      .log_addr ( f_p_log_addr ), //[SRAM_ADDR_WIDTH -1:0]
      .log_exp_data ( f_p_log_exp_data ), //[SRAM_DATA_WIDTH -1:0]
      .log_rd_data ( f_p_log_rd_data ), //[SRAM_DATA_WIDTH -1:0]

      //intfc to misc
      //input:
      .clk ( clk ),
      .reset ( reset )
      );

   sram_test_rand_pat_fast sram_test_rand_pat_u
     (
      //intfc to sram_ctrl
      //output:
      .addr ( r_p_ram_addr ),  //[SRAM_ADDR_WIDTH -1:0]
      .wr_data ( r_p_ram_wr_data ),  //[SRAM_DATA_WIDTH -1:0]
      .tri_en ( r_p_ram_tri_en ),
      .we_bw ( r_p_ram_we_bw ),

      //input:
      .rd_data ( ram_rd_data ), //[SRAM_DATA_WIDTH -1:0]

      //intfc to test wrapper
      //input:
      .start ( rand_pat_test_start ),
      .seed ( rand_seed ), //[SRAM_DATA_WIDTH -1:0]

      //output:
      .done ( rand_pat_test_done ),
      .fail ( rand_pat_test_fail ),

      //to log registers
      //output:
      .log_vld ( r_p_log_vld ),
      .log_addr ( r_p_log_addr ),  //[SRAM_ADDR_WIDTH -1:0]
      .log_exp_data ( r_p_log_exp_data ),  //[SRAM_DATA_WIDTH -1:0]
      .log_rd_data ( r_p_log_rd_data ),  //[SRAM_DATA_WIDTH -1:0]

      //intfc to misc
      //input:
      .clk ( clk ),
      .reset ( reset )
      );

   sram_test_reg sram_test_reg_u
     (
      //intfc to cpu
      //input:
      .reg_req ( reg_req ),
      .reg_rd_wr_L ( reg_rd_wr_L ),
      .reg_addr ( reg_addr ),  //[`CPCI_NF2_ADDR_WIDTH -1:0]
      .reg_wr_data ( reg_wr_data ), //[`CPCI_NF2_DATA_WIDTH -1:0]

      //output:
      .reg_ack ( reg_ack ),
      .reg_rd_data ( reg_rd_data ), //[`CPCI_NF2_DATA_WIDTH -1:0]

      //intfc to tests
      //input:
      .log_vld ( log_vld ),
      .log_addr ( log_addr ), //[SRAM_ADDR_WIDTH   :0]
      .log_exp_data ( log_exp_data ),  //[SRAM_DATA_WIDTH -1:0]
      .log_rd_data ( log_rd_data ), //[SRAM_DATA_WIDTH -1:0]

      //output:
      .rand_seed ( rand_seed ),//[SRAM_DATA_WIDTH -1:0]
      .test_start ( test_start ),
      .test_en ( test_en ), //[TOTAL_TEST_NUM -1:0]
      .sram_en ( sram_en ), //[1:0]

      //intfc to tester
      .one_test_done ( one_test_done ),
      .one_test_fail ( one_test_fail ),
      .test_idx ( test_idx ), //[2:0]
      .sram_idx ( sram_idx ),

      .done (done | !running),
      .success (!fail),

      //intfc to misc
      //input:
      .clk ( clk ),
      .reset ( reset )
      );

endmodule // sram_test_fast
