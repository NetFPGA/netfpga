///////////////////////////////////////////////////////////////////////////////
// $Id: cnet.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: cnet.v
// Project: CPCI (PCI Control FPGA)
// Description: Emulates the programming interface of the CNET
//
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////


module cnet(
            // Interface to the CNET
            input          rp_prog_b,
            output         rp_init_b,
            input          rp_cs_b,
            input          rp_rdwr_b,
            input [7:0]    rp_data,
            output         rp_done,

            input          want_crc_error,

            input          rp_cclk
         );


// ==================================================================
// Local
// ==================================================================

`define PROG_B_CNT      10 - 1
`define INIT_B_CNT      10 - 1
//`define PROG_BYTE_CNT   16
`define PROG_BYTE_CNT   362185 * 4

`define OUTBITSTREAM    "bitstream.out"

integer        i, i_nxt;

reg            rdwr, rdwr_nxt;
integer        prog_cnt, prog_cnt_nxt;

integer        fd = 0;
integer        count;

wire [7:0]     data;

reg [31:0]     prog_word;

// ==================================================================
// State machine to emulate programming
// ==================================================================

reg [2:0] curr_state, curr_state_nxt;

`define  IDLE        3'h0
`define  PROG_B      3'h1
`define  INIT_B      3'h2
`define  PROG        3'h3
`define  EMPTY       3'h4

always @(posedge rp_cclk)
begin
   curr_state <= curr_state_nxt;
   i <= i_nxt;
   prog_cnt <= prog_cnt_nxt;
   rdwr <= rdwr_nxt;
end

// ==================================================================
// Open a file for output
// ==================================================================
always @(posedge rp_cclk)
begin
   if (curr_state == `PROG && !rp_cs_b)
   begin
      case (count)
         0 :   begin
                  prog_word[7:0] = data;
               end
         1 :   begin
                  prog_word[15:8] = data;
               end
         2 :   begin
                  prog_word[23:16] = data;
               end
         3 :   begin
                  prog_word[31:24] = data;
               end
      endcase
      count = count + 1;
      if (count == 4)
      begin
         count = 0;
         $fdisplay(fd, "%08x", prog_word);
      end
   end

   if (curr_state == `PROG_B && curr_state_nxt == `INIT_B)
   begin
      if (fd != 0)
         $fclose(fd);
      count = 0;
      fd = $fopen(`OUTBITSTREAM);
   end
end

always @(posedge rp_cclk)
begin
   if (curr_state != `PROG && curr_state_nxt == `PROG && rp_rdwr_b)
      $display($time, " WARNING: The current version of the CNET programming interface module doesn't support reads");
end

always @*
begin
   curr_state_nxt = curr_state;
   i_nxt = (i > 0) ? i - 1 : 0;
   prog_cnt_nxt = prog_cnt;
   rdwr_nxt = rdwr;

   case (curr_state)
      `IDLE : begin
         if (!rp_prog_b) begin
            curr_state_nxt = `PROG_B;
            i_nxt = `PROG_B_CNT;
         end
      end

      `PROG_B : begin
         if (rp_prog_b)
            if (i == 0) begin
               curr_state_nxt = `INIT_B;
               i_nxt = `INIT_B_CNT;
            end
            else
               $display($time, " ERROR: rp_prog_b was de-asserted too early, i=%d", i);
      end

      `INIT_B : begin
         if (!rp_prog_b) begin
            curr_state_nxt = `PROG_B;
            i_nxt = `PROG_B_CNT;
         end
         else if (i == 0) begin
            curr_state_nxt = `PROG;
            prog_cnt_nxt = `PROG_BYTE_CNT;
            rdwr_nxt = rp_rdwr_b;
         end
      end

      `PROG : begin
         if (!rp_prog_b) begin
            curr_state_nxt = `PROG_B;
            i_nxt = `PROG_B_CNT;
         end
         else if (!rp_cs_b) begin
            if (rdwr != rp_rdwr_b)
               $display($time, " ERROR: RP_RDWR_B should not be changed during read/write");
            prog_cnt_nxt = prog_cnt - 1;
            if (want_crc_error) begin
               curr_state_nxt = `INIT_B;
               i_nxt = `INIT_B_CNT;
            end
            else if (prog_cnt_nxt == 0)
               curr_state_nxt = `IDLE;
         end
      end

      `EMPTY : begin
         if (i == 0) begin
            curr_state_nxt = `INIT_B;
            i_nxt = `INIT_B_CNT;
         end
      end

      default : begin
         curr_state_nxt = `IDLE;
      end
   endcase
end

initial
begin
   // Reset the device
   curr_state = `EMPTY;
   i = `PROG_B_CNT;
end

// ==================================================================
// Miscelaneous signal generation
// ==================================================================

assign #1 rp_init_b = !(curr_state == `PROG_B || curr_state == `INIT_B);
assign #1 rp_done = curr_state == `IDLE;

assign data = {rp_data[0],
               rp_data[1],
               rp_data[2],
               rp_data[3],
               rp_data[4],
               rp_data[5],
               rp_data[6],
               rp_data[7]};

endmodule // cnet

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
