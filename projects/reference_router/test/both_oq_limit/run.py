#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c2', 'nf2c3'], hw_config = [phy2loop2])
nftest_start()

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

# Verify that the PHY is in the expected state
if isHW():
    nftest_regread_expect(reg_defines.MDIO_PHY_0_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_1_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_2_CONTROL_REG(), 0x5140)
    nftest_regread_expect(reg_defines.MDIO_PHY_3_CONTROL_REG(), 0x5140)

NUM_PKTS = 5

DA = routerMAC[0]
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

precreated = []
for port in range(4):
    pkts = []
    for i in range(NUM_PKTS):
        pkts.append(make_IP_pkt(dst_MAC=routerMAC[port], src_MAC=SA,
                                dst_IP=DST_IP, src_IP=SRC_IP,
                                pkt_len=random.randint(60,1514)))
    precreated.append(pkts)

nftest_regwrite(reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 0)

nftest_barrier()

for i in range(NUM_PKTS):
    for port in range(4):
        pkt = precreated[port][i]
        nftest_send_dma('nf2c%d'%port, pkt)
        if port < 2:
            nftest_expect_phy('nf2c%d'%port, pkt)
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)


nftest_barrier()

print "Disabling servicing output queues"
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 0)

print "Setting max number of pkts in queue to " + str(NUM_PKTS)
nftest_regwrite(reg_defines.OQ_QUEUE_0_MAX_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regwrite(reg_defines.OQ_QUEUE_2_MAX_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regwrite(reg_defines.OQ_QUEUE_4_MAX_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regwrite(reg_defines.OQ_QUEUE_6_MAX_PKTS_IN_Q_REG(), NUM_PKTS)

print "Resending packets."
nftest_barrier()
sent = [[],[],[],[]]
for i in range(NUM_PKTS):
    for port in range(4):
        pkt = precreated[port][i]
        nftest_send_dma('nf2c%d'%port, pkt)
        sent[port].append(pkt)

nftest_barrier()

print "\nVerifying that the packets are stored in the output queues"
nftest_regread_expect(reg_defines.OQ_QUEUE_0_NUM_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_2_NUM_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_4_NUM_PKTS_IN_Q_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_6_NUM_PKTS_IN_Q_REG(), NUM_PKTS)

print "Sending more packets that should be dropped."
nftest_barrier()
for i in range(NUM_PKTS):
    for port in range(4):
        pkt = precreated[port][i]
        nftest_send_dma('nf2c%d'%port, pkt)

nftest_barrier()

print "Verifying dropped pkts counter."
nftest_regread_expect(reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), NUM_PKTS)

print "Start servicing the output queues again. Packets should be sent out."
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

nftest_barrier()

for port in range(4):
    for pkt in sent[port]:
        if port > 1:
            nftest_expect_dma('nf2c%d'%port, pkt)
        else:
            nftest_expect_phy('nf2c%d'%port, pkt)

nftest_barrier()

print "Reset max number of pkts in queues."
nftest_regwrite(reg_defines.OQ_QUEUE_0_MAX_PKTS_IN_Q_REG(), 0xffffffff)
nftest_regwrite(reg_defines.OQ_QUEUE_2_MAX_PKTS_IN_Q_REG(), 0xffffffff)
nftest_regwrite(reg_defines.OQ_QUEUE_4_MAX_PKTS_IN_Q_REG(), 0xffffffff)
nftest_regwrite(reg_defines.OQ_QUEUE_6_MAX_PKTS_IN_Q_REG(), 0xffffffff)

nftest_finish()
