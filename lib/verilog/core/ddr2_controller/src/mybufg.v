`timescale 1ns/100ps //added by sailaja

module mybufg (
                I,
                O
               );

//Input/Output declarations

input I;

output O;

//attribute syn_hier : string;
//attribute syn_hier of mybufg_arch: architecture is "hard";




//bufg u1 (I,O);
BUFG u1 (O,I);


endmodule




