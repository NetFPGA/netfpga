#!/usr/bin/python
# make_pkts.py

import testReg
import testPkt
import Test
import Packet
import reg_defines_reference_nic

Test.init()
testReg.regWrite(0x08, 0) #CPCI_Control_reg
testReg.regWrite(0x40, 0) #CPCI_Interrupt_Mask
testPkt.barrier()

# Prepare the DMA and enable interrupts
#prepare_DMA('@3.9us');
#enable_interrupts(0);

DA = '00:dd:dd:dd:dd:dd'
SA = '00:55:55:55:55:55'

# Send a packet in via DMA
length = 60;
in_port = 1;
pkt = Packet.make_IP_pkt(length, DA, SA, length, '192.168.0.1', '192.168.0.2')
testPkt.pktSendDMA(in_port, pkt)
testPkt.pktExpectPHY(in_port, pkt)

# check counter values
testReg.regRead(reg_defines_reference_nic.DMA_CTRL_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_EGRESS_PKTS_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_EGRESS_BYTES_REG(), 0x3c);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_TIMEOUTS_REG(), 0x0);

testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_CONTROL_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_OVERRUNS_REG(), 0x0);

# Send a packet in an ethernet port and expect via DMA

in_port = 1
pkt = Packet.make_IP_pkt(length, DA, SA, length, '192.168.0.1', '192.168.0.2');
testPkt.pktSendPHY(in_port, pkt)
testPkt.pktExpectDMA(in_port, pkt)

# check counter values
testReg.regRead(reg_defines_reference_nic.DMA_CTRL_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_INGRESS_PKTS_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_INGRESS_BYTES_REG(), 0x3c);
testReg.regRead(reg_defines_reference_nic.DMA_NUM_TIMEOUTS_REG(), 0x0);

testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_CONTROL_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
testReg.regRead(reg_defines_reference_nic.CPU_QUEUE_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);

# *********** Finishing Up - need this in all scripts ! ****************************
testPkt.barrier()

print  "--- make_pkts.py: Generated and sent all configuration packets.\n"
Test.close()
