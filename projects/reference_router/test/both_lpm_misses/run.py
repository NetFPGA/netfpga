#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop0 = ('../connections/2phy', [])

nftest_init([phy2loop0])
nftest_start()

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

for i in range(32):
    nftest_invalidate_LPM_table_entry('nf2c0', i)
for i in range(32):
    nftest_invalidate_ARP_table_entry('nf2c0', i)

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

index = 0
subnetIP = "192.168.1.0"
subnetMask = "255.255.255.0"
nextHopIP = "192.168.1.54"
outPort = 0x4
nextHopMAC = "dd:55:dd:66:dd:77"

nftest_add_LPM_table_entry('nf2c0', index, subnetIP, subnetMask, nextHopIP, outPort)

nftest_add_ARP_table_entry('nf2c0', index, nextHopIP, nextHopMAC)

nftest_barrier()

for i in range(100):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC0,
                      EtherType=0x800, src_IP="192.168.0.1",
                      dst_IP="192.168.2.1", TTL=64)

    nftest_send_phy('nf2c0', pkt)
    nftest_expect_dma('nf2c0', pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_LPM_NUM_MISSES_REG(), 100)

nftest_finish()
