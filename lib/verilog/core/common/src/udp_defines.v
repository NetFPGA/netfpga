`ifndef _UDP_DEFINES_
 `define _UDP_DEFINES_ 1

 // Each SRAM is 2MB (512k x 36 bits)
 // Carve it up to equal parts for each output queue
 `define OQ_DEFAULT_ADDR_LOW(j, num_oqs)  ((j)*20'h8_0000/(num_oqs))
 `define OQ_DEFAULT_ADDR_HIGH(j, num_oqs) (((j+1)*20'h8_0000/(num_oqs)) - 1)

`endif //  `ifndef _UDP_DEFINES_


