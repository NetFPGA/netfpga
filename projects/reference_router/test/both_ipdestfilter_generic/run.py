#!/bin/env python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop2 = ('../connections/2phy', ['nf2c2', 'nf2c3'])

nftest_init([phy2loop2])
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

# Verify that the PHY is in the correct state
if isHW():
    nftest_regread_expect(reg_defines.MDIO_PHY_0_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_1_CONTROL_REG(), 0x1140)
    nftest_regread_expect(reg_defines.MDIO_PHY_2_CONTROL_REG(), 0x5140)
    nftest_regread_expect(reg_defines.MDIO_PHY_3_CONTROL_REG(), 0x5140)

NUM_PKTS = 20

# add destinations to be filtered to the software
nftest_add_dst_ip_filter_entry (5, dstIP[0])
nftest_add_dst_ip_filter_entry (6, dstIP[1])
nftest_add_dst_ip_filter_entry (7, dstIP[2])

nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 0)

nftest_barrier()

ippkt_hdr = make_MAC_hdr(dst_MAC=routerMAC[0],
                         src_MAC=dstMAC[3])/make_IP_hdr(src_IP=dstIP[3],
                                                      dst_IP=dstIP[0], ttl=64)

precreated = [[],[]]
for port in range(2):
    ippkt_hdr[scapy.Ether].dst = routerMAC[port]
    for i in range(NUM_PKTS):
        whichIP = random.randint(0,2)
        ippkt_hdr[scapy.IP].dst = dstIP[whichIP]
        load = generate_load(random.randint(60-len(ippkt_hdr), 1514-len(ippkt_hdr)))
        precreated[port].append(ippkt_hdr/load)

exp_hdr = ippkt_hdr
exp_hdr[scapy.Ether].dst = dstMAC[0]
exp_hdr[scapy.Ether].src = routerMAC[1]
exp_hdr[scapy.IP].dst = dstIP[0]
exp_hdr[scapy.IP].ttl = 63

expected = [[], []]
for port in range(2):
    expected[port] = [exp_hdr/x.load for x in precreated[port]]

for i in range(NUM_PKTS):
    for port in range(2):
        pkt = precreated[port][i]
        nftest_send_phy('nf2c%d'%port, pkt)
        nftest_expect_dma('nf2c%d'%port, pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 2*NUM_PKTS)

nftest_invalidate_dst_ip_filter_entry(5)
nftest_add_LPM_table_entry(0, dstIP[0], "255.255.255.0", "0.0.0.0", 0x04) # send out MAC1
nftest_add_ARP_table_entry(0, dstIP[0], dstMAC[0])

nftest_barrier()

for i in range(NUM_PKTS):
    for port in range(2):
        pkt = precreated[port][i]
        nftest_send_phy('nf2c%d'%port, pkt)
        if pkt[scapy.IP].dst == dstIP[0]:
            nftest_expect_phy('nf2c1', expected[port][i])
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)

nftest_finish()
