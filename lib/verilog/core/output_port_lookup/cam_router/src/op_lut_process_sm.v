///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: op_lut_process_sm.v 3000 2007-11-21 09:09:56Z jnaous $
//
// Module: op_lut_process_sm.v
// Project: NF2.1 reference router
// Description: Take the information from the preprocess blocks, write a new
//              module header for the output port, write the packet with the
//              information from the preprocess.
//
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps
module op_lut_process_sm
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter NUM_QUEUES = 8,
    parameter NUM_QUEUES_WIDTH = log2(NUM_QUEUES),
    parameter STAGE_NUM  = 4,
    parameter IOQ_STAGE_NUM = 8'hff)
  (// --- interface to input fifo - fallthrough
   input                              in_fifo_vld,
   input [DATA_WIDTH-1:0]             in_fifo_data,
   input [CTRL_WIDTH-1:0]             in_fifo_ctrl,
   output reg                         in_fifo_rd_en,

   // --- interface to eth_parser
   input                              is_arp_pkt,
   input                              is_ip_pkt,
   input                              is_for_us,
   input                              is_broadcast,
   input                              eth_parser_info_vld,
   input      [NUM_QUEUES_WIDTH-1:0]  mac_dst_port_num,

   // --- interface to ip_arp
   input      [47:0]                  next_hop_mac,
   input      [NUM_QUEUES-1:0]        output_port,
   input                              arp_lookup_hit, // indicates if the next hop mac is correct
   input                              lpm_lookup_hit, // indicates if the route to the destination IP was found
   input                              arp_mac_vld,    // indicates the lookup is done

   // --- interface to op_lut_hdr_parser
   input                              is_from_cpu,
   input      [NUM_QUEUES-1:0]        to_cpu_output_port,   // where to send pkts this pkt if it has to go to the CPU
   input      [NUM_QUEUES-1:0]        from_cpu_output_port, // where to send this pkt if it is coming from the CPU
   input                              is_from_cpu_vld,
   input      [NUM_QUEUES_WIDTH-1:0]  input_port_num,

   // --- interface to IP_checksum
   input                              ip_checksum_vld,
   input                              ip_checksum_is_good,
   input                              ip_hdr_has_options,
   input      [15:0]                  ip_new_checksum,     // new checksum assuming decremented TTL
   input                              ip_ttl_is_good,
   input      [7:0]                   ip_new_ttl,

   // --- input to dest_ip_filter
   input                              dest_ip_hit,
   input                              dest_ip_filter_vld,

   // -- connected to all preprocess blocks
   output reg                         rd_preprocess_info,

   // --- interface to next module
   output reg                         out_wr,
   output reg [DATA_WIDTH-1:0]        out_data,
   output reg [CTRL_WIDTH-1:0]        out_ctrl,     // new checksum assuming decremented TTL
   input                              out_rdy,

   // --- interface to registers
   output reg                         pkt_sent_from_cpu,              // pulsed: we've sent a pkt from the CPU
   output reg                         pkt_sent_to_cpu_options_ver,    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
   output reg                         pkt_sent_to_cpu_bad_ttl,        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
   output reg                         pkt_sent_to_cpu_dest_ip_hit,    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
   output reg                         pkt_forwarded     ,             // pulsed: forwarded pkt to the destination port
   output reg                         pkt_dropped_checksum,           // pulsed: dropped pkt coz bad checksum
   output reg                         pkt_sent_to_cpu_non_ip,         // pulsed: sent pkt to cpu coz it's not IP
   output reg                         pkt_sent_to_cpu_arp_miss,       // pulsed: sent pkt to cpu coz we didn't find arp entry for next hop ip
   output reg                         pkt_sent_to_cpu_lpm_miss,       // pulsed: sent pkt to cpu coz we didn't find lpm entry for destination ip
   output reg                         pkt_dropped_wrong_dst_mac,      // pulsed: dropped pkt not destined to us

   input  [47:0]                      mac_0,    // address of rx queue 0
   input  [47:0]                      mac_1,    // address of rx queue 1
   input  [47:0]                      mac_2,    // address of rx queue 2
   input  [47:0]                      mac_3,    // address of rx queue 3

   // misc
   input reset,
   input clk
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

   //------------------- Internal parameters -----------------------
   localparam NUM_STATES          = 7;
   localparam WAIT_PREPROCESS_RDY = 1;
   localparam MOVE_MODULE_HDRS    = 2;
   localparam SEND_SRC_MAC_LO     = 4;
   localparam SEND_IP_TTL         = 8;
   localparam SEND_IP_CHECKSUM    = 16;
   localparam MOVE_PKT            = 32;
   localparam DROP_PKT            = 64;

   //---------------------- Wires and regs -------------------------
   wire                 preprocess_vld;

   reg [NUM_STATES-1:0] state;
   reg [NUM_STATES-1:0] state_next;
   reg [DATA_WIDTH-1:0] out_data_next;
   reg [CTRL_WIDTH-1:0] out_ctrl_next;
   reg                  out_wr_next;
   reg                  ctrl_prev_is_0;
   wire                 eop;

   reg [47:0]           src_mac_sel;

   reg [NUM_QUEUES-1:0] dst_port;
   reg [NUM_QUEUES-1:0] dst_port_next;

   reg                  to_from_cpu;
   reg                  to_from_cpu_next;

   //-------------------------- Logic ------------------------------
   assign preprocess_vld = eth_parser_info_vld & arp_mac_vld
                         & is_from_cpu_vld & ip_checksum_vld & dest_ip_filter_vld;

   assign eop = (ctrl_prev_is_0 && (in_fifo_ctrl!=0));

   /* select the src mac address to write in the forwarded pkt */
   always @(*) begin
      case(output_port)
        'h1: src_mac_sel       = mac_0;
        'h4: src_mac_sel       = mac_1;
        'h10: src_mac_sel      = mac_2;
        'h40: src_mac_sel      = mac_3;
        default: src_mac_sel   = mac_0;
      endcase // case(output_port)
   end


   /* Modify the packet's hdrs and add the module hdr */
   always @(*) begin
      out_ctrl_next                 = in_fifo_ctrl;
      out_data_next                 = in_fifo_data;
      out_wr_next                   = 0;
      rd_preprocess_info            = 0;
      state_next                    = state;
      in_fifo_rd_en                 = 0;
      to_from_cpu_next              = to_from_cpu;
      dst_port_next                 = dst_port;

      pkt_sent_from_cpu             = 0;
      pkt_sent_to_cpu_options_ver   = 0;
      pkt_sent_to_cpu_arp_miss      = 0;
      pkt_sent_to_cpu_lpm_miss      = 0;
      pkt_sent_to_cpu_bad_ttl       = 0;
      pkt_forwarded                 = 0;
      pkt_dropped_checksum          = 0;
      pkt_sent_to_cpu_non_ip        = 0;
      pkt_dropped_wrong_dst_mac     = 0;
      pkt_sent_to_cpu_dest_ip_hit   = 0;

      case(state)
        WAIT_PREPROCESS_RDY: begin
           if(preprocess_vld) begin
              /* if the packet is from the CPU then all the info on it is correct.
               * We just pipe it to the output */
              if(is_from_cpu) begin
                 to_from_cpu_next     = 1;
                 dst_port_next        = from_cpu_output_port;
                 rd_preprocess_info   = 1;
                 state_next           = MOVE_MODULE_HDRS;
                 pkt_sent_from_cpu    = 1;
              end
              /* check that the port on which it was received matches its mac */
              else if(is_for_us && (input_port_num==mac_dst_port_num || is_broadcast)) begin
                 if(is_ip_pkt) begin
                    if(ip_checksum_is_good) begin
                       /* if the packet has any options or ver!=4 or the TTL is 1 or 0 or if the ip destination address
                        * is in the destination filter list, then send it to the cpu queue corresponding to the input queue
                        * Also send pkt to CPU if we don't find it in the ARP lookup or in the LPM lookup*/
                       if(dest_ip_hit || (ip_hdr_has_options | !ip_ttl_is_good | !arp_lookup_hit | !lpm_lookup_hit)) begin
                          rd_preprocess_info            = 1;
                          to_from_cpu_next              = 1;
                          dst_port_next                 = to_cpu_output_port;
                          state_next                    = MOVE_MODULE_HDRS;

                          // Note: care must be taken to ensure that only
                          // *one* of the counters will be incremented at any
                          // given time. (Otherwise the output port lookup
                          // counters will register more packets than other
                          // modules.)
                          //
                          // These are currently sorted in order of priority
                          pkt_sent_to_cpu_dest_ip_hit   = dest_ip_hit;
                          pkt_sent_to_cpu_bad_ttl       = !ip_ttl_is_good & !dest_ip_hit;
                          pkt_sent_to_cpu_options_ver   = ip_hdr_has_options &
                                                          ip_ttl_is_good & !dest_ip_hit;
                          pkt_sent_to_cpu_lpm_miss      = !lpm_lookup_hit & !ip_hdr_has_options &
                                                          ip_ttl_is_good & !dest_ip_hit;
                          pkt_sent_to_cpu_arp_miss      = !arp_lookup_hit & lpm_lookup_hit &
                                                          !ip_hdr_has_options & ip_ttl_is_good &
                                                          !dest_ip_hit;
                       end
                       else if (!is_broadcast) begin
                          to_from_cpu_next   = 0;
                          dst_port_next      = output_port;
                          state_next         = MOVE_MODULE_HDRS;
                          pkt_forwarded      = 1;
                       end // else: !if(ip_hdr_has_options | !ip_ttl_is_good)
                       else begin
                          pkt_dropped_wrong_dst_mac   = 1;
                          rd_preprocess_info          = 1;
                          in_fifo_rd_en               = 1;
                          state_next                  = DROP_PKT;
                       end
                    end // if (ip_checksum_is_good)
                    else begin
                       pkt_dropped_checksum   = 1;
                       rd_preprocess_info     = 1;
                       in_fifo_rd_en          = 1;
                       state_next             = DROP_PKT;
                    end // else: !if(ip_checksum_is_good)
                 end // if (is_ip_pkt)
                 else begin // non-ip pkt
                    pkt_sent_to_cpu_non_ip   = 1;
                    rd_preprocess_info       = 1;
                    to_from_cpu_next         = 1;
                    dst_port_next            = to_cpu_output_port;
                    state_next               = MOVE_MODULE_HDRS;
                 end // else: !if(is_ip_pkt)
              end // if (is_for_us)
              else begin // pkt not for us
                 pkt_dropped_wrong_dst_mac   = 1;
                 rd_preprocess_info          = 1;
                 in_fifo_rd_en               = 1;
                 state_next                  = DROP_PKT;
              end // else: !if(is_for_us)
           end // if (preprocess_vld & out_rdy)
        end // case: WAIT_PREPROCESS_RDY

        MOVE_MODULE_HDRS: begin
           if(out_rdy & in_fifo_vld) begin
              out_wr_next      = 1;
              in_fifo_rd_en    = 1;
              if (in_fifo_ctrl == IOQ_STAGE_NUM) begin
                 out_data_next = {{(DATA_WIDTH-NUM_QUEUES-`IOQ_DST_PORT_POS){1'b0}}, dst_port, in_fifo_data[`IOQ_DST_PORT_POS-1:0]};
                 if (to_from_cpu)
                    state_next = MOVE_PKT;
              end
              else if(in_fifo_ctrl==0) begin
                 out_data_next = {next_hop_mac, src_mac_sel[47:32]};
                 state_next    = SEND_SRC_MAC_LO;
              end
              else begin
                 out_data_next = in_fifo_data;
              end
           end
        end // case: MOVE_MODULE_HDRS

        SEND_SRC_MAC_LO: begin
           if(out_rdy && in_fifo_vld) begin
              out_wr_next     = 1;
              in_fifo_rd_en   = 1;
              out_data_next   = {src_mac_sel[31:0], in_fifo_data[31:0]};
              state_next      = SEND_IP_TTL;
           end
        end

        SEND_IP_TTL: begin
           if(out_rdy && in_fifo_vld) begin
              out_wr_next     = 1;
              in_fifo_rd_en   = 1;
              // don't decrement the TTL for local pkts
              out_data_next   = {in_fifo_data[63:16], ip_new_ttl[7:0], in_fifo_data[7:0]};
              state_next      = SEND_IP_CHECKSUM;
           end
        end

        SEND_IP_CHECKSUM: begin
           if(out_rdy && in_fifo_vld) begin
              out_wr_next          = 1;
              in_fifo_rd_en        = 1;
              // don't write a new checksum for local pkts
              out_data_next        = {ip_new_checksum, in_fifo_data[47:0]};
              rd_preprocess_info   = 1;
              state_next           = MOVE_PKT;
           end
        end

        MOVE_PKT: begin
           if(out_rdy && in_fifo_vld) begin
              out_wr_next     = 1;
              in_fifo_rd_en   = 1;
              out_data_next   = in_fifo_data;
              if(eop) begin
                 state_next   = WAIT_PREPROCESS_RDY;
              end
           end
        end // case: MOVE_PKT

        DROP_PKT: begin
           if(in_fifo_vld) begin
              in_fifo_rd_en = 1;
              if(eop) begin
                 state_next = WAIT_PREPROCESS_RDY;
              end
           end
        end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state             <= WAIT_PREPROCESS_RDY;
         out_data          <= 0;
         out_ctrl          <= 1;
         out_wr            <= 0;
         ctrl_prev_is_0    <= 0;
         to_from_cpu       <= 0;
         dst_port          <= 'h0;
      end
      else begin
         state             <= state_next;
         out_data          <= out_data_next;
         out_ctrl          <= out_ctrl_next;
         out_wr            <= out_wr_next;
         ctrl_prev_is_0    <= in_fifo_rd_en ? (in_fifo_ctrl==0) : ctrl_prev_is_0;
         to_from_cpu       <= to_from_cpu_next;
         dst_port          <= dst_port_next;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // op_lut_process_sm

