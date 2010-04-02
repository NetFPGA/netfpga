#define EVT_CAP_ENABLE_CAPTURE_REG              0x2000300
#define EVT_CAP_SEND_PKT_REG                    0x2000304
#define EVT_CAP_DST_MAC_HI_REG                  0x2000308
#define EVT_CAP_DST_MAC_LO_REG                  0x200030c
#define EVT_CAP_SRC_MAC_HI_REG                  0x2000310
#define EVT_CAP_SRC_MAC_LO_REG                  0x2000314
#define EVT_CAP_ETHERTYPE_REG                   0x2000318
#define EVT_CAP_IP_DST_REG                      0x200031c
#define EVT_CAP_IP_SRC_REG                      0x2000320
#define EVT_CAP_UDP_SRC_PORT_REG                0x2000330
#define EVT_CAP_UDP_DST_PORT_REG                0x2000334
#define EVT_CAP_OUTPUT_PORTS_REG                0x2000338
#define EVT_CAP_RESET_TIMERS_REG                0x200033c
#define EVT_CAP_MONITOR_MASK_REG                0x2000324
#define EVT_CAP_TIMER_RESOLUTION_REG            0x2000340
#define EVT_CAP_NUM_EVT_PKTS_SENT_REG           0x2000344
#define EVT_CAP_NUM_EVTS_SENT_REG               0x2000348
#define EVT_CAP_NUM_EVTS_DROPPED_REG            0x200032c
#define EVT_CAP_SIGNAL_ID_MASK_REG              0x2000328

// ethertype of our event packets
#define CAP_ETHERTYPE 0x9999

#define TS_EVENT        0x00000000
#define ST_EVENT        0x40000000
#define RM_EVENT        0x80000000
#define DR_EVENT        0xc0000000

#define EVENT_TYPE_MASK 0xc0000000
#define OQ_MASK         0x38000000
#define LENGTH_MASK     0x07f80000
#define TIME_MASK       0x0007ffff

#define OQ_SHIFT        27
#define LEN_SHIFT       19
