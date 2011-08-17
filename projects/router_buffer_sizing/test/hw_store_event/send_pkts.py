#!/bin/env python

from NFTest import *
from RegressRouterLib import *

nftest_init(hw_config=[('../connections/conn', [])])
nftest_start()

routerMAC = []
routerIP = []
for i in range(4):
    routerMAC.append("00:ca:fe:00:00:%02d"%i)
    routerIP.append("192.168.%d.40"%i)

    nftest_add_dst_ip_filter_entry(i, routerIP[i])
    nftest_set_router_MAC("nf2c%d"%i, routerMAC[i])

for i in range(32):
    nftest_invalidate_LPM_table_entry(i)
    nftest_invalidate_ARP_table_entry(i)

# add an entry in the routing table:
index = 0
subnetIP = "192.168.100.0"
subnetIP2 = "192.168.101.1"
subnetMask = "255.255.255.0"
subnetMask2 = "255.255.255.225"
nextHopIP = "192.168.1.54"
nextHopIP2 = "192.168.3.12"
outPort = 0x1 # output on MAC0
outPort2 = 0x4 # port numbers are one hot, it means port  2 which is eth2
nextHopMAC = "dd:55:dd:66:dd:77"

nftest_add_LPM_table_entry (
                            1,
                            subnetIP,
                            subnetMask,
                            nextHopIP,
                            outPort);

nftest_add_LPM_table_entry (
                            0,
                            subnetIP2,
                            subnetMask2,
                            nextHopIP2,
                            outPort2);


# add an entry in the ARP table
nftest_add_ARP_table_entry(
                           index,
                           nextHopIP,
                           nextHopMAC);

# add an entry in the ARP table
nftest_add_ARP_table_entry(
                           1,
                           nextHopIP2,
                           nextHopMAC);

evts_ethertype = 0x9999

nftest_regwrite(reg_defines.EVT_CAP_DST_MAC_HI_REG(), 0x0000dddd)
nftest_regwrite(reg_defines.EVT_CAP_DST_MAC_LO_REG(), 0xdddddddd)
nftest_regwrite(reg_defines.EVT_CAP_SRC_MAC_HI_REG(), 0x00005555)
nftest_regwrite(reg_defines.EVT_CAP_SRC_MAC_LO_REG(), 0x55555555)
nftest_regwrite(reg_defines.EVT_CAP_ETHERTYPE_REG(), evts_ethertype)
nftest_regwrite(reg_defines.EVT_CAP_IP_DST_REG(), 0xabcd1234)
nftest_regwrite(reg_defines.EVT_CAP_IP_SRC_REG(), 0x567890ef)
nftest_regwrite(reg_defines.EVT_CAP_UDP_SRC_PORT_REG(), 9876)
nftest_regwrite(reg_defines.EVT_CAP_UDP_DST_PORT_REG(), 9999)
evt_out_port = 1
nftest_regwrite(reg_defines.EVT_CAP_OUTPUT_PORTS_REG(), 2)
nftest_regwrite(reg_defines.EVT_CAP_MONITOR_MASK_REG(), 0x7)    # events mask
nftest_regwrite(reg_defines.EVT_CAP_SIGNAL_ID_MASK_REG(), 0xff) # queue mask
nftest_regwrite(reg_defines.EVT_CAP_ENABLE_CAPTURE_REG(), 1)

DA = routerMAC[0]
SA = "aa:bb:cc:dd:ee:ff"
DST_IP = "192.168.101.1"
SRC_IP = "192.168.100.1"
length = 100
nextHopMAC = "dd:55:dd:66:dd:77"

for i in range(1000):
    pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP, src_IP=SRC_IP, pkt_len=length)
    nftest_send_phy('nf2c0', pkt)

nftest_finish()
