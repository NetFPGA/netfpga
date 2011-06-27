#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

import random

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

for portid in range(2):
    # set parameters
    SA = "aa:bb:cc:dd:ee:ff"
    EtherType = 0x800
    TTL = 64
    DST_IP = "192.168.2.1";   #not in the lpm table
    SRC_IP = "192.168.0.1"
    VERSION = 0x4
    nextHopMAC = "dd:55:dd:66:dd:77"

    # Wrong mac destination
    DA = "00:ca:fe:00:00:11"

    # precreate random packets
    portPkts = []
    for i in range(30):
        portPkts.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA,
                                    EtherType=EtherType, src_IP=SRC_IP,
                                    dst_IP=DST_IP, TTL=TTL,
                                    pkt_len=random.randint(60, 1514)))

    scapy.wrpcap("eth" + str(portid+1) + "_pkts.pcap", portPkts)
