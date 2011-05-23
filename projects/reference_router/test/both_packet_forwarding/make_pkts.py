#!/usr/bin/python

from NFTestLib import *

import hwPktLib

from RegressRouterLib import *

from PacketLib import *

import time

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"

nextHopMAC = "dd:55:dd:66:dd:77"

precreated0 = []
precreated0_exp = []
# loop for 20 packets from eth1 to eth2
for i in range(20):
    # set parameters
    DA = routerMAC0
    SA = "aa:bb:cc:dd:ee:ff"
    TTL = 64
    DST_IP = "192.168.1.1"
    SRC_IP = "192.168.0.1"
    length = 100
    nextHopMAC = "dd:55:dd:66:dd:77"

    sent_pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                               src_IP=SRC_IP, TTL=TTL, pkt_len=length)
    exp_pkt = make_IP_pkt(dst_MAC=nextHopMAC, src_MAC=routerMAC1,
                              TTL=TTL-1, dst_IP=DST_IP, src_IP=SRC_IP)
    exp_pkt[scapy.Raw].load = sent_pkt[scapy.Raw].load

    precreated0.append(sent_pkt)
    precreated0_exp.append(exp_pkt)

precreated1 = []
precreated1_exp = []
# loop for 20 packets from eth2 to eth1
for i in range(20):
    # set parameters
    DA = routerMAC1
    SA = "aa:bb:cc:dd:ee:ff"
    TTL = 64
    DST_IP = "192.168.2.1"
    SRC_IP = "192.168.0.1"
    length = 100
    nextHopMAC = "dd:55:dd:66:dd:77"

    sent_pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP, src_IP=SRC_IP, TTL=TTL, pkt_len=length)
    exp_pkt = make_MAC_hdr(dst_MAC=nextHopMAC, src_MAC=routerMAC0)/make_IP_hdr(TTL=TTL-1, dst_IP=DST_IP, src_IP=SRC_IP)/sent_pkt[scapy.Raw]

    precreated1.append(sent_pkt)
    precreated1_exp.append(exp_pkt)

scapy.wrpcap('precreated0.pcap', precreated0)
scapy.wrpcap('precreated0_exp.pcap', precreated0_exp)
scapy.wrpcap('precreated1.pcap', precreated1)
scapy.wrpcap('precreated1_exp.pcap', precreated1_exp)
