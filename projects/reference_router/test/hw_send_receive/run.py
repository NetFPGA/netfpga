#!/bin/env python

from NFTest import *
import random
from NFTest.hwRegLib import *
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c2', 'nf2c3'], hw_config = [phy2loop2])
nftest_start()

NUM_PKTS = 100

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
nftest_add_dst_ip_filter_entry (4, ALLSPFRouters);


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

print "Sending now:"
pkt = None
totalPktLengths = [0,0,0,0]
for i in range(NUM_PKTS):
    for port in range(4):
        pkt = make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC[port], src_IP=SRC_IP,
                          dst_IP=DST_IP, pkt_len=random.randint(60,1514))
        totalPktLengths[port] += len(pkt)
        nftest_send_dma('nf2c%d'%port, pkt)
        if port < 2:
            nftest_expect_phy('nf2c%d'%port, pkt)
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)

print 'nf2c0 numBytes sent--->' + str(totalPktLengths[0])
print 'nf2c1 numBytes sent--->' + str(totalPktLengths[1])
print 'nf2c2 numBytes sent--->' + str(totalPktLengths[2])
print 'nf2c3 numBytes sent--->' + str(totalPktLengths[3])

nftest_barrier()

reset_phy()

nftest_regread_expect(reg_defines.MAC_GRP_0_CONTROL_REG(), 0)
nftest_regread_expect(reg_defines.MAC_GRP_1_CONTROL_REG(), 0)
nftest_regread_expect(reg_defines.MAC_GRP_2_CONTROL_REG(), 0)
nftest_regread_expect(reg_defines.MAC_GRP_3_CONTROL_REG(), 0)

###### QUEUE 0
nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[0])
nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

###### QUEUE 1
nftest_regread_expect(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG(), 0)
nftest_regread_expect(reg_defines.MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[1])
nftest_regread_expect(reg_defines.MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0)

###### QUEUE 2
nftest_regread_expect(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[2])
nftest_regread_expect(reg_defines.MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[2])

###### QUEUE 3
nftest_regread_expect(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), NUM_PKTS)
nftest_regread_expect(reg_defines.MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[3])
nftest_regread_expect(reg_defines.MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG(), totalPktLengths[3])

nftest_finish()
