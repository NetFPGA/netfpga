#!/bin/env python

from NFTestLib import *
from NFTestHeader import reg_defines, scapy

from hwRegLib import *

from RegressRouterLib import *

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

internal_loopback = 0
print_all_stats = 0
run_lenght = 100 # seconds
print_interval = 1
load_timeout = 5.0
expect = 0

NUM_PORTS = 4
BUFFER_SIZE_PER_PORT = 512000 # bytes
length = 128
desired_q_occ_fraction = 0.5
desired_q_occ = BUFFER_SIZE_PER_PORT / length * desired_q_occ_fraction
print "desired q occ: " + str(desired_q_occ)
packets_to_loop = 255

num_2_32 = 4294967296

total_errors = 0

def get_dest_MAC(i):
    i_plus_one = i + 1
    if internal_loopback:
        return "00:ca:fe:00:00:0" + str(i_plus_one)
    else:
        if i == 0:
            return "00:ca:fe:00:00:02"
        if i == 1:
            return "00:ca:fe:00:00:01"
        if i == 2:
            return "00:ca:fe:00:00:04"
        if i == 3:
            return "00:ca:fe:00:00:03"

def get_q_num_pkts_reg(i):
    if i == 0:
        return reg_defines.OQ_QUEUE_0_NUM_PKTS_IN_Q()
    if i == 1:
        return reg_defines.OQ_QUEUE_1_NUM_PKTS_IN_Q()
    if i == 2:
        return reg_defines.OQ_QUEUE_2_NUM_PKTS_IN_Q()
    if i == 3:
        return reg_defines.OQ_QUEUE_3_NUM_PKTS_IN_Q()

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

ALLSPFRouters = "224.0.0.5"

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, routerIP0)
nftest_add_dst_ip_filter_entry ('nf2c0', 1, routerIP1)
nftest_add_dst_ip_filter_entry ('nf2c0', 2, routerIP2)
nftest_add_dst_ip_filter_entry ('nf2c0', 3, routerIP3)
nftest_add_dst_ip_filter_entry ('nf2c0', 4, ALLSPFRouters)

nftest_set_router_MAC ('nf2c0', routerMAC0)
nftest_set_router_MAC ('nf2c1', routerMAC1)
nftest_set_router_MAC ('nf2c2', routerMAC2)
nftest_set_router_MAC ('nf2c3', routerMAC3)

check_value = 0
# router mac 0
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_0_HI_REG())
if check_value != 0xca:
    total_errors += 1
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_0_LO_REG())
if check_value != 0xfe000001:
    total_errors += 1

# router mac 1
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_1_HI_REG())
if check_value != 0xca:
    total_errors += 1
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_1_LO_REG())
if check_value != 0xfe000002:
    total_errors += 1

# router mac 2
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_2_HI_REG())
if check_value != 0xca:
    total_errors += 1
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_2_LO_REG())
if check_value != 0xfe000003:
    total_errors += 1

# router mac 3
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_3_HI_REG())
if check_value != 0xca:
    total_errors += 1
check_value = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_3_LO_REG())
if check_value != 0xfe000004:
    total_errors += 1

print str(total_errors)
# put all ports in internal_loopback mode if specified
if internal_loopback:
    phy_loopback('nf2c0')
    phy_loopback('nf2c1')
    phy_loopback('nf2c2')
    phy_loopback('nf2c3')

for i in range(32):
    nftest_invalidate_LPM_table_entry('nf2c0', i)

for i in range(32):
    nftest_invalidate_ARP_table_entry('nf2c0', i)

total_errors = 0
# add LPM and ARP entries for each port
for i in range(NUM_PORTS):
    i_plus_1 = i + 1
    subnetIP = "192.168." + str(i_plus_1) + ".1"
    subnetMask = "255.255.255.225"
    nextHopIP = "192.168.5." + str(i_plus_1)
    outPort = 1 << (2 * i)
    nextHopMAC = get_dest_MAC(i)

    # add an entry in the routing table
    nftest_add_LPM_table_entry('nf2c0', i, subnetIP, subnetMask, nextHopIP, outPort)
    # add and entry in the ARP table
    nftest_add_ARP_table_entry('nf2c0', i, nextHopIP, nextHopMAC)

