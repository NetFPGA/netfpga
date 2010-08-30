#!/usr/bin/python

import Packet
import testReg
import testPkt
import Test

Test.init()

length = 100;
DA_sub = ':dd:dd:dd:dd';
SA_sub = ':55:55:55:55';
pkt;
in_port;
out_port;

$delay = '@7us';
range = 1454;
minimum = 60;

for i in range(50):
    length = int(rand(range)) + minimum
    temp = sprintf("%02x:%02x", (i>>8)&0xff, i&0xff); #questionable sprintf
    DA = temp + DA_sub
    SA = temp + SA_sub
    in_port = (int(rand(100))%4)+1
    pkt = Packet.make_IP_pkt(length, DA, SA, 64, '192.168.0.1', '192.168.0.2');
    if i%2==0:
        testPkt.pktSendPHY(in_port, pkt)
        testPkt.pktExpectDMA(in_port, pkt)
    else:
        testPkt.pktSendDMA(in_port, pkt)
        testPkt.pktExpectPHY(in_port, pkt)

Test.close()
print  "--- make_pkts.py: Generated and sent all configuration packets.\n";
