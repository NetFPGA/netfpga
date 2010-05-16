///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpu_dma_queue_regs.v 2265 2007-09-17 22:02:57Z grg $
//
// Module: nf2_dma_regs.v
// Project: NetFPGA 1G
// Description: Register module for DMA interface
//
// The "deltas" in this block are designed to store the updates that need to
// be applied to the registers in RAM. An example would be the number of
// packets that have arrived since the appropriate register in RAM was last
// updated. These deltas are applied periodically to RAM (in which case the
// deltas are reset).
//
//
// To add registers to this block the following steps should be followed:
//   1. Add the register to the appropriate defines file
//   2. Create a new delta register. The delta register should hold the
//      changes since the previous update
//   3. Add code to update the delta register. This code should:
//        i) reset the delta register on reset
//       ii) set the delta register to the current input when the real
//           register in RAM is being updated (this is so that the update is
//           not lost)
//      iii) set the delta register to its current value + the input during
//           other cycles
//      eg.
//         if (reset)
//            tx_pkt_stored_delta <= 'h0;
//         else if (!new_reg_req && reg_cnt == `DMA_TX_QUEUE_NUM_PKTS_ENQUEUED)
//            tx_pkt_stored_delta <= tx_pkt_stored;
//         else
//            tx_pkt_stored_delta <= tx_pkt_stored_delta + tx_pkt_stored;
//
//   4. Update the number of registers
//   5. Add a line to the case statement in the main state machine that
//      applies the delta when reg_cnt is at the correct address.
//
///////////////////////////////////////////////////////////////////////////////

