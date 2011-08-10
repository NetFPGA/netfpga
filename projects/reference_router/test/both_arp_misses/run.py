#!/bin/env python

from NFTest import *
from RegressRouterLib import *
import random

phy2loop0 = ('../connections/2phy', [])

nftest_init(sim_loop = [], hw_config = [phy2loop0])
nftest_start()

routerMAC = ["00:ca:fe:00:00:01", "00:ca:fe:00:00:02", "00:ca:fe:00:00:03", "00:ca:fe:00:00:04"]
routerIP = ["192.168.0.40", "192.168.1.40", "192.168.2.40", "192.168.3.40"]

# Clear all tables in a hardware test (not needed in software)
if isHW():
    nftest_invalidate_all_tables()

# Write the mac and IP addresses
for port in range(4):
    nftest_add_dst_ip_filter_entry (port, routerIP[port])
    nftest_set_router_MAC ('nf2c%d'%port, routerMAC[port])

index = 0
subnetIP = "192.168.1.0"
subnetMask = "255.255.255.0"
nextHopIP = "192.168.1.54"
outPort = 0x4
nextHopMAC = "dd:55:dd:66:dd:77"

nftest_add_LPM_table_entry(index, subnetIP, subnetMask, nextHopIP, outPort)

nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_NUM_MISSES_REG(), 0)

nftest_barrier()

DA = routerMAC[0]
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

print "Sending packets"

for i in range(30):
    sent_pkt = make_IP_pkt(src_MAC=SA, dst_MAC=DA,
                           dst_IP=DST_IP, src_IP=SRC_IP,
                           pkt_len=random.randint(60,1514))
    nftest_send_phy('nf2c0', sent_pkt)
    nftest_expect_dma('nf2c0', sent_pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_NUM_MISSES_REG(), 30)

nftest_finish()
