#!/bin/env python

from NFTest import *
import random
import sys

phy0loop4 = ('../connections/conn', ['nf2c0', 'nf2c1', 'nf2c2', 'nf2c3'])

nftest_init(sim_loop = ['nf2c0', 'nf2c1', 'nf2c2', 'nf2c3'], hw_config = [phy0loop4])
nftest_start()

# set parameters
DA = "00:ca:fe:00:00:01"
SA = "aa:bb:cc:dd:ee:ff"
TTL = 64
DST_IP = "192.168.1.1"
SRC_IP = "192.168.0.1"
nextHopMAC = "dd:55:dd:66:dd:77"
NUM_PKTS = 2

print "Sending now: "
pkts = [[], [], [], []]
totalPktLengths = [0,0,0,0]
# send NUM_PKTS from ports nf2c0...nf2c3
for i in range(NUM_PKTS):
    sys.stdout.write('\r'+str(i))
    sys.stdout.flush()
    for port in range(4):
        DA = "00:ca:fe:00:00:%02x"%port
        pkts[port].append(make_IP_pkt(dst_MAC=DA, src_MAC=SA, dst_IP=DST_IP,
                             src_IP=SRC_IP, TTL=TTL,
                             pkt_len=random.randint(60,1514)))
        totalPktLengths[port] += len(pkts[port][i])
        nftest_send_dma('nf2c' + str(port), pkts[port][i])
        nftest_expect_dma('nf2c' + str(port), pkts[port][i])

print ""

nftest_barrier()

print "Checking pkt errors on Normal Operation\n"
# check counter values
for i in range(4):
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + i*0x40000, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + i*0x40000, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])

print ""

nftest_fpga_reset()

# Disable CRC
for i in range(4):
    nftest_regwrite(reg_defines.MAC_GRP_0_CONTROL_REG() + i*reg_defines.MAC_GRP_OFFSET(), 1 << reg_defines.MAC_GRP_MAC_DIS_CRC_GEN_BIT_NUM())

nftest_barrier()

# Send Packets with CRC disabled
print "Sending now: "
totalPktLengths = [0,0,0,0]
# send NUM_PKTS from ports nf2c0...nf2c3
for i in range(NUM_PKTS):
    sys.stdout.write('\r'+str(i))
    sys.stdout.flush()
    for port in range(4):
        totalPktLengths[port] += len(pkts[port][i])
        nftest_send_dma('nf2c' + str(port), pkts[port][i])

print ""

nftest_barrier()


print "Checking pkt errors on Operation after CRC is disabled\n"
# check counter values
for i in range(4):
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + i*0x40000, 0)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + i*0x40000, NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, 0)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + i*0x40000, totalPktLengths[i])
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG()  + i*0x40000, NUM_PKTS)

print ""

nftest_fpga_reset()

# Enable CRC
for i in range(4):
    nftest_regwrite(reg_defines.MAC_GRP_0_CONTROL_REG() + i*reg_defines.MAC_GRP_OFFSET(), 0 << reg_defines.MAC_GRP_MAC_DIS_CRC_GEN_BIT_NUM())

nftest_barrier()

# Send packets normally again
print "Sending now: "
totalPktLengths = [0,0,0,0]
# send NUM_PKTS from ports nf2c0...nf2c3
for i in range(NUM_PKTS):
    sys.stdout.write('\r'+str(i))
    sys.stdout.flush()
    for port in range(4):
        totalPktLengths[port] += len(pkts[port][i])
        nftest_send_dma('nf2c' + str(port), pkts[port][i])
        nftest_expect_dma('nf2c' + str(port), pkts[port][i])

print ""

nftest_barrier()

print "Checking pkt errors on Normal Operation after CRC is enabled\n"
# check counter values
for i in range(4):
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + i*reg_defines.MAC_GRP_OFFSET(), NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + i*reg_defines.MAC_GRP_OFFSET(), NUM_PKTS)
    nftest_regread_expect(reg_defines.MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + i*reg_defines.MAC_GRP_OFFSET(), totalPktLengths[i])
    nftest_regread_expect(reg_defines.MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + i*reg_defines.MAC_GRP_OFFSET(), totalPktLengths[i])

print ""

nftest_finish()
