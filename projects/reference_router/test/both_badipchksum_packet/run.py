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

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

pkts = []
for portid in range(2):
    # set parameters
    if portid == 0:
        DA = routerMAC0
    else:
        DA = routerMAC1
    SA = "aa:bb:cc:dd:ee:ff"
    EtherType = 0x800
    TTL = 64
    DST_IP = "192.168.2.1";   #not in the lpm table
    SRC_IP = "192.168.0.1"
    VERSION = 0x4
    nextHopMAC = "dd:55:dd:66:dd:77"

    # precreate random packets
    portPkts = []
    for i in range(30):
        portPkts.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, EtherType=EtherType,
                                    dst_IP=DST_IP, src_IP=SRC_IP, TTL=TTL,
                                    pkt_len=random.randint(60,1514)))
        portPkts[i].chksum = 0
    pkts.append(portPkts)

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

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
            nftest_send_phy('nf2c0', sent_pkt)
        elif portid == 1:
            # send packet out of eth2->nf2c1
            nftest_send_phy('nf2c1', sent_pkt)
        else:
            print 'ERROR: Not a valid port'
    nftest_barrier()

    # Read the counters
    nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG(), 30)

    nftest_barrier()

nftest_finish()
