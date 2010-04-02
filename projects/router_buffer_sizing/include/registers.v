///////////////////////////////////////////////////////////////////////////////
//
// Module: registers.v
// Project: router_buffer_sizing
// Description: Project specific register defines
//
///////////////////////////////////////////////////////////////////////////////

// -------------------------------------
//   Constants
// -------------------------------------

// ===== File: lib/verilog/common/xml/global.xml =====

// Maximum number of phy ports
`define MAX_PHY_PORTS                             4

// PCI address bus width
`define PCI_ADDR_WIDTH                            32

// PCI data bus width
`define PCI_DATA_WIDTH                            32

// PCI byte enable bus width
`define PCI_BE_WIDTH                              4

// CPCI--CNET address bus width. This is byte addresses even though bottom bits are zero.
`define CPCI_CNET_ADDR_WIDTH                      27

// CPCI--CNET data bus width
`define CPCI_CNET_DATA_WIDTH                      32

// CPCI--Virtex address bus width. This is byte addresses even though bottom bits are zero.
`define CPCI_NF2_ADDR_WIDTH                       27

// CPCI--Virtex data bus width
`define CPCI_NF2_DATA_WIDTH                       32

// DMA data bus width
`define DMA_DATA_WIDTH                            32

// DMA control bus width
`define DMA_CTRL_WIDTH                            4

// CPCI debug bus width
`define CPCI_DEBUG_DATA_WIDTH                     29

// SRAM address width
`define SRAM_ADDR_WIDTH                           19

// SRAM data width
`define SRAM_DATA_WIDTH                           36

// DRAM address width
`define DRAM_ADDR_WIDTH                           24


// ===== File: lib/verilog/common/xml/nf_defines.xml =====

// Clock period of 125 MHz clock in ns
`define FAST_CLK_PERIOD                           8

// Clock period of 62.5 MHz clock in ns
`define SLOW_CLK_PERIOD                           16

// Header value used by the IO queues
`define IO_QUEUE_STAGE_NUM                        8'hff

// Data path data width
`define DATA_WIDTH                                64

// Data path control width
`define CTRL_WIDTH                                8


// ===== File: lib/verilog/output_queues/sram_rr_output_queues/xml/sram_rr_output_queues.xml =====

`define NUM_OUTPUT_QUEUES                         8

`define OQ_DEFAULT_MAX_PKTS                       19'h7ffff

`define OQ_SRAM_PKT_CNT_WIDTH                     19

`define OQ_SRAM_WORD_CNT_WIDTH                    19

`define OQ_SRAM_BYTE_CNT_WIDTH                    19

`define OQ_ENABLE_SEND_BIT_NUM                    0

`define OQ_INITIALIZE_OQ_BIT_NUM                  1


// ===== File: lib/verilog/output_port_lookup/cam_router/xml/cam_router.xml =====

// Number of entrties in the ARP table
`define ROUTER_OP_LUT_ARP_TABLE_DEPTH             32

// Number of entrties in the routing table table
`define ROUTER_OP_LUT_ROUTE_TABLE_DEPTH           32

// Number of entrties in the destination IP filter table
`define ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH   32

// Default MAC address for port 0
`define ROUTER_OP_LUT_DEFAULT_MAC_0               48'hcafef00d0001
`define ROUTER_OP_LUT_DEFAULT_MAC_0_HI            32'hcafe
`define ROUTER_OP_LUT_DEFAULT_MAC_0_LO            32'hf00d0001

// Default MAC address for port 1
`define ROUTER_OP_LUT_DEFAULT_MAC_1               48'hcafef00d0002
`define ROUTER_OP_LUT_DEFAULT_MAC_1_HI            32'hcafe
`define ROUTER_OP_LUT_DEFAULT_MAC_1_LO            32'hf00d0002

// Default MAC address for port 2
`define ROUTER_OP_LUT_DEFAULT_MAC_2               48'hcafef00d0003
`define ROUTER_OP_LUT_DEFAULT_MAC_2_HI            32'hcafe
`define ROUTER_OP_LUT_DEFAULT_MAC_2_LO            32'hf00d0003

// Default MAC address for port 3
`define ROUTER_OP_LUT_DEFAULT_MAC_3               48'hcafef00d0004
`define ROUTER_OP_LUT_DEFAULT_MAC_3_HI            32'hcafe
`define ROUTER_OP_LUT_DEFAULT_MAC_3_LO            32'hf00d0004


// ===== File: lib/verilog/utils/xml/device_id_reg.xml =====

// Total number of registers
`define DEV_ID_NUM_REGS                           32

