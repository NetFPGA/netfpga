#!/usr/bin/python
# make_pkts.py

import testReg
import testPkt
import Test
import Packet

DA_sub = ':dd:dd:dd:dd:dd'; SA_sub = ':55:55:55:55:55';

Test.init()
testReg.regWrite(0x08, 0) #CPCI_Control_reg
testReg.regWrite(0x40, 0) #CPCI_Interrupt_Mask
testPkt.barrier()

length = 60;
for i in range(10):
  temp = "%02x" % i
  DA = temp + DA_sub
  SA = temp + SA_sub
  in_port = (i%4)+1
  pkt = Packet.make_IP_pkt(length, DA, SA, '64', '192.168.0.1', '192.168.0.2')
  print "- made IP pkt "
  if i%2 == 0:
    testPkt.pktSendPHY(in_port, pkt)
    testPkt.pktExpectDMA(in_port, pkt)
  else:
    testPkt.pktSendDMA(in_port, pkt)
    testPkt.pktExpectPHY(in_port, pkt)

  #testPkt.delay(1000)
  testReg.regWrite(0x0000020,0xabcd)
  testReg.regRead(0x0000020,0xabcd)
  testReg.regWrite(0x0000020,0xdead)
  testReg.regRead(0x0000020,0xdead)
  testReg.regWrite(0x0000020,0xabcd)
  testReg.regRead(0x0000020,0xabcd)
  testReg.regWrite(0x0000020,0xdead)
  testReg.regRead(0x0000020,0xdead)
  testReg.regWrite(0x0000020,0xabcd)
  testReg.regRead(0x0000020,0xabcd)
  testReg.regWrite(0x0000020,0xdead)
  testReg.regRead(0x0000020,0xdead)
  #testPkt.delay(1000)

#testPkt.delay(1000)
testPkt.barrier()

print  "--- make_pkts.py: Generated and sent all configuration packets.\n"
Test.close()
#Test.modelSim("eric")
