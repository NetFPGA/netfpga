///////////////////////////////////////////////////////////////////////////////
// $Id: preprocess_control.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: preprocess_control.v
// Project: NF2.1
// Description: asserts the appropriate signals for parsing the headers
//
///////////////////////////////////////////////////////////////////////////////

  module preprocess_control
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,

    // --- Interface to other preprocess blocks
    output reg                         word_MAC_DA_HI,
    output reg                         word_MAC_DASA,
    output reg                         word_MAC_SA_LO,
    output reg                         word_ETH_IP_VER,
    output reg                         word_IP_LEN_ID,
    output reg                         word_IP_FRAG_TTL_PROTO,
    output reg                         word_IP_CHECKSUM_SRC_HI,
    output reg                         word_IP_SRC_DST,
    output reg                         word_IP_DST_LO,

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

   localparam SKIP_MODULE_HDRS = 1;
   localparam WORD_1           = 2;
   localparam WORD_2           = 4;
   localparam WORD_3           = 8;
   localparam WORD_4           = 16;
   localparam WORD_5           = 32;
   localparam WAIT_EOP         = 64;

   //---------------------- Wires/Regs -------------------------------
   reg [6:0]                            state, state_next;

   //------------------------ Logic ----------------------------------

   always @(*) begin
      state_next = state;
      word_MAC_DA_HI = 0;
      word_MAC_DASA  = 0;
      word_MAC_SA_LO = 0;
      word_ETH_IP_VER = 0;
      word_IP_LEN_ID = 0;
      word_IP_FRAG_TTL_PROTO = 0;
      word_IP_CHECKSUM_SRC_HI = 0;
      word_IP_SRC_DST = 0;
      word_IP_DST_LO = 0;

      case(state)
        SKIP_MODULE_HDRS: begin
           if(in_ctrl==0 && in_wr) begin
              word_MAC_DA_HI = 1;
              word_MAC_DASA  = 1;
              state_next     = WORD_1;
           end
        end

        WORD_1: begin
           if(in_wr) begin
              word_MAC_SA_LO = 1;
              word_ETH_IP_VER = 1;
              state_next = WORD_2;
           end
        end

        WORD_2: begin
           if(in_wr) begin
              word_IP_LEN_ID = 1;
              word_IP_FRAG_TTL_PROTO = 1;
              state_next = WORD_3;
           end
        end

        WORD_3: begin
           if(in_wr) begin
              word_IP_CHECKSUM_SRC_HI = 1;
              word_IP_SRC_DST = 1;
              state_next = WORD_4;
           end
        end

        WORD_4: begin
           if(in_wr) begin
              word_IP_DST_LO = 1;
              state_next = WAIT_EOP;
           end
        end

        WAIT_EOP: begin
           if(in_ctrl!=0 & in_wr) begin
              state_next = SKIP_MODULE_HDRS;
           end
        end
      endcase // case(state)
   end // always @ (*)

   always@(posedge clk) begin
      if(reset) begin
         state <= SKIP_MODULE_HDRS;
      end
      else begin
         state <= state_next;
      end
   end

endmodule // op_lut_hdr_parser
