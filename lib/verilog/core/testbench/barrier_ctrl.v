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
   input [0:NUM_PORTS - 1] if_good,
   input                   pci_good,

   output reg              barrier_proceed
);

initial
begin
   barrier_proceed = 0;

   while (1) begin
      wait ({if_good, pci_good} === {(NUM_PORTS + 1){1'b1}});

      barrier_proceed = 1;

      wait ({if_good, pci_good} === 'h0);

      barrier_proceed = 0;
   end
end

endmodule // barrier_ctrl
