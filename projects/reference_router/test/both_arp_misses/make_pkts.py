#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

import random

routerMAC0 = "00:ca:fe:00:00:01"
DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

portPkts = []
for i in range(30):
    portPkts.append(make_IP_pkt(src_MAC=SA, dst_MAC=DA, EtherType=0x800,
                                dst_IP=DST_IP, src_IP=SRC_IP, TTL=TTL,
                                pkt_len=random.randint(60,1514)))

scapy.wrpcap('eth1_pkts.pcap', portPkts)
