// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_mdio.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: nf2_mdio.v
// Project: NetFPGA-1G
// Description: Handles read/writes to the external quad PHY device.
//
// Implements the MDC/MDIO protocol defined in
// the IEEE 802.3-2002 specification Section 22.2.4.5.
//
// This assumes that the PHY can operate with Preamble suppression (no preamble).
//
// The transaction appears at the pins as:
//
//         Start  Opcode Phy_Addr Reg_Addr  Turn_Around  Data16
//        2 bits  2 bits  5 bits   5 bits    2 bits      16 bits
// READ:   0 1     1 0    bbbbb    bbbbb     Z 0         bbbb...bbbb
// WRITE:  0 1     0 1    bbbbb    bbbbb     1 0         bbbb...bbbb
//
// Data is sampled on rising edge.
// Clock must be < 12.5MHz. Yes. less than twelve and a half megahertz!
//
// NOTE: Must assert phy_busy in the same cycle that a req is seen.
//       Hold phy_busy asserted until done.
//
//
//
// No address bits are used: there are only two registers, one write and one read.
//
// You write a command to the write register. The command is either a PHY write
// or a PHY read.
//
// If it's a PHY write then busy will be asserted and the write will occur.
//
// If it's a PHY read then busy is NOT asserted and the current read data will
//   be immediately returned. The top bit (bit 31) will be 1 if this data is
//     valid (i.e. the read command has completed).
//
// So, if it's a read you:
//   1. write a READ command to the write register.
//   2. Keep reading the read register until bit 31 is 1 whereupon
//      the actual read data is in 15:0.
//
// Format of the write command:
//
//   31:    0 = READ 1 = WRITE
//   25:24  PHY select (0-3)
//   20:16  Register Address [4:0]
//   15:0   Write Data.
//
//
//
// 3/08/2007 Modified by Jad Naous at Agilent to use the register interface
//
//



module nf2_mdio
  (
   input                                 phy_reg_req,
   input                                 phy_reg_rd_wr_L,
   output reg                            phy_reg_ack,
   input      [`MDIO_REG_ADDR_WIDTH-1:0] phy_reg_addr,
   output reg [`CPCI_NF2_DATA_WIDTH-1:0] phy_reg_rd_data,
   input      [`CPCI_NF2_DATA_WIDTH-1:0] phy_reg_wr_data,

   // --- pin outputs (and tri-enable)

   output reg phy_mdc,
   output     phy_mdata_out,
   output     phy_mdata_tri,
   input      phy_mdata_in,

   // --- Misc

   input reset,
   input clk

   );


   //----- Glue logic to translate from/to reg interface -------------
   localparam NUM_REGS_USED = 32*4;
   localparam GLUE_IDLE            = 0;
   localparam GLUE_WAIT_PHY_READ   = 1;
   localparam GLUE_WAIT_PHY_WRITE  = 2;
   localparam GLUE_WAIT_REQ        = 3;

   // --- Interface to nf2_rdwr

   reg        phy_busy;
   reg        phy_wr_req;
   reg        phy_rd_req;
   reg        phy_rd_vld;
   reg [31:0] phy_rd_data;
   reg [31:0] phy_wr_data;

   wire       addr_good = (phy_reg_addr < NUM_REGS_USED);
   wire [4:0] phy_addr  = phy_reg_addr[4:0];
   wire [1:0] phy_sel   = phy_reg_addr[6:5];

   reg [1:0]  glue_state;

   always @(posedge clk) begin

      if(reset) begin
         glue_state         <= GLUE_IDLE;
         phy_wr_req         <= 0;
         phy_rd_req         <= 0;
         phy_wr_data        <= 0;
         phy_reg_ack        <= 0;
         phy_reg_rd_data    <= 0;
      end

      else begin

         case(glue_state)

           GLUE_IDLE: begin
              if(phy_reg_req & !phy_busy) begin
                 if(addr_good) begin
                    phy_wr_req     <= 1'b1;
                    phy_rd_req     <= 0;
                    phy_wr_data    <= {!phy_reg_rd_wr_L,
                                       5'h0,
                                       phy_sel,
                                       3'h0,
                                       phy_addr,
                                       phy_reg_wr_data[15:0]};
                    phy_reg_ack    <= 0;
                    if(phy_reg_rd_wr_L) begin
                       glue_state       <= GLUE_WAIT_PHY_READ;
                    end
                    else begin
                       glue_state       <= GLUE_WAIT_PHY_WRITE;
                    end
                 end // if (addr_good)
                 else begin
                    phy_reg_rd_data <= 32'hDEAD_BEEF;
                    phy_reg_ack     <= 1;
                    glue_state      <= GLUE_WAIT_REQ;
                 end // else: !if(addr_good)
              end // if (phy_reg_req & !phy_busy)
              else begin
                 phy_wr_req      <= 0;
                 phy_rd_req      <= 0;
                 phy_reg_ack     <= 0;
              end
           end // case: GLUE_IDLE

           GLUE_WAIT_PHY_READ: begin
              phy_wr_req <= 0;

              if(!phy_reg_req) begin
                 glue_state <= GLUE_IDLE;
                 phy_rd_req <= 0;
              end
              else begin
                 if(!phy_busy) begin
                    phy_rd_req <= 1;
                 end


                 if(phy_rd_vld & phy_rd_data[31] & !phy_busy) begin
                    phy_reg_ack         <= 1;
                    phy_reg_rd_data     <= {16'h0, phy_rd_data[15:0]};
                    glue_state          <= GLUE_WAIT_REQ;
                 end
              end
           end // case: GLUE_WAIT_PHY_READ

           GLUE_WAIT_PHY_WRITE: begin
              phy_wr_req     <= 0;
              if(!phy_busy) begin
                 phy_reg_ack <= 1;
                 glue_state  <= GLUE_WAIT_REQ;
              end
           end

           GLUE_WAIT_REQ: begin
              phy_wr_req     <= 0;
              phy_rd_req     <= 0;
              phy_reg_ack    <= 0;
              if(!phy_reg_req) begin
                 glue_state <= GLUE_IDLE;
              end
           end

         endcase // case(glue_state)
      end // else: !if(reset)

   end // always @ (posedge clk)

//------------------------ Original logic -------------------------------

   // We need to run very sloooowly so generate a signal that does that.
   // This counts clocks to determine the rising edge and falling edge of MDC
   // In general make FALL_COUNT = 2*RISE_COUNT

   parameter RISE_COUNT = 5;
   parameter FALL_COUNT = 10;

   reg       mdc_rising, mdc_falling; // pulses. valid one clock only.
   reg [7:0] mdc_counter;


   // Note: Reset the MDC counter to 1 otherwise we end up with one extra
   // core clock being wasted
   always @(posedge clk)
      if (reset | (mdc_counter == FALL_COUNT))
         mdc_counter <= 1;
      else
         mdc_counter <= mdc_counter + 1;

   always @(posedge clk) begin
      mdc_rising  <=  (mdc_counter == RISE_COUNT);
      mdc_falling <=  (mdc_counter == FALL_COUNT);
      phy_mdc <= reset ? 0 : (mdc_rising ? 1 : (mdc_falling ? 0 : phy_mdc));
   end


   // State machine for command writes.
   // Most state transitions happen only on falling edge of MDC.

   reg ld_command, ld_tri;
   reg [31:0] wr_data;
   reg [31:0] wr_data_nxt;
   reg [4:0] cmd_counter;
   reg [1:0] state, state_nxt;
   reg [1:0] opcode;

   parameter IDLE = 0,
             START = 1,
             RUN = 2;

   parameter NONE = 0,
             WRITE = 1,
             READ  = 2;

   always @* begin

      // defaults
      phy_busy   = 1;
      state_nxt  = state;
      wr_data_nxt = wr_data;
      ld_command = 0;
      ld_tri     = 0;
      case (state)

        IDLE: begin
           if (phy_wr_req) begin

              phy_busy   = 1;
              wr_data_nxt = phy_wr_data;
              state_nxt  = START;

           end
           else
             phy_busy = 0;
        end

        START: begin
           if (mdc_falling) begin
              ld_tri = 1;
              ld_command = 1;
              state_nxt = RUN;
           end
        end

        RUN: begin
           if (mdc_falling && (cmd_counter == 'h0))
             state_nxt = IDLE;
        end

        default: begin
           // synthesis translate_off
           if ($time > 100 && !reset) $display("%t ERROR <%m> : state machine in illegal state 0x%x", $time,state);
           // synthesis translate_on
        end

      endcase

   end // always @ *

   always @(posedge clk) begin
      state <= reset ? IDLE : state_nxt;
      wr_data <= reset ? 'h0 : wr_data_nxt;
   end

   // load up the command register and tri_ctrl reg

   reg [31:0] cmd_reg, tri_ctrl;

   always @(posedge clk)
      if (reset)
         opcode <= NONE;
      else if (ld_command)
         opcode <= wr_data[31] ? WRITE : READ;
      else
         if (state == IDLE)
            opcode <= NONE;

   always @(posedge clk)
      if (reset)
         cmd_reg <= 'h0;
      else if (ld_command)
         cmd_reg <= {2'b01, wr_data[31] ? 2'b01 : 2'b10, 3'b000,
         //          start            rd/wr opcode
                     wr_data[25:24], wr_data[20:16], 2'b10, wr_data[15:0]};
         //            PHY (0-3)      Register Addr   TA     Data
      else if ((state == RUN) && mdc_falling)
         cmd_reg <= {cmd_reg[30:0],1'b0};

   // tri-state control
   always @(posedge clk)
      if (reset)
         tri_ctrl <= 'h0;
      else if (ld_tri)
         tri_ctrl <= wr_data[31] ? 32'hffff_ffff : 32'h fffc_0000;
      else if (mdc_falling)
         tri_ctrl <= {tri_ctrl[30:0],1'b0};

   // command reg counter
   always @(posedge clk)
      if (reset) cmd_counter <= 'h0;
      else begin
         if (ld_tri)
            cmd_counter <= 5'h1f;

         else if (mdc_falling)
            if (cmd_counter != 0)
               cmd_counter <= cmd_counter - 1;
      end

   always @(posedge clk) begin
      if (reset) begin
         phy_rd_vld  <= 0;
         phy_rd_data <= 'h0;
      end
      else begin
         phy_rd_vld  <= phy_rd_req;  // always ack immediately.
         if ((state == RUN) && (mdc_rising) && (opcode == READ) )
            phy_rd_data <= {1'b0, 11'b0, cmd_counter, phy_rd_data[14:0], phy_mdata_in};
         else if (state == IDLE)
            phy_rd_data <= {1'b1, phy_rd_data[30:0]};
         else if ((state == START) && (opcode == READ))
            phy_rd_data <= {1'b0, 11'b0, cmd_counter, 16'h0};
         else
            phy_rd_data <= {1'b0, phy_rd_data[30:0]};
      end
   end

   assign phy_mdata_out = cmd_reg[31];
   assign phy_mdata_tri = tri_ctrl[31];

endmodule // nf2_mdio

