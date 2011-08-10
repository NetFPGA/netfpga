#!/bin/env python

from NFTest import *
from NFTest.hwRegLib import *
from RegressRouterLib import *

phy2loop0 = ('../connections/2phy', [])

nftest_init(sim_loop = [], hw_config = [phy2loop0])
nftest_start()

NUM_PORTS = 4

def get_dest_MAC(i):
    i_plus_one = i + 1
    if i == 0:
        return "00:ca:fe:00:00:02"
    if i == 1:
        return "00:ca:fe:00:00:01"
    if i == 2:
        return "00:ca:fe:00:00:04"
    if i == 3:
        return "00:ca:fe:00:00:03"

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
nftest_add_dst_ip_filter_entry (4, ALLSPFRouters)

# router mac 0
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_0_HI_REG(), 0xca)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_0_LO_REG(), 0xfe000001)
# router mac 1
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_1_HI_REG(), 0xca)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_1_LO_REG(), 0xfe000002)
# router mac 2
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_2_HI_REG(), 0xca)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_2_LO_REG(), 0xfe000003)
# router mac 3
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_3_HI_REG(), 0xca)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_3_LO_REG(), 0xfe000004)

# add LPM and ARP entries for each port
for i in range(NUM_PORTS):
    i_plus_1 = i + 1
    subnetIP = "192.168." + str(i_plus_1) + ".1"
    subnetMask = "255.255.255.225"
    nextHopIP = "192.168.5." + str(i_plus_1)
    outPort = 1 << (2 * i)
    nextHopMAC = get_dest_MAC(i)

    # add an entry in the routing table
    nftest_add_LPM_table_entry(i, subnetIP, subnetMask, nextHopIP, outPort)
    # add and entry in the ARP table
    nftest_add_ARP_table_entry(i, nextHopIP, nextHopMAC)

# ARP table
mac_hi = 0xca
mac_lo = [0xfe000002, 0xfe000001, 0xfe000004, 0xfe000003]
router_ip = [0xc0a80501, 0xc0a80502, 0xc0a80503, 0xc0a80504]
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), i)
    # ARP MAC
    if i < 4:
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), mac_hi)
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), mac_lo[i])
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), router_ip[i])
    else:
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), 0)
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), 0)
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0)

# Routing table
router_ip = [0xc0a80101, 0xc0a80201, 0xc0a80301, 0xc0a80401]
subnet_mask = [0xffffffe1, 0xffffffe1, 0xffffffe1, 0xffffffe1]
arp_port = [1, 4]
next_hop_ip = [0xc0a80501, 0xc0a80502, 0xc0a80503, 0xc0a80504]
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), i)
    if i < 2:
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), arp_port[i])
    if i < 4:
        # Router IP
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), router_ip[i])
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), next_hop_ip[i])
        # Router subnet mask
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), subnet_mask[i])
    else:
        # Router IP
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), 0)
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0)
        # Router subnet mask
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), 0xffffffff)

# IP filter
filter = [0xc0a80028, 0xc0a80128, 0xc0a80228, 0xc0a80328, 0xe0000005]
for i in range(31):
    nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), i)
    if i < 5:
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), filter[i])
    else:
        nftest_regread_expect(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), 0)

nftest_finish()
