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

NUM_PKTS = 20

# add destinations to be filtered to the software
nftest_add_dst_ip_filter_entry (5, dstIP[0])
nftest_add_dst_ip_filter_entry (6, dstIP[1])
nftest_add_dst_ip_filter_entry (7, dstIP[2])

nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG(), 0)

nftest_barrier()

exp_hdr = make_MAC_hdr(dst_MAC=dstMAC[0],
                       src_MAC=routerMAC[1])/make_IP_hdr(src_IP=dstIP[3],
                                                      dst_IP=dstIP[0])
exp_hdr[scapy.IP].ttl = 63

for i in range(NUM_PKTS):
    for port in range(2):
        pkt = make_IP_pkt(dst_MAC=routerMAC[port], src_MAC=dstMAC[3],
                          src_IP=dstIP[3], dst_IP=dstIP[random.randint(0,2)],
                          pkt_len=random.randint(60,1514))

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
        pkt = make_IP_pkt(dst_MAC=routerMAC[port], src_MAC=dstMAC[3],
                          src_IP=dstIP[3], dst_IP=dstIP[random.randint(0,2)],
                          pkt_len=random.randint(60,1514))
        exp_pkt = exp_hdr/pkt.load

        nftest_send_phy('nf2c%d'%port, pkt)
        if pkt[scapy.IP].dst == dstIP[0]:
            nftest_expect_phy('nf2c1', exp_pkt)
        else:
            nftest_expect_dma('nf2c%d'%port, pkt)

nftest_finish()
