#!/bin/env python

from NFTestLib import *
from PacketLib import *

from hwPktLib import *
from hwRegLib import *

from RegressRouterLib import *

import random

import time

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

import scapy.all as scapy

interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2")

nftest_init(interfaces, 'conn')
nftest_start()

NUM_PKTS_PER_PORT = 500
PKT_SIZE = 1514

nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 0x0)
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 0x0)

routerMAC0 = "00:ca:fe:00:00:01"
routerMAC1 = "00:ca:fe:00:00:02"
routerMAC2 = "00:ca:fe:00:00:03"
routerMAC3 = "00:ca:fe:00:00:04"

routerIP0 = "192.168.0.40"
routerIP1 = "192.168.1.40"
routerIP2 = "192.168.2.40"
routerIP3 = "192.168.3.40"

total_errors = 0

nwords_before_0 = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_WORDS_LEFT_REG())
nwords_before_2 = regread('nf2c0', reg_defines.OQ_QUEUE_2_NUM_WORDS_LEFT_REG())
nwords_before_4 = regread('nf2c0', reg_defines.OQ_QUEUE_4_NUM_WORDS_LEFT_REG())
nwords_before_6 = regread('nf2c0', reg_defines.OQ_QUEUE_6_NUM_WORDS_LEFT_REG())

pkts = []
for i in range(4):
    pkts.append(scapy.rdpcap('pkts' + str(i) + '.pcap'))

for i in range(4):
    for pkt in pkts[i]:
        nftest_send('nf2c'+str(i), pkt)

time.sleep(4)

for i in range(4):
    pktsStored = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 0x400)
    pktsDropped = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG() + i * 0x400)
    pktsRemoved = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 0x400)
    bytesStored = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 0x400)
    bytesRemoved = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 0x400)

    if pktsStored + pktsDropped != NUM_PKTS_PER_PORT:
        print "Error: packets stored plus dropped not equal to number sent";
        print "Packets Stored: " + str(pktsStored) + "   Dropped: " + str(pktsDropped) + "   Total:   " + str(pktsStored + pktsDropped)
        print "Expected: " + str(NUM_PKTS_PER_PORT)
        total_errors += 1

    if pktsRemoved != 0:
        print "Error: packets removed should be zero"
        print "Removed: " + str(pktsRemoved)
        total_errors += 1

    if pktsStored * PKT_SIZE != bytesStored:
        print "Error: bytes stored not equal to number expected"
        print "Bytes Stored: " + str(bytesStored) + "   Expected: " + str(pktsStored * PKTSIZE)
        total_errors += 1

header_bytes_re = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED_REG())
header_bytes = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED_REG())
num_packets = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG())
header = num_packets * 8
if header_bytes != header:
    total_errors += 1
print "queue 0 -> header stored: " + str(header_bytes) + " header removed: " + str(header_bytes_re)

header_bytes_re = regread('nf2c0', reg_defines.OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED_REG())
header_bytes = regread('nf2c0', reg_defines.OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED_REG())
num_packets = regread('nf2c0', reg_defines.OQ_QUEUE_2_NUM_PKTS_STORED_REG())
header = num_packets * 8
if header_bytes != header:
    total_errors += 1
print "queue 2 -> header stored: " + str(header_bytes) + " header removed: " + str(header_bytes_re)

header_bytes_re = regread('nf2c0', reg_defines.OQ_QUEUE_4_NUM_OVERHEAD_BYTES_REMOVED_REG())
header_bytes = regread('nf2c0', reg_defines.OQ_QUEUE_4_NUM_OVERHEAD_BYTES_STORED_REG())
num_packets = regread('nf2c0', reg_defines.OQ_QUEUE_4_NUM_PKTS_STORED_REG())
header = num_packets * 8
if header_bytes != header:
    total_errors += 1
print "queue 4 -> header stored: " + str(header_bytes) + " header removed: " + str(header_bytes_re)

