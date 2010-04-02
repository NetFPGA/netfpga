/*********** THESE ARE ALL WORD ADDRESSES (note the <<2 when printing external addresses) ***********/

 `define DROP_NTH_SW_REG_ADDR_WIDTH      `UDP_BLOCK_SIZE_64_REG_ADDR_WIDTH
 `define DROP_NTH_SW_BLOCK_ADDR_WIDTH    `UDP_BLOCK_SIZE_64_BLOCK_ADDR_WIDTH
 `define DROP_NTH_SW_BLOCK_ADDR          `DROP_NTH_SW_BLOCK_ADDR_WIDTH'h7
 `define DROP_NTH_SW_BLOCK_TAG           ({`UDP_BLOCK_SIZE_64_TAG, `DROP_NTH_SW_BLOCK_ADDR})

 `define DROP_NTH_CNTRS_REG_ADDR_WIDTH   `UDP_BLOCK_SIZE_64_REG_ADDR_WIDTH
 `define DROP_NTH_CNTRS_BLOCK_ADDR_WIDTH `UDP_BLOCK_SIZE_64_BLOCK_ADDR_WIDTH
 `define DROP_NTH_CNTRS_BLOCK_ADDR       `DROP_NTH_CNTRS_BLOCK_ADDR_WIDTH'h8
 `define DROP_NTH_CNTRS_BLOCK_TAG        ({`UDP_BLOCK_SIZE_64_TAG, `DROP_NTH_CNTRS_BLOCK_ADDR})

/*******************************************************************
 -- Internal addresses -- these are used inside the modules
 *******************************************************************/

 `define DROP_NTH_PKT_EN     `DROP_NTH_SW_REG_ADDR_WIDTH'h0
 `define DROP_NTH_PKT        `DROP_NTH_SW_REG_ADDR_WIDTH'h1

 `define DROP_NTH_PKT_CNTR     `DROP_NTH_CNTRS_REG_ADDR_WIDTH'h0

/************************
  --- External addresses
 ************************/

 `define DROP_NTH_PKT_EN_REG         (`UDP_BASE_ADDRESS | {`DROP_NTH_SW_BLOCK_TAG, `DROP_NTH_PKT_EN})
 `define DROP_NTH_PKT_REG                                (`UDP_BASE_ADDRESS | {`DROP_NTH_SW_BLOCK_TAG, `DROP_NTH_PKT})
 `define DROP_NTH_PKT_CNTR_REG                           (`UDP_BASE_ADDRESS | {`DROP_NTH_CNTRS_BLOCK_TAG, `DROP_NTH_PKT_CNTR})



/************************
  --- Print the registers
 ************************/

`define PRINT_USER_REG_ADDRESSES                                                                                                                   \
    $fwrite(c_reg_defines_fd, "#define DROP_NTH_PKT_EN_REG                     0x%07x\n", `DROP_NTH_PKT_EN_REG<<2);               \
    $fwrite(c_reg_defines_fd, "#define DROP_NTH_PKT_REG                    0x%07x\n", `DROP_NTH_PKT_REG<<2);                \
    $fwrite(c_reg_defines_fd, "#define DROP_NTH_PKT_CNTR_REG                   0x%07x\n\n", `DROP_NTH_PKT_CNTR_REG<<2)

