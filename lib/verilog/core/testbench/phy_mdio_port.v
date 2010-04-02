///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_mdio_port.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: phy_mdio_port.v
// Project: NetFPGA
// Description: Simple MDIO interface simulator
//
// Stores values on writes
// Returns most recent value on read
//
///////////////////////////////////////////////////////////////////////////////

module phy_mdio_port
   (
      inout             mdio,
      input             mdc
   );

   // Define storage size
   parameter PHY_CNT = 4;
   parameter REG_ADDR_BITS = 5;
   localparam REG_SIZE = 1 << (REG_ADDR_BITS - 1);


   // States to keep track of where we are
   localparam PREAMBLE        = 0;
   localparam START           = 1;
   localparam OP              = 2;
   localparam PHY_ADDR        = 3;
   localparam REG_ADDR        = 4;
   localparam TA              = 5;
   localparam READ_PRE        = 6;
   localparam READ            = 7;
   localparam READ_DONE       = 8;
   localparam WRITE_PRE       = 9;
   localparam WRITE           = 10;
   localparam WRITE_DONE      = 11;
   localparam HOLD            = 12;

   // Storage for all words written
   reg [15:0] regfile [REG_SIZE * PHY_CNT - 1 : 0];



   reg mdio_wr;
   reg mdio_tri_en;

   reg seen_preamble;
   integer preamble_cnt;
   integer cnt;
   reg [1:0] op;
   reg [4:0] phy;
   reg [4:0] addr;

   reg [15:0] curr_data;

   reg [3:0] state;


   // Tri-state enable
   assign mdio = mdio_tri_en ? mdio_wr : 1'bz;

   initial
   begin
      seen_preamble = 1'b0;
      preamble_cnt = 0;
      state = PREAMBLE;
      mdio_tri_en = 1'b0;
      mdio_wr = 1'b0;
   end

   always @(posedge mdc)
   begin
      case (state)
         PREAMBLE : begin
            if (mdio === 1'b1) begin
               if (preamble_cnt < 32)
                  preamble_cnt <= preamble_cnt + 1;
            end
            else if (mdio === 1'b0) begin
               if (preamble_cnt >= 32)
                  state <= START;
               else
                  $display($time, " %m: ERROR: Insufficient preamble bits (%d) before operation", preamble_cnt);
            end
            else
               preamble_cnt <= 0;
         end

         START : begin
            if (mdio == 1'b1) begin
               state <= OP;
               cnt <= 0;
            end
            else begin
               $display($time, " %m: ERROR: Start command invalid");
               state <= HOLD;
            end
         end

         OP : begin
            if (cnt == 1) begin
               state <= PHY_ADDR;
               cnt <= 0;
            end
            else
               cnt <= cnt + 1;

            op = {op[0], mdio};
         end

         PHY_ADDR : begin
            if (cnt == 4) begin
               state <= REG_ADDR;
               cnt <= 0;
            end
            else
               cnt <= cnt + 1;

            phy = {phy[3:0], mdio};
         end


         REG_ADDR : begin
            if (cnt == 4) begin
               state <= TA;
               cnt <= 0;
            end
            else
               cnt <= cnt + 1;

            addr = {addr[3:0], mdio};
         end

         TA : begin
            // Work out if this is a read or a write
            if (op == 2'b10) begin
               curr_data <= regfile[(phy << 5) + addr];
               state <= READ_PRE;
               mdio_tri_en <= 1'b1;
               mdio_wr <= 1'b0;
            end
            else if (op == 2'b01) begin
               state <= WRITE_PRE;
            end
            else begin
               $display($time, " %m: ERROR: Invalid op: %02b  (phy: %02x  addr: %02x)", op, phy, addr);
               state <= HOLD;
            end
         end

         READ_PRE : begin
            state <= READ;
            mdio_wr <= curr_data[15];
            curr_data = {curr_data[14:0], 1'b0};
            cnt <= 0;
         end

         READ : begin
            if (cnt == 15)
               state <= READ_DONE;
            else
               state <= READ;

            mdio_wr <= curr_data[15];
            curr_data = {curr_data[14:0], 1'b0};
            cnt <= cnt + 1;
         end

         READ_DONE : begin
            mdio_tri_en <= 1'b0;
            state <= PREAMBLE;
            $display($time, "%m: INFO: Read %04x from %02x of phy %02x", regfile[(phy << 5) + addr], addr, phy);
         end

         WRITE_PRE : begin
            state <= WRITE;
            cnt <= 0;
         end

         WRITE : begin
            if (cnt == 15)
               state <= WRITE_DONE;
            else
               state <= WRITE;

            curr_data = {curr_data[14:0], mdio};
            cnt <= cnt + 1;
         end

         WRITE_DONE : begin
            state <= PREAMBLE;
            regfile[(phy << 5) + addr] <= curr_data;
            $display($time, "%m: INFO: Wrote %04x to %02x of phy %02x", curr_data, addr, phy);
         end

         HOLD : begin
            state <= HOLD;
         end
      endcase
   end

endmodule // phy_mdio_port

