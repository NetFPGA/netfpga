//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: nf2_reg.v
// Project: NetFPGA
// Description: cpu accessible registers
//
///////////////////////////////////////////////////////////////////////////////


module nf2_reg
  (
   input                                  fifo_empty,// functions like a bus_req signal
   output reg                             fifo_rd_en,
   input                                  bus_rd_wr_L,
   input      [`CPCI_NF2_ADDR_WIDTH-1:0]  bus_addr,
   input      [`CPCI_NF2_DATA_WIDTH-1:0]  bus_wr_data,
   output reg [`CPCI_NF2_DATA_WIDTH-1:0]  bus_rd_data,
   output reg                             bus_rd_vld,

   input                                  test_done,
   input                                  test_success,

   //- misc
   input                                  clk,
   input                                  reset);

   //--------------------- Internal parameters -----------------------------------------------------------
   localparam
      IDLE_STATE = 2'h0,
      GET_REQ_STATE = 2'h1,
      WAIT_ACK_STATE = 2'h2;

   localparam
      TIMEOUT_COUNT_DOWN = 9'd511;

   //--------------------- Wires/regs ---------------------
   reg                              cpu_req, cpu_req_nxt;
   reg                              cpu_rd_wr_L, cpu_rd_wr_L_nxt;
   reg [`CPCI_NF2_ADDR_WIDTH -3: 0] cpu_addr, cpu_addr_nxt;
   reg [`CPCI_NF2_DATA_WIDTH -1: 0] cpu_wr_data, cpu_wr_data_nxt;
   reg                              cpu_ack;
   reg [`CPCI_NF2_DATA_WIDTH -1: 0] cpu_rd_data;
   reg [8:0]                        cpu_timeout_cnt_dn, cpu_timeout_cnt_dn_nxt;

   reg [1:0]                        state, state_nxt;

   reg [31:0] 			    tot_success, tot_failure;

   //-------------------- Logic ----------------------------
   always @(*) begin
      fifo_rd_en = 1'b 0;

      bus_rd_data = {`CPCI_NF2_DATA_WIDTH {1'b 0}};
      bus_rd_vld = 1'b 0;

      cpu_req_nxt = cpu_req;
      cpu_rd_wr_L_nxt = cpu_rd_wr_L;
      cpu_addr_nxt = cpu_addr;
      cpu_wr_data_nxt = cpu_wr_data;
      cpu_timeout_cnt_dn_nxt = cpu_timeout_cnt_dn;

      state_nxt = state;

      case (state)
         IDLE_STATE: begin
            if (! fifo_empty) begin
               fifo_rd_en = 1'b1;
               state_nxt = GET_REQ_STATE;
            end   // if (! fifo_empty)
         end   // IDLE_STATE

         GET_REQ_STATE: begin

            cpu_req_nxt = 1'b 1;
            cpu_addr_nxt = bus_addr[`CPCI_NF2_ADDR_WIDTH-1:2];

            cpu_timeout_cnt_dn_nxt = TIMEOUT_COUNT_DOWN;
            state_nxt = WAIT_ACK_STATE;

            if (bus_rd_wr_L) begin     // read
               cpu_wr_data_nxt = {`CPCI_NF2_DATA_WIDTH {1'b 0}};
               cpu_rd_wr_L_nxt = 1'b 1;
            end   // (if bus_rd_wr_L)
            else begin                 // write
               cpu_rd_wr_L_nxt = 1'b 0;
               cpu_wr_data_nxt = bus_wr_data;
            end   // else

         end   // GET_REQ_STATE

         WAIT_ACK_STATE: begin
            cpu_timeout_cnt_dn_nxt = cpu_timeout_cnt_dn - 1;

            if (cpu_ack || !(|cpu_timeout_cnt_dn)) begin

               // synthesis translate_off
               if(cpu_timeout_cnt_dn==0) begin
                  $display("%t %m ERROR: Timeout while waiting for ack for register access.", $time);
               end
               // synthesis translate_on

               cpu_rd_wr_L_nxt = 1'b 1;
               if (cpu_rd_wr_L) begin
                  bus_rd_data = (cpu_ack === 1'b1) ? cpu_rd_data : 'h deadbeef;
                  bus_rd_vld = 1'b 1;
               end   // if (cpu_rd_wr_L)

               cpu_req_nxt = 1'b 0;

               if (! fifo_empty) begin
                  fifo_rd_en = 1'b 1;
                  state_nxt = GET_REQ_STATE;
               end
               else
                 state_nxt = IDLE_STATE;

            end // if (cpu_ack)
         end   // WAIT_ACK_STATE

      endcase // case(state)

   end // always @ (*)


   always @(posedge clk) begin
      if (reset) begin
         state <= IDLE_STATE;

         cpu_req <= 1'b 0;
         cpu_rd_wr_L <= 1'b 0;
         cpu_addr <= {(`CPCI_NF2_ADDR_WIDTH-2) {1'b 0}};
         cpu_wr_data <= {`CPCI_NF2_DATA_WIDTH {1'b 0}};
         cpu_timeout_cnt_dn <= 7'h 0;

	 tot_success <= 'h 0;
	 tot_failure <= 'h 0;

      end   // if (reset)
      else begin
         state <= state_nxt;

         cpu_req <= cpu_req_nxt;
         cpu_rd_wr_L <= cpu_rd_wr_L_nxt;
         cpu_addr <= cpu_addr_nxt;
         cpu_wr_data <= cpu_wr_data_nxt;
         cpu_timeout_cnt_dn <= cpu_timeout_cnt_dn_nxt;
	 tot_success <= (test_done & test_success) ?
			 (tot_success + 'h 1) : tot_success;
	 tot_failure <= (test_done & (~test_success)) ?
			 (tot_failure + 'h 1) : tot_failure;

      end   // else

   end // always @ (posedge clk)


   always @(posedge clk) begin

      if(reset) begin

         cpu_ack     <= 1'b 0;
         cpu_rd_data <= {`CPCI_NF2_DATA_WIDTH {1'b 0}};

      end // if (reset)
      else begin

         casez (cpu_addr)
	   25'h 10_0000: begin

	      cpu_rd_data <= tot_success;
	      cpu_ack     <= cpu_req;

	   end

	   25'h 10_0001: begin

	      cpu_rd_data <= tot_failure;
	      cpu_ack     <= cpu_req;

	   end

          default: begin
              cpu_ack     <= cpu_req;
              cpu_rd_data <= 32'h DEAD_BEEF;
           end // case: default

         endcase // casez(cpu_addr)

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // nf2_reg
