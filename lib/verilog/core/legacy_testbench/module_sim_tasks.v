///////////////////////////////////////////////////////////////////////////////
// $Id: module_sim_tasks.v 1969 2007-07-18 21:59:27Z jnaous $
//
// Module: module_sim_tasks.v
// Project: testbench
// Description: set of tasks to interact with a single module
//
///////////////////////////////////////////////////////////////////////////////

/* Read a register and get the result */
task readReg;
      input integer addr;
      output integer value;

      begin
         @(posedge clk) begin #1 begin end end
         reg_req     = 1;
         reg_rd_wr_L = 1;
         reg_addr    = addr;
         while(reg_ack !== 1) begin
            @(posedge clk) begin #1 begin end end
         end

         @(posedge clk) begin #1 begin end end
         value     = reg_rd_data;
         reg_req   = 0;
      end
endtask // readReg

/* Read a register and print error message if the value
 * is not equal to the expected value. The mask is used
 * to select which bits we care about matching */
task readRegExpectMask;
      input integer addr;
      input integer exp_value;
      input integer mask;

      reg [CPCI_NF2_DATA_WIDTH-1:0] rd_data;
      begin
         readReg(addr, rd_data);
         if((rd_data&mask) !== (exp_value&mask)) begin
            $display("%t %m ERROR: Reg read wrong value. Read 0x%08x but expected 0x%08x, mask: 0x%08x.", $time, rd_data, exp_value, mask);
         end
      end
endtask // readRegExpectMask

/* Read a register and print error message if the value
 * is not equal to the expected value. All bits are
 * compared */
task readRegExpect;
      input integer addr;
      input integer exp_value;

      begin
         readRegExpectMask(addr, exp_value, {CPCI_NF2_DATA_WIDTH{1'b1}});
      end
endtask // readRegExpect

/* write a value in the register */
task writeReg;
      input integer addr;
      input integer value;

      begin
         @(posedge clk) begin #1 begin end end
         reg_req     = 1;
         reg_rd_wr_L = 0;
         reg_addr    = addr;
         reg_wr_data = value;
         while(reg_ack !== 1) begin
            @(posedge clk) begin #1 begin end end
         end

         @(posedge clk) begin #1 begin end end
         reg_req   = 0;
      end
endtask

/* inject packet of length 'length'. The pkt is fully specified
 * in the memory 'pkt'. */
task inject_pkt;
      input integer length;

      integer i;
      begin
         i=0;
         $display("%t %m Injecting pkt length %u...", $time, length);
         while(i<length) begin
	    #1
            if(in_rdy===1) begin
               in_wr = 1;
               {in_ctrl, in_data} = pkt[i];
               i=i+1;
            end
	    else if(in_rdy===0) begin
	       in_wr = 0;
	    end
	    @(posedge clk) begin #1 begin end end
         end // while (i<length)
	 in_wr = 0;
      end
endtask // inject_pkt

/* wait for the pkt in memory 'exp_pkt' to come out.
 * The pkt needs to come out between min_num_cycles
 * and max_num_cycles later.
 */
task expect_pkt;
      input integer length;
      input integer min_num_cycles;
      input integer max_num_cycles;

      integer i;
      integer num_cycles;
      begin
	 num_cycles=0;
         $display("%t %m Expect pkt length %u...", $time, length);
         while(num_cycles < max_num_cycles && out_wr !== 1) begin
            @(posedge clk) begin end
            num_cycles = num_cycles + 1;
         end

         if(num_cycles<min_num_cycles) begin
            $display("%t %m ERROR: Packet came out too early.",$time);
            $stop;
         end
         else if(num_cycles>=max_num_cycles) begin
            $display("%t %m ERROR: latency exceeded without packet coming out.", $time);
            $stop;
         end
         else begin
            i=0;
            while(i<length) begin
               if(out_wr===1) begin
                  if({out_ctrl, out_data} !== exp_pkt[i]) begin
                     $display("%t %m ERROR: Expected packet word (0x%018x) doesn't match output (0x%018x).", $time, exp_pkt[i], {out_ctrl, out_data});
                     $stop;
                  end
                  i=i+1;
               end
               @(posedge clk) begin end
            end // while (i<length)
         end // else: !if(num_cycles>=max_num_cycles)

      end
endtask // expect_pkt
