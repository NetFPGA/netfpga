#!/bin/env python

from NFTest import *
import sys
import time

phy0loop4 = ('../connections/conn', ['nf2c0', 'nf2c1', 'nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c0', 'nf2c1', 'nf2c2', 'nf2c3'], hw_config = [phy0loop4])
nftest_start()

NUM_PKTS_PER_PORT = 50
PKT_SIZE  = 1514

pkts = [[], [], [], []]
for i in range(NUM_PKTS_PER_PORT):
    pkts[0].append(scapy.Raw(generate_load(PKT_SIZE)))

for i in range(NUM_PKTS_PER_PORT):
    pkts[1].append(scapy.Raw(generate_load(PKT_SIZE)))

for i in range(NUM_PKTS_PER_PORT):
    pkts[2].append(scapy.Raw(generate_load(PKT_SIZE)))

for i in range(NUM_PKTS_PER_PORT):
    pkts[3].append(scapy.Raw(generate_load(PKT_SIZE)))

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
        nftest_send_dma(iface, pkt)

time.sleep(2)

# Verify that the correct number of packets have been received
for i in range(4):
    pktsStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    pktsDropped = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    pktsRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    bytesStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    bytesRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())

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
    pktsStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_STORED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    pktsRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    bytesStored = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())
    bytesRemoved = hwRegLib.regread('nf2c0', reg_defines.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + i * 2 * reg_defines.OQ_QUEUE_GROUP_INST_OFFSET())

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
        nftest_send_dma(iface, pkt)
        nftest_expect_dma(iface, pkt)

nftest_barrier()

hwRegLib.reset_phy()

nftest_finish(total_errors = total_errors)
