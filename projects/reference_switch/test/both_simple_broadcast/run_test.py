#!/bin/env python

from NFTestLib import *
from NFTestHeader import reg_defines, scapy

from make_pkts import num_broadcast

import sys

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

pkts = scapy.rdpcap('pkts.pcap')
for i in range(num_broadcast):
    #nftest_send('eth1', pkts[i])
    nftest_send_phy('nf2c0', pkts[i])
    #nftest_expect('eth2', pkts[i])
    nftest_expect_phy('nf2c1', pkts[i])
    if not isHW():
        nftest_expect_phy('nf2c2', pkts[i])
        nftest_expect_phy('nf2c3', pkts[i])

nftest_barrier()

total_errors = 0

tmp = nftest_regread_expect(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), num_broadcast)
if isHW():
    if tmp != num_broadcast:
        print "ERROR: Num pkts sent from MAC 1 Tx Queue is %d not %d"%(tmp, num_broadcast)
        total_errors += 1

tmp = nftest_regread_expect(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), num_broadcast)
if isHW():
    if tmp != num_broadcast:
        print "ERROR: Num pkts sent from MAC 2 Tx Queue is %d not %d"%(tmp, num_broadcast)
        total_errors += 1

tmp = nftest_regread_expect(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), num_broadcast)
if isHW():
    if tmp != num_broadcast:
        print "ERROR: Num pkts sent from MAC 3 Tx Queue is %d not %d"%(tmp, num_broadcast)
        total_errors += 1

tmp = nftest_regread_expect(reg_defines.SWITCH_OP_LUT_NUM_MISSES_REG(), num_broadcast)
if isHW():
    if tmp != num_broadcast:
        print "ERROR: Num Switch LUT misses is %d not %d"%(tmp, num_broadcast)
        total_errors += 1

nftest_barrier()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)

