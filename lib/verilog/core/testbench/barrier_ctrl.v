//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: barrier_ctrl.v
// Project: NetFPGA-1G board testbench
// Description: Barrier control module. Aggregates barrier good notifications
// from individual modules and pushes out a global barrier good notification
// when all modules are ready.
//
///////////////////////////////////////////////////////////////////////////////

// `timescale 1 ns/1 ns
module barrier_ctrl #(
   parameter NUM_PORTS = 4
)
(
   input [0:NUM_PORTS - 1] if_activity,
   input                   pci_activity,

   input [0:NUM_PORTS - 1] if_good,
   input                   pci_good,

   output reg              barrier_proceed
);

// Time to wait before declaring the system "stuck" when we have a barrier
// and not all modules are ready to proceed.
//
// Currently: 200 ns
parameter INACTIVITY_TIMEOUT = 200000;

time req_time;
reg timeout;

initial
begin
   barrier_proceed = 0;
   timeout = 0;

   forever begin
      wait ({if_good, pci_good} != 'h0);

      req_time = $time;
      timeout = 0;
      #1;

      // Wait until either all ports are asserting a barrier request,
      // none of the ports are asserting a barrier request, or a timeout
      // occurs waiting for the barrier
      wait (({if_good, pci_good} === {(NUM_PORTS + 1){1'b1}}) ||
            ({if_good, pci_good} === 'h0) || timeout);

      if (timeout) begin
         $display($time," %m Error: timeout exceeded waiting for barrier");
         $finish;
      end
      else if ({if_good, pci_good} === {(NUM_PORTS + 1){1'b1}}) begin
         // Barrier request from all modules

         barrier_proceed = 1;

         wait ({if_good, pci_good} === 'h0);

         barrier_proceed = 0;
      end
   end
end

initial
begin
   forever begin
      wait ({if_good, pci_good} != 'h0 && {if_activity, pci_activity} != 'h0);

      req_time = $time;
      #1;
   end
end

initial
begin
   forever begin
      if ({if_good, pci_good} != 'h0) begin
         while ({if_good, pci_good} != 'h0) begin
            #1;
            #(req_time + INACTIVITY_TIMEOUT - $time);
            if ({if_good, pci_good} != 'h0 && req_time + INACTIVITY_TIMEOUT <= $time)
               timeout = 1;
         end
      end
      else begin
         wait ({if_good, pci_good} != 'h0);
      end
   end
end

endmodule // barrier_ctrl
