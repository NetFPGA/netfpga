#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

import random

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"

dstIP0 = "192.168.0.50"
dstIP1 = "192.168.1.50"
dstIP2 = "192.168.2.50"
dstIP3 = "192.168.3.50"

dstMAC0 = "aa:bb:cc:dd:ee:01"
dstMAC1 = "aa:bb:cc:dd:ee:02"
dstMAC2 = "aa:bb:cc:dd:ee:03"
dstMAC3 = "aa:bb:cc:dd:ee:04"

NUM_PKTS = 20

ippkt_hdr = make_MAC_hdr(dst_MAC=routerMAC0,
                         src_MAC=dstMAC3)/make_IP_hdr(src_IP=dstIP3,
                                                      dst_IP=dstIP0, ttl=64)

precreated0 = []
load0 = []
ippkt_hdr[scapy.Ether].dst = routerMAC0
for i in range(NUM_PKTS):
    whichIP = random.randint(0,2)
    if whichIP == 0:
        ippkt_hdr[scapy.IP].dst = dstIP0
    elif whichIP == 1:
        ippkt_hdr[scapy.IP].dst = dstIP1
    else:
        ippkt_hdr[scapy.IP].dst = dstIP2
    load = generate_load(random.randint(60-len(ippkt_hdr), 1514-len(ippkt_hdr)))
    load0.append(load)
    precreated0.append(ippkt_hdr/load)

precreated1 = []
load1 = []
ippkt_hdr[scapy.Ether].dst = routerMAC1
for i in range(NUM_PKTS):
    whichIP = random.randint(0,2)
    if whichIP == 0:
        ippkt_hdr[scapy.IP].dst = dstIP0
    elif whichIP == 1:
        ippkt_hdr[scapy.IP].dst = dstIP1
    else:
        ippkt_hdr[scapy.IP].dst = dstIP2
    load = generate_load(random.randint(60-len(ippkt_hdr), 1514-len(ippkt_hdr)))
    load1.append(load)
    precreated1.append(ippkt_hdr/load)

scapy.wrpcap('precreated0.pcap', precreated0)
scapy.wrpcap('precreated1.pcap', precreated1)

exp_hdr = ippkt_hdr
exp_hdr[scapy.Ether].dst = dstMAC0
exp_hdr[scapy.Ether].src = routerMAC1
exp_hdr[scapy.IP].dst = dstIP0
exp_hdr[scapy.IP].ttl = 63

expected0 = [exp_hdr/x.load for x in precreated0]
expected1 = [exp_hdr/x.load for x in precreated1]

scapy.wrpcap('expected0.pcap', expected0)
scapy.wrpcap('expected1.pcap', expected1)
