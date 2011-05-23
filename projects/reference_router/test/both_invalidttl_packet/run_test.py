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

pkts = []
pkts.append(scapy.rdpcap('eth1_pkts.pcap'))
pkts.append(scapy.rdpcap('eth2_pkts.pcap'))

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

total_errors = 0
temp_val = 0

for portid in range(2):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_WRONG_DEST_REG(), 0)
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG(), 0)
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG(), 0)
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_BAD_TTLS_REG(), 0)
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG(), 0)
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 0)

    nftest_barrier()

    # loop for 30 packets
    for i in range(30):
        sent_pkt = pkts[portid][i]
        if portid == 0:
            # send packet out of eth1->nf2c0
            nftest_send('eth1', sent_pkt)
            nftest_expect('nf2c0', sent_pkt)
        elif portid == 1:
            # send packet out of eth2->nf2c1
            nftest_send('eth2', sent_pkt)
            nftest_expect('nf2c1', sent_pkt)
        else:
            print 'ERROR: Not a valid port'
    nftest_barrier()

    # Read the counters
    temp_val = nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_BAD_TTLS_REG(), 30)
    if isHW():
        if temp_val != 30:
            print 'Expected 30 TTL < 1  packets.  Received ' + str(temp_val)
            total_errors += 1

    nftest_barrier()

nftest_barrier()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
