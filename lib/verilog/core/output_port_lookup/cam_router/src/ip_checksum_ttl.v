///////////////////////////////////////////////////////////////////////////////
// $Id: ip_checksum_ttl.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: ip_checksum_ttl.v
// Project: NF2.1 reference router
// Description: Check the IP checksum over the IP header, and
//              generate a new one assuming that the TTL gets decremented.
//              Check if the TTL is valid, and generate the new TTL.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/100ps
module ip_checksum_ttl
  #(parameter DATA_WIDTH = 64)
  (
   //--- datapath interface
   input  [DATA_WIDTH-1:0]            in_data,
   input                              in_wr,

   //--- interface to preprocess
   input                              word_ETH_IP_VER,
   input                              word_IP_LEN_ID,
   input                              word_IP_FRAG_TTL_PROTO,
   input                              word_IP_CHECKSUM_SRC_HI,
   input                              word_IP_SRC_DST,
   input                              word_IP_DST_LO,

   // --- interface to process
   output                             ip_checksum_vld,
   output                             ip_checksum_is_good,
   output                             ip_hdr_has_options,
   output                             ip_ttl_is_good,
   output     [7:0]                   ip_new_ttl,
   output     [15:0]                  ip_new_checksum,     // new checksum assuming decremented TTL
   input                              rd_checksum,

   // misc
   input reset,
   input clk
   );

   //---------------------- Wires and regs---------------------------
   reg [19:0]  checksum_word_0, checksum_word_1;
   reg [19:0]  in_word_0_0, in_word_0_1, in_word_0_2;
   reg [19:0]  in_word_1_0, in_word_1_1, in_word_1_2;
   wire [19:0] next_sum_0, next_sum_1;
   reg [16:0]  adjusted_checksum;
   reg         checksum_done;
   wire        empty;
   reg  [7:0]  ttl_new;
   reg         ttl_good;
   reg         hdr_has_options;
   reg         add_carry_1, add_carry_2;

   //------------------------- Modules-------------------------------

   fallthrough_small_fifo #(.WIDTH(27), .MAX_DEPTH_BITS(2))
      arp_fifo
        (.din ({&checksum_word_0[15:0], adjusted_checksum[15:0], ttl_good, ttl_new, hdr_has_options}), // {IP good, new checksum}
         .wr_en (checksum_done),             // Write enable
         .rd_en (rd_checksum),               // Read the next word
         .dout ({ip_checksum_is_good, ip_new_checksum, ip_ttl_is_good, ip_new_ttl, ip_hdr_has_options}),
         .full (),
         .nearly_full (),
         .prog_full (),
         .empty (empty),
         .reset (reset),
         .clk (clk)
         );

   //------------------------- Logic -------------------------------
   assign ip_checksum_vld = !empty;

   /* MUX the additions to save adder logic */
   assign next_sum_0 = in_word_0_0 + in_word_0_1 + in_word_0_2;
   assign next_sum_1 = in_word_1_0 + in_word_1_1 + in_word_1_2;

   always @(*) begin
      in_word_0_0 = {4'h0, in_data[31:16]};
      in_word_0_1 = {4'h0, in_data[15:0]};
      in_word_0_2 = checksum_word_0;
      in_word_1_0 = {4'h0, in_data[DATA_WIDTH-1:DATA_WIDTH-16]};
      in_word_1_1 = {4'h0, in_data[DATA_WIDTH-17:DATA_WIDTH-32]};
      in_word_1_2 = checksum_word_1;

      if(word_ETH_IP_VER) begin
         in_word_0_0 = 20'h0;
         in_word_0_2 = 20'h0;
      end
      if(word_IP_DST_LO) begin
         in_word_0_0 = {4'h0, in_data[DATA_WIDTH-1:DATA_WIDTH-16]};
         in_word_0_1 = checksum_word_1;
      end
      if(add_carry_1 | add_carry_2) begin
         in_word_0_0 = 20'h0;
         in_word_0_1 = {16'h0, checksum_word_0[19:16]};
         in_word_0_2 = {4'h0,  checksum_word_0[15:0]};
      end

      if(word_IP_LEN_ID) begin
         in_word_1_2 = 20'h0;
      end
   end // always @ (*)

   // checksum logic. 16bit 1's complement over the IP header.
   // --- see RFC1936 for guidance.
   // 1's compl add: do a 2's compl add and then add the carry out
   // as if it were a carry in.
   // Final checksum (computed over the whole header incl checksum)
   // is in checksum_a and valid when IP_checksum_valid is 1
   // If checksum is good then it should be 0xffff
   always @(posedge clk) begin
      if(reset) begin
         checksum_word_0 <= 20'h0;   // does the addition for the low 32 bits
         checksum_word_1 <= 20'h0;   // does the addition for the high 32 bits
         adjusted_checksum <= 17'h0; // calculates the new chksum
         checksum_done <= 0;
         add_carry_1 <= 0;
         add_carry_2 <= 0;
         ttl_new <= 0;
         ttl_good <= 0;
         hdr_has_options <= 0;
      end
      else begin

         /* make sure the version is correct and there are no options */
         if(word_ETH_IP_VER) begin
            hdr_has_options <= (in_data[15:8]!=8'h45);
         end


         if(word_IP_FRAG_TTL_PROTO) begin
            ttl_new <= (in_data[15:8]==8'h0) ? 8'h0 : in_data[15:8] - 1'b1;
            ttl_good <= (in_data[15:8] > 8'h1);
         end

         if(word_ETH_IP_VER | word_IP_FRAG_TTL_PROTO | word_IP_SRC_DST |
            word_IP_DST_LO | add_carry_1 | add_carry_2) begin
            checksum_word_0 <= next_sum_0;
         end

         if(word_IP_LEN_ID | word_IP_CHECKSUM_SRC_HI) begin
            checksum_word_1 <= next_sum_1;
         end

         // see RFC 1141
         if(word_IP_CHECKSUM_SRC_HI) begin
            adjusted_checksum <= {1'h0, in_data[DATA_WIDTH-1:DATA_WIDTH-16]} + 17'h0100; // adjust for the decrement in TTL
         end

         if(word_IP_DST_LO) begin
            adjusted_checksum <= {1'h0, adjusted_checksum[15:0]} + adjusted_checksum[16];
            add_carry_1 <= 1;
         end
         else begin
            add_carry_1 <= 0;
         end

         if(add_carry_1) begin
            add_carry_2 <= 1;
         end
         else begin
            add_carry_2 <= 0;
         end

         if(add_carry_2) begin
            checksum_done <= 1;
         end
         else begin
            checksum_done <= 0;
         end

         // synthesis translate_off
         // If we have any carry left in top 4 bits then algorithm is wrong
         if (checksum_done && checksum_word_0[19:16] != 4'h0) begin
            $display("%t %m ERROR: top 4 bits of checksum_word_0 not zero - algo wrong???",
                     $time);
            #100 $stop;
         end
         // synthesis translate_on

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // IP_checksum
