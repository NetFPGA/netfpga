#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.101.2"
SRC_IP = "192.168.100.2"
nextHopMAC = "dd:55:dd:66:dd:77"

NUM_PKTS_IN_MAC_OQ = 4

precreated0 = []
for i in range(NUM_PKTS_IN_MAC_OQ + 1):
    precreated0.append(make_IP_pkt(dst_MAC=routerMAC0, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated1 = []
for i in range(NUM_PKTS_IN_MAC_OQ + 1):
    precreated1.append(make_IP_pkt(dst_MAC=routerMAC1, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated2 = []
for i in range(NUM_PKTS_IN_MAC_OQ + 1):
    precreated2.append(make_IP_pkt(dst_MAC=routerMAC2, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated3 = []
for i in range(NUM_PKTS_IN_MAC_OQ + 1):
    precreated3.append(make_IP_pkt(dst_MAC=routerMAC3, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

scapy.wrpcap('precreated0.pcap', precreated0)
scapy.wrpcap('precreated1.pcap', precreated1)
scapy.wrpcap('precreated2.pcap', precreated2)
scapy.wrpcap('precreated3.pcap', precreated3)
