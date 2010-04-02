///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: generic_cntr_regs.v 5404 2009-04-30 00:44:52Z grg $
//
// Module: generic_cntr_reg.v
// Project: NF2.1
// Author: Jad Naous/Glen Gibb
// Description: Implements a generic counter register block that uses RAM and
// temporarily stores updates in registers before committing them to RAM.
//
// This design is efficient in that the update registers are kept small so one
// large adder can be shared amongst all registers. The routing resources
// associated with the RAM simplifies the routing of the registers.
// Demultiplexes, stores and serves register requests
//
// To use this block you should specify a number of parameters at
// instantiation:
//   TAG -- the tag to match against (probably defined in udp_defines.v)
//   REG_ADDR_WIDTH -- width of the address block allocated to this register
//                     group. It is important that this is specified correctly
//                     as this width is used to enable tag matching
//   NUM_REGS_USED -- how many registers in this block?
//   NUM_INSTANCES -- how many instances of the counters shall we emulate
//
// Other parameter which may be useful
//   INPUT_WIDTH -- width of each update input
//   MIN_UPDATE_INTERVAL -- how many clock cycles between successive update
//                          inputs
//   RESET_ON_READ -- reset registers when read
//
// Last Modified: 2/22/08 by Jad Naous to allow decrements and to not ack addresses
//                                     that are not found.
//                3/29/08 by Jad Naous to force reg file into bram
//                4/14/08 by Jad Naous to make bram write-first, fixing an issue
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module generic_cntr_regs
   #(
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter TAG = 0,                  // Tag to match against
      parameter REG_ADDR_WIDTH = 5,       // Width of block addresses
      parameter NUM_REGS_USED = 8,        // How many registers
      parameter REG_START_ADDR = 0,       // Address of the first counter
      parameter INPUT_WIDTH = 1,          // Width of each update request
      parameter MIN_UPDATE_INTERVAL = 8,  // Clocks between successive inputs
      parameter REG_WIDTH = `CPCI_NF2_DATA_WIDTH, // How wide should each counter be?
      parameter RESET_ON_READ = 0,

      // Don't modify the parameters below. They are used to calculate the
      // widths of the various register inputs/outputs.
      parameter REG_END_ADDR = REG_START_ADDR + NUM_REGS_USED,  // address of last counter + 1
      parameter UPDATES_START = REG_START_ADDR * INPUT_WIDTH,   // first bit of the updates vector
      parameter UPDATES_END = REG_END_ADDR * INPUT_WIDTH        // bit after last bit of the updates vector
   )
   (
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output reg                             reg_req_out,
      output reg                             reg_ack_out,
      output reg                             reg_rd_wr_L_out,
      output reg [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output reg [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // --- update interface
      input [UPDATES_END - 1:UPDATES_START]  updates,
      input [REG_END_ADDR-1:REG_START_ADDR]  decrement, // if 1 then subtract the update, else add.

      input                                  clk,
      input                                  reset
    );

   `LOG2_FUNC
   `CEILDIV_FUNC

   // ------------- Internal parameters --------------
   localparam MIN_CYCLE_TIME = NUM_REGS_USED + 1;

   // Calculate the number of updates we can see in a single cycle through the
   // RAM.
   //
   // This should be:
   //     ceil(MIN_CYCLE_TIME / MIN_UPDATE_INTERVAL)
   localparam UPDATES_PER_CYCLE = ceildiv(MIN_CYCLE_TIME, MIN_UPDATE_INTERVAL);
   localparam LOG_UPDATES_PER_CYCLE = log2(UPDATES_PER_CYCLE);

   // Calculate how much storage to allocate for each delta
   //
   // A single update requires INPUT_WIDTH bits of storage
   // In the worst case we would add the updates and get a total of
   //     (2^INPUT_WIDTH - 1) * UPDATES_PER_CYCLE
   // This can be represented in:
   //     log2( (2^INPUT_WIDTH - 1) * UPDATES_PER_CYCLE )
   //      = INPUT_WIDTH + log2(UPDATES_PER_CYCLE)
   // we add one for sign extension.
   localparam DELTA_WIDTH = INPUT_WIDTH + LOG_UPDATES_PER_CYCLE + 1;

   localparam RESET = 0,
              NORMAL = 1;

   // ------------- Wires/reg ------------------

   reg [REG_WIDTH-1:0]                    reg_file [REG_START_ADDR:REG_END_ADDR-1];

   wire [REG_ADDR_WIDTH-1:0]              addr, addr_d1;
   wire [`UDP_REG_ADDR_WIDTH-REG_ADDR_WIDTH-1:0] tag_addr;

   reg [REG_ADDR_WIDTH-1:0]               reg_cnt;
   wire [REG_ADDR_WIDTH-1:0]              reg_cnt_nxt;
   wire [REG_ADDR_WIDTH-1:0]              reg_file_rd_addr;
   reg [REG_ADDR_WIDTH-1:0]               reg_file_rd_addr_ram;
   wire [REG_ADDR_WIDTH-1:0]              reg_file_wr_addr;

   reg [DELTA_WIDTH-1:0]                  deltas[REG_START_ADDR:REG_END_ADDR-1];
   wire [DELTA_WIDTH-1:0]                 delta;

   wire [DELTA_WIDTH-1:0]                 update[REG_START_ADDR:REG_END_ADDR-1];

   wire [REG_WIDTH-1:0]                   reg_file_out;
   reg [REG_WIDTH-1:0]                    reg_file_in;
   reg                                    reg_file_wr_en;

   reg [REG_ADDR_WIDTH-1:0]               reg_cnt_d1;
   reg                                    reg_rd_req_good_d1, reg_wr_req_good_d1;
   reg [`UDP_REG_ADDR_WIDTH-1:0]          reg_addr_in_d1;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]         reg_data_in_d1;
   reg                                    reg_req_in_d1;
   reg                                    reg_ack_in_d1;
   reg                                    reg_rd_wr_L_in_d1;
   reg [UDP_REG_SRC_WIDTH-1:0]            reg_src_in_d1;

   integer                                i;

   reg                                    state;


   // -------------- Logic --------------------

   assign addr = reg_addr_in[REG_ADDR_WIDTH-1:0];
   assign addr_d1 = reg_addr_in_d1[REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:REG_ADDR_WIDTH];

   assign addr_good = addr < REG_END_ADDR && addr >= REG_START_ADDR;
   assign tag_hit = tag_addr == TAG;
   assign reg_rd_req_good = (tag_hit && addr_good && reg_req_in && reg_rd_wr_L_in);
   assign reg_wr_req_good = (tag_hit && addr_good && reg_req_in && ~reg_rd_wr_L_in);
   assign reg_cnt_nxt = (reg_cnt==REG_END_ADDR-1'b1) ? REG_START_ADDR : reg_cnt + 1'b1;

   assign delta = deltas[reg_cnt_d1];

   assign reg_file_rd_addr = reg_rd_req_good ? addr : reg_cnt;
   assign reg_file_wr_addr = (state == RESET
                              ? reg_cnt
                              : (reg_wr_req_good_d1 || reg_rd_req_good_d1)
                              ? addr_d1 : reg_cnt_d1);

   // choose when and what to write in the ram
   always @(*) begin
      reg_file_in      = reg_file_out + {{(REG_WIDTH - DELTA_WIDTH){delta[DELTA_WIDTH-1]}}, delta};
      reg_file_wr_en   = 0;
      if(state == RESET || (reg_rd_req_good_d1 && RESET_ON_READ)) begin
         reg_file_wr_en   = 1;
         reg_file_in      = 0;
      end
      else if(!reg_wr_req_good_d1 && !reg_rd_req_good_d1) begin
         reg_file_wr_en   = 1;
      end
      else if(reg_wr_req_good_d1) begin
         reg_file_in      = reg_data_in_d1;
         reg_file_wr_en   = 1;
      end
   end // always @ (*)

   // Generate the individual update lines from the updates vector
   //
   // Note: I have the ugly bit selection because ModelSim doesn't seem to
   // like parameters used in :+ selects! :-(
   generate
      genvar j;
      for (j = REG_START_ADDR; j < REG_END_ADDR; j = j + 1) begin : update_gen
         assign update[j] = {{(DELTA_WIDTH - INPUT_WIDTH){1'b0}}, updates[(j + 1) * INPUT_WIDTH - 1 : j * INPUT_WIDTH]};
      end
   endgenerate

   /*********** RAM *************/
   always @(posedge clk) begin
      // write to the register file
      if(reg_file_wr_en) begin
         reg_file[reg_file_wr_addr] <= reg_file_in;
      end
      reg_file_rd_addr_ram <= reg_file_rd_addr;
   end
   assign reg_file_out = reg_file[reg_file_rd_addr_ram];

   /****************************/

   // State machine that handles register access from the CPU
   always @(posedge clk) begin
      if(reset) begin
         reg_cnt               <= REG_START_ADDR;
         reg_rd_req_good_d1    <= 0;
         reg_wr_req_good_d1    <= 0;
         reg_req_in_d1         <= 0;
         reg_ack_out           <= 0;
         reg_req_out           <= 0;
         state                 <= RESET;
         for (i = REG_START_ADDR; i < REG_END_ADDR; i = i + 1) begin
            deltas[i]      <= 0;
         end
      end // if (reset)

      else begin
         reg_cnt_d1            <= reg_cnt;
         if(state == RESET) begin
            reg_cnt <= reg_cnt_nxt;
            if(reg_cnt == REG_END_ADDR-1'b1) begin
               state <= NORMAL;
            end
         end
         else begin
            /*********************************************************************
             * first stage - read bram, latch reg req signals
             */
            reg_cnt               <= (reg_rd_req_good || reg_wr_req_good) ? reg_cnt : reg_cnt_nxt;
            reg_rd_req_good_d1    <= reg_rd_req_good;
            reg_wr_req_good_d1    <= reg_wr_req_good;
            reg_addr_in_d1        <= reg_addr_in;
            reg_data_in_d1        <= reg_data_in;
            reg_req_in_d1         <= reg_req_in;
            reg_ack_in_d1         <= reg_ack_in;
            reg_rd_wr_L_in_d1     <= reg_rd_wr_L_in;
            reg_src_in_d1         <= reg_src_in;

            // synthesis translate_off
            if(reg_ack_in && (reg_rd_req_good || reg_wr_req_good)) begin
               $display("%t %m ERROR: Register request already ack even though", $time);
               $display("it should be destined to this module. This can happen");
               $display("if two modules have aliased register addresses.");
               $stop;
            end
            // synthesis translate_on

            /********************************************************************
             * second stage - output rd req or do write req or delta update
             */
            reg_ack_out        <= reg_rd_req_good_d1 || reg_wr_req_good_d1 || reg_ack_in_d1;
            reg_data_out       <= reg_rd_req_good_d1 ? reg_file_out : reg_data_in_d1;
            reg_addr_out       <= reg_addr_in_d1;
            reg_req_out        <= reg_req_in_d1;
            reg_rd_wr_L_out    <= reg_rd_wr_L_in_d1;
            reg_src_out        <= reg_src_in_d1;

            /*******************************************************************
             * update the deltas
             */
            for (i = REG_START_ADDR; i < REG_END_ADDR; i = i + 1) begin
               // if we just update the register corresponding to this delta then
               // clear it.
               if ((i==reg_cnt_d1)           // this delta was committed to reg_file
                   && !reg_wr_req_good_d1    // we didn't write in this cycle
                   && !(reg_rd_req_good_d1 && RESET_ON_READ) // we didn't read and reset
                   ) begin
                  deltas[i] <= decrement[i] ? -update[i] : update[i];
               end
               else begin
                  deltas[i] <= decrement[i] ? deltas[i] - update[i] : deltas[i] + update[i];
               end
            end // for (i = REG_START_ADDR; i < REG_END_ADDR; i = i + 1)
         end // else: !if(state == RESET)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule
