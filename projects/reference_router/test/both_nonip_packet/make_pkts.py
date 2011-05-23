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
routerMAC1 = "00:ca:fe:00:00:02"

for portid in range(2):
    # set parameters
    if portid == 0:
        DA = routerMAC0
    else:
        DA = routerMAC1
    SA = "aa:bb:cc:dd:ee:ff"
    TTL = 64
    DST_IP = "192.168.2.1";   #not in the lpm table
    SRC_IP = "192.168.0.1"
    VERSION = 0x4
    nextHopMAC = "dd:55:dd:66:dd:77"

    # Non IP packets
    EtherType = 0x802

    # precreate random packets
    portPkts = []
    for i in range(30):
        portPkts.append(make_IP_pkt(dst_MAC=DA, src_MAC=SA,
                                    EtherType=EtherType, dst_IP=DST_IP,
                                    TTL=TTL, pkt_len=random.randint(60,1514)))

    scapy.wrpcap('eth' + str(portid+1) + '_pkts.pcap', portPkts)
