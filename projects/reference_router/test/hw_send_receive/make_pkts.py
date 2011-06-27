#!/bin/env python

from PacketLib import *
from NFTestHeader import reg_defines, scapy

import random

NUM_PKTS = 100

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"


# precreate random sized packets
precreated0 = []
for i in range(NUM_PKTS):
    precreated0.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC0,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated1 = []
for i in range(NUM_PKTS):
    precreated1.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC1,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated2 = []
for i in range(NUM_PKTS):
    precreated2.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC2,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

precreated3 = []
for i in range(NUM_PKTS):
    precreated3.append(make_IP_pkt(src_MAC=SA, dst_MAC=routerMAC3,
                                   EtherType=0x800, src_IP=SRC_IP,
                                   dst_IP=DST_IP, TTL=TTL,
                                   pkt_len=random.randint(60,1514)))

scapy.wrpcap('precreated0.pcap', precreated0)
scapy.wrpcap('precreated1.pcap', precreated1)
scapy.wrpcap('precreated2.pcap', precreated2)
scapy.wrpcap('precreated3.pcap', precreated3)
