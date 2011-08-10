#!/bin/env python

from NFTest import *
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c2', 'nf2c3'], hw_config = [phy2loop2])
nftest_start()

NUM_TBL_ENTRIES = 32

routerMAC = ["00:ca:fe:00:00:01", "00:ca:fe:00:00:02", "00:ca:fe:00:00:03", "00:ca:fe:00:00:04"]
routerIP = ["192.168.0.40", "192.168.1.40", "192.168.2.40", "192.168.3.40"]
dstIP = ["192.168.0.50", "192.168.1.50", "192.168.2.50", "192.168.3.50"]
dstMAC = ["aa:bb:cc:dd:ee:01", "aa:bb:cc:dd:ee:02", "aa:bb:cc:dd:ee:03", "aa:bb:cc:dd:ee:04"]

ALLSPFRouters = "224.0.0.5"

# Clear all tables in a hardware test (not needed in software)
if isHW():
    nftest_invalidate_all_tables()

# Write the mac and IP addresses
for port in range(4):
    nftest_add_dst_ip_filter_entry (port, routerIP[port])
    nftest_set_router_MAC ('nf2c%d'%port, routerMAC[port])
nftest_add_dst_ip_filter_entry (4, ALLSPFRouters)

# set the oq sram boundaries
for q in range(8):
    addr_offset = q * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET()
    nftest_regwrite(reg_defines.OQ_QUEUE_0_ADDR_HI_REG() + addr_offset, q * 0x10000 + 0x3ff)
    nftest_regwrite(reg_defines.OQ_QUEUE_0_ADDR_LO_REG() + addr_offset, q * 0x10000)
    nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG() + addr_offset, 1<<reg_defines.OQ_INITIALIZE_OQ_BIT_NUM())

# Enable all Output Queues. Later on some Output Queues are selectively disabled
for q in range(8):
    addr_offset = q * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET()
    nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG() + addr_offset, (1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM()))

DA = routerMAC[0]
SA = "aa:bb:cc:dd:ee:ff"
DST_IP = "192.168.101.2"
SRC_IP = "192.168.100.2"
nextHopMAC = "dd:55:dd:66:dd:77"

NUM_PKTS_IN_MAC_OQ = 4

precreated = [[], [], [], []]
for port in range(4):
    for i in range(NUM_PKTS_IN_MAC_OQ + 1):
        precreated[port].append(make_IP_pkt(dst_MAC=routerMAC[port], src_MAC=SA,
                                dst_IP=DST_IP, src_IP=SRC_IP, pkt_len=1016))

print "Start testing MAC OQ sizes"

print "Disabling servicing MAC output queues"
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 0)

# clear counter values for CPU output queues only
nftest_regwrite(reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 0)

nftest_regwrite(reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_NUM_PKTS_REMOVED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_NUM_PKTS_REMOVED_REG(), 0)

nftest_barrier()

sent = [[],[],[],[]]
for i in range(NUM_PKTS_IN_MAC_OQ):
    for port in range(4):
        pkt = precreated[port][i]
        nftest_send_dma('nf2c%d'%port, pkt)
        sent[port].append(pkt)

print "MAC OQs should be full. Start to drop received pkts"

for port in range(4):
    pkt = precreated[port][NUM_PKTS_IN_MAC_OQ]
    nftest_send_dma('nf2c%d'%port, pkt)

nftest_barrier()

print "\nVerifying that the packets are stored in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_0_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_2_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_4_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_6_NUM_PKTS_IN_Q_REG(), NUM_PKTS_IN_MAC_OQ)

print "Verifying dropped pkts counter."
nftest_regread_expect(reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 1)
nftest_regread_expect(reg_defines.OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 1)
nftest_regread_expect(reg_defines.OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 1)
nftest_regread_expect(reg_defines.OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 1)

print "Start servicing the output queues again. Packets should be sent out."
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

for port in range(4):
    for pkt in sent[port]:
        if port < 2:
            nftest_expect_phy('nf2c%d'%port, pkt)
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)

nftest_barrier()

print "Verifying that the packets are drained in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_2_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_4_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_MAC_OQ)
nftest_regread_expect(reg_defines.OQ_QUEUE_6_NUM_PKTS_REMOVED_REG(), NUM_PKTS_IN_MAC_OQ)

print "Done testing MAC OQ sizes"

nftest_finish()