module nf2_dma_regs
   (
      // Register interface
      input                                  reg_req,
      input                                  reg_rd_wr_L,
      input  [`DMA_REG_ADDR_WIDTH-1:0]       reg_addr,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_wr_data,

      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_rd_data,
      output reg                             reg_ack,

      // Interface to DMA logic
      output                                 iface_disable,
      output                                 iface_reset,
      input                                  pkt_ingress,
      input                                  pkt_egress,
      input [11:0]                           pkt_len,
      input                                  timeout,

      // --- Misc
      input                                  reset,
      input                                  clk
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

   // -------- Internal parameters --------------

   localparam NUM_REGS_USED         = 6; /* don't forget to update this when adding regs */
   localparam REG_FILE_ADDR_WIDTH   = log2(NUM_REGS_USED);
   //localparam REG_FILE_DEPTH        = 2 ** REG_FILE_ADDR_WIDTH;

   // Calculations for register sizes
   // -------------------------------
   //
   // A cycle is 16 clocks max
   //      (13 reg + 1 reg read/write < 16)
   //
   // Min packet size: is 8 words
   //
   // Max packets per period = 2  (16 / 8)

   // Word/byte count widths. Should support 2k packets -- i.e. up to 2048
   // bytes per packet
   //
   // Note: don't need to increase the size to allow for multiple packets
   // in a single cycle since we can't fit large packets in a single cycle
   localparam WORD_CNT_WIDTH  = 10; // 2^10 = 1024 [0..1023]
   localparam BYTE_CNT_WIDTH  = 12; // 2^12 = 4096 [0..4095]

   localparam DELTA_WIDTH = BYTE_CNT_WIDTH + 1;

   // States
   localparam RESET = 0;
   localparam NORMAL = 1;


   // ------------- Wires/reg ------------------

   // Register file and related registers
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file [0:NUM_REGS_USED-1];

   reg [`CPCI_NF2_DATA_WIDTH-1:0]      reg_file_in;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]     reg_file_out;

   reg                                 reg_file_wr;
   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_file_addr;



   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg_nxt;

   wire [REG_FILE_ADDR_WIDTH-1:0]      addr;

   wire                                addr_good;

   reg [3:0]                           reset_long;

   reg                                 reg_req_d1;


   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_cnt;
   reg [REG_FILE_ADDR_WIDTH-1:0]       reg_cnt_nxt;


   reg                                 state;
   reg                                 state_nxt;

   // Signals for temporarily storing the deltas for the registers
   reg                                 ingress_pkt_cnt_delta;
   reg [BYTE_CNT_WIDTH-1:0]            ingress_byte_cnt_delta;

   reg                                 egress_pkt_cnt_delta;
   reg [BYTE_CNT_WIDTH-1:0]            egress_byte_cnt_delta;

   reg                                 timeout_cnt_delta;

   wire                                new_reg_req;

   reg [DELTA_WIDTH-1:0]               delta;

   wire                                iface_reset_internal;

   reg [31:0]                          iface_reset_internal_extend;

   // -------------------------------------------
   // Register file RAM
   // -------------------------------------------

   always @(posedge clk) begin
      if (reg_file_wr)
         reg_file[reg_file_addr] <= reg_file_in;
   end

   assign reg_file_out = reg_file[reg_file_addr];


   // -------------- Logic --------------------

   // Track the deltas
   //
   // These are committed later to the register file
   always @(posedge clk) begin
      if (reset)
         ingress_pkt_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `DMA_NUM_INGRESS_PKTS)
         ingress_pkt_cnt_delta <= pkt_ingress;
      else
         ingress_pkt_cnt_delta <= ingress_pkt_cnt_delta  || pkt_ingress;


      if (reset)
         ingress_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `DMA_NUM_INGRESS_BYTES)
         ingress_byte_cnt_delta <= pkt_ingress ? pkt_len : 'h0;
      else if (pkt_ingress)
         ingress_byte_cnt_delta <= ingress_byte_cnt_delta + pkt_len;


      if (reset)
         egress_pkt_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `DMA_NUM_EGRESS_PKTS)
         egress_pkt_cnt_delta <= pkt_egress;
      else
         egress_pkt_cnt_delta <= egress_pkt_cnt_delta  || pkt_egress;


      if (reset)
         egress_byte_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `DMA_NUM_EGRESS_BYTES)
         egress_byte_cnt_delta <= pkt_egress ? pkt_len : 'h0;
      else if (pkt_egress)
         egress_byte_cnt_delta <= egress_byte_cnt_delta + pkt_len;


      if (reset)
         timeout_cnt_delta <= 'h0;
      else if (!new_reg_req && reg_cnt == `DMA_NUM_TIMEOUTS)
         timeout_cnt_delta <= timeout;
      else
         timeout_cnt_delta <= timeout_cnt_delta || timeout;

   end // always block for delta logic

   //assign control_reg = reg_file[`DMA_CTRL];
   assign iface_disable       = control_reg[`DMA_IFACE_CTRL_DISABLE_POS];
   assign iface_reset_internal= control_reg[`DMA_IFACE_CTRL_RESET_POS];

   assign addr                = reg_addr[REG_FILE_ADDR_WIDTH-1:0];
   assign addr_good           = reg_addr[`DMA_REG_ADDR_WIDTH-1:REG_FILE_ADDR_WIDTH] == 'h0 &&
                                          addr < NUM_REGS_USED;

   assign new_reg_req         = reg_req && !reg_req_d1;

   // Reset logic
   always @(posedge clk) begin
      if (reset)
         iface_reset_internal_extend <= 'h0;
      else
         iface_reset_internal_extend <= {iface_reset_internal_extend[30:0], iface_reset_internal};
   end

   assign iface_reset = |iface_reset_internal_extend;


   // Main state machine
   always @*
   begin
      // Set the defaults
      state_nxt = state;
      control_reg_nxt = control_reg;
      control_reg_nxt[`DMA_IFACE_CTRL_RESET_POS] = 1'b0;
      reg_file_in = reg_file_out;
      reg_cnt_nxt = reg_cnt;
      reg_file_addr = 'h0;
      reg_file_wr = 1'b0;
      delta = 1'b0;


      if (reset) begin
         state_nxt = RESET;
         reg_cnt_nxt = 'h0;
         reg_file_in = 'h0;
         reg_file_addr = 'h0;
         control_reg_nxt = 'h0;
      end
      else begin
         case (state)
            RESET : begin
               if (reg_cnt == NUM_REGS_USED - 1) begin
                  state_nxt = NORMAL;
                  reg_cnt_nxt = 'h0;
               end
               else
                  reg_cnt_nxt = reg_cnt + 'h1;

               reg_file_in = 'h0;
               reg_file_wr = 1'b1;
               reg_file_addr = reg_cnt;
            end

            NORMAL : begin
               if(new_reg_req) begin // read request
                  reg_file_addr = addr;
                  reg_file_wr = addr_good && !reg_rd_wr_L;
                  reg_file_in = reg_wr_data;

                  if (addr == `DMA_CTRL) begin
                     if (!reg_rd_wr_L)
                        control_reg_nxt = reg_wr_data;
                  end
                  // The following code does reset on read
                  //
                  //reg_file_wr = addr_good;

                  //if (addr == `DMA_CTRL) begin
                  //   if (reg_rd_wr_L)
                  //      reg_file_in = reg_file_out;
                  //   else begin
                  //      reg_file_in = reg_wr_data;
                  //      control_reg_nxt = reg_wr_data;
                  //   end
                  //end
                  //else
                  //   reg_file_in = 'h0;
               end
               else begin
                  reg_file_wr = 1'b1;
                  reg_file_addr = reg_cnt;

                  if (reg_cnt == NUM_REGS_USED - 1)
                     reg_cnt_nxt = 'h0;
                  else
                     reg_cnt_nxt = reg_cnt + 'h1;

                  case (reg_cnt)
                     `DMA_CTRL :    delta = 0;
                     `DMA_NUM_INGRESS_PKTS:  delta = ingress_pkt_cnt_delta;
                     `DMA_NUM_INGRESS_BYTES: delta = ingress_byte_cnt_delta;
                     `DMA_NUM_EGRESS_PKTS:   delta = egress_pkt_cnt_delta;
                     `DMA_NUM_EGRESS_BYTES:  delta = egress_byte_cnt_delta;
                     `DMA_NUM_TIMEOUTS:      delta = timeout_cnt_delta;
                     default :               delta = 0;
                  endcase // case (reg_cnt)

                  reg_file_in = reg_file_out + {{(`CPCI_NF2_DATA_WIDTH - DELTA_WIDTH){delta[DELTA_WIDTH-1]}}, delta};
               end // if () else
            end // NORMAL

         endcase // case (state)
      end
   end

   always @(posedge clk) begin
      state       <= state_nxt;
      reg_cnt     <= reg_cnt_nxt;
      reg_req_d1  <= reg_req;
      control_reg <= control_reg_nxt;

      if( reset ) begin
         reg_rd_data  <= 0;
         reg_ack      <= 0;
      end
      else begin
         // Register access logic
         if(new_reg_req) begin // read request
            if(addr_good) begin
               if (addr == `DMA_CTRL)
                  reg_rd_data <= control_reg;
               else
                  reg_rd_data <= reg_file_out;
            end
            else begin
               reg_rd_data <= 32'hdead_beef;
            end
         end

         // requests complete after one cycle
         reg_ack <= new_reg_req;
      end // else: !if( reset )
   end // always @ (posedge clk)

endmodule // nf2_dma_regs
