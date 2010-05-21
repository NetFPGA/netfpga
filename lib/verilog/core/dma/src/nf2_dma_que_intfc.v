///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_dma_que_intfc.v 6061 2010-04-01 20:53:23Z grg $
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: nf2_dma_que_intfc.v
// Project: NetFPGA-1G
// Description: DMA interface to CPU queues
//
// Acts as a MUX/DEMUX between the DMA interface and the CPU queues.
//
// WARNING: Directions TX/RX are relative to the *host* in this module.
//          This is different to most other modules.
//
/////////////////////////////////////////////////////////////////////////
//
// txfifo_rd_data includes:
//  1 bit. 1'b 0 for "data format"; 1'b 1 for "req format"
//  1 bit. EOP in "data format". 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//         in "req format", 1'b 0 for "dma tx", 1'b 1 for "dma rx"
//  2 bits. bytecnt in "data format". 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
//          always 2'b 00 in "req format"
// 32 bits. pkt data in "data format".
//         {28'b 0, 4-bits queue_id} in "req format"
//
// rxfifo_wr_data includes:
//  1 bit. EOP. 1'b 1 indicates the last pkt word.
//         1'b 0 indicates this is not the last pkt word.
//  2 bits. bytecnt. 2'b 00: 4 bytes; 2'b 01: 1 byte;
//          2'b 10: 2 bytes; 2'b 11: 3 bytes.
// 32 bits. pkt data .
//
//////////////////////////////////////////////////////////////////


