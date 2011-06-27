#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

dstIP0 = "192.168.0.50"
dstIP1 = "192.168.1.50"
dstIP2 = "192.168.2.50"
dstIP3 = "192.168.3.50"

dstMAC0 = "aa:bb:cc:dd:ee:01"
dstMAC1 = "aa:bb:cc:dd:ee:02"
dstMAC2 = "aa:bb:cc:dd:ee:03"
dstMAC3 = "aa:bb:cc:dd:ee:04"

ALLSPFRouters = "224.0.0.5"

NUM_PKTS_IN_CPU_OQ = 8

DA = routerMAC0
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.101.2"
SRC_IP = "192.168.100.2"
nextHopMAC = "dd:55:dd:66:dd:77"

precreated0 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated0.append(make_IP_pkt(dst_MAC=routerMAC0, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated1 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated1.append(make_IP_pkt(dst_MAC=routerMAC1, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated2 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated2.append(make_IP_pkt(dst_MAC=routerMAC2, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

precreated3 = []
for i in range(NUM_PKTS_IN_CPU_OQ + 1):
    precreated3.append(make_IP_pkt(dst_MAC=routerMAC3, src_MAC=SA,
                                   EtherType=0x800, dst_IP=DST_IP,
                                   src_IP=SRC_IP, TTL=TTL, pkt_len=1016))

scapy.wrpcap('precreated0.pcap', precreated0)
scapy.wrpcap('precreated1.pcap', precreated1)
scapy.wrpcap('precreated2.pcap', precreated2)
scapy.wrpcap('precreated3.pcap', precreated3)
