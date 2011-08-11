#!/usr/bin/python

import Packet
import testReg
import testPkt
import Test
import random

Test.init()
testReg.regWrite(0x08, 0) #CPCI_Control_reg
testReg.regWrite(0x40, 0) #CPCI_Interrupt_Mask
testPkt.barrier()

length = 100;
DA_sub = ':dd:dd:dd:dd';
SA_sub = ':55:55:55:55';

int_range = 1454;
minimum = 60;

for i in range(50):
    length = 4*random.randint(0,int_range/4)+minimum
    temp = "%02x:%02x"%((i>>8)&0xff, i&0xff )
    DA = temp + DA_sub
    SA = temp + SA_sub
    in_port = random.randint(0,100)%4+1
    pkt = Packet.make_IP_pkt(length, DA, SA, 64, '192.168.0.1', '192.168.0.2');
    if i%2==0:
        testPkt.pktSendPHY(in_port, pkt)
        testPkt.pktExpectDMA(in_port, pkt)
    else:
        testPkt.pktSendDMA(in_port, pkt)
        testPkt.pktExpectPHY(in_port, pkt)

testPkt.barrier()

Test.close()
print  "--- make_pkts.py: Generated and sent all configuration packets.\n";
