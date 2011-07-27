#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop0 = ('../connections/2phy', [])

nftest_init([phy2loop0])
nftest_start()

routerMAC = ["00:ca:fe:00:00:01", "00:ca:fe:00:00:02", "00:ca:fe:00:00:03", "00:ca:fe:00:00:04"]
routerIP = ["192.168.0.40", "192.168.1.40", "192.168.2.40", "192.168.3.40"]
dstIP = ["192.168.0.50", "192.168.1.50", "192.168.2.50", "192.168.3.50"]
dstMAC = ["aa:bb:cc:dd:ee:01", "aa:bb:cc:dd:ee:02", "aa:bb:cc:dd:ee:03", "aa:bb:cc:dd:ee:04"]

ALLSPFRouters = "224.0.0.5"

pkts = []
for portid in range(2):
    # set parameters
    DA = routerMAC[portid]
    SA = "aa:bb:cc:dd:ee:ff"
    EtherType = 0x800
    TTL = 64
    DST_IP = dstIP[0]
    SRC_IP = "192.168.0.1"
    VERSION = 0x4
    nextHopMAC = "dd:55:dd:66:dd:77"

    # precreate random packets
    portPkts = []
    for i in range(30):
        portPkts.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA,
                                    EtherType=EtherType, src_IP=SRC_IP,
                                    dst_IP=DST_IP, TTL=TTL,
                                    pkt_len=random.randint(60,1514)))
    pkts.append(portPkts)

# Clear all tables in a hardware test (not needed in software)
if isHW():
    nftest_invalidate_all_tables()

# Write the mac and IP addresses
for port in range(4):
    nftest_add_dst_ip_filter_entry (port, routerIP[port])
    nftest_set_router_MAC ('nf2c%d'%port, routerMAC[port])
nftest_add_dst_ip_filter_entry (4, ALLSPFRouters)
nftest_add_dst_ip_filter_entry (5, dstIP[0])

for portid in range(2):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 0)

    nftest_barrier()

    # loop for 30 packets
    for i in range(30):
        sent_pkt = pkts[portid][i]
        nftest_send_phy('nf2c%d'%portid, sent_pkt)
        nftest_expect_dma('nf2c%d'%portid, sent_pkt)
    nftest_barrier()

    # Read the counters
    nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 30)

    nftest_barrier()

nftest_finish()