// Number of non string registers
`define DEV_ID_NON_DEV_STR_REGS                   7

// Device description length (in words, not chars)
`define DEV_ID_DEV_STR_WORD_LEN                   25

// Device description length (in bytes/chars)
`define DEV_ID_DEV_STR_BYTE_LEN                   100

// Device description length (in bits)
`define DEV_ID_DEV_STR_BIT_LEN                    800

// Length of MD5 sum (bits)
`define DEV_ID_MD5SUM_LENGTH                      128

// MD5 sum of the string "device_id.v"
`define DEV_ID_MD5_VALUE                          128'h4071736d8a603d2b4d55f62989a73c95
`define DEV_ID_MD5_VALUE_0                        32'h4071736d
`define DEV_ID_MD5_VALUE_1                        32'h8a603d2b
`define DEV_ID_MD5_VALUE_2                        32'h4d55f629
`define DEV_ID_MD5_VALUE_3                        32'h89a73c95


// ===== File: lib/verilog/io_queues/ethernet_mac/xml/ethernet_mac.xml =====

// TX queue disable bit
`define MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM          0

// RX queue disable bit
`define MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM          1

// Reset MAC bit
`define MAC_GRP_RESET_MAC_BIT_NUM                 2

// MAC TX queue disable bit
`define MAC_GRP_MAC_DISABLE_TX_BIT_NUM            3

// MAC RX queue disable bit
`define MAC_GRP_MAC_DISABLE_RX_BIT_NUM            4

// MAC disable jumbo TX bit
`define MAC_GRP_MAC_DIS_JUMBO_TX_BIT_NUM          5

// MAC disable jumbo RX bit
`define MAC_GRP_MAC_DIS_JUMBO_RX_BIT_NUM          6

// MAC disable crc check disable bit
`define MAC_GRP_MAC_DIS_CRC_CHECK_BIT_NUM         7

