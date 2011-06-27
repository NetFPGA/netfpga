#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"

nextHopMAC = "dd:55:dd:66:dd:77"

pkts = []
exp_pkts = []
for i in range(100):
    hdr = make_MAC_hdr(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC0,
                       EtherType=0x800)/scapy.IP(src="192.168.0.1",
                                                 dst="192.168.1.1", ttl=64)
    exp_hdr = make_MAC_hdr(src_MAC=routerMAC1, dst_MAC=nextHopMAC,
                           EtherType=0x800)/scapy.IP(src="192.168.0.1",
                                                     dst="192.168.1.1", ttl=63)
    load = generate_load(100)
    pkt = hdr/load
    exp_pkt = exp_hdr/load

    pkts.append(pkt)
    exp_pkts.append(exp_pkt)

scapy.wrpcap('eth1_pkts.pcap', pkts)
scapy.wrpcap('eth2_pkts.pcap', exp_pkts)
