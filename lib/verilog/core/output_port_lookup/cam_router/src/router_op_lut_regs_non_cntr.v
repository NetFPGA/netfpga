///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: router_op_lut_regs_non_cntr.v 5437 2009-05-04 21:11:51Z grg $
//
// Module: router_op_lut_regs_non_cntr.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
// Contains the non-counter registers.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module router_op_lut_regs_non_cntr
   #( parameter NUM_QUEUES = 5,
       parameter ARP_LUT_DEPTH_BITS = 4,
       parameter LPM_LUT_DEPTH_BITS = 4,
       parameter FILTER_DEPTH_BITS = 4,
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

      // --- interface to ip_lpm
      output reg [LPM_LUT_DEPTH_BITS-1:0 ] lpm_rd_addr,          // address in table to read
      output reg                           lpm_rd_req,           // request a read
      input [31:0]                         lpm_rd_ip,            // ip to match in the CAM
      input [31:0]                         lpm_rd_mask,          // subnet mask
      input [NUM_QUEUES-1:0]               lpm_rd_oq,            // input queue
      input [31:0]                         lpm_rd_next_hop_ip,   // ip addr of next hop
      input                                lpm_rd_ack,           // pulses high
      output reg [LPM_LUT_DEPTH_BITS-1:0]  lpm_wr_addr,
      output reg                           lpm_wr_req,
      output [NUM_QUEUES-1:0]              lpm_wr_oq,
      output [31:0]                        lpm_wr_next_hop_ip,   // ip addr of next hop
      output [31:0]                        lpm_wr_ip,            // data to match in the CAM
      output [31:0]                        lpm_wr_mask,
      input                                lpm_wr_ack,

      // --- ip_arp
      output reg [ARP_LUT_DEPTH_BITS-1:0]  arp_rd_addr,          // address in table to read
      output reg                           arp_rd_req,           // request a read
      input  [47:0]                        arp_rd_mac,           // data read from the LUT at rd_addr
      input  [31:0]                        arp_rd_ip,            // ip to match in the CAM
      input                                arp_rd_ack,           // pulses high
      output reg [ARP_LUT_DEPTH_BITS-1:0]  arp_wr_addr,
      output reg                           arp_wr_req,
      output [47:0]                        arp_wr_mac,
      output [31:0]                        arp_wr_ip,            // data to match in the CAM
      input                                arp_wr_ack,

      // --- interface to dest_ip_filter
      output reg  [FILTER_DEPTH_BITS-1:0]  dest_ip_filter_rd_addr,          // address in table to read
      output reg                           dest_ip_filter_rd_req,           // request a read
      input [31:0]                         dest_ip_filter_rd_ip,            // ip to match in the CAM
      input                                dest_ip_filter_rd_ack,           // pulses high
      output reg [FILTER_DEPTH_BITS-1:0]   dest_ip_filter_wr_addr,
      output reg                           dest_ip_filter_wr_req,
      output [31:0]                        dest_ip_filter_wr_ip,            // data to match in the CAM
      input                                dest_ip_filter_wr_ack,

      // --- eth_parser
      output reg [47:0]                    mac_0,    // address of rx queue 0
      output reg [47:0]                    mac_1,    // address of rx queue 1
      output reg [47:0]                    mac_2,    // address of rx queue 2
      output reg [47:0]                    mac_3,    // address of rx queue 3

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
   localparam NUM_REGS_USED = 32;
   localparam ADDR_WIDTH = log2(NUM_REGS_USED);

   localparam WAIT_FOR_REQ             = 1;
   localparam WRITE_TO_ARP_LUT         = 2;
   localparam READ_FROM_ARP_LUT        = 4;
   localparam WRITE_TO_RT_LUT          = 8;
   localparam READ_FROM_RT_LUT         = 16;
   localparam WRITE_TO_DEST_IP_FILTER  = 32;
   localparam READ_FROM_DEST_IP_FILTER = 64;
   localparam DONE                     = 128;

   // ------------- Wires/reg ------------------

   wire [ADDR_WIDTH-1:0]                 addr;
   wire [`ROUTER_OP_LUT_REG_ADDR_WIDTH- 1:0] reg_addr;
   wire [`UDP_REG_ADDR_WIDTH-`ROUTER_OP_LUT_REG_ADDR_WIDTH- 1:0] tag_addr;

   wire                                  addr_good;
   wire                                  tag_hit;

   reg [7:0]                             state;

   reg                                   reg_rd_wr_L_held;
   reg  [`UDP_REG_ADDR_WIDTH-1:0]        reg_addr_held;
   reg  [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_held;
   reg  [UDP_REG_SRC_WIDTH-1:0]          reg_src_held;

   reg [NUM_QUEUES-1:0]                  lpm_oq;
   reg [31:0]                            lpm_next_hop_ip;
   reg [31:0]                            lpm_ip;
   reg [31:0]                            lpm_mask;

   reg [47:0]                            arp_mac;
   reg [31:0]                            arp_ip;

   reg [31:0]                            dest_ip_filter_ip;


   // -------------- Logic --------------------

   assign addr = reg_addr_in[ADDR_WIDTH-1:0];
   assign reg_addr = reg_addr_in[`ROUTER_OP_LUT_REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`ROUTER_OP_LUT_REG_ADDR_WIDTH];

   //assign addr_good = reg_addr < NUM_REGS_USED;
   assign addr_good = reg_addr >= `ROUTER_OP_LUT_MAC_0_HI &&
                      reg_addr <= `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR;
   assign tag_hit = tag_addr == `ROUTER_OP_LUT_BLOCK_ADDR;

   assign lpm_wr_oq                = lpm_oq;
   assign lpm_wr_next_hop_ip       = lpm_next_hop_ip;
   assign lpm_wr_ip                = lpm_ip;
   assign lpm_wr_mask              = lpm_mask;

   assign dest_ip_filter_wr_ip     = dest_ip_filter_ip;

   assign arp_wr_ip                = arp_ip;
   assign arp_wr_mac               = arp_mac;

   // The following resets have been moved here to enable optimization by
   // pushing some registers into RAMs
   // synthesis translate_off
   initial
   begin
      arp_rd_addr = 'h0;
      arp_wr_addr = 'h0;
      lpm_rd_addr = 'h0;
      lpm_wr_addr = 'h0;
      dest_ip_filter_rd_addr = 'h0;
      dest_ip_filter_wr_addr = 'h0;
   end
   // synthesis translate_on

   /* run the counters and mux between write and update */
   always @(posedge clk) begin
      if(reset) begin
         arp_mac <= 48'h0;
         arp_ip <= 32'h0;
         lpm_ip <= 'h0;
         lpm_mask <= 'h0;
         lpm_next_hop_ip <= 'h0;
         lpm_oq <= 'h0;
         mac_0 <= {`ROUTER_OP_LUT_DEFAULT_MAC_0_HI, `ROUTER_OP_LUT_DEFAULT_MAC_0_LO};
         mac_1 <= {`ROUTER_OP_LUT_DEFAULT_MAC_1_HI, `ROUTER_OP_LUT_DEFAULT_MAC_1_LO};
         mac_2 <= {`ROUTER_OP_LUT_DEFAULT_MAC_2_HI, `ROUTER_OP_LUT_DEFAULT_MAC_2_LO};
         mac_3 <= {`ROUTER_OP_LUT_DEFAULT_MAC_3_HI, `ROUTER_OP_LUT_DEFAULT_MAC_3_LO};
         dest_ip_filter_ip <= 'h0;

         reg_req_out                                    <= 0;
         reg_ack_out                                    <= 0;
         reg_rd_wr_L_out                                <= 0;
         reg_addr_out                                   <= 0;
         reg_data_out                                   <= 0;
         reg_src_out                                    <= 0;

         reg_rd_wr_L_held                               <= 0;
         reg_addr_held                                  <= 0;
         reg_data_held                                  <= 0;
         reg_src_held                                   <= 0;

         state                                          <= WAIT_FOR_REQ;
         lpm_rd_req                                     <= 0;
         lpm_wr_req                                     <= 0;
         arp_rd_req                                     <= 0;
         arp_wr_req                                     <= 0;
         dest_ip_filter_wr_req                          <= 0;
         dest_ip_filter_rd_req                          <= 0;
      end // if (reset)
      else begin
         case(state)
            WAIT_FOR_REQ: begin
               if (reg_req_in && tag_hit) begin
                  if (!reg_rd_wr_L_in && addr_good) begin // write
                     // Update the appropriate register
                     case (addr)
                        `ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI        : arp_mac[47:32]   <= reg_data_in;
                        `ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO        : arp_mac[31:0]    <= reg_data_in;
                        `ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP   : arp_ip           <= reg_data_in;
                        `ROUTER_OP_LUT_ARP_TABLE_RD_ADDR             : arp_rd_addr      <= reg_data_in;
                        `ROUTER_OP_LUT_ARP_TABLE_WR_ADDR             : arp_wr_addr      <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP          : lpm_ip           <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK        : lpm_mask         <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP : lpm_next_hop_ip  <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT : lpm_oq           <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR           : lpm_rd_addr      <= reg_data_in;
                        `ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR           : lpm_wr_addr      <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_0_HI                      : mac_0[47:32]     <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_0_LO                      : mac_0[31:0]      <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_1_HI                      : mac_1[47:32]     <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_1_LO                      : mac_1[31:0]      <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_2_HI                      : mac_2[47:32]     <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_2_LO                      : mac_2[31:0]      <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_3_HI                      : mac_3[47:32]     <= reg_data_in;
                        `ROUTER_OP_LUT_MAC_3_LO                      : mac_3[31:0]      <= reg_data_in;
                        `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP  : dest_ip_filter_ip<= reg_data_in;
                        `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR   : dest_ip_filter_rd_addr <= reg_data_in;
                        `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR   : dest_ip_filter_wr_addr <= reg_data_in;
                     endcase

                     // Perform the correct post processing
                     case(addr)
                        `ROUTER_OP_LUT_ARP_TABLE_WR_ADDR             : state <= WRITE_TO_ARP_LUT;
                        `ROUTER_OP_LUT_ARP_TABLE_RD_ADDR             : state <= READ_FROM_ARP_LUT;
                        `ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR           : state <= WRITE_TO_RT_LUT;
                        `ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR           : state <= READ_FROM_RT_LUT;
                        `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR   : state <= WRITE_TO_DEST_IP_FILTER;
                        `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR   : state <= READ_FROM_DEST_IP_FILTER;
                        default                                      : state <= DONE;
                     endcase // case(addr)

                     reg_req_out       <= 0;
                     reg_ack_out       <= 0;
                     reg_rd_wr_L_out   <= 0;
                     reg_addr_out      <= 0;
                     reg_data_out      <= 0;
                     reg_src_out       <= 0;

                     reg_rd_wr_L_held  <= reg_rd_wr_L_in;
                     reg_addr_held     <= reg_addr_in;
                     reg_data_held     <= reg_data_in;
                     reg_src_held      <= reg_src_in;
                  end
                  else begin
                     reg_req_out       <= 1'b 1;
                     reg_rd_wr_L_out   <= reg_rd_wr_L_in;
                     reg_addr_out      <= reg_addr_in;
                     if (addr_good) begin
                        reg_ack_out       <= 1'b 1;
                        case (addr)
                           `ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI        : reg_data_out <= arp_mac[47:32];
                           `ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO        : reg_data_out <= arp_mac[31:0];
                           `ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP   : reg_data_out <= arp_ip;
                           `ROUTER_OP_LUT_ARP_TABLE_RD_ADDR             : reg_data_out <= arp_rd_addr;
                           `ROUTER_OP_LUT_ARP_TABLE_WR_ADDR             : reg_data_out <= arp_wr_addr;
                           `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP          : reg_data_out <= lpm_ip;
                           `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK        : reg_data_out <= lpm_mask;
                           `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP : reg_data_out <= lpm_next_hop_ip;
                           `ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT : reg_data_out <= lpm_oq;
                           `ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR           : reg_data_out <= lpm_rd_addr;
                           `ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR           : reg_data_out <= lpm_wr_addr;
                           `ROUTER_OP_LUT_MAC_0_HI                      : reg_data_out <= mac_0[47:32];
                           `ROUTER_OP_LUT_MAC_0_LO                      : reg_data_out <= mac_0[31:0];
                           `ROUTER_OP_LUT_MAC_1_HI                      : reg_data_out <= mac_1[47:32];
                           `ROUTER_OP_LUT_MAC_1_LO                      : reg_data_out <= mac_1[31:0];
                           `ROUTER_OP_LUT_MAC_2_HI                      : reg_data_out <= mac_2[47:32];
                           `ROUTER_OP_LUT_MAC_2_LO                      : reg_data_out <= mac_2[31:0];
                           `ROUTER_OP_LUT_MAC_3_HI                      : reg_data_out <= mac_3[47:32];
                           `ROUTER_OP_LUT_MAC_3_LO                      : reg_data_out <= mac_3[31:0];
                           `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP  : reg_data_out <= dest_ip_filter_ip;
                           `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR   : reg_data_out <= dest_ip_filter_rd_addr;
                           `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR   : reg_data_out <= dest_ip_filter_wr_addr;
                           default                                : reg_data_out <= 32'h DEAD_BEEF;
                        endcase
                     end
                     else
                     begin
                        reg_ack_out    <= 1'b 0;
                        reg_data_out   <= reg_data_in;
                     end
                     reg_src_out       <= reg_src_in;
                  end
               end
               else begin
                  reg_req_out       <= reg_req_in;
                  reg_ack_out       <= reg_ack_in;
                  reg_rd_wr_L_out   <= reg_rd_wr_L_in;
                  reg_addr_out      <= reg_addr_in;
                  reg_data_out      <= reg_data_in;
                  reg_src_out       <= reg_src_in;
               end
            end // case: WAIT_FOR_REQ

            WRITE_TO_ARP_LUT: begin
               if(arp_wr_ack) begin
                  state <= DONE;
                  arp_wr_req <= 0;
               end
               else begin
                  arp_wr_req <= 1;
               end
            end

           READ_FROM_ARP_LUT: begin
              if(arp_rd_ack) begin
                 arp_mac[47:32] <= arp_rd_mac[47:32];
                 arp_mac[31:0] <= arp_rd_mac[31:0];
                 arp_ip <= arp_rd_ip;
                 state <= DONE;
                 arp_rd_req <= 0;
              end // if (rd_ack)
              else begin
                 arp_rd_req <= 1;
              end
           end // case: READ_FROM_MAC_LUT

           WRITE_TO_RT_LUT: begin
              if(lpm_wr_ack) begin
                 state <= DONE;
                 lpm_wr_req <= 0;
              end
              else begin
                 lpm_wr_req <= 1;
              end
           end

           READ_FROM_RT_LUT: begin
              if(lpm_rd_ack) begin
                 lpm_ip <= lpm_rd_ip;
                 lpm_mask <= lpm_rd_mask;
                 lpm_next_hop_ip <= lpm_rd_next_hop_ip;
                 lpm_oq <= lpm_rd_oq;
                 state <= DONE;
                 lpm_rd_req <= 0;
              end // if (rd_ack)
              else begin
                 lpm_rd_req <= 1;
              end
           end // case: READ_FROM_MAC_LUT

           WRITE_TO_DEST_IP_FILTER: begin
              if(dest_ip_filter_wr_ack) begin
                 state <= DONE;
                 dest_ip_filter_wr_req <= 0;
              end
              else begin
                 dest_ip_filter_wr_req <= 1;
              end
           end // case: WRITE_TO_DEST_IP_FILTER

           READ_FROM_DEST_IP_FILTER: begin
              if(dest_ip_filter_rd_ack) begin
                 dest_ip_filter_ip <= dest_ip_filter_rd_ip;
                 state                                        <= DONE;
                 dest_ip_filter_rd_req                        <= 0;
              end // if (rd_ack)
              else begin
                 dest_ip_filter_rd_req <= 1;
              end
           end // case: READ_FROM_DEST_IP_FILTER

           DONE: begin
               state <= WAIT_FOR_REQ;

               reg_req_out      <= 1'b 1;
               reg_ack_out      <= 1'b 1;
               reg_rd_wr_L_out  <= reg_rd_wr_L_held;
               reg_addr_out     <= reg_addr_held;
               reg_data_out     <= reg_data_held;
               reg_src_out      <= reg_src_held;
           end
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule
