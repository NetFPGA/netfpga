#!/bin/env python

from NFTestLib import *
from PacketLib import *

from RegressRouterLib import *

import random

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

dstIP0 = "192.168.0.50"
dstIP1 = "192.168.1.50"
dstIP2 = "192.168.2.50"
dstIP3 = "192.168.3.50"

dstMAC0 = "aa:bb:cc:dd:ee:01"
dstMAC1 = "aa:bb:cc:dd:ee:02"
dstMAC2 = "aa:bb:cc:dd:ee:03"
dstMAC3 = "aa:bb:cc:dd:ee:04"

ALLSPFRouters = "224.0.0.5"

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)
nftest_add_dst_ip_filter_entry ('nf2c0', 4, ALLSPFRouters)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

if isHW():
    nftest_regread_expect(reg_defines.MDIO_PHY_0_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_1_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_2_CONTROL_REG(), 0x5140)
    nftest_regread_expect(reg_defines.MDIO_PHY_3_CONTROL_REG(), 0x5140)

NUM_PKTS = 20

# add destinations to be filtered to the software
nftest_add_dst_ip_filter_entry ('nf2c0', 5, dstIP0)
nftest_add_dst_ip_filter_entry ('nf2c0', 6, dstIP1)
nftest_add_dst_ip_filter_entry ('nf2c0', 7, dstIP2)

nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 0)

nftest_barrier()

precreated0 = scapy.rdpcap('precreated0.pcap')
precreated1 = scapy.rdpcap('precreated1.pcap')

for i in range(NUM_PKTS):
    pkt = precreated0[i]
    nftest_send('eth1', pkt)
    nftest_expect('nf2c0', pkt)

    pkt = precreated1[i]
    nftest_send('eth2', pkt)
    nftest_expect('nf2c1', pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 2*NUM_PKTS)

nftest_invalidate_dst_ip_filter_entry('nf2c0', 5)
nftest_add_LPM_table_entry('nf2c0', 0, dstIP0, "255.255.255.0", "0.0.0.0", 0x04) # send out MAC1
nftest_add_ARP_table_entry('nf2c0', 0, dstIP0, dstMAC0)

expected0 = scapy.rdpcap('expected0.pcap')
expected1 = scapy.rdpcap('expected1.pcap')

nftest_barrier()

for i in range(NUM_PKTS):
    pkt = precreated0[i]
    nftest_send('eth1', pkt)
    if pkt[scapy.IP].dst == dstIP0:
        nftest_expect('eth2', expected0[i])
    else:
        nftest_expect('nf2c0', pkt)

    pkt = precreated1[i]
    nftest_send('eth2', pkt)
    if pkt[scapy.IP].dst == dstIP0:
        nftest_expect('eth2', expected1[i])
    else:
        nftest_expect('nf2c1', pkt)

nftest_barrier()

nftest_invalidate_LPM_table_entry('nf2c0', 0)
nftest_invalidate_ARP_table_entry('nf2c0', 0)

nftest_barrier()

total_errors = nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