// MAC disable crc generate bit
`define MAC_GRP_MAC_DIS_CRC_GEN_BIT_NUM           8



// -------------------------------------
//   Modules
// -------------------------------------

// Tag/address widths
`define CORE_BLOCK_ADDR_WIDTH           1
`define CORE_REG_ADDR_WIDTH             22
`define CPU_QUEUE_BLOCK_ADDR_WIDTH      4
`define CPU_QUEUE_REG_ADDR_WIDTH        16
`define DEV_ID_BLOCK_ADDR_WIDTH         4
`define DEV_ID_REG_ADDR_WIDTH           16
`define DMA_BLOCK_ADDR_WIDTH            4
`define DMA_REG_ADDR_WIDTH              16
`define DRAM_BLOCK_ADDR_WIDTH           1
`define DRAM_REG_ADDR_WIDTH             24
`define EVT_CAP_BLOCK_ADDR_WIDTH        17
`define EVT_CAP_REG_ADDR_WIDTH          6
`define IN_ARB_BLOCK_ADDR_WIDTH         17
`define IN_ARB_REG_ADDR_WIDTH           6
`define MAC_GRP_BLOCK_ADDR_WIDTH        4
`define MAC_GRP_REG_ADDR_WIDTH          16
`define MDIO_BLOCK_ADDR_WIDTH           4
`define MDIO_REG_ADDR_WIDTH             16
`define OQ_BLOCK_ADDR_WIDTH             13
`define OQ_REG_ADDR_WIDTH               10
`define RATE_LIMIT_BLOCK_ADDR_WIDTH     19
`define RATE_LIMIT_REG_ADDR_WIDTH       4
`define ROUTER_OP_LUT_BLOCK_ADDR_WIDTH  17
`define ROUTER_OP_LUT_REG_ADDR_WIDTH    6
`define SRAM_BLOCK_ADDR_WIDTH           1
`define SRAM_REG_ADDR_WIDTH             22
`define STRIP_HEADERS_BLOCK_ADDR_WIDTH  17
`define STRIP_HEADERS_REG_ADDR_WIDTH    6
`define UDP_BLOCK_ADDR_WIDTH            1
`define UDP_REG_ADDR_WIDTH              23

// Module tags
`define CORE_BLOCK_ADDR           1'h0
`define DEV_ID_BLOCK_ADDR         4'h0
`define MDIO_BLOCK_ADDR           4'h1
`define DMA_BLOCK_ADDR            4'h4
`define MAC_GRP_0_BLOCK_ADDR      4'h8
`define MAC_GRP_1_BLOCK_ADDR      4'h9
`define MAC_GRP_2_BLOCK_ADDR      4'ha
`define MAC_GRP_3_BLOCK_ADDR      4'hb
`define CPU_QUEUE_0_BLOCK_ADDR    4'hc
`define CPU_QUEUE_1_BLOCK_ADDR    4'hd
`define CPU_QUEUE_2_BLOCK_ADDR    4'he
`define CPU_QUEUE_3_BLOCK_ADDR    4'hf
`define SRAM_BLOCK_ADDR           1'h1
`define UDP_BLOCK_ADDR            1'h1
`define STRIP_HEADERS_BLOCK_ADDR  17'h00000
`define ROUTER_OP_LUT_BLOCK_ADDR  17'h00001
`define IN_ARB_BLOCK_ADDR         17'h00002
`define RATE_LIMIT_0_BLOCK_ADDR   19'h0000c
`define RATE_LIMIT_1_BLOCK_ADDR   19'h0000d
`define RATE_LIMIT_2_BLOCK_ADDR   19'h0000e
`define RATE_LIMIT_3_BLOCK_ADDR   19'h0000f
`define EVT_CAP_BLOCK_ADDR        17'h00004
`define OQ_BLOCK_ADDR             13'h0001
`define DRAM_BLOCK_ADDR           1'h1


// -------------------------------------
//   Registers
// -------------------------------------

// Name: cpu_dma_queue
// Description: CPU DMA queue
// File: lib/verilog/io_queues/cpu_dma_queue/xml/cpu_dma_queue.xml

// Name: device_id
// Description: Device identification
// File: lib/verilog/utils/xml/device_id_reg.xml
`define DEV_ID_MD5_0       16'h0
`define DEV_ID_MD5_1       16'h1
`define DEV_ID_MD5_2       16'h2
`define DEV_ID_MD5_3       16'h3
`define DEV_ID_DEVICE_ID   16'h4
`define DEV_ID_REVISION    16'h5
`define DEV_ID_CPCI_ID     16'h6
`define DEV_ID_DEV_STR_0   16'h7
`define DEV_ID_DEV_STR_1   16'h8
`define DEV_ID_DEV_STR_2   16'h9
`define DEV_ID_DEV_STR_3   16'ha
`define DEV_ID_DEV_STR_4   16'hb
`define DEV_ID_DEV_STR_5   16'hc
`define DEV_ID_DEV_STR_6   16'hd
`define DEV_ID_DEV_STR_7   16'he
`define DEV_ID_DEV_STR_8   16'hf
`define DEV_ID_DEV_STR_9   16'h10
`define DEV_ID_DEV_STR_10  16'h11
`define DEV_ID_DEV_STR_11  16'h12
`define DEV_ID_DEV_STR_12  16'h13
`define DEV_ID_DEV_STR_13  16'h14
`define DEV_ID_DEV_STR_14  16'h15
`define DEV_ID_DEV_STR_15  16'h16
`define DEV_ID_DEV_STR_16  16'h17
`define DEV_ID_DEV_STR_17  16'h18
`define DEV_ID_DEV_STR_18  16'h19
`define DEV_ID_DEV_STR_19  16'h1a
`define DEV_ID_DEV_STR_20  16'h1b
`define DEV_ID_DEV_STR_21  16'h1c
`define DEV_ID_DEV_STR_22  16'h1d
`define DEV_ID_DEV_STR_23  16'h1e
`define DEV_ID_DEV_STR_24  16'h1f

// Name: dma
// Description: DMA transfer module
// File: lib/verilog/dma/xml/dma.xml

// Name: event_capture
// Description: Event Capture Registers
// File: lib/verilog/event_capture/xml/event_capture.xml
`define EVT_CAP_ENABLE_CAPTURE     6'h0
`define EVT_CAP_SEND_PKT           6'h1
`define EVT_CAP_DST_MAC_HI         6'h2
`define EVT_CAP_DST_MAC_LO         6'h3
`define EVT_CAP_SRC_MAC_HI         6'h4
`define EVT_CAP_SRC_MAC_LO         6'h5
`define EVT_CAP_ETHERTYPE          6'h6
`define EVT_CAP_IP_DST             6'h7
`define EVT_CAP_IP_SRC             6'h8
`define EVT_CAP_MONITOR_MASK       6'h9
`define EVT_CAP_SIGNAL_ID_MASK     6'ha
`define EVT_CAP_NUM_EVTS_DROPPED   6'hb
`define EVT_CAP_UDP_SRC_PORT       6'hc
`define EVT_CAP_UDP_DST_PORT       6'hd
`define EVT_CAP_OUTPUT_PORTS       6'he
`define EVT_CAP_RESET_TIMERS       6'hf
`define EVT_CAP_TIMER_RESOLUTION   6'h10
`define EVT_CAP_NUM_EVT_PKTS_SENT  6'h11
`define EVT_CAP_NUM_EVTS_SENT      6'h12

// Name: in_arb
// Description: Round-robin input arbiter
// File: lib/verilog/input_arbiter/rr_input_arbiter/xml/rr_input_arbiter.xml
`define IN_ARB_NUM_PKTS_SENT       6'h0
`define IN_ARB_LAST_PKT_WORD_0_HI  6'h1
`define IN_ARB_LAST_PKT_WORD_0_LO  6'h2
`define IN_ARB_LAST_PKT_CTRL_0     6'h3
`define IN_ARB_LAST_PKT_WORD_1_HI  6'h4
`define IN_ARB_LAST_PKT_WORD_1_LO  6'h5
`define IN_ARB_LAST_PKT_CTRL_1     6'h6
`define IN_ARB_STATE               6'h7

// Name: mdio
// Description: MDIO interface
// File: lib/verilog/io/mdio/xml/mdio.xml
//   Register group: PHY
//
//   Address decompositions:
//     - Inst:  Addresses of the *instances* within the module
`define MDIO_PHY_INST_BLOCK_ADDR_WIDTH    11
`define MDIO_PHY_INST_REG_ADDR_WIDTH      5

`define MDIO_PHY_0_INST_BLOCK_ADDR  11'd0
`define MDIO_PHY_1_INST_BLOCK_ADDR  11'd1
`define MDIO_PHY_2_INST_BLOCK_ADDR  11'd2
`define MDIO_PHY_3_INST_BLOCK_ADDR  11'd3

`define MDIO_PHY_CONTROL                                 5'h0
`define MDIO_PHY_STATUS                                  5'h1
`define MDIO_PHY_PHY_ID_0                                5'h2
`define MDIO_PHY_PHY_ID_1                                5'h3
`define MDIO_PHY_AUTONEGOTIATION_ADVERT                  5'h4
`define MDIO_PHY_AUTONEG_LINK_PARTNER_BASE_PAGE_ABILITY  5'h5
`define MDIO_PHY_AUTONEG_EXPANSION                       5'h6
`define MDIO_PHY_AUTONEG_NEXT_PAGE_TX                    5'h7
`define MDIO_PHY_AUTONEG_LINK_PARTNER_RCVD_NEXT_PAGE     5'h8
`define MDIO_PHY_MASTER_SLAVE_CTRL                       5'h9
`define MDIO_PHY_MASTER_SLAVE_STATUS                     5'ha
`define MDIO_PHY_PSE_CTRL                                5'hb
`define MDIO_PHY_PSE_STATUS                              5'hc
`define MDIO_PHY_MMD_ACCESS_CTRL                         5'hd
`define MDIO_PHY_MMD_ACCESS_STATUS                       5'he
`define MDIO_PHY_EXTENDED_STATUS                         5'hf


