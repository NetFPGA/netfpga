
`ifndef _NF21_DEFINES_
 `define _NF21_DEFINES_ 1

 /* Common Functions */
`define LOG2_FUNC \
function integer log2; \
      input integer number; \
      begin \
         log2=0; \
         while(2**log2<number) begin \
            log2=log2+1; \
         end \
      end \
endfunction

`define CEILDIV_FUNC \
function integer ceildiv; \
      input integer num; \
      input integer divisor; \
      begin \
         if (num <= divisor) \
           ceildiv = 1; \
         else begin \
            ceildiv = num / divisor; \
            if (ceildiv * divisor < num) \
              ceildiv = ceildiv + 1; \
         end \
      end \
endfunction


 `define IO_QUEUE_STAGE_NUM   8'hff

 `define IOQ_BYTE_LEN_POS     0
 `define IOQ_SRC_PORT_POS     16
 `define IOQ_WORD_LEN_POS     32
 `define IOQ_DST_PORT_POS     48

 `define NF2_BASE_ADDR                    32'h0010_0000

/*********** THESE ARE ALL WORD ADDRESSES (note the <<2 when printing external addresses) ***********/

 // --- Define address ranges
 // 4 bits to identify blocks of size 64k words
 `define BLOCK_SIZE_64k_BLOCK_ADDR_WIDTH   4
 `define BLOCK_SIZE_64k_REG_ADDR_WIDTH     16

 // 2 bits to identify blocks of size 1M words
 `define BLOCK_SIZE_1M_BLOCK_ADDR_WIDTH  2
 `define BLOCK_SIZE_1M_REG_ADDR_WIDTH    20

 // 1 bit to identify blocks of size 4M words
 `define BLOCK_SIZE_4M_BLOCK_ADDR_WIDTH  1
 `define BLOCK_SIZE_4M_REG_ADDR_WIDTH    22

 // 1 bit to identify blocks of size 8M words
 `define BLOCK_SIZE_8M_BLOCK_ADDR_WIDTH  1
 `define BLOCK_SIZE_8M_REG_ADDR_WIDTH    23

 // 1 bit to identify blocks of size 16M words
 `define BLOCK_SIZE_16M_BLOCK_ADDR_WIDTH  1
 `define BLOCK_SIZE_16M_REG_ADDR_WIDTH    24



/*********************************************************
 * useful macros
 *********************************************************/
 `define REG_END(addr_num)   `CPCI_NF2_DATA_WIDTH*((addr_num)+1)-1
 `define REG_START(addr_num) `CPCI_NF2_DATA_WIDTH*(addr_num)

 // Extract a word of width "width" from a flat bus
 //
 // Note: word 0 is assumed to occupy the LSBs of the bus
 `define WORD(word, width)    (word) * (width) +: (width)
 `define WORD2(word, width)    (word) * (width) + 0

`include "udp_defines.v"

`endif //  `ifndef _NF21_DEFINES_
