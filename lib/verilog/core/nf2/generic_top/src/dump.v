module dump;

initial
begin
      $timeformat(-9,2,"ns", 10); // -9 =ns  2=digits after .
end // initial begin

initial
begin
      $dumpfile("testdump.vcd");
      $dumpvars(1,testbench);
      $dumpvars(1,testbench.u_board.nf2_top.nf2_core);
      $dumpvars(2,testbench.u_board.nf2_top.nf2_core.serial_test);
      $dumpon;

      //       // Use with signalscan (optional)
      //          //$recordvars("depth =3",netfpga_top);
      //
end

endmodule
