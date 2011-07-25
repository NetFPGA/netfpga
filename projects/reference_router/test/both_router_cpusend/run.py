#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init([phy2loop2])
nftest_start()

if isHW():
    NUM_PKTS = 20
else:
    NUM_PKTS = 10

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

ALLSPFRouters = "224.0.0.5"

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

if isHW():
    nftest_regread_expect(reg_defines.MDIO_PHY_0_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_1_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_2_CONTROL_REG(), 0x5140)
    nftest_regread_expect(reg_defines.MDIO_PHY_3_CONTROL_REG(), 0x5140)

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

# precreate random sized packets
precreated0 = []
for i in range(NUM_PKTS):
    precreated0.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC0,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                    pkt_len=random.randint(60, 1514)))

precreated1 = []
for i in range(NUM_PKTS):
    precreated1.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC1,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60, 1514)))

precreated2 = []
for i in range(NUM_PKTS):
    precreated2.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC2,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60, 1514)))

precreated3 = []
for i in range(NUM_PKTS):
    precreated3.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC3,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60, 1514)))

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

nftest_barrier()

nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[0])

nftest_regread_expect(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[1])

nftest_regread_expect(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[2])

nftest_regread_expect(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[2])
nftest_regread_expect(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS)

nftest_regread_expect(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[3])

nftest_regread_expect(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[3])
nftest_regread_expect(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS)

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 4*NUM_PKTS)

nftest_finish()
