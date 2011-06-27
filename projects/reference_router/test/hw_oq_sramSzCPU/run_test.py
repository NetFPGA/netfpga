#!/bin/env python

from NFTestLib import *
from NFTestHeader import reg_defines, scapy

from RegressRouterLib import *

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

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

precreated0 = scapy.rdpcap('precreated0.pcap')
precreated1 = scapy.rdpcap('precreated1.pcap')
precreated2 = scapy.rdpcap('precreated2.pcap')
precreated3 = scapy.rdpcap('precreated3.pcap')

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

NUM_PKTS_IN_CPU_OQ = 8

import time; time.sleep(1)

nftest_barrier()

sent = [[],[],[],[]]
for i in range(NUM_PKTS_IN_CPU_OQ):
    pkt = precreated0[i]
    nftest_send('eth1', pkt)
    sent[0].append(pkt)

    pkt = precreated1[i]
    nftest_send('eth2', pkt)
    sent[1].append(pkt)

    pkt = precreated2[i]
    nftest_send('nf2c2', pkt)
    sent[2].append(pkt)

    pkt = precreated3[i]
    nftest_send('nf2c3', pkt)
    sent[3].append(pkt)

print "CPU OQs should be full. Start to drop received pkts"

pkt = precreated0[NUM_PKTS_IN_CPU_OQ]
nftest_send('eth1', pkt)

pkt = precreated1[NUM_PKTS_IN_CPU_OQ]
nftest_send('eth2', pkt)

pkt = precreated2[NUM_PKTS_IN_CPU_OQ]
nftest_send('nf2c2', pkt)

pkt = precreated3[NUM_PKTS_IN_CPU_OQ]
nftest_send('nf2c3', pkt)

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
nftest_regread_expect(reg_defines.OQ_QUEUE_7_NUM_PKTS_DROPPED_REG(), 1)

print "Start servicing the output queues again. Packets should be sent out."
nftest_regwrite(reg_defines.OQ_QUEUE_1_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_3_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_5_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_7_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

for i in range(4):
    for pkt in sent[i]:
        nftest_expect('nf2c'+str(i), pkt)

nftest_barrier()

print "Verifying that the packets are drained in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_1_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_3_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_5_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_7_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_CPU_OQ)

print "Done testing CPU OQ sizes"

nftest_barrier()

total_errors = nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
