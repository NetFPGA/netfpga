///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: generic_regs.v
// Project: NF2.1
// Description: Implements a generic register block that stores counters in SRAM
//              and can handle control signals from the software to the hardware
//              and vice versa.
//
// To use this block you should specify a number of parameters at
// instantiation:
//   TAG -- specifies the major block's tag. This should be specified as a macro
//          somewhere like (udp_defines.v)
//   REG_ADDR_WIDTH -- width of the address block allocated to this register
//                     group. It is important that this is specified correctly
//                     as this width is used to enable tag matching
//   NUM_COUNTERS      -- number of counters needed (per instance)
//   NUM_SOFTWARE_REGS -- number of registers that are written by software and
//                        read by hardware (per instance)
//   NUM_HARDWARE_REGS -- number of registers written by hardware and read by
//                        software (per instance)
//   NUM_INSTANCES -- how many instances of the counters shall we emulate
//   RESET_ON_READ -- reset counters when read if set to 1.
//
// Other parameter which may be useful
//   COUNTER_INPUT_WIDTH -- width of each counter update input
//   MIN_UPDATE_INTERVAL -- how many clock cycles between successive update
//                          inputs
//   REG_START_ADDR -- specify where to start addresses (see below)
//   ACK_UNFOUND_ADDRESSES -- if an address is not found then return DEADBEEF
//   REVERSE_WORD_ORDER -- By default, registers are input and output in order
//                         from right to left: {n, n-1, ..., 0}. This reverses
//                         the order to {0, 1, ..., n}.
//
// This is implemented as three modules connected in series, the first module
// implements the counters, the second implements the sw regs, and the third
// implements the hw regs.
//
// The addresses are sequential similar to the way the modules are attached.
// For example, if there are 4 counter, 2 sw regs and 4 hw regs then the
// counters will have addresses 0-3, the sw regs will have addresses 4-5, and
// the hw regs will have addresses 6-9.
//
// If REG_START_ADDR is non-zero, it is added to the addresses. So in the previous
// example, if REG_START_ADDR is 5, then the counters will have addresses 5-8,
// the sw regs will have addresses 9-10, and the hw regs will have addresses 11-14.
// This allows connecting other register modules before this generic_regs module.
//
// If ACK_UNFOUND_ADDRESSES is set to 1 (default), then if an address does
// not match in any of the registers that are in this group and the tag
// indicates a hit, then the request is ack'ed and if it's a read,
// then 32'hDEADBEEF is returned. Otherwise, nothing is done, and the request
// is unchanged. This allows connecting other register modules after this module.
//
// NOTE: The various register inputs/outputs (SW/HW/Counters) will always be
// at least one bit wide. This is because you can't conditionally define
// ports, at least not without using `defines.
//
// Notes on "instances":
//   The module now supports the concepts of multiple instances of a set of
//   counters. The total number of counters supported by the block will be:
//     NUM_REGS_USED * NUM_INSTANCES
//   In the case of only a single instance then the block will span exactly
//   NUM_REGS_USED addresses.
//
//   Specify the number of counter, hardware and software registers PER
//   INSTANCE.
//   Specify REG_ADDR_WIDTH as the MODULE block address width, not the
//   instance block address width.
//
//   In the case of multiple instances the block will span
//     pow2ceil(NUM_REGS_USED) * pow2ceil(NUM_INSTANCES)
//   where pow2ceil is defined as the nearest power of 2 above the specified
//   value. In this case the address space is broken down as follows:
//
//   Address high ----------------------------------------------- Address low
//   TAG |<- ceil(log2(NUM_INSTANCES)) -> | <- ceil(log2(NUM_REGS_USED)) -> |
//
//   When using multiple instances, the all instances of a particular register
//   should be group before the next register. For example, if we have
//   2 instances with the registers A, B and C then the registers should be
//   input as:
//     {C1, C0, B1, B0, A1, A0}
//
// Last Modified: 4/29/09 by Glen Gibb to support multiple instances
//                6/03/09 by Glen Gibb -- incorporated bug fixes from
//                                        James Hongyi Zeng
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module generic_regs
   #(
      parameter UDP_REG_SRC_WIDTH     = 2,                       // identifies which module started this request
      parameter TAG                   = 0,                       // Tag to match against
      parameter REG_ADDR_WIDTH        = 5,                       // Width of block addresses
      parameter NUM_COUNTERS          = 8,                       // How many counters (per instance)
      parameter NUM_SOFTWARE_REGS     = 8,                       // How many sw regs (per instance)
      parameter NUM_HARDWARE_REGS     = 8,                       // How many hw regs (per instance)
      parameter NUM_INSTANCES         = 1,                       // Number of instances
      parameter COUNTER_INPUT_WIDTH   = 1,                       // Width of each counter update request
      parameter MIN_UPDATE_INTERVAL   = 8,                       // Clocks between successive counter inputs
      parameter COUNTER_WIDTH         = `CPCI_NF2_DATA_WIDTH,    // How wide should counters be?
      parameter RESET_ON_READ         = 0,                       // Resets the counters when they are read
      parameter REG_START_ADDR        = 0,                       // Address of the first counter
      parameter ACK_UNFOUND_ADDRESSES = 1,                       // If 1, then send an ack for req that have
                                                                 // this block's tag but not the rigt address
      parameter REVERSE_WORD_ORDER    = 0,                       // Reverse order of registers in and out

      // Don't modify the parameters below. They are used to calculate the
      // widths of the various register inputs/outputs.
      parameter INSTANCES =
         NUM_INSTANCES > 1 ? 2 ** log2(NUM_INSTANCES) : 1,
      parameter INST_WIDTH =
         NUM_INSTANCES > 1 ? log2(NUM_INSTANCES) : 0,
      parameter COUNTER_UPDATE_WIDTH =
         NUM_COUNTERS > 0 ? NUM_COUNTERS * COUNTER_INPUT_WIDTH * INSTANCES : INSTANCES,
      parameter COUNTER_DECREMENT_WIDTH =
         NUM_COUNTERS > 0 ? NUM_COUNTERS * INSTANCES : INSTANCES,
      parameter SOFTWARE_REGS_WIDTH =
         NUM_SOFTWARE_REGS > 0 ? NUM_SOFTWARE_REGS * `CPCI_NF2_DATA_WIDTH * INSTANCES : INSTANCES,
      parameter HARDWARE_REGS_WIDTH =
         NUM_HARDWARE_REGS > 0 ? NUM_HARDWARE_REGS * `CPCI_NF2_DATA_WIDTH * INSTANCES : INSTANCES
   )
   (
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output reg                             reg_req_out,
      output reg                             reg_ack_out,
      output reg                             reg_rd_wr_L_out,
      output reg [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output reg [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // --- counters interface
      input [COUNTER_UPDATE_WIDTH - 1 :0]    counter_updates,   // all the counter updates are concatenated
      input [COUNTER_DECREMENT_WIDTH - 1:0]  counter_decrement, // if 1 then subtract the update, else add.

      // --- SW regs interface
      output [SOFTWARE_REGS_WIDTH - 1 : 0]   software_regs, // signals from the software

      // --- HW regs interface
      input  [HARDWARE_REGS_WIDTH - 1 : 0]   hardware_regs, // signals from the hardware

      input                                clk,
      input                                reset
    );

   `LOG2_FUNC

   //------------------ Internal Parameters ---------------------

   //---------------------- Wires/Regs --------------------------
   wire                                   cntr_reg_req_out;
   wire                                   cntr_reg_ack_out;
   wire                                   cntr_reg_rd_wr_L_out;
   wire [`UDP_REG_ADDR_WIDTH-1:0]         cntr_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]        cntr_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]           cntr_reg_src_out;

   wire                                   sw_reg_req_out;
   wire                                   sw_reg_ack_out;
   wire                                   sw_reg_rd_wr_L_out;
   wire [`UDP_REG_ADDR_WIDTH-1:0]         sw_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]        sw_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]           sw_reg_src_out;

   wire                                   hw_reg_req_out;
   wire                                   hw_reg_ack_out;
   wire                                   hw_reg_rd_wr_L_out;
   wire [`UDP_REG_ADDR_WIDTH-1:0]         hw_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]        hw_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]           hw_reg_src_out;

   wire [`UDP_REG_ADDR_WIDTH-1:0]         reg_addr_in_swapped;
   wire [`UDP_REG_ADDR_WIDTH-1:0]         hw_reg_addr_out_swapped;

   wire [COUNTER_UPDATE_WIDTH - 1 :0]     counter_updates_ordered;
   wire [COUNTER_DECREMENT_WIDTH - 1:0]   counter_decrement_ordered;
   wire [SOFTWARE_REGS_WIDTH - 1 : 0]     software_regs_ordered;
   wire [HARDWARE_REGS_WIDTH - 1 : 0]     hardware_regs_ordered;

   wire [COUNTER_UPDATE_WIDTH - 1 :0]     counter_updates_expanded;
   wire [COUNTER_DECREMENT_WIDTH - 1:0]   counter_decrement_expanded;
   wire [SOFTWARE_REGS_WIDTH - 1 : 0]     software_regs_expanded;
   wire [HARDWARE_REGS_WIDTH - 1 : 0]     hardware_regs_expanded;

   //------------------------ Modules ---------------------------

generate
if (NUM_COUNTERS > 0) begin
   generic_cntr_regs
     #(.UDP_REG_SRC_WIDTH     (UDP_REG_SRC_WIDTH),
       .TAG                   (TAG),
       .REG_ADDR_WIDTH        (REG_ADDR_WIDTH),
       .NUM_REGS_USED         (NUM_COUNTERS * INSTANCES),
       .REG_WIDTH             (COUNTER_WIDTH),
       .MIN_UPDATE_INTERVAL   (MIN_UPDATE_INTERVAL),
       .RESET_ON_READ         (RESET_ON_READ),
       .INPUT_WIDTH           (COUNTER_INPUT_WIDTH),
       .REG_START_ADDR        (REG_START_ADDR))
   generic_cntr_regs
     (
      .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in_swapped),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),

      .reg_req_out       (cntr_reg_req_out),
      .reg_ack_out       (cntr_reg_ack_out),
      .reg_rd_wr_L_out   (cntr_reg_rd_wr_L_out),
      .reg_addr_out      (cntr_reg_addr_out),
      .reg_data_out      (cntr_reg_data_out),
      .reg_src_out       (cntr_reg_src_out),

      // --- update interface
      .updates           (counter_updates_expanded),
      .decrement         (counter_decrement_expanded),

      .clk               (clk),
      .reset             (reset));
end
else begin
   assign cntr_reg_req_out       = reg_req_in;
   assign cntr_reg_ack_out       = reg_ack_in;
   assign cntr_reg_rd_wr_L_out   = reg_rd_wr_L_in;
   assign cntr_reg_addr_out      = reg_addr_in_swapped;
   assign cntr_reg_data_out      = reg_data_in;
   assign cntr_reg_src_out       = reg_src_in;
end
endgenerate

generate
if (NUM_SOFTWARE_REGS > 0) begin
   generic_sw_regs
     #(.UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
       .TAG                 (TAG),
       .REG_ADDR_WIDTH      (REG_ADDR_WIDTH),
       .NUM_REGS_USED       (NUM_SOFTWARE_REGS * INSTANCES),
       .REG_START_ADDR      (REG_START_ADDR + NUM_COUNTERS * INSTANCES))
   generic_sw_regs
     (
      .reg_req_in        (cntr_reg_req_out),
      .reg_ack_in        (cntr_reg_ack_out),
      .reg_rd_wr_L_in    (cntr_reg_rd_wr_L_out),
      .reg_addr_in       (cntr_reg_addr_out),
      .reg_data_in       (cntr_reg_data_out),
      .reg_src_in        (cntr_reg_src_out),

      .reg_req_out       (sw_reg_req_out),
      .reg_ack_out       (sw_reg_ack_out),
      .reg_rd_wr_L_out   (sw_reg_rd_wr_L_out),
      .reg_addr_out      (sw_reg_addr_out),
      .reg_data_out      (sw_reg_data_out),
      .reg_src_out       (sw_reg_src_out),

      .software_regs     (software_regs_expanded),

      .clk               (clk),
      .reset             (reset));
end
else begin
   assign sw_reg_req_out       = cntr_reg_req_out;
   assign sw_reg_ack_out       = cntr_reg_ack_out;
   assign sw_reg_rd_wr_L_out   = cntr_reg_rd_wr_L_out;
   assign sw_reg_addr_out      = cntr_reg_addr_out;
   assign sw_reg_data_out      = cntr_reg_data_out;
   assign sw_reg_src_out       = cntr_reg_src_out;

   assign sofware_regs         = 'h0;
end
endgenerate

generate
if (NUM_HARDWARE_REGS > 0) begin
   generic_hw_regs
     #(.UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
       .TAG                 (TAG),
       .REG_ADDR_WIDTH      (REG_ADDR_WIDTH),
       .NUM_REGS_USED       (NUM_HARDWARE_REGS * INSTANCES),
       .REG_START_ADDR      (REG_START_ADDR + (NUM_COUNTERS+NUM_SOFTWARE_REGS) * INSTANCES))
   generic_hw_regs
     (
      .reg_req_in        (sw_reg_req_out),
      .reg_ack_in        (sw_reg_ack_out),
      .reg_rd_wr_L_in    (sw_reg_rd_wr_L_out),
      .reg_addr_in       (sw_reg_addr_out),
      .reg_data_in       (sw_reg_data_out),
      .reg_src_in        (sw_reg_src_out),

      .reg_req_out       (hw_reg_req_out),
      .reg_ack_out       (hw_reg_ack_out),
      .reg_rd_wr_L_out   (hw_reg_rd_wr_L_out),
      .reg_addr_out      (hw_reg_addr_out_swapped),
      .reg_data_out      (hw_reg_data_out),
      .reg_src_out       (hw_reg_src_out),

      .hardware_regs     (hardware_regs_expanded),

      .clk               (clk),
      .reset             (reset));
end
else begin
   assign hw_reg_req_out       = sw_reg_req_out;
   assign hw_reg_ack_out       = sw_reg_ack_out;
   assign hw_reg_rd_wr_L_out   = sw_reg_rd_wr_L_out;
   assign hw_reg_addr_out_swapped      = sw_reg_addr_out;
   assign hw_reg_data_out      = sw_reg_data_out;
   assign hw_reg_src_out       = sw_reg_src_out;
end
endgenerate

   // -------------- Logic --------------------

   // check for a bad address
   always @(posedge clk) begin
      if (reset) begin
         reg_req_out        <= 0;
         reg_ack_out        <= 0;
         reg_rd_wr_L_out    <= 0;
         reg_addr_out       <= 0;
         reg_data_out       <= 0;
         reg_src_out        <= 0;
      end
      else begin
         if (ACK_UNFOUND_ADDRESSES
             && hw_reg_req_out
             && !hw_reg_ack_out
             && hw_reg_addr_out[`UDP_REG_ADDR_WIDTH - 1:REG_ADDR_WIDTH]==TAG) begin
            reg_ack_out        <= 1'b1;
            reg_data_out       <= hw_reg_rd_wr_L_out ? 32'hDEADBEEF : hw_reg_data_out;
         end
         else begin
            reg_ack_out        <= hw_reg_ack_out;
            reg_data_out       <= hw_reg_data_out;
         end // else: !if(ACK_UNFOUND_ADDRESSES...
         reg_req_out        <= hw_reg_req_out;
         reg_rd_wr_L_out    <= hw_reg_rd_wr_L_out;
         reg_addr_out       <= hw_reg_addr_out;
         reg_src_out        <= hw_reg_src_out;
      end // else: !if(reset)
   end // always @(posedge clk)

   // Reverse order of words if needed
   generate
      genvar i;
      if(NUM_COUNTERS>1 && REVERSE_WORD_ORDER) begin
         for(i=0; i<NUM_COUNTERS; i=i+1) begin:gen_ordered_cntrs
            assign counter_updates_ordered[(i+1)*COUNTER_INPUT_WIDTH - 1: i*COUNTER_INPUT_WIDTH]
                                           = counter_updates[(NUM_COUNTERS-i)*COUNTER_INPUT_WIDTH - 1:(NUM_COUNTERS-i-1)*COUNTER_INPUT_WIDTH];
            assign counter_decrement_ordered[i] = counter_decrement[NUM_COUNTERS-i-1];
         end
      end
      else begin
         assign counter_updates_ordered = counter_updates;
         assign counter_decrement_ordered = counter_decrement;
      end // else: !if(NUM_COUNTERS>1 && REVERSE_WORD_ORDER)

      if(NUM_SOFTWARE_REGS>1 && REVERSE_WORD_ORDER) begin
         for(i=0; i<NUM_SOFTWARE_REGS; i=i+1) begin:gen_ordered_sw_regs
            assign software_regs[(i+1)*`CPCI_NF2_DATA_WIDTH - 1: i*`CPCI_NF2_DATA_WIDTH]
                                           = software_regs_ordered[(NUM_SOFTWARE_REGS-i)*`CPCI_NF2_DATA_WIDTH - 1:(NUM_SOFTWARE_REGS-i-1)*`CPCI_NF2_DATA_WIDTH];
         end
      end
      else begin
         assign software_regs = software_regs_ordered;
      end // else: !if(NUM_SOFTWARE_REGS>1 && REVERSE_WORD_ORDER)

      if(NUM_HARDWARE_REGS>1 && REVERSE_WORD_ORDER) begin
         for(i=0; i<NUM_HARDWARE_REGS; i=i+1) begin:gen_ordered_hw_regs
            assign hardware_regs_ordered[(i+1)*`CPCI_NF2_DATA_WIDTH - 1: i*`CPCI_NF2_DATA_WIDTH]
                                           = hardware_regs[(NUM_HARDWARE_REGS-i)*`CPCI_NF2_DATA_WIDTH - 1:(NUM_HARDWARE_REGS-i-1)*`CPCI_NF2_DATA_WIDTH];
         end
      end
      else begin
         assign hardware_regs_ordered = hardware_regs;
      end // else: !if(NUM_HARDWARE_REGS>1 && REVERSE_WORD_ORDER)
   endgenerate

   // Expand variables when we have multiple instances
   //
   // To allow address remapping to occur the inputs/outputs need to be padded
   // as if the number of instances was a power of 2. So if we had 3 instances
   // with the registers A and B, we would go from:
   //   {B2, B1, B0, A2, A1, A0}
   // to:
   //   {0, B2, B1, B0, 0, A2, A1, A0}
   // Notice the zeros inserted above to ensure that each group of registers
   // is a power of two size.
   generate
      genvar j;
      if(INSTANCES != 1 && INSTANCES != NUM_INSTANCES) begin
         if (NUM_COUNTERS>0) begin
            for(j=0; j<NUM_COUNTERS; j=j+1) begin:gen_expanded_cntrs
               assign counter_updates_expanded[j*COUNTER_INPUT_WIDTH*INSTANCES +
                                               NUM_INSTANCES*COUNTER_INPUT_WIDTH - 1 :
                                               j*COUNTER_INPUT_WIDTH*INSTANCES] =
                      counter_updates_ordered[(j+1)*COUNTER_INPUT_WIDTH*NUM_INSTANCES +
                                               j*COUNTER_INPUT_WIDTH*NUM_INSTANCES];
               assign counter_updates_expanded[(j+1)*COUNTER_INPUT_WIDTH*INSTANCES - 1 :
                                               j*COUNTER_INPUT_WIDTH*INSTANCES +
                                               NUM_INSTANCES*COUNTER_INPUT_WIDTH] = 0;

               assign counter_decrement_expanded[j*INSTANCES + NUM_INSTANCES - 1 : j*INSTANCES] =
                      counter_decrement_ordered[(j+1)*NUM_INSTANCES + j*NUM_INSTANCES];
               assign counter_decrement_expanded[(j+1)*INSTANCES - 1 : j*INSTANCES + NUM_INSTANCES] = 0;
            end
         end

         if (NUM_SOFTWARE_REGS>0) begin
            for(j=0; j<NUM_SOFTWARE_REGS; j=j+1) begin:gen_ordered_sw_regs
               assign software_regs_ordered[(j+1)*`CPCI_NF2_DATA_WIDTH - 1: j*`CPCI_NF2_DATA_WIDTH] =
                      software_regs_expanded[j*`CPCI_NF2_DATA_WIDTH*INSTANCES +
                                             NUM_INSTANCES*`CPCI_NF2_DATA_WIDTH - 1:
                                             j*`CPCI_NF2_DATA_WIDTH];
            end
         end

         if (NUM_HARDWARE_REGS>0) begin
            for(j=0; j<NUM_HARDWARE_REGS; j=j+1) begin:gen_ordered_hw_regs
               assign hardware_regs_expanded[j*`CPCI_NF2_DATA_WIDTH*INSTANCES +
                                             NUM_INSTANCES*`CPCI_NF2_DATA_WIDTH - 1 :
                                             j*`CPCI_NF2_DATA_WIDTH*INSTANCES] =
                      hardware_regs_ordered[(j+1)*`CPCI_NF2_DATA_WIDTH*NUM_INSTANCES:
                                            j*`CPCI_NF2_DATA_WIDTH*NUM_INSTANCES];
               assign hardware_regs_expanded[(j+1)*`CPCI_NF2_DATA_WIDTH*INSTANCES - 1 :
                                             j*`CPCI_NF2_DATA_WIDTH*INSTANCES +
                                             NUM_INSTANCES*`CPCI_NF2_DATA_WIDTH] = 0;
            end
         end
      end
      else begin
         assign counter_updates_expanded = counter_updates_ordered;
         assign counter_decrement_expanded = counter_decrement_ordered;
         assign software_regs_ordered = software_regs_expanded;
         assign hardware_regs_expanded = hardware_regs_ordered;
      end // else: !if(INSTANCES != 1 && INSTANCES != NUM_INSTANCES)
   endgenerate

   generate
      if (NUM_INSTANCES > 1) begin
         assign reg_addr_in_swapped = {reg_addr_in[`UDP_REG_ADDR_WIDTH-1:REG_ADDR_WIDTH],
                                       reg_addr_in[REG_ADDR_WIDTH-INST_WIDTH-1:0],
                                       reg_addr_in[REG_ADDR_WIDTH-1:REG_ADDR_WIDTH-INST_WIDTH]};
         assign hw_reg_addr_out = {hw_reg_addr_out_swapped[`UDP_REG_ADDR_WIDTH-1:REG_ADDR_WIDTH],
                                   hw_reg_addr_out_swapped[INST_WIDTH-1:0],
                                   hw_reg_addr_out_swapped[REG_ADDR_WIDTH-1:INST_WIDTH]};
      end
      else begin
         assign reg_addr_in_swapped = reg_addr_in;
         assign hw_reg_addr_out = hw_reg_addr_out_swapped;
      end
   endgenerate

endmodule // generic_regs
