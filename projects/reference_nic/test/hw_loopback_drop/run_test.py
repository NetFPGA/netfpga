#!/bin/env python

from NFTestLib import *
from PacketLib import *

import hwRegLib
import hwPktLib

import random
import time

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3")

nftest_init(interfaces, 'conn')
nftest_start()

nftest_barrier()

# load packets from pcap files
from make_pkts import NUM_PKTS_PER_PORT
from make_pkts import PKT_SIZE
pkts = []
pkts.append(scapy.rdpcap("pkts0.pcap"))
pkts.append(scapy.rdpcap("pkts1.pcap"))
pkts.append(scapy.rdpcap("pkts2.pcap"))
pkts.append(scapy.rdpcap("pkts3.pcap"))

# Disable all output queues
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 0x0)

total_errors = 0

# Send in the packets
print "Sending packets while output queues disabled..."
for i in range(4):
    iface = 'nf2c' + str(i)
    for pkt in pkts[i]:
        nftest_send(iface, pkt)

time.sleep(2)

# Verify that the correct number of packets have been received
for i in range(4):
    pktsStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 0x400)
    pktsDropped = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG() + i * 0x400)
    pktsRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 0x400)
    bytesStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 0x400)
    bytesRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 0x400)

    if pktsStored + pktsDropped != NUM_PKTS_PER_PORT:
        print "Error: packets stored plus dropped not equal to number sent"
        print "Packets Stored:", str(pktsStored), "    Dropped:", str(pktsDropped), "    Total:", str(pktsStored + pktsDropped)
        print "Expected:", str(NUM_PKTS_PER_PORT)
        total_errors += 1

    if pktsRemoved != 0:
        print "Error: packets removed should be zero"
        print "Removed:", str(pktsRemoved)
        total_errors += 1

    if pktsStored * PKT_SIZE != bytesStored:
        print "Error: bytes stored not equal to number expected"
        print "Bytes Stored:", str(bytesStored), "    Expected:", str(pktsStored*PKTSIZE)
        total_errors += 1

# Reenable output queues
print "Enabling output queues and verifying that queued packets are sent..."
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

time.sleep(2)
hwPktLib.restart()

# Verify that the correct number of packets have been received
for i in range(4):
    pktsStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 0x400)
    pktsRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 0x400)
    bytesStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 0x400)
    bytesRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 0x400)

    if pktsStored != pktsRemoved:
        print "Error: packets stored not equal to packets removed"
        print "Packets Stored:", str(pktsStored), "    Removed:", str(pktsRemoved)
        total_errors += 1

    if bytesStored != bytesRemoved:
        print "Error: bytes stored not equal to bytes removed"
        print "Bytes Stored:", str(bytesStored), "    Removed:", str(bytesRemoved)
        total_errors += 1

# Send more packets to make sure that the queues are functioning
print "Sending additional packets to verify that they are transmitted..."
for i in range(2):
    iface = 'nf2c' + str(i)
    for pkt in pkts[i]:
        nftest_send(iface, pkt)
        nftest_expect(iface, pkt)

nftest_barrier()

hwRegLib.reset_phy()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