print total_errors

# ARP table
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), i)
    # ARP MAC
    mac_hi = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG())
    mac_lo = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG())
    print "arp row:" + str(i) + " arp mac:(" + str(mac_hi) + str(mac_lo) + ")"
    router_ip = regread('nf2c0', reg_defines. ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG())
    if i == 0:
        if mac_hi != 0xca:
            total_errors += 1
        if mac_lo != 0xfe000002:
            total_errors += 1
        if router_ip != 0xc0a80501:
            total_errors += 1
    elif i == 1:
        if mac_hi != 0xca:
            total_errors += 1
        if mac_lo != 0xfe000001:
            total_errors += 1
        if router_ip != 0xc0a80502:
            total_errors += 1
    elif i == 2:
        if mac_hi != 0xca:
            total_errors += 1
        if mac_lo != 0xfe000004:
            total_errors += 1
        if router_ip != 0xc0a80503:
            total_errors += 1
    elif i == 3:
        if mac_hi != 0xca:
            total_errors += 1
        if mac_lo != 0xfe000003:
            total_errors += 1
        if router_ip != 0xc0a80504:
            total_errors += 1
    else:
        if mac_hi != 0:
            total_errors += 1
        if mac_lo != 0:
            total_errors += 1
        if router_ip != 0:
            total_errors += 1

print total_errors

# Routing table
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), i)
    # Router IP
    router_ip = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG())
    print "  router_ip:(%x)"%router_ip,

    arp_port = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG())
    print "output port:(%d)"%arp_port,

    next_hop_ip = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG())
    print "  next hop ip:(%x)"%next_hop_ip,

    # Router subnet mask
    subnet_mask = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG())
    print "  subnet_mask:(%x)"%subnet_mask

    if i == 0:
        if router_ip != 0xc0a80101:
            total_errors += 1
        if subnet_mask != 0xffffffe1:
            total_errors += 1
        if arp_port != 1:
            total_errors += 1
        if next_hop_ip != 0xc0a80501:
            total_errors += 1
    elif i == 1:
        if router_ip != 0xc0a80201:
            total_errors += 1
        if subnet_mask != 0xffffffe1:
            total_errors += 1
        if arp_port != 4:
            total_errors += 1
        if next_hop_ip != 0xc0a80502:
            total_errors += 1
    elif i == 2:
        if router_ip != 0xc0a80301:
            total_errors += 1
        if subnet_mask != 0xffffffe1:
            total_errors += 1
        if next_hop_ip != 0xc0a80503:
            total_errors += 1
    elif i == 3:
        if router_ip != 0xc0a80401:
            total_errors += 1
        if subnet_mask != 0xffffffe1:
            total_errors += 1
        if next_hop_ip != 0xc0a80504:
            total_errors += 1
    else:
        if router_ip != 0:
            total_errors += 1
        if subnet_mask != 0xffffffff:
            total_errors += 1
        if next_hop_ip != 0:
            total_errors += 1

# IP filter
print total_errors
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), i)
    filter = regread('nf2c0', reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG())
    if i == 0:
        if filter != 0xc0a80028:
            total_errors += 1
    elif i == 1:
        if filter != 0xc0a80128:
            total_errors += 1
    elif i == 2:
        if filter != 0xc0a80228:
            total_errors += 1
    elif i == 3:
        if filter != 0xc0a80328:
            total_errors += 1
    elif i == 4:
        if filter != 0xe0000005:
            total_errors += 1
    else:
        if filter != 0:
            total_errors += 1
    print "row:" + str(i) + " filter (%x)"%filter

print total_errors

nftest_barrier()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
