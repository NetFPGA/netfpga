#!/bin/env python

from NFTestLib import *
from PacketLib import *

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

import simPkt

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

# load packets from pcap files
NUM_PKTS = 1#0#from make_pkts import NUM_PKTS
pkts = []
pkts.append(scapy.rdpcap("pkts0.pcap"))
pkts.append(scapy.rdpcap("pkts1.pcap"))
pkts.append(scapy.rdpcap("pkts2.pcap"))
pkts.append(scapy.rdpcap("pkts3.pcap"))

pkt = None
totalPktLengths = [0,0,0,0]
# send NUM_PKTS from ports nf2c0...nf2c3
for i in range(NUM_PKTS):
    for port in range(4):
        totalPktLengths[port] += len(pkts[port][i])
        nftest_send('nf2c' + str(port), pkts[port][i])
        nftest_expect('nf2c' + str(port), pkts[port][i])
        simPkt.pktSendPHY(port + 1, pkts[port][i])
        simPkt.pktExpectDMA(port + 1, pkts[port][i])

nftest_barrier()

# check counter values
for i in range(4):
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + i*0x40000, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + i*0x40000, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])

nftest_finish()
