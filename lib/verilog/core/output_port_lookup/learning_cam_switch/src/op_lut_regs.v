///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: op_lut_regs.v 5525 2009-05-08 02:41:25Z g9coving $
//
// Module: op_lut_regs.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
//----
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

  module op_lut_regs
    #( parameter NUM_OUTPUT_QUEUES = 5,
       parameter LUT_DEPTH_BITS = 4,
       parameter UDP_REG_SRC_WIDTH = 2
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

     output [LUT_DEPTH_BITS-1:0]          rd_addr,          // address in table to read
     output reg                           rd_req,           // request a read
     input [NUM_OUTPUT_QUEUES-1:0]        rd_oq,            // data read from the LUT at rd_addr
     input                                rd_wr_protect,    // wr_protect bit read
     input [47:0]                         rd_mac,           // data to match in the CAM
     input                                rd_ack,           // stays high when data is rdy until req goes low

     output [LUT_DEPTH_BITS-1:0]          wr_addr,
     output reg                           wr_req,
     output [NUM_OUTPUT_QUEUES-1:0]       wr_oq,
     output                               wr_protect,       // wr_protect bit to write
     output [47:0]                        wr_mac,           // data to match in the CAM
     input                                wr_ack,

     input                                lut_hit,
     input                                lut_miss,

     input                                clk,
     input                                reset
     );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2


   // ------------- Internal parameters --------------
   parameter NUM_REGS_USED = 6;
   parameter OP_LUT_REG_ADDR_WIDTH_USED = log2(NUM_REGS_USED);

   parameter WAIT_FOR_REQ = 1;
   parameter WRITE_TO_MAC_LUT = 2;
   parameter READ_FROM_MAC_LUT = 4;
   parameter DONE = 8;

   // ------------- Wires/reg ------------------

   wire [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file [0:NUM_REGS_USED-1];
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file_next [0:NUM_REGS_USED-1];

   wire [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file_selected;

   wire [OP_LUT_REG_ADDR_WIDTH_USED-1:0]addr;
   wire [`IN_ARB_REG_ADDR_WIDTH - 1:0]  reg_addr;
   wire [`UDP_REG_ADDR_WIDTH-`SWITCH_OP_LUT_BLOCK_ADDR_WIDTH-`SWITCH_OP_LUT_REG_ADDR_WIDTH - 1:0] tag_addr;

   wire                                 addr_good;
   wire                                 tag_hit;

   wire [`CPCI_NF2_DATA_WIDTH-1:0]      mac_addr_lo;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      ports_mac_addr_hi;

   reg [3:0]                            state, state_next;

   reg [`CPCI_NF2_DATA_WIDTH-1:0]       op_lut_reg_rd_data_next;

   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_hits;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_misses;

   reg  [NUM_REGS_USED*`CPCI_NF2_DATA_WIDTH-1:0]   reg_file_linear;
   wire [NUM_REGS_USED*`CPCI_NF2_DATA_WIDTH-1:0]   reg_file_linear_next;

   reg                                   reg_rd_wr_L_held;
   reg  [`UDP_REG_ADDR_WIDTH-1:0]        reg_addr_held;
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_held;
   reg  [UDP_REG_SRC_WIDTH-1:0]          reg_src_held;

   reg                                   reg_rd_wr_L_held_nxt;
   reg  [`UDP_REG_ADDR_WIDTH-1:0]        reg_addr_held_nxt;
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_held_nxt;
   reg  [UDP_REG_SRC_WIDTH-1:0]          reg_src_held_nxt;

   reg                                   reg_req_out_nxt;
   reg                                   reg_ack_out_nxt;
   reg                                   reg_rd_wr_L_out_nxt;
   reg  [`UDP_REG_ADDR_WIDTH-1:0]        reg_addr_out_nxt;
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_out_nxt;
   reg  [UDP_REG_SRC_WIDTH-1:0]          reg_src_out_nxt;


   // -------------- Logic --------------------

   assign addr = reg_addr_in[OP_LUT_REG_ADDR_WIDTH_USED-1:0];
   assign reg_addr = reg_addr_in[`SWITCH_OP_LUT_REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`SWITCH_OP_LUT_REG_ADDR_WIDTH];

   assign addr_good = (reg_addr<NUM_REGS_USED);
   assign tag_hit = tag_addr == `SWITCH_OP_LUT_BLOCK_ADDR;

   assign mac_addr_lo = reg_file[`SWITCH_OP_LUT_MAC_LO];
   assign ports_mac_addr_hi = reg_file[`SWITCH_OP_LUT_PORTS_MAC_HI];
   assign wr_oq = ports_mac_addr_hi[NUM_OUTPUT_QUEUES+15:16]; // ports
   assign wr_protect = ports_mac_addr_hi[31]; // wr_protect bit
   assign wr_mac = {ports_mac_addr_hi, reg_file[`SWITCH_OP_LUT_MAC_LO]}; // mac addr
   assign wr_addr = reg_file[`SWITCH_OP_LUT_MAC_LUT_WR_ADDR];

   assign rd_addr = reg_file[`SWITCH_OP_LUT_MAC_LUT_RD_ADDR];

   assign num_hits = reg_file[`SWITCH_OP_LUT_NUM_HITS];
   assign num_misses = reg_file[`SWITCH_OP_LUT_NUM_MISSES];

   assign reg_file_selected = reg_file[addr];

   /* select the correct words from the registers */
   generate
   genvar j;
   for(j=0; j<NUM_REGS_USED; j=j+1) begin:linear_reg
      assign reg_file_linear_next[`REG_END(j):`REG_START(j)] = reg_file_next[j];
      assign reg_file[j] = reg_file_linear[`REG_END(j):`REG_START(j)];
   end
   endgenerate

   /* run the counters and mux between write and update */
   always @(*) begin

      reg_file_next[`SWITCH_OP_LUT_PORTS_MAC_HI]    = ports_mac_addr_hi;
      reg_file_next[`SWITCH_OP_LUT_MAC_LO]          = mac_addr_lo;
      reg_file_next[`SWITCH_OP_LUT_MAC_LUT_WR_ADDR] = wr_addr;
      reg_file_next[`SWITCH_OP_LUT_MAC_LUT_RD_ADDR] = rd_addr;

      reg_file_next[`SWITCH_OP_LUT_NUM_HITS]   = num_hits + lut_hit;
      reg_file_next[`SWITCH_OP_LUT_NUM_MISSES] = num_misses + lut_miss;

      state_next = state;

      reg_req_out_nxt = 0;
      reg_ack_out_nxt = 0;
      reg_rd_wr_L_out_nxt = 0;
      reg_addr_out_nxt = 0;
      reg_data_out_nxt = 0;
      reg_src_out_nxt = 0;

      reg_rd_wr_L_held_nxt = reg_rd_wr_L_held;
      reg_addr_held_nxt    = reg_addr_held;
      reg_data_held_nxt    = reg_data_held;
      reg_src_held_nxt     = reg_src_held;

      wr_req = 0;
      rd_req = 0;

      case(state)
        WAIT_FOR_REQ: begin
            if (reg_req_in && tag_hit) begin
               if (!reg_rd_wr_L_in && addr_good) begin
                  reg_file_next[addr] = reg_data_in;
                  case (addr)
                     `SWITCH_OP_LUT_MAC_LUT_WR_ADDR : state_next = WRITE_TO_MAC_LUT;
                     `SWITCH_OP_LUT_MAC_LUT_RD_ADDR : state_next = READ_FROM_MAC_LUT;
                     default : state_next = DONE;
                  endcase
                  reg_rd_wr_L_held_nxt = reg_rd_wr_L_in;
                  reg_addr_held_nxt    = reg_addr_in;
                  reg_data_held_nxt    = reg_data_in;
                  reg_src_held_nxt     = reg_src_in;
               end
               else begin
                  reg_req_out_nxt     = 1'b 1;
                  reg_ack_out_nxt     = 1'b 1;
                  reg_rd_wr_L_out_nxt = reg_rd_wr_L_in;
                  reg_addr_out_nxt    = reg_addr_in;
                  reg_data_out_nxt    = addr_good ? reg_file_selected : 32'h DEAD_BEEF;
                  reg_src_out_nxt     = reg_src_in;
               end
            end
            else begin
               reg_req_out_nxt = reg_req_in;
               reg_ack_out_nxt = reg_ack_in;
               reg_rd_wr_L_out_nxt = reg_rd_wr_L_in;
               reg_addr_out_nxt = reg_addr_in;
               reg_data_out_nxt = reg_data_in;
               reg_src_out_nxt = reg_src_in;
            end

           end // case: WAIT_FOR_REQ

        WRITE_TO_MAC_LUT: begin
           if(wr_ack) begin
              state_next = DONE;
           end
           else begin
              wr_req = 1;
           end
        end

        READ_FROM_MAC_LUT: begin
           if(rd_ack) begin
              reg_file_next[`SWITCH_OP_LUT_PORTS_MAC_HI] = {rd_wr_protect,
                                                     {(15-NUM_OUTPUT_QUEUES){1'b0}},
                                                     rd_oq,
                                                     rd_mac[47:32]};
              reg_file_next[`SWITCH_OP_LUT_MAC_LO] = rd_mac[31:0];
              /*op_lut_reg_rd_data_next = {rd_wr_protect,
                                         {(15-NUM_OUTPUT_QUEUES){1'b0}},
                                         rd_oq,
                                         rd_mac[47:32]};*/
              state_next = DONE;
           end // if (rd_ack)
           else begin
              rd_req = 1;
           end
        end // case: READ_FROM_MAC_LUT

        DONE: begin
           state_next = WAIT_FOR_REQ;

           reg_req_out_nxt      = 1'b 1;
           reg_ack_out_nxt      = 1'b 1;
           reg_rd_wr_L_out_nxt  = reg_rd_wr_L_held;
           reg_addr_out_nxt     = reg_addr_held;
           reg_data_out_nxt     = reg_data_held;
           reg_src_out_nxt      = reg_src_held;
        end
      endcase // case(state)
   end // always @ (*)


   always @(posedge clk) begin
      if( reset ) begin
         reg_req_out       <= 0;
         reg_ack_out       <= 0;
         reg_rd_wr_L_out   <= 0;
         reg_addr_out      <= 0;
         reg_data_out      <= 0;
         reg_src_out       <= 0;

         reg_rd_wr_L_held  <= 0;
         reg_addr_held     <= 0;
         reg_data_held     <= 0;
         reg_src_held      <= 0;

         // zero out the registers being used
	 reg_file_linear <= {(`CPCI_NF2_DATA_WIDTH*NUM_REGS_USED){1'b0}};
         state <= WAIT_FOR_REQ;
      end
      else begin
         reg_req_out       <= reg_req_out_nxt;
         reg_ack_out       <= reg_ack_out_nxt;
         reg_rd_wr_L_out   <= reg_rd_wr_L_out_nxt;
         reg_addr_out      <= reg_addr_out_nxt;
         reg_data_out      <= reg_data_out_nxt;
         reg_src_out       <= reg_src_out_nxt;

         reg_rd_wr_L_held  <= reg_rd_wr_L_held_nxt;
         reg_addr_held     <= reg_addr_held_nxt;
         reg_data_held     <= reg_data_held_nxt;
         reg_src_held      <= reg_src_held_nxt;

	 reg_file_linear <= reg_file_linear_next;

         state <= state_next;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule
