#!/usr/bin/python

from PacketLib import *
from NFTestHeader import scapy

NUM_PKTS = 500

# set parameters
DA = "00:ca:fe:00:00:01"
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"

pkts0 = []
for i in range(NUM_PKTS):
    pkts0.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                             src_IP=SRC_IP, TTL=TTL,
                             pkt_len=1514))
pkts1 = []
DA = "00:ca:fe:00:00:02"
for i in range(NUM_PKTS):
    pkts1.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                             src_IP=SRC_IP, TTL=TTL,
                             pkt_len=1514))

pkts2 = []
DA = "00:ca:fe:00:00:03"
for i in range(NUM_PKTS):
    pkts2.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                             src_IP=SRC_IP, TTL=TTL,
                             pkt_len=1514))

pkts3 = []
DA = "00:ca:fe:00:00:04"
for i in range(NUM_PKTS):
    pkts3.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                             src_IP=SRC_IP, TTL=TTL,
                             pkt_len=1514))


scapy.wrpcap("pkts0.pcap", pkts0)
scapy.wrpcap("pkts1.pcap", pkts1)
scapy.wrpcap("pkts2.pcap", pkts2)
scapy.wrpcap("pkts3.pcap", pkts3)
