#!/bin/env python

from NFTestLib import *
from PacketLib import *

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

# load packets from pcap files
from make_pkts import NUM_PKTS
pkts = []
pkts.append(scapy.rdpcap("pkts0.pcap"))
pkts.append(scapy.rdpcap("pkts1.pcap"))
pkts.append(scapy.rdpcap("pkts2.pcap"))
pkts.append(scapy.rdpcap("pkts3.pcap"))

print "Sending now: "
pkt = None
totalPktLengths = [0,0,0,0]
# send NUM_PKTS from ports nf2c0...nf2c3
for i in range(NUM_PKTS):
    sys.stdout.write('\r'+str(i))
    sys.stdout.flush()
    for port in range(4):
        totalPktLengths[port] += len(pkts[port][i])
        nftest_send('nf2c' + str(port), pkts[port][i])
        nftest_expect('nf2c' + str(port), pkts[port][i])

print ""

nftest_barrier()

total_errors = 0

print "Checking pkt errors"
# check counter values
for i in range(4):
    reg_data = 0
    reg_data = nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + i*0x40000, NUM_PKTS)

    if reg_data != NUM_PKTS:
        total_errors += 1
        print "ERROR: MAC Queue ", str(i), " counters are wrong"
        print "   Rx pkts stored: ", str(reg_data), "     expected: ", str(NUM_PKTS)

    reg_data = nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + i*0x40000, NUM_PKTS)

    if reg_data != NUM_PKTS:
        total_errors += 1
        print "ERROR: MAC Queue ", str(i), " counters are wrong"
        print "   Tx pkts sent: ", str(reg_data), "     expected: ", str(NUM_PKTS)


    reg_data = nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])

    if reg_data != totalPktLengths[i]:
        total_errors += 1
        print "ERROR: MAC Queue ", str(i), " counters are wrong"
        print "   Rx pkts pushed: ", str(reg_data), "     expected: ", str(totalPktLengths[i])


    reg_data = nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])

    if reg_data != totalPktLengths[i]:
        total_errors += 1
        print "ERROR: MAC Queue ", str(i), " counters are wrong"
        print "   Tx pkts pushed: ", str(reg_data), "     expected: ", str(totalPktLengths[i])

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
