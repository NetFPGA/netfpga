#!/usr/bin/python

from NFTestLib import *
from PacketLib import *

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
import reg_defines_reference_nic as reg_defines

import scapy.all as scapy

import random

NUM_PKTS_PER_PORT = 500
PKT_SIZE  = 1514

pkts0 = []
for i in range(NUM_PKTS_PER_PORT):
    pkts0.append(scapy.Raw(generate_load(PKT_SIZE)))

pkts1 = []
for i in range(NUM_PKTS_PER_PORT):
    pkts1.append(scapy.Raw(generate_load(PKT_SIZE)))

pkts2 = []
for i in range(NUM_PKTS_PER_PORT):
    pkts2.append(scapy.Raw(generate_load(PKT_SIZE)))

pkts3 = []
for i in range(NUM_PKTS_PER_PORT):
    pkts3.append(scapy.Raw(generate_load(PKT_SIZE)))


scapy.wrpcap("pkts0.pcap", pkts0)
scapy.wrpcap("pkts1.pcap", pkts1)
scapy.wrpcap("pkts2.pcap", pkts2)
scapy.wrpcap("pkts3.pcap", pkts3)
