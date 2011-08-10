#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

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
nftest_add_ARP_table_entry(index, nextHopIP, nextHopMAC)

nftest_barrier()

for i in range(100):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC[0],
                      src_IP="192.168.0.1", dst_IP="192.168.2.1")

    nftest_send_phy('nf2c0', pkt)
    nftest_expect_dma('nf2c0', pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_LPM_NUM_MISSES_REG(), 100)

nftest_finish()
