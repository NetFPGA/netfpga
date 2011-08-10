#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c2', 'nf2c3'], hw_config = [phy2loop2])
nftest_start()

if isHW():
    NUM_PKTS = 20
else:
    NUM_PKTS = 10

routerMAC = ["00:ca:fe:00:00:01", "00:ca:fe:00:00:02", "00:ca:fe:00:00:03", "00:ca:fe:00:00:04"]
routerIP = ["192.168.0.40", "192.168.1.40", "192.168.2.40", "192.168.3.40"]

ALLSPFRouters = "224.0.0.5"

# Clear all tables in a hardware test (not needed in software)
if isHW():
    nftest_invalidate_all_tables()

# Write the mac and IP addresses
for port in range(4):
    nftest_add_dst_ip_filter_entry (port, routerIP[port])
    nftest_set_router_MAC ('nf2c%d'%port, routerMAC[port])
nftest_add_dst_ip_filter_entry (4, ALLSPFRouters)

# Verify that the PHYs are in the correct state
if isHW():
    nftest_regread_expect(reg_defines.MDIO_PHY_0_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_1_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_2_CONTROL_REG(), 0x5140)
    nftest_regread_expect(reg_defines.MDIO_PHY_3_CONTROL_REG(), 0x5140)

DA = routerMAC[0]
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

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

nftest_barrier()

print "Sending now:"
pkt = None
totalPktLengths = [0,0,0,0]
for i in range(NUM_PKTS):
    for port in range(4):
        pkt = make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC[port],
                          src_IP=SRC_IP, dst_IP=DST_IP,
                          pkt_len=random.randint(60, 1514))
        totalPktLengths[port] += len(pkt)
        nftest_send_dma('nf2c%d'%port, pkt)
        if port < 2:
            nftest_expect_phy('nf2c%d'%port, pkt)
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)

nftest_barrier()

for port in range(4):
    offset = port * reg_defines.MAC_GRP_OFFSET()
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + offset, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + offset, totalPktLengths[port])

    if port >= 2:
        nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + offset, NUM_PKTS)
        nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + offset, totalPktLengths[port])

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 4*NUM_PKTS)

nftest_finish()
