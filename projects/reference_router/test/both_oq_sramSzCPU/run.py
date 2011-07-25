#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init([phy2loop2])
nftest_start()

NUM_TBL_ENTRIES = 32

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

# clear LPM table
for i in range(32):
    nftest_invalidate_LPM_table_entry('nf2c0', i)

# clear ARP table
for i in range(32):
    nftest_invalidate_ARP_table_entry('nf2c0', i)

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

# set the oq sram boundaries
nftest_regwrite(reg_defines.OQ_QUEUE_0_ADDR_HI_REG(), 0x3ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_0_ADDR_LO_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_1_ADDR_HI_REG(), 0x105ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_1_ADDR_LO_REG(), 0x10000)
nftest_regwrite(reg_defines.OQ_QUEUE_1_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_2_ADDR_HI_REG(), 0x203ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_2_ADDR_LO_REG(), 0x20000)
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_3_ADDR_HI_REG(), 0x305ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_3_ADDR_LO_REG(), 0x30000)
nftest_regwrite(reg_defines.OQ_QUEUE_3_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_4_ADDR_HI_REG(), 0x403ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_4_ADDR_LO_REG(), 0x40000)
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_5_ADDR_HI_REG(), 0x505ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_5_ADDR_LO_REG(), 0x50000)
nftest_regwrite(reg_defines.OQ_QUEUE_5_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_6_ADDR_HI_REG(), 0x603ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_6_ADDR_LO_REG(), 0x60000)
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

nftest_regwrite(reg_defines.OQ_QUEUE_7_ADDR_HI_REG(), 0x705ff) #1024 words * 8 byte/word = 8KB
nftest_regwrite(reg_defines.OQ_QUEUE_7_ADDR_LO_REG(), 0x70000)
nftest_regwrite(reg_defines.OQ_QUEUE_7_CTRL_REG(), 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

# Enable all Output Queues. Later on some Output Queues are selectively disabled
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_1_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_3_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_5_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))
nftest_regwrite(reg_defines.OQ_QUEUE_7_CTRL_REG(), (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))

NUM_PKTS_IN_CPU_OQ = 8

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.101.2"
SRC_IP = "192.168.100.2"
nextHopMAC = "dd:55:dd:66:dd:77"

precreated0 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated0.append(make_IP_pkt(dst_MAC=routerMAC0, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated1 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated1.append(make_IP_pkt(dst_MAC=routerMAC1, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated2 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated2.append(make_IP_pkt(dst_MAC=routerMAC2, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated3 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated3.append(make_IP_pkt(dst_MAC=routerMAC3, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))


print "Start testing CPU OQ sizes"

print "Disabling servicing output queues"
nftest_regwrite(reg_defines.OQ_QUEUE_1_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_3_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_5_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_7_CTRL_REG(), 0)

# clear counter values for CPU output queues only
nftest_regwrite(reg_defines.OQ_QUEUE_1_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_3_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_5_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_7_NUM_PKTS_DROPPED_REG(), 0)

nftest_regwrite(reg_defines.OQ_QUEUE_1_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_3_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_5_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_7_NUM_PKTS_REMOVED_REG(), 0)

import time; time.sleep(1)

nftest_barrier()

sent = [[],[],[],[]]
for i in range(NUM_PKTS_IN_CPU_OQ):
    pkt = precreated0[i]
    nftest_send_phy('nf2c0', pkt)
    sent[0].append(pkt)

    pkt = precreated1[i]
    nftest_send_phy('nf2c1', pkt)
    sent[1].append(pkt)

    pkt = precreated2[i]
    nftest_send_dma('nf2c2', pkt)
    sent[2].append(pkt)

    pkt = precreated3[i]
    nftest_send_dma('nf2c3', pkt)
    sent[3].append(pkt)

print "CPU OQs should be full. Start to drop received pkts"

pkt = precreated0[NUM_PKTS_IN_CPU_OQ]
nftest_send_phy('nf2c0', pkt)

pkt = precreated1[NUM_PKTS_IN_CPU_OQ]
nftest_send_phy('nf2c1', pkt)

pkt = precreated2[NUM_PKTS_IN_CPU_OQ]
nftest_send_dma('nf2c2', pkt)

pkt = precreated3[NUM_PKTS_IN_CPU_OQ]
nftest_send_dma('nf2c3', pkt)

nftest_barrier()

print "\nVerifying that the packets are stored in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_1_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_3_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_5_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_7_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_CPU_OQ)

print "Verifying dropped pkts counter."
nftest_regread_expect(reg_defines.OQ_QUEUE_1_NUM_PKTS_DROPPED_REG(), 1)
nftest_regread_expect(reg_defines.OQ_QUEUE_3_NUM_PKTS_DROPPED_REG(), 1)
nftest_regread_expect(reg_defines.OQ_QUEUE_5_NUM_PKTS_DROPPED_REG(), 1)
if not isHW():
    simReg.regDelay(10000)
nftest_regread_expect(reg_defines.OQ_QUEUE_7_NUM_PKTS_DROPPED_REG(), 1)

print "Start servicing the output queues again. Packets should be sent out."
nftest_regwrite(reg_defines.OQ_QUEUE_1_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_3_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_5_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_7_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

nftest_barrier()

for i in range(4):
    for pkt in sent[i]:
        nftest_expect_dma('nf2c'+str(i), pkt)

nftest_barrier()

print "Verifying that the packets are drained in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_1_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_3_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_5_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_7_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)

print "Done testing CPU OQ sizes"

nftest_finish()