header_bytes_re = regread('nf2c0', reg_defines.OQ_QUEUE_6_NUM_OVERHEAD_BYTES_REMOVED_REG())
header_bytes = regread('nf2c0', reg_defines.OQ_QUEUE_6_NUM_OVERHEAD_BYTES_STORED_REG())
num_packets = regread('nf2c0', reg_defines.OQ_QUEUE_6_NUM_PKTS_STORED_REG())
header = num_packets * 8
if header_bytes != header:
    total_errors += 1
print "queue 6 -> header stored: " + str(header_bytes) + " header removed: " + str(header_bytes_re)

address_hi = regread('nf2c0', reg_defines.OQ_QUEUE_0_ADDR_HI_REG())
address_lo = regread('nf2c0', reg_defines.OQ_QUEUE_0_ADDR_LO_REG())
print "address queue 0: %x%x"%(address_hi, address_lo)

address_hi = regread('nf2c0', reg_defines.OQ_QUEUE_2_ADDR_HI_REG())
address_lo = regread('nf2c0', reg_defines.OQ_QUEUE_2_ADDR_LO_REG())
print "address queue 2: %x%x"%(address_hi, address_lo)

address_hi = regread('nf2c0', reg_defines.OQ_QUEUE_4_ADDR_HI_REG())
address_lo = regread('nf2c0', reg_defines.OQ_QUEUE_4_ADDR_LO_REG())
print "address queue 4: %x%x"%(address_hi, address_lo)

address_hi = regread('nf2c0', reg_defines.OQ_QUEUE_6_ADDR_HI_REG())
address_lo = regread('nf2c0', reg_defines.OQ_QUEUE_6_ADDR_LO_REG())
print "address queue 6: %x%x"%(address_hi, address_lo)

print "Enabling output queues and verifying that queued packets are sent..."
nftest_regwrite(reg_defines.OQ_QUEUE_0_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_2_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_4_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())
nftest_regwrite(reg_defines.OQ_QUEUE_6_CTRL_REG(), 1 << reg_defines.OQ_ENABLE_SEND_BIT_NUM())

time.sleep(4)

for i in range(2):
    for pkt in pkts[i]:
        nftest_expect("eth" +str(i+1), pkt)
restart() # resets packet lists so missing dropped packets are ignored

nwords_after_0 = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_WORDS_LEFT_REG())
nwords_after_2 = regread('nf2c0', reg_defines.OQ_QUEUE_2_NUM_WORDS_LEFT_REG())
nwords_after_4 = regread('nf2c0', reg_defines.OQ_QUEUE_4_NUM_WORDS_LEFT_REG())
nwords_after_6 = regread('nf2c0', reg_defines.OQ_QUEUE_6_NUM_WORDS_LEFT_REG())

if nwords_before_0 != nwords_after_0:
    total_errors += 1
if nwords_before_2 != nwords_after_2:
    total_errors += 1
if nwords_before_4 != nwords_after_4:
    total_errors += 1
if nwords_before_6 != nwords_after_6:
    total_errors += 1

for i in range(4):
    pktsStored = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 0x400)
    pktsDropped = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG() + i * 0x400)
    pktsRemoved = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 0x400)
    bytesStored = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 0x400)
    bytesRemoved = regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 0x400)

    if pktsStored != pktsRemoved:
        print "Error: packets stored not equal to packets removed"
        print "Packets Stored: " + str(pktsStored) + "   Removed: " + str(pktsRemoved)
        total_errors += 1
    if bytesStored != bytesRemoved:
        print "Error: bytes stored not equal to bytes removed"
        print "Bytes Stored: " + str(bytesStored) + "   Removed: " + str(bytesRemoved)
        total_errors += 1

nftest_barrier()

total_errors += nftest_finish()

if total_errors == 0:
    print 'SUCCESS!'
    sys.exit(0)
else:
    print 'FAIL: ' + str(total_errors) + ' errors'
    sys.exit(1)
