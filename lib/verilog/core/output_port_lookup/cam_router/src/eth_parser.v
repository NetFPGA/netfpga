///////////////////////////////////////////////////////////////////////////////
// $Id: eth_parser.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: eth_parser.v
// Project: NF2.1
// Description: decides if the MAC dstof the ingress pkt is us, and if it's an
//              ARP or IP packet. Assume that NUM_QUEUES < MIN_PKT_SIZE-2
//
///////////////////////////////////////////////////////////////////////////////

  module eth_parser
    #(parameter DATA_WIDTH = 64,
      parameter NUM_QUEUES = 8,
      parameter NUM_QUEUES_WIDTH = log2(NUM_QUEUES)
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,

    // --- Interface to process block
    output                             is_arp_pkt,
    output                             is_ip_pkt,
    output                             is_for_us,
    output                             is_broadcast,
    output [NUM_QUEUES_WIDTH-1:0]      mac_dst_port_num,
    input                              eth_parser_rd_info,
    output                             eth_parser_info_vld,

    // --- Interface to preprocess block
    input                              word_MAC_DA_HI,
    input                              word_MAC_DASA,
    input                              word_ETH_IP_VER,

    // --- Interface to registers
    input  [47:0]                      mac_0,    // address of rx queue 0
    input  [47:0]                      mac_1,    // address of rx queue 1
    input  [47:0]                      mac_2,    // address of rx queue 2
    input  [47:0]                      mac_3,    // address of rx queue 3

    // --- Misc

    input                              reset,
    input                              clk
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

   //------------------ Internal Parameter ---------------------------
   parameter                           ETH_ARP = 16'h0806;
   parameter                           ETH_IP = 16'h0800;

   parameter                           IDLE = 0;
   parameter                           DO_SEARCH = 1;

   //---------------------- Wires/Regs -------------------------------
   reg [47:0]                          dst_MAC;
   reg [47:0]                          mac_sel;
   reg [15:0]                          ethertype;

   reg                                 search_req;

   reg                                 state, state_next;
   reg [log2(NUM_QUEUES/2):0]          mac_count, mac_count_next;
   reg                                 wr_en;
   reg                                 port_found;

   wire                                broadcast_bit;

   //----------------------- Modules ---------------------------------
   fallthrough_small_fifo #(.WIDTH(4+NUM_QUEUES_WIDTH), .MAX_DEPTH_BITS(2))
      eth_fifo
        (.din ({port_found,                // is for us
                (ethertype==ETH_ARP),      // is ARP
                (ethertype==ETH_IP),       // is IP
                (broadcast_bit),           // is broadcast
                {mac_count[log2(NUM_QUEUES/2)-1:0], 1'b0}}),     // dst port num
         .wr_en (wr_en),             // Write enable
         .rd_en (eth_parser_rd_info),       // Read the next word
         .dout ({is_for_us, is_arp_pkt, is_ip_pkt, is_broadcast, mac_dst_port_num}),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------ Logic ----------------------------------
   assign eth_parser_info_vld = !empty;
   assign broadcast_bit = dst_MAC[40];

   always @(*) begin
      mac_sel = mac_0;
      case(mac_count)
         0: mac_sel = mac_0;
         1: mac_sel = mac_1;
         2: mac_sel = mac_2;
         3: mac_sel = mac_3;
         4: mac_sel = ~48'h0;
      endcase // case(mac_count)
   end // always @ (*)

   /******************************************************************
    * Get the destination, source and ethertype of the pkt
    *****************************************************************/
   always @(posedge clk) begin
      if(reset) begin
         dst_MAC   <= 0;
         ethertype <= 0;
         search_req <= 0;
      end
      else begin
         if(word_MAC_DA_HI) begin
            dst_MAC[47:16] <= in_data[DATA_WIDTH-1:DATA_WIDTH-32];
         end
         if(word_MAC_DASA) begin
            dst_MAC[15:0]  <= in_data[31:16];
         end
         if(word_ETH_IP_VER) begin
            ethertype      <= in_data[31:16];
            search_req     <= 1;
         end
         else begin
            search_req     <= 0;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

   /*************************************************************
    * check to see if the destination port matches any of our port
    * MAC addresses. We need to make sure that this search is
    * completed before the end of the packet.
    *************************************************************/
   always @(*) begin

      state_next = state;
      mac_count_next = mac_count;
      wr_en = 0;
      port_found = 0;

      case(state)

        IDLE: begin
           if(search_req) begin
              state_next = DO_SEARCH;
              mac_count_next = NUM_QUEUES/2;
           end
        end

        DO_SEARCH: begin
           mac_count_next = mac_count-1;
           if(mac_sel==dst_MAC || broadcast_bit) begin
              wr_en = 1;
              state_next = IDLE;
              port_found = 1;
           end
           else if(mac_count == 0) begin
              state_next = IDLE;
              wr_en = 1;
           end
        end

      endcase // case(state)

   end // always @(*)


   always @(posedge clk) begin
      if(reset) begin
         state <= IDLE;
         mac_count <= 0;
      end
      else begin
         state <= state_next;
         mac_count <= mac_count_next;
      end
   end

   // synthesis translate_off
   always @(posedge clk) begin
      if(state==DO_SEARCH && word_MAC_DA_HI) begin
         $display("%t %m ERROR: Latched new address before the last search was done!", $time);
         $stop;
      end
   end
   // synthesis translate_on

endmodule // eth_parser


