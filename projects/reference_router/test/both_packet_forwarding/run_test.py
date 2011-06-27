#!/usr/bin/python

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

# clear LPM table
for i in range(32):
    nftest_invalidate_LPM_table_entry('nf2c0', i);

# clear ARP table
for i in range(32):
    nftest_invalidate_ARP_table_entry('nf2c0', i);

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c1', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c2', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c3', 3, routerIP3)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

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

nftest_add_LPM_table_entry ('nf2c0',
                1,
                subnetIP,
                subnetMask,
                nextHopIP,
                outPort)

nftest_add_LPM_table_entry ('nf2c0',
                0,
                subnetIP2,
                subnetMask2,
                nextHopIP2,
                outPort2)


# add an entry in the ARP table
nftest_add_ARP_table_entry('nf2c0',
               index,
               nextHopIP,
               nextHopMAC)

# add an entry in the ARP table
nftest_add_ARP_table_entry('nf2c0',
               1,
               nextHopIP2,
               nextHopMAC)

total_errors = 0
temp_error_val = 0

#clear the num pkts forwarded reg
nftest_regwrite(reg_defines.ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 0)

nftest_barrier()

precreated0 = scapy.rdpcap('precreated0.pcap')
precreated0_exp = scapy.rdpcap('precreated0_exp.pcap')
# loop for 20 packets from eth1 to eth2
for i in range(20):
    sent_pkt = precreated0[i]
    exp_pkt = precreated0_exp[i]
    # send packet out of eth1->nf2c0
    nftest_send('eth1', sent_pkt);
    nftest_expect('eth2', exp_pkt);

precreated1 = scapy.rdpcap('precreated1.pcap')
precreated1_exp = scapy.rdpcap('precreated1_exp.pcap')
# loop for 20 packets from eth2 to eth1
for i in range(20):
    sent_pkt = precreated1[i]
    exp_pkt = precreated1_exp[i]

    # send packet out of eth1->nf2c0
    nftest_send('eth2', sent_pkt)
    nftest_expect('eth1', exp_pkt)

nftest_barrier()

nftest_regread_expect(reg_defines.ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 40);

total_errors = nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
