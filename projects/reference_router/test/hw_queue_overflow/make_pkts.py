#!/bin/env python

from NFTestLib import *
from PacketLib import *

from hwPktLib import *

from RegressRouterLib import *

import random

import time

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

NUM_PKTS_PER_PORT = 500
PKT_SIZE = 1514

# Generate NUM_PKTS_PER_PORT packets to fill up the output queues
for portid in range(4):
    portPkts = []
    for i in range(NUM_PKTS_PER_PORT):
        portPkts.append(scapy.Raw(generate_load(PKT_SIZE)))
    scapy.wrpcap('pkts' + str(portid) + '.pcap', portPkts)
