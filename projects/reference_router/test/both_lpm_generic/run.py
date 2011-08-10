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


subnetIP = ["192.168.1.1", "192.168.1.0"]
subnetMask = ["255.255.255.225", "255.255.255.0"]
nextHopIP = ["192.168.3.12", "192.168.1.54"]
outPort = [0x4, 0x1]
nextHopMAC = "dd:55:dd:66:dd:77"

for i in range(2):
    nftest_add_LPM_table_entry(i, subnetIP[i], subnetMask[i], nextHopIP[i], outPort[i])
    nftest_add_ARP_table_entry(i, nextHopIP[i], nextHopMAC)

nftest_barrier()

for i in range(100):
    hdr = make_MAC_hdr(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC[0],
                       )/scapy.IP(src="192.168.0.1", dst="192.168.1.1")
    exp_hdr = make_MAC_hdr(src_MAC=routerMAC[1], dst_MAC=nextHopMAC,
                           )/scapy.IP(src="192.168.0.1", dst="192.168.1.1", ttl=63)
    load = generate_load(100)
    pkt = hdr/load
    exp_pkt = exp_hdr/load

    nftest_send_phy('nf2c0', pkt)
    nftest_expect_phy('nf2c1', exp_pkt)

nftest_finish()
