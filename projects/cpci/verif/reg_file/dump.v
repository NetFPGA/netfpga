module dump;

initial
begin
      $timeformat(-9,2,"ns", 10); // -9 =ns  2=digits after .
end // initial begin

initial
begin
      $dumpfile("testdump.vcd");
      $dumpvars(0,reg_file_tb);
      $dumpon;

      //       // Use with signalscan (optional)
      //          //$recordvars("depth =3",netfpga_top);
      //
end

endmodule