// Name: nf2_mac_grp
// Description: Ethernet MAC group
// File: lib/verilog/io_queues/ethernet_mac/xml/ethernet_mac.xml
`define MAC_GRP_CONTROL                         16'h0
`define MAC_GRP_RX_QUEUE_NUM_PKTS_IN_QUEUE      16'h1
`define MAC_GRP_RX_QUEUE_NUM_PKTS_STORED        16'h2
`define MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_FULL  16'h3
`define MAC_GRP_RX_QUEUE_NUM_PKTS_DROPPED_BAD   16'h4
`define MAC_GRP_RX_QUEUE_NUM_PKTS_DEQUEUED      16'h5
`define MAC_GRP_RX_QUEUE_NUM_WORDS_PUSHED       16'h6
`define MAC_GRP_RX_QUEUE_NUM_BYTES_PUSHED       16'h7
`define MAC_GRP_TX_QUEUE_NUM_PKTS_IN_QUEUE      16'h8
`define MAC_GRP_TX_QUEUE_NUM_PKTS_ENQUEUED      16'h9
`define MAC_GRP_TX_QUEUE_NUM_PKTS_SENT          16'ha
`define MAC_GRP_TX_QUEUE_NUM_WORDS_PUSHED       16'hb
`define MAC_GRP_TX_QUEUE_NUM_BYTES_PUSHED       16'hc

// Name: output_queues
// Description: SRAM-based output queue using round-robin removal
// File: lib/verilog/output_queues/sram_rr_output_queues/xml/sram_rr_output_queues.xml
//   Register group: QUEUE
//
//   Address decompositions:
//     - Inst:  Addresses of the *instances* within the module
`define OQ_QUEUE_INST_BLOCK_ADDR_WIDTH    3
`define OQ_QUEUE_INST_REG_ADDR_WIDTH      7

`define OQ_QUEUE_0_INST_BLOCK_ADDR  3'd0
`define OQ_QUEUE_1_INST_BLOCK_ADDR  3'd1
`define OQ_QUEUE_2_INST_BLOCK_ADDR  3'd2
`define OQ_QUEUE_3_INST_BLOCK_ADDR  3'd3
`define OQ_QUEUE_4_INST_BLOCK_ADDR  3'd4
`define OQ_QUEUE_5_INST_BLOCK_ADDR  3'd5
`define OQ_QUEUE_6_INST_BLOCK_ADDR  3'd6
`define OQ_QUEUE_7_INST_BLOCK_ADDR  3'd7

`define OQ_QUEUE_CTRL                        7'h0
`define OQ_QUEUE_NUM_PKT_BYTES_STORED        7'h1
`define OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED   7'h2
`define OQ_QUEUE_NUM_PKT_BYTES_REMOVED       7'h3
`define OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED  7'h4
`define OQ_QUEUE_NUM_PKTS_STORED             7'h5
`define OQ_QUEUE_NUM_PKTS_DROPPED            7'h6
`define OQ_QUEUE_NUM_PKTS_REMOVED            7'h7
`define OQ_QUEUE_ADDR_LO                     7'h8
`define OQ_QUEUE_ADDR_HI                     7'h9
`define OQ_QUEUE_RD_ADDR                     7'ha
`define OQ_QUEUE_WR_ADDR                     7'hb
`define OQ_QUEUE_NUM_PKTS_IN_Q               7'hc
`define OQ_QUEUE_MAX_PKTS_IN_Q               7'hd
`define OQ_QUEUE_NUM_WORDS_IN_Q              7'he
`define OQ_QUEUE_NUM_WORDS_LEFT              7'hf
`define OQ_QUEUE_FULL_THRESH                 7'h10


// Name: rate_limiter
// Description: Event Capture Registers
// File: lib/verilog/rate_limiter/xml/rate_limiter.xml
`define RATE_LIMIT_ENABLE  4'h0
`define RATE_LIMIT_SHIFT   4'h1

// Name: router_op_lut
// Description: Output port lookup for IPv4 router (CAM based)
// File: lib/verilog/output_port_lookup/cam_router/xml/cam_router.xml
`define ROUTER_OP_LUT_ARP_NUM_MISSES                 6'h0
`define ROUTER_OP_LUT_LPM_NUM_MISSES                 6'h1
`define ROUTER_OP_LUT_NUM_CPU_PKTS_SENT              6'h2
`define ROUTER_OP_LUT_NUM_BAD_OPTS_VER               6'h3
`define ROUTER_OP_LUT_NUM_BAD_CHKSUMS                6'h4
`define ROUTER_OP_LUT_NUM_BAD_TTLS                   6'h5
`define ROUTER_OP_LUT_NUM_NON_IP_RCVD                6'h6
`define ROUTER_OP_LUT_NUM_PKTS_FORWARDED             6'h7
`define ROUTER_OP_LUT_NUM_WRONG_DEST                 6'h8
`define ROUTER_OP_LUT_NUM_FILTERED_PKTS              6'h9
`define ROUTER_OP_LUT_MAC_0_HI                       6'ha
`define ROUTER_OP_LUT_MAC_0_LO                       6'hb
`define ROUTER_OP_LUT_MAC_1_HI                       6'hc
`define ROUTER_OP_LUT_MAC_1_LO                       6'hd
`define ROUTER_OP_LUT_MAC_2_HI                       6'he
`define ROUTER_OP_LUT_MAC_2_LO                       6'hf
`define ROUTER_OP_LUT_MAC_3_HI                       6'h10
`define ROUTER_OP_LUT_MAC_3_LO                       6'h11
`define ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP           6'h12
`define ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK         6'h13
`define ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP  6'h14
`define ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT  6'h15
`define ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR            6'h16
`define ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR            6'h17
`define ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI         6'h18
`define ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO         6'h19
`define ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP    6'h1a
`define ROUTER_OP_LUT_ARP_TABLE_RD_ADDR              6'h1b
`define ROUTER_OP_LUT_ARP_TABLE_WR_ADDR              6'h1c
`define ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP   6'h1d
`define ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR    6'h1e
`define ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR    6'h1f

