///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpci_program_iface.v 1890 2007-07-02 20:38:18Z grg $
//
// Module: cpci_program_iface.v
// Project: CPCI reprogramming interface
// Description: Simulates the CPCI reprogramming interface
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ns

module cpci_program_iface
   (
      output reg  cpci_rp_done,
      output reg  cpci_rp_init_b,
      output reg  cpci_rp_cclk,

      input    cpci_rp_en,
      input    cpci_rp_prog_b,
      input    cpci_rp_din
   );

// Set the clock period to 4 MHz
parameter CCLK_PERIOD = 250;

// Minimum amout of time to hold prog_b low
parameter MIN_PROG_B_TIME = 300;

// ----- Reprogramming states -----
localparam IDLE         = 3'd0;
localparam PROG_B       = 3'd1;
localparam INIT_B       = 3'd2;
localparam PROGRAM      = 3'd3;
localparam ERROR        = 3'd7;


// Reprogramming clock
always #(CCLK_PERIOD / 2) cpci_rp_cclk = !cpci_rp_cclk;
initial begin cpci_rp_cclk = 0; end

reg [2:0] state;

time prog_b_start;

reg [7:0] count;
reg [7:0] byte;
reg [2:0] bit;

// ----- Main state machine -----

initial
begin
   cpci_rp_init_b = 1'b1;
   cpci_rp_done = 1'b1;

   state = IDLE;
end

always @(posedge cpci_rp_cclk)
begin
   case (state)
      IDLE : begin
         // Do nothing -- handled below
      end

      PROG_B : begin
         // Do nothing -- handled below
      end

      INIT_B : begin
         // Jump to program
         state <= PROGRAM;
         count <= 'h0;
         bit <= 'h0;
         cpci_rp_init_b = 1'b1;
      end

      PROGRAM : begin
         // Record the byte
         byte <= {byte[6:0], cpci_rp_din};
         bit <= bit + 'h1;

         if (bit == 'd7) begin
            if ({byte[6:0], cpci_rp_din} != count) begin
               $display($time, " Error: Incorrect data on din. Saw: %02x   Expected: %02x", {byte[6:0], cpci_rp_din}, count);
               state <= ERROR;
            end
            else begin
               if (count == 'd15) begin
                  state <= IDLE;
                  cpci_rp_done <= 1'b1;

                  $display($time, " CPCI reprogramming completed successfully");
               end
               count <= count + 'h1;
            end
         end
      end

      ERROR : begin
         // Sit here until prog_b is pulled low
      end

      default : begin
         $display($time, " %m: Invalid state: %x", state);
      end
   endcase
end



// ====================================
// Detect and process prog_b signal

always @(negedge cpci_rp_prog_b or posedge cpci_rp_prog_b)
begin
   if (!cpci_rp_prog_b && cpci_rp_en) begin
      prog_b_start <= $time;
      state <= PROG_B;

      cpci_rp_init_b = 1'b0;
      cpci_rp_done = 1'b0;

      $display($time, " CPCI reprogramming commenced");
   end
   else if (state == PROG_B && cpci_rp_en) begin
      if ($time - prog_b_start < MIN_PROG_B_TIME) begin
         $display($time, " Error: PROG_B low duration too short. Was: %t   Minimum: %t", $time - prog_b_start, MIN_PROG_B_TIME);
         state <= ERROR;
      end
      else
         state <= INIT_B;
   end
end



// ====================================
// Detect transitions on cpci_rp_en
always @(negedge cpci_rp_en or posedge cpci_rp_en)
begin
   if (state != IDLE) begin
      $display($time, " Error: cpci_rp_en transitioned when not in the IDLE state");
      state <= ERROR;
   end
end



endmodule // cpci_program_iface
