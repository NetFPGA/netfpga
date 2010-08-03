///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: target32.v 3454 2008-03-25 05:00:58Z grg $
//
// Module: finish_ctrl.v
// Project: Testbench (NetFPGA testbench)
// Description: Manage the end of the simulation
//
// The simulation can run in two modes:
//   - simulation will end at time specified by config.sim
//   - simulation ends when the ingress files/pci sim data reach their ends
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

//`include "defines.v"

// default filenames
`define CONFIG_FILE_NAME "config.sim"

`define DEFAULT_FINISH_TIME 1000000


module finish_ctrl #(
      parameter NUM_PORTS = 4
   )
   (
      input [0:NUM_PORTS - 1] if_done,
      input                   pci_done,
      output reg              sim_end,
      input                   host32_is_active
   );

// ========== Global declarations ==========

time        finish_time;
reg         should_use_done;


// ========== Tasks ==========

// ========================================================
// Process a configuration file
// ========================================================

task read_configuration;
   integer fd_c, tmp;

   begin
      #1;

      fd_c = $fopen(`CONFIG_FILE_NAME, "r");

      if (fd_c == 0) begin
         finish_time = `DEFAULT_FINISH_TIME;
         should_use_done = 1;
         $display("No configuration file named %s",`CONFIG_FILE_NAME);
         $display("    Simulation will finish when inputs processed or time reaches %t.", finish_time);
      end
      else begin
         tmp=$fscanf(fd_c,"FINISH=%d",finish_time);
         should_use_done = 0;
         $display("Read Configuration file %s",`CONFIG_FILE_NAME);
         $display("    Finish time is %t.", finish_time);
      end

      $fclose(fd_c);

   end
endtask // read_configuration


// ========================================================
// Wait until the simulation end time is reached
// ========================================================

task wait_for_end_time;
   time t;
   integer i;
   begin
      // First, figure out when to finish
      if (finish_time == 0) begin
         $display("%m Weird! finish_time should have been set. Will use default.");
         finish_time = `DEFAULT_FINISH_TIME ;
      end

      if (finish_time < $time) begin // Finished already!
         $display($time," Finishing immediately - maybe that's not what you wanted - if so then change config.txt to something larger");
      end
      else begin
         t = finish_time - $time;
         #t;
      end

      // OK, now it's time to finish so clean up
      $display($time," Simulation has reached finish time - ending.");
      sim_end = 1;

      // leave a bit of time for other processes to close
      #100 $finish;

   end
endtask // wait_for_end_time


// ========================================================
// Wait for each module to indicate done
// ========================================================

task wait_for_done;
   begin
      if (should_use_done) begin
         // Wait until the host is active
         wait (host32_is_active == 1);

         // Wait until everyone asserts the done signal
         wait ({if_done, pci_done} === {(NUM_PORTS + 1){1'b1}});

         // OK, now it's time to finish so clean up
         $display($time," Simulation has reached finish time - ending.");
         sim_end = 1;

         // leave a bit of time for other processes to close
         #100 $finish;
      end
   end
endtask // wait_for_done

// ================================================================
// Code to handle the end of the simulation
// ================================================================

initial
begin
   should_use_done = 0;
   sim_end = 0;
   read_configuration;

   fork
      wait_for_end_time;
      wait_for_done;
   join
end

endmodule // finish_ctrl