// Name: strip_headers
// Description: Strip headers from data
// File: lib/verilog/strip_headers/keep_length/xml/strip_headers.xml



// -------------------------------------
//   Bitmasks
// -------------------------------------

// Type: oq_control
// File: lib/verilog/output_queues/sram_rr_output_queues/xml/sram_rr_output_queues.xml
`define OQ_CONTROL_ENABLE_SEND     0
`define OQ_CONTROL_INITIALIZE_OQ   1

// Type: mii_ctrl
// Description: MII control register
// File: lib/verilog/io/mdio/xml/mdio.xml
`define MII_CTRL_RESET               15
`define MII_CTRL_INTERNAL_LOOPBACK   14
`define MII_CTRL_SPEED_SEL_LO        13
`define MII_CTRL_AUTONEG_ENABLE      12
`define MII_CTRL_PWR_DOWN            11
`define MII_CTRL_ISOLATE             10
`define MII_CTRL_RESTART_AUTONEG     9
`define MII_CTRL_DUPLEX_MODE         8
`define MII_CTRL_COLLISION_TEST_EN   7
`define MII_CTRL_SPEED_SEL_HI        6

// Type: mii_status
// Description: MII status register
// File: lib/verilog/io/mdio/xml/mdio.xml
`define MII_STATUS_100BASE_T4_CAPABLE            15
`define MII_STATUS_100BASE_X_FULL_DPLX_CAPABLE   14
`define MII_STATUS_100BASE_X_HALF_DPLX_CAPABLE   13
`define MII_STATUS_10BASE_T_FULL_DPLX_CAPABLE    12
`define MII_STATUS_10BASE_T_HALF_DPLX_CAPABLE    11
`define MII_STATUS_10BASE_T2_FULL_DPLX_CAPABLE   10
`define MII_STATUS_10BASE_T2_HALF_DPLX_CAPABLE   9
`define MII_STATUS_EXTENDED_STATUS               8
`define MII_STATUS_MF_PREAMBLE_SUPPRESS          6
`define MII_STATUS_AUTONEG_COMPLETE              5
`define MII_STATUS_REMOTE_FAULT                  4
`define MII_STATUS_AUTONEG_ABILITY               3
`define MII_STATUS_LINK_STATUS                   2
`define MII_STATUS_JABBER_DETECT                 1
`define MII_STATUS_EXTENDED_CAPABILITY           0

// Type: mac_grp_control
// Description: MAC group control register
// File: lib/verilog/io_queues/ethernet_mac/xml/ethernet_mac.xml
`define MAC_GRP_CONTROL_TX_QUEUE_DISABLE        0
`define MAC_GRP_CONTROL_RX_QUEUE_DISABLE        1
`define MAC_GRP_CONTROL_RESET_MAC               2
`define MAC_GRP_CONTROL_MAC_DISABLE_TX          3
`define MAC_GRP_CONTROL_MAC_DISABLE_RX          4
`define MAC_GRP_CONTROL_MAC_DISABLE_JUMBO_TX    5
`define MAC_GRP_CONTROL_MAC_DISABLE_JUMBO_RX    6
`define MAC_GRP_CONTROL_MAC_DISABLE_CRC_CHECK   7
`define MAC_GRP_CONTROL_MAC_DISABLE_CRC_GEN     8



