
Questions about the DDR2 Block Read/Write Module and Its Test Circuit

---------
1. How to run the simulation test of the test circuit?

Answer:
Change the working directory to sub-directory verif/, run command:
"nf21_run_test.pl --major dram --minor simple".

---------
2. How to run syntheis, mapping, place and route for the test circuit?

Answer:
Change the working directory to sub-directory synth/, run command:
"make really_clean; make".

---------
3. How to load the test circuit bit file to NetFPGA card and run the test?

Answer:
You must log on as "root" to load the bit file and run the test.
Follow the steps below.

 (a) Change the working directory to sub-directory synth/,
     run command: "nf_download nf2_top_par.bit".

 (b) Change the working directory to sub-directory sw/,
     run command: "make" to build executable program "throughput".

 (c) Take note for the PKT_DATA_WIDTH parameter used in the test circuit.
     Select an allowed combination of <system clk frequency select> and
     <pkt_data_width_bits> from the table below.

Allowed combinations of <system clk frequency select> and <pkt_data_width_bits>:
   ------------------------------|-------------------------
   <system clk frequency select> | <pkt_data_width_bits>
                  0              |          288
                  1              |          144
                  1              |          288
   ------------------------------|-------------------------

   Run command for your selected combination:
   "./throughput <system clk frequency select> <pkt_data_width_bits>".

   The program "throughput" prints on the monitor screen:
   (i)   Good: the cumulative number of attempts of writing all 32K blocks
         (2KB each block), reading and comparing w/o mismatch.
   (ii)  Bad: the cumulative number of attempts of writing all 32K blocks
         (2KB each block), reading and comparing with at least one mismatch.
   (iii) Iteration: the sum of Good and Bad.
   (iv)  The time-average measured throughput for user logic to access DDR2 DRAM
         from the moment "throughput" was run to the current time. The throughput
         includes both write and read to DDR2 DRAM.