module nf2_dma_que_intfc
  #(
      parameter NUM_CPU_QUEUES         = 4,
      parameter DMA_DATA_WIDTH         = 32,
      parameter DMA_CTRL_WIDTH         = DMA_DATA_WIDTH/8,
      parameter USER_DATA_PATH_WIDTH   = 64,
      parameter CPCI_NF2_DATA_WIDTH    = 32
   )
   (
      // ---- signals to/from CPU rx queue 0
      output                           cpu_q_dma_rd_0,
      input [DMA_DATA_WIDTH-1:0]       cpu_q_dma_rd_data_0,
      input [DMA_CTRL_WIDTH-1:0]       cpu_q_dma_rd_ctrl_0,

      // ---- signals to/from CPU rx queue 1
      output                           cpu_q_dma_rd_1,
      input [DMA_DATA_WIDTH-1:0]       cpu_q_dma_rd_data_1,
      input [DMA_CTRL_WIDTH-1:0]       cpu_q_dma_rd_ctrl_1,

      // ---- signals to/from CPU rx queue 2
      output                           cpu_q_dma_rd_2,
      input [DMA_DATA_WIDTH-1:0]       cpu_q_dma_rd_data_2,
      input [DMA_CTRL_WIDTH-1:0]       cpu_q_dma_rd_ctrl_2,

      // ---- signals to/from CPU rx queue 3
      output                           cpu_q_dma_rd_3,
      input [DMA_DATA_WIDTH-1:0]       cpu_q_dma_rd_data_3,
      input [DMA_CTRL_WIDTH-1:0]       cpu_q_dma_rd_ctrl_3,

      // signals to/from CPU tx queues
      input [NUM_CPU_QUEUES-1:0]       cpu_q_dma_nearly_full,

      // signals to/from CPU tx queue 0
      output reg                       cpu_q_dma_wr_0,
      output reg                       cpu_q_dma_wr_pkt_vld_0,
      output reg [DMA_DATA_WIDTH-1:0]  cpu_q_dma_wr_data_0,
      output reg [DMA_CTRL_WIDTH-1:0]  cpu_q_dma_wr_ctrl_0,

      // signals to/from CPU tx queue 1
      output reg                       cpu_q_dma_wr_1,
      output reg                       cpu_q_dma_wr_pkt_vld_1,
      output reg [DMA_DATA_WIDTH-1:0]  cpu_q_dma_wr_data_1,
      output reg [DMA_CTRL_WIDTH-1:0]  cpu_q_dma_wr_ctrl_1,

      // signals to/from CPU tx queue 2
      output reg                       cpu_q_dma_wr_2,
      output reg                       cpu_q_dma_wr_pkt_vld_2,
      output reg [DMA_DATA_WIDTH-1:0]  cpu_q_dma_wr_data_2,
      output reg [DMA_CTRL_WIDTH-1:0]  cpu_q_dma_wr_ctrl_2,

      // signals to/from CPU tx queue 3
      output reg                       cpu_q_dma_wr_3,
      output reg                       cpu_q_dma_wr_pkt_vld_3,
      output reg [DMA_DATA_WIDTH-1:0]  cpu_q_dma_wr_data_3,
      output reg [DMA_CTRL_WIDTH-1:0]  cpu_q_dma_wr_ctrl_3,

      // --- signals to/from nf2_dma_sync
      input                            txfifo_empty,
      input                            txfifo_rd_is_req,
      input                            txfifo_rd_pkt_vld,
      input                            txfifo_rd_type_eop,
      input [1:0]                      txfifo_rd_valid_bytes,
      input [DMA_DATA_WIDTH-1:0]       txfifo_rd_data,
      output reg                       txfifo_rd_inc,

      input                            rxfifo_full,
      input                            rxfifo_nearly_full,
      output reg                       rxfifo_wr,
      output reg                       rxfifo_wr_eop,
      output reg [1:0]                 rxfifo_wr_valid_bytes,
      output reg [DMA_DATA_WIDTH-1:0]  rxfifo_wr_data,

      // register update signals
      output reg                       pkt_ingress,
      output reg                       pkt_egress,
      output reg [11:0]                pkt_len,

      //--- misc
      input                            enable_dma,
      input                            reset,
      input                            clk
   );

   reg [3:0] queue_id, queue_id_nxt;

   reg [DMA_DATA_WIDTH-1:0]    dma_wr_pkt_vld;
   reg [DMA_DATA_WIDTH-1:0]    dma_wr_data;
   reg [DMA_CTRL_WIDTH-1:0]    dma_wr_ctrl;
   reg                         dma_rd_vld, dma_rd_vld_nxt;
   wire [DMA_DATA_WIDTH-1:0]    dma_rd_data;
   wire [DMA_CTRL_WIDTH-1:0]    dma_rd_ctrl;

   reg                         cpu_q_dma_wr_nxt[0:NUM_CPU_QUEUES-1];
   reg                         cpu_q_dma_wr_pkt_vld_nxt[0:NUM_CPU_QUEUES-1];
   reg [DMA_DATA_WIDTH-1:0]    cpu_q_dma_wr_data_nxt[0:NUM_CPU_QUEUES-1];
   reg [DMA_CTRL_WIDTH-1:0]    cpu_q_dma_wr_ctrl_nxt[0:NUM_CPU_QUEUES-1];

   reg  cpu_q_dma_rd[0:NUM_CPU_QUEUES-1];
   wire [DMA_DATA_WIDTH-1:0] cpu_q_dma_rd_data[0:NUM_CPU_QUEUES-1];
   wire [DMA_CTRL_WIDTH-1:0] cpu_q_dma_rd_ctrl[0:NUM_CPU_QUEUES-1];
   wire [3:0] queue_decoded;
   reg [3:0] queue_sel_nxt;
   reg [3:0] queue_sel;

   reg first_word;
   reg first_word_nxt;

   reg         pkt_ingress_nxt;
   reg         pkt_egress_nxt;
   reg [11:0]  pkt_len_nxt;

   reg [1:0] state, state_nxt;
   parameter IDLE_STATE = 2'h 0,
             TX_STATE = 2'h 1,
             RX_STATE = 2'h 2;

   localparam
      DMA_WORD_IS_DATA = 1'b0,
      DMA_WORD_IS_REQ = 1'b1,
      XFER_NOT_EOP = 1'b0,
      XFER_EOP = 1'b1,
      DMA_TX_REQ = 1'b0,
      DMA_RX_REQ = 1'b1;

   assign queue_decoded = 4'b1 << txfifo_rd_data[1:0];

   assign dma_rd_data = cpu_q_dma_rd_data[queue_id];
   assign dma_rd_ctrl = cpu_q_dma_rd_ctrl[queue_id];
   integer i;

   assign cpu_q_dma_rd_0 = cpu_q_dma_rd[0];
   assign cpu_q_dma_rd_1 = cpu_q_dma_rd[1];
   assign cpu_q_dma_rd_2 = cpu_q_dma_rd[2];
   assign cpu_q_dma_rd_3 = cpu_q_dma_rd[3];

   assign cpu_q_dma_rd_data[0] = cpu_q_dma_rd_data_0;
   assign cpu_q_dma_rd_data[1] = cpu_q_dma_rd_data_1;
   assign cpu_q_dma_rd_data[2] = cpu_q_dma_rd_data_2;
   assign cpu_q_dma_rd_data[3] = cpu_q_dma_rd_data_3;

   assign cpu_q_dma_rd_ctrl[0] = cpu_q_dma_rd_ctrl_0;
   assign cpu_q_dma_rd_ctrl[1] = cpu_q_dma_rd_ctrl_1;
   assign cpu_q_dma_rd_ctrl[2] = cpu_q_dma_rd_ctrl_2;
   assign cpu_q_dma_rd_ctrl[3] = cpu_q_dma_rd_ctrl_3;

   always @(*) begin
      state_nxt = state;
      queue_id_nxt = queue_id;
      queue_sel_nxt = queue_sel;
      dma_rd_vld_nxt = 1'b 0;

      txfifo_rd_inc = 1'b 0;

      dma_wr_ctrl = 'h 0;
      dma_wr_data = 'h 0;

      for (i = 0; i < NUM_CPU_QUEUES; i = i + 1) begin
         cpu_q_dma_wr_nxt[i] = 1'b 0;
         cpu_q_dma_wr_pkt_vld_nxt[i] = 1'b 0;
         cpu_q_dma_wr_data_nxt[i] = 'h 0;
         cpu_q_dma_wr_ctrl_nxt[i] = 'h 0;

         cpu_q_dma_rd[i] = 1'b 0;
      end

      rxfifo_wr = 1'b 0;
      rxfifo_wr_eop = 0;
      rxfifo_wr_valid_bytes = 'h 0;
      rxfifo_wr_data = 'h 0;

      first_word_nxt = first_word;
      pkt_ingress_nxt = 0;
      pkt_egress_nxt = 0;
      pkt_len_nxt = pkt_len;

      case (state)
         IDLE_STATE: begin
            if (enable_dma) begin
               if (! txfifo_empty) begin
                  txfifo_rd_inc = 1'b 1;

                  // Identify if the word is data or a request
                  // (it should be a request)
                  case (txfifo_rd_is_req)
                     DMA_WORD_IS_DATA: begin
                        //synthesis translate_off

                        // Don't display an error message immediately as we may
                        // have seen the transition on the empty signal before the
                        // data signal has transitioned
                        #1 if (txfifo_rd_is_req) begin
                           $display("%t %m ERROR: expect req format, but got data format!", $time);
                        end
                        //synthesis translate_on
                     end

                     DMA_WORD_IS_REQ: begin
                        queue_id_nxt = txfifo_rd_data;
                        queue_sel_nxt = queue_decoded;

                        first_word_nxt = 1'b1;

                        // Identify Rx/Tx
                        case (txfifo_rd_type_eop)
                           DMA_TX_REQ: state_nxt = TX_STATE;
                           DMA_RX_REQ: state_nxt = RX_STATE;
                        endcase // case(txfifo_rd_type_eop)

                     end // case: 1'b 1

                  endcase // case(txfifo_rd_is_req)

               end // if (! txfifo_empty)
            end // if (enable_dma)
         end // IDLE_STATE

         TX_STATE: begin
            if (! txfifo_empty) begin
               if (first_word) begin
                  first_word_nxt = 1'b0;
                  pkt_len_nxt = txfifo_rd_data;
               end

               case (txfifo_rd_type_eop)
                  XFER_NOT_EOP: dma_wr_ctrl = 'b 0;

                  XFER_EOP: begin
                     // Calculate the CTRL word for the EOP
                     case (txfifo_rd_valid_bytes)
                        2'b 00: dma_wr_ctrl = 'b 1000;
                        2'b 01: dma_wr_ctrl = 'b 0001;
                        2'b 10: dma_wr_ctrl = 'b 0010;
                        2'b 11: dma_wr_ctrl = 'b 0100;
                     endcase //case(txfifo_rd_valid_bytes)
                  end // case: 1'b 1
               endcase // case(txfifo_rd_type_eop)

               dma_wr_pkt_vld = txfifo_rd_pkt_vld;
               dma_wr_data = txfifo_rd_data;

               if (queue_sel != 'h0) begin
                  if ((cpu_q_dma_nearly_full & queue_sel) == 'h0) begin
                     cpu_q_dma_wr_nxt[queue_id] = 1'b 1;
                     cpu_q_dma_wr_pkt_vld_nxt[queue_id] = dma_wr_pkt_vld;
                     cpu_q_dma_wr_data_nxt[queue_id] = dma_wr_data;
                     cpu_q_dma_wr_ctrl_nxt[queue_id] = dma_wr_ctrl;

                     txfifo_rd_inc = 1'b 1;
                     if (| dma_wr_ctrl) begin
                        state_nxt = IDLE_STATE;
                        pkt_ingress_nxt = 1'b1;
                     end
                  end
               end
               else begin
                  // unknown queue_id. dequeue the pkt data anyway.
                  txfifo_rd_inc = 1'b 1;
                  if (| dma_wr_ctrl) 
                     state_nxt = IDLE_STATE;
               end

            end // if (! txfifo_empty)
         end // TX_STATE

      RX_STATE: begin

         if (!rxfifo_nearly_full) begin
            // note that cpu queues are fall-thru queues.
            // So data are available now
            cpu_q_dma_rd[queue_id] = 1'b1;

            rxfifo_wr = 1'b 1;
            rxfifo_wr_data = dma_rd_data;

            if (first_word) begin
               first_word_nxt = 1'b0;
               pkt_len_nxt = dma_rd_data;
            end

            if (dma_rd_ctrl == 'h 0) begin
               //not EOP
               rxfifo_wr_eop=1'b 0;
               rxfifo_wr_valid_bytes=2'b 0;
            end
            else begin
               //EOP
               rxfifo_wr_eop=1'b 1;

               // data is in little endian: [7:0] is the first byte.
               case (dma_rd_ctrl)
                  'b 0001: rxfifo_wr_valid_bytes=2'h 1;
                  'b 0010: rxfifo_wr_valid_bytes=2'h 2;
                  'b 0100: rxfifo_wr_valid_bytes=2'h 3;
                  'b 1000: rxfifo_wr_valid_bytes=2'h 0;
                  default: rxfifo_wr_valid_bytes=2'h 0;
               endcase // case(dma_rd_ctrl)

               state_nxt = IDLE_STATE;

               pkt_egress_nxt = 1'b1;
            end // else: !if(dma_rd_ctrl == 'h 0)

         end // if (!rxfifo_nearly_full)

      end // case: RX_STATE

      endcase // case(state)

   end // always @ (*)

   always @(posedge clk) begin
     if (reset) begin
        state <= IDLE_STATE;

        queue_id <= 'h 0;
        queue_sel <= 'h 0;
        dma_rd_vld <= 'h 0;


        cpu_q_dma_wr_0 <= 1'b 0;
        cpu_q_dma_wr_data_0 <= 'h 0;
        cpu_q_dma_wr_ctrl_0 <= 'h 0;

        cpu_q_dma_wr_1 <= 1'b 0;
        cpu_q_dma_wr_data_1 <= 'h 0;
        cpu_q_dma_wr_ctrl_1 <= 'h 0;

        cpu_q_dma_wr_2 <= 1'b 0;
        cpu_q_dma_wr_data_2 <= 'h 0;
        cpu_q_dma_wr_ctrl_2 <= 'h 0;

        cpu_q_dma_wr_3 <= 1'b 0;
        cpu_q_dma_wr_data_3 <= 'h 0;
        cpu_q_dma_wr_ctrl_3 <= 'h 0;

        first_word <= 1'b1;

        pkt_ingress <= 1'b0;
        pkt_egress <= 1'b0;
        pkt_len <= 1'b0;
     end
     else begin
        state <= state_nxt;

        queue_id <= queue_id_nxt;
        queue_sel <= queue_sel_nxt;
        dma_rd_vld <= dma_rd_vld_nxt;


        cpu_q_dma_wr_0 <= cpu_q_dma_wr_nxt[0];
        cpu_q_dma_wr_pkt_vld_0 <= cpu_q_dma_wr_pkt_vld_nxt[0];
        cpu_q_dma_wr_data_0 <= cpu_q_dma_wr_data_nxt[0];
        cpu_q_dma_wr_ctrl_0 <= cpu_q_dma_wr_ctrl_nxt[0];

        cpu_q_dma_wr_1 <= cpu_q_dma_wr_nxt[1];
        cpu_q_dma_wr_pkt_vld_1 <= cpu_q_dma_wr_pkt_vld_nxt[1];
        cpu_q_dma_wr_data_1 <= cpu_q_dma_wr_data_nxt[1];
        cpu_q_dma_wr_ctrl_1 <= cpu_q_dma_wr_ctrl_nxt[1];

        cpu_q_dma_wr_2 <= cpu_q_dma_wr_nxt[2];
        cpu_q_dma_wr_pkt_vld_2 <= cpu_q_dma_wr_pkt_vld_nxt[2];
        cpu_q_dma_wr_data_2 <= cpu_q_dma_wr_data_nxt[2];
        cpu_q_dma_wr_ctrl_2 <= cpu_q_dma_wr_ctrl_nxt[2];

        cpu_q_dma_wr_3 <= cpu_q_dma_wr_nxt[3];
        cpu_q_dma_wr_pkt_vld_3 <= cpu_q_dma_wr_pkt_vld_nxt[3];
        cpu_q_dma_wr_data_3 <= cpu_q_dma_wr_data_nxt[3];
        cpu_q_dma_wr_ctrl_3 <= cpu_q_dma_wr_ctrl_nxt[3];

        first_word <= first_word_nxt;

        pkt_ingress <= pkt_ingress_nxt;
        pkt_egress <= pkt_egress_nxt;
        pkt_len <= pkt_len_nxt;
     end
   end // always @ (posedge clk)

endmodule // nf2_dma_que_intfc
