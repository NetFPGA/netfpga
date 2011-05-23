#!/bin/env python

from NFTestLib import *
from PacketLib import *

from RegressRouterLib import *

import random

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

routerMAC0 = "00:ca:fe:00:00:01"

pkts = []
for i in range(100):
    pkt = make_IP_pkt(src_MAC="aa:bb:cc:dd:ee:ff", dst_MAC=routerMAC0,
                      EtherType=0x800, src_IP="192.168.0.1",
                      dst_IP="192.168.2.1", TTL=64)

    pkts.append(pkt)

scapy.wrpcap('eth1_pkts.pcap', pkts)
