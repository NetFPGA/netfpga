#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

from RegressRouterLib import *

import random

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"

for portid in range(2):
    # set parameters
    if portid == 0:
        DA = routerMAC0
    else:
        DA = routerMAC1
    SA = "aa:bb:cc:dd:ee:ff"
    EtherType = 0x800
    TTL = 64
    DST_IP = "192.168.2.1";   #not in the lpm table
    SRC_IP = "192.168.0.1"
    nextHopMAC = "dd:55:dd:66:dd:77"

    # Non IP option or ip_ver not 4
    VERSION = 5

    # precreate random packets
    portPkts = []
    for i in range(30):
        pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, EtherType=EtherType,
                          src_IP=SRC_IP, dst_IP=DST_IP, TTL=TTL,
                          pkt_len=random.randint(60,1514))
        pkt.version = VERSION
        portPkts.append(pkt)

    scapy.wrpcap('eth' + str(portid+1) + '_pkts.pcap', portPkts)
