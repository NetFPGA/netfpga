#!/bin/env python

from PacketLib import *
from NFTestHeader import scapy

NUM_PKTS_PER_PORT = 500
PKT_SIZE = 1514

# Generate NUM_PKTS_PER_PORT packets to fill up the output queues
for portid in range(4):
    portPkts = []
    for i in range(NUM_PKTS_PER_PORT):
        portPkts.append(scapy.Raw(generate_load(PKT_SIZE)))
    scapy.wrpcap('pkts' + str(portid) + '.pcap', portPkts)
