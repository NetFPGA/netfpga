#!/bin/env python

from NFTestLib import *
from NFTestHeader import reg_defines, scapy

from RegressRouterLib import *

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

for i in range(32):
    nftest_invalidate_LPM_table_entry('nf2c0', i)

for i in range(32):
    nftest_invalidate_ARP_table_entry('nf2c0', i)

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)


index = 0
subnetIP = "192.168.1.0"
subnetIP2 = "192.168.1.1"
subnetMask = "255.255.255.0"
subnetMask2 = "255.255.255.225"
nextHopIP = "192.168.1.54"
nextHopIP2 = "0.0.0.0"
outPort = 0x1
outPort2 = 0x4
nextHopMAC = "dd:55:dd:66:dd:77"

nftest_add_LPM_table_entry('nf2c0', 1, subnetIP, subnetMask, nextHopIP, outPort)

nftest_add_LPM_table_entry('nf2c0', 0, subnetIP2, subnetMask2, nextHopIP2, outPort2)

nftest_add_ARP_table_entry('nf2c0', index, nextHopIP, nextHopMAC)

nftest_add_ARP_table_entry('nf2c0', 1, subnetIP2, nextHopMAC)

nftest_barrier()

total_errors = 0

pkts = scapy.rdpcap('eth1_pkts.pcap')
exp_pkts = scapy.rdpcap('eth2_pkts.pcap')
for i in range(100):
    nftest_send('eth1', pkts[i])
    nftest_expect('eth2', exp_pkts[i])

nftest_barrier()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
