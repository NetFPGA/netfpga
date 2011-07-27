#!/usr/bin/python

from NFTest import *
import random
from RegressRouterLib import *

phy2loop0 = ('../connections/2phy', [])

nftest_init([phy2loop0])
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

# add an entry in the routing table:
index = 0
subnetIP = "192.168.2.0"
subnetIP2 = "192.168.1.0"
subnetMask = "255.255.255.0"
subnetMask2 = "255.255.255.0"
nextHopIP = "192.168.1.54"
nextHopIP2 = "192.168.3.12"
outPort = 0x1 # output on MAC0
outPort2 = 0x4
nextHopMAC = "dd:55:dd:66:dd:77"

nftest_add_LPM_table_entry (
                1,
                subnetIP,
                subnetMask,
                nextHopIP,
                outPort)

nftest_add_LPM_table_entry (
                0,
                subnetIP2,
                subnetMask2,
                nextHopIP2,
                outPort2)


# add an entry in the ARP table
nftest_add_ARP_table_entry(
               index,
               nextHopIP,
               nextHopMAC)

# add an entry in the ARP table
nftest_add_ARP_table_entry(
               1,
               nextHopIP2,
               nextHopMAC)

#clear the num pkts forwarded reg
nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 0)

nftest_barrier()

precreated = [[], []]
precreated_exp = [[], []]
# loop for 20 packets from eth1 to eth2
for port in range(2):
    for i in range(20):
        # set parameters
        DA = routerMAC[port]
        SA = "aa:bb:cc:dd:ee:ff"
        TTL = 64
        DST_IP = "192.168.%d.1"%(port + 1)
        SRC_IP = "192.168.0.1"
        length = 100
        nextHopMAC = "dd:55:dd:66:dd:77"

        sent_pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=length)
        exp_pkt = make_IP_pkt(dst_MAC=nextHopMAC, src_MAC=routerMAC[1 - port],
                                  TTL=TTL-1, dst_IP=DST_IP, src_IP=SRC_IP)
        exp_pkt[scapy.Raw].load = sent_pkt[scapy.Raw].load

        precreated[port].append(sent_pkt)
        precreated_exp[port].append(exp_pkt)

# loop for 20 packets from eth1 to eth2
for port in range(2):
    for i in range(20):
        sent_pkt = precreated[port][i]
        exp_pkt = precreated_exp[port][i]
        # send packet out of eth1->nf2c0
        nftest_send_phy('nf2c%d'%port, sent_pkt);
        nftest_expect_phy('nf2c%d'%(1-port), exp_pkt);

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 40);

nftest_finish()
