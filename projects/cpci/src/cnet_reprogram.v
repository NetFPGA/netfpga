///////////////////////////////////////////////////////////////////////////////
// $Id: cnet_reprogram.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: cnet_reprogram.v
// Project: CPCI (PCI Control FPGA)
// Description: Manages the reprogramming of the CNET device.
//              Programming is performed using Slave SelectMAP mode
//              (refer to Chapter 4 of the Virtex II Pro User's Guide).
//
// Change history: 8/5/05 -   Only transition from Idle to program modes with
//                            the application of the PROG_RESET signal.
//                            Check DONE before INIT in the Download state.
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////


//`include "defines.v"

module cnet_reprogram(
            // Interface within the CPCI
            input [`PCI_DATA_WIDTH-1:0] prog_data,      // Data being written from the PCI interface
            input          prog_data_vld, // Data on pci_data is valid
            input          prog_reset,    // Reset the programming process

            output         cnet_reprog,   // Indicates that reprogramming is occuring

            output         overflow,      // Indicates a reprogramming buffer overflow
            output reg     error,         // Indicate an error during programming
            output reg     empty,         // Indicate the Write FIFO is now empty

            output reg     init,          // Indicates that the FPGA is in initializaion
            output reg     done,          // Indicates programming is complete

            // Interface to the CNET
            output reg     rp_prog_b,
            input          rp_init_b,
            output         rp_cclk,
            output         rp_cs_b,
            output         rp_rdwr_b,
            output reg [7:0]   rp_data,
            input          rp_done,
            // If we ever do PCI-66:
            // input          rp_busy,


            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Tprogram is defined as the minimum duration for a pulse on prog_b
// and is 300ns.
//
// At 33MHz this translates to approximately 10 clocks
`define PROG_B_CLOCKS   'd10

// prog_b counters - this size would allow up to 32
reg [4:0] prog_b_cnt, prog_b_cnt_nxt;

// Keep track of which byte from the FIFO is currently being programmed
reg [1:0] curr_byte, curr_byte_nxt;

// Count the number of clocks we spend in wait to make sure that the CNET
// is up
reg [2:0] wait_cnt, wait_cnt_nxt;

// Fifo data out
wire [`PCI_DATA_WIDTH - 1:0] fifo_data;

reg rp_prog_b_nxt;
reg fifo_rd_en, fifo_rd_en_nxt;

reg error_nxt;

// Negative edge signals to be made positive edge
reg init_ne, done_ne;

wire fifo_empty;

always @(posedge clk) empty <= fifo_empty;


// ==================================================================
// Instantiate a fifo
// ==================================================================

fifo_8x32 reprog_fifo(
            .din (prog_data),
            .wr_en (prog_data_vld),
            .rd_en (fifo_rd_en),
            .dout (fifo_data),
            .full (fifo_full),
            .empty (fifo_empty),
            .reset (reset | overflow | error | prog_reset),
            .clk (clk)
         );

// ==================================================================
// Main state machine
// ==================================================================

/* The state machine has the following states:
 *   RP_Idle            - Currently not reprogramming the CNET
 *   RP_Prog_B          - Asserting prog_b - must be asserted for at
 *                        least 300ns
 *   RP_Wait_For_Init   - Waiting for the init_b signal to go high to
 *                        indicate that clearing of the FPGA is complete
 *   RP_Download        - Downloading data
 *   RP_Wait            - Waiting for device to come up
 */

reg [2:0]   curr_state, curr_state_nxt;

`define RP_Idle            3'h0
`define RP_Prog_B          3'h1
`define RP_Wait_For_Init   3'h2
`define RP_Download        3'h3
`define RP_Wait            3'h4

always @(posedge clk)
begin
   curr_state <= curr_state_nxt;
   prog_b_cnt <= prog_b_cnt_nxt;
   rp_prog_b <= rp_prog_b_nxt;
   curr_byte <= curr_byte_nxt;
   wait_cnt <= wait_cnt_nxt;
   fifo_rd_en <= fifo_rd_en_nxt;
   error <= error_nxt;
end

always @*
begin
   // Set defaults
   curr_state_nxt = curr_state;
   prog_b_cnt_nxt = prog_b_cnt;
   rp_prog_b_nxt = rp_prog_b;
   curr_byte_nxt = curr_byte;
   wait_cnt_nxt = wait_cnt;
   fifo_rd_en_nxt = 1'b0;
   error_nxt = 1'b0;

   // Go to the idle state on reset
   if (reset) begin
      curr_state_nxt = `RP_Idle;
      prog_b_cnt_nxt = 'h0;
      rp_prog_b_nxt = 1'b1;
      curr_byte_nxt = 2'b0;
      wait_cnt_nxt = 'h0;
   end
   else
      case (curr_state)
         `RP_Idle : begin
            // Check if there is data being applied to the prog_data bus
            if (prog_reset) begin
               curr_state_nxt = `RP_Prog_B;
               prog_b_cnt_nxt = 'h0;
               rp_prog_b_nxt = 1'b0;
            end
         end

         `RP_Prog_B : begin
            // Check if the timer has expired
            if (prog_b_cnt == (`PROG_B_CLOCKS - 1)) begin
               curr_state_nxt = `RP_Wait_For_Init;
               rp_prog_b_nxt = 1'b1;
            end
            else
               // Increment the counter
               prog_b_cnt_nxt = prog_b_cnt + 1;
         end

         `RP_Wait_For_Init : begin
            // Wait for init to be de-asserted
            if (!init) begin
               curr_state_nxt = `RP_Download;
               curr_byte_nxt = 2'b0;
            end
         end

         `RP_Download : begin
            // Check for reset
            if (prog_reset) begin
               curr_state_nxt = `RP_Prog_B;
               prog_b_cnt_nxt = 'h0;
               rp_prog_b_nxt = 1'b0;
            end
            // Check if download is complete
            else if (done) begin
               curr_state_nxt = `RP_Wait;
               wait_cnt_nxt = 'h0;
            end
            // Check for download errors
            else if (init) begin
               // An error occurred. Return to the Prog_B state
               curr_state_nxt = `RP_Prog_B;
               prog_b_cnt_nxt = 'h0;
               rp_prog_b_nxt = 1'b0;
               error_nxt = 1'b1;
            end
            // Check if we have data in the buffer
            else if (!fifo_empty) begin
               // Assert the read signal 1 byte early
               if (curr_byte == 2'h2) begin
                  fifo_rd_en_nxt = 1'b1;
               end

               // Move to the next byte
               curr_byte_nxt = curr_byte + 'h1;
            end
         end

         `RP_Wait : begin
            // Check for reset
            if (prog_reset) begin
               curr_state_nxt = `RP_Prog_B;
               prog_b_cnt_nxt = 'h0;
               rp_prog_b_nxt = 1'b0;
            end
            else if (wait_cnt == 'h7)
               curr_state_nxt = `RP_Idle;

            wait_cnt_nxt = wait_cnt + 'h1;
         end

         default : begin
            curr_state_nxt = `RP_Idle;
         end
      endcase
end


// ==================================================================
// Sample signals returning from the CNET
// ==================================================================

always @(negedge clk)
begin
   init_ne <= ~rp_init_b;
   done_ne <= rp_done;
end

always @(posedge clk)
begin
   init <= init_ne;
   done <= done_ne;
end


// ==================================================================
// Miscelaneous signal generation
// ==================================================================

// Always in programming mode - don't want to read it back
assign rp_rdwr_b = 0;

// We want cs to be ~fifo_empty, therefore cs_b is ~(~fifo_empty)
assign rp_cs_b = !(!fifo_empty && curr_state == `RP_Download);

// Note that the bit allocations for each byte are reversed as per
// Xilinx App Note 502: http://direct.xilinx.com/bvdocs/appnotes/xapp502.pdf
always @*
begin
   case (curr_byte)
      2'b00 : rp_data <= {fifo_data[0],
                          fifo_data[1],
                          fifo_data[2],
                          fifo_data[3],
                          fifo_data[4],
                          fifo_data[5],
                          fifo_data[6],
                          fifo_data[7]};
      2'b01 : rp_data <= {fifo_data[8],
                          fifo_data[9],
                          fifo_data[10],
                          fifo_data[11],
                          fifo_data[12],
                          fifo_data[13],
                          fifo_data[14],
                          fifo_data[15]};
      2'b10 : rp_data <= {fifo_data[16],
                          fifo_data[17],
                          fifo_data[18],
                          fifo_data[19],
                          fifo_data[20],
                          fifo_data[21],
                          fifo_data[22],
                          fifo_data[23]};
      2'b11 : rp_data <= {fifo_data[24],
                          fifo_data[25],
                          fifo_data[26],
                          fifo_data[27],
                          fifo_data[28],
                          fifo_data[29],
                          fifo_data[30],
                          fifo_data[31]};
   endcase
end

// The programming clock should be the inverse of the system clock
assign rp_cclk = ~clk;

assign cnet_reprog = curr_state != `RP_Idle;

assign overflow = fifo_full & prog_data_vld & ~fifo_rd_en;

endmodule // cnet_reprogram

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
