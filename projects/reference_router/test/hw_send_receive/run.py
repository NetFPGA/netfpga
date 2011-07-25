#!/bin/env python

from NFTest import *
import random
from NFTest.hwRegLib import *
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init([phy2loop2])
nftest_start()

NUM_PKTS = 100

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

ALLSPFRouters = "224.0.0.5"

check_value = 0 # ??
total_errors = 0

# Write the mac and IP addresses doesn't matter which of the nf2c0..3 you write to.
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0);
nftest_add_dst_ip_filter_entry ('nf2c0', 1, routerIP1);
nftest_add_dst_ip_filter_entry ('nf2c0', 2, routerIP2);
nftest_add_dst_ip_filter_entry ('nf2c0', 3, routerIP3);
nftest_add_dst_ip_filter_entry ('nf2c0', 4, ALLSPFRouters);

# For these it does matter which interface you write to
nftest_set_router_MAC ('nf2c0', routerMAC0);
nftest_set_router_MAC ('nf2c1', routerMAC1);
nftest_set_router_MAC ('nf2c2', routerMAC2);
nftest_set_router_MAC ('nf2c3', routerMAC3);

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

hdr = scapy.Ether(dst=DA, src=SA, type=0x800)/scapy.IP(dst=DST_IP, src=SRC_IP, ttl=TTL)

# precreate random sized packets
precreated0 = []
for i in range(NUM_PKTS):
    precreated0.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC0,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated1 = []
for i in range(NUM_PKTS):
    precreated1.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC1,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated2 = []
for i in range(NUM_PKTS):
    precreated2.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC2,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated3 = []
for i in range(NUM_PKTS):
    precreated3.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC3,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

# reset counters
nftest_regwrite(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

nftest_regwrite(reg_defines.MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

nftest_regwrite(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

nftest_regwrite(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)
nftest_regwrite(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

print "Sending now:"
pkt = None
totalPktLengths = [0,0,0,0]
for i in range(NUM_PKTS):
    pkt = precreated0[i]
    totalPktLengths[0] += len(pkt)
    nftest_send_dma('nf2c0', pkt)
    nftest_expect_phy('nf2c0', pkt)

    pkt = precreated1[i]
    totalPktLengths[1] += len(pkt)
    nftest_send_dma('nf2c1', pkt)
    nftest_expect_phy('nf2c1', pkt)

    pkt = precreated2[i]
    totalPktLengths[2] += len(pkt)
    nftest_send_dma('nf2c2', pkt)
    nftest_expect_dma('nf2c2', pkt)

    pkt = precreated3[i]
    totalPktLengths[3] += len(pkt)
    nftest_send_dma('nf2c3', pkt)
    nftest_expect_dma('nf2c3', pkt)

print 'nf2c0 numBytes sent--->' + str(totalPktLengths[0])
print 'nf2c1 numBytes sent--->' + str(totalPktLengths[1])
print 'nf2c2 numBytes sent--->' + str(totalPktLengths[2])
print 'nf2c3 numBytes sent--->' + str(totalPktLengths[3])

nftest_barrier()

reset_phy()

control_reg0 = regread('nf2c0', reg_defines.MAC_GRP_0_CONTROL_REG())
if control_reg0 != 0:
    total_errors += 1

control_reg1 = regread('nf2c0', reg_defines.MAC_GRP_1_CONTROL_REG())
if control_reg1 != 0:
    total_errors += 1

control_reg2 = regread('nf2c0', reg_defines.MAC_GRP_2_CONTROL_REG())
if control_reg2 != 0:
    total_errors += 1

control_reg3 = regread('nf2c0', reg_defines.MAC_GRP_3_CONTROL_REG())
if control_reg3 != 0:
    total_errors += 1

###### QUEUE 0
check_value = regread('nf2c0', reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT --> " + str(check_value) + " Expecting--> " + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG())
if check_value != 0:
    total_errors += 1
    print "MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED --> " + str(check_value) + " Expecting-->0"

check_value = regread('nf2c0', reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[0]:
    total_errors += 1
    print "MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED--> " + str(check_value) + " Expecting--> " + str(totalPktLengths[0])

check_value = regread('nf2c0', reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != 0:
    total_errors += 1
    print "MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED --> " + str(check_value) + " Expecting --> 0"

###### QUEUE 1
check_value = regread('nf2c0', reg_defines.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT --> " + str(check_value) + " Expecting--> " + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG())
if check_value != 0:
    total_errors += 1
    print "MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED --> " + str(check_value) + " Expecting-->0"

check_value = regread('nf2c0', reg_defines.MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[1]:
    total_errors += 1
    print "MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED--> " + str(check_value) + " Expecting--> " + str(totalPktLengths[1])

check_value = regread('nf2c0', reg_defines.MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != 0:
    total_errors += 1
    print "MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED --> " + str(check_value) + " Expecting --> 0"

###### QUEUE 2
check_value = regread('nf2c0', reg_defines.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT --> " + str(check_value) + " Expecting--> " + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED --> " + str(check_value) + " Expecting-->" + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[2]:
    total_errors += 1
    print "MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED--> " + str(check_value) + " Expecting--> " + str(totalPktLengths[2])

check_value = regread('nf2c0', reg_defines.MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[2]:
    total_errors += 1
    print "MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED --> " + str(check_value) + " Expecting --> " + str(totalPktLengths[2])

###### QUEUE 3
check_value = regread('nf2c0', reg_defines.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT --> " + str(check_value) + " Expecting--> " + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG())
if check_value != NUM_PKTS:
    total_errors += 1
    print "MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED --> " + str(check_value) + " Expecting-->" + str(NUM_PKTS)

check_value = regread('nf2c0', reg_defines.MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[3]:
    total_errors += 1
    print "MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED--> " + str(check_value) + " Expecting--> " + str(totalPktLengths[3])

check_value = regread('nf2c0', reg_defines.MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG())
if check_value != totalPktLengths[3]:
    total_errors += 1
    print "MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED --> " + str(check_value) + " Expecting --> " + str(totalPktLengths[3])


nftest_barrier()

total_errors += nftest_finish()
