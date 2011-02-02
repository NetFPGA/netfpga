#!/usr/bin/python
# Author: James Hsi, Eric Lo
# Date: 1/31/2011

import os
import Test
import testReg

NUM_PORTS = 4

CMD_SEND = 1
CMD_BARRIER = 2
CMD_DELAY = 3

CMD_PCI_BARRIER = 4
CMD_PCI_DELAY = 5

# Global counters for synchronization
numExpectedPktsPHY = [0,0,0,0]; numExpectedPktsDMA = [0,0,0,0];

# Packet counters
SentPktsPHYcount = [0,0,0,0]; SentPktsDMAcount = [0,0,0,0];
ExpectedPktsPHYcount = [0,0,0,0]; ExpectedPktsDMAcount = [0,0,0,0];


############################
# Function: pktSendPHY
# Arguments: toPort - the port the packet will be sent to (1-4)
#			pkt - the packet data, class scapy.Packet
#
############################
def pktSendPHY(toPort, pkt):
	f = Test.fPort(toPort)

	strpkt = ""
	strpktHdr = ""
	count = 1
	for x in str(pkt):
			strpktHdr +="%02x "%ord(x)
			strpkt +="%02x"%ord(x)
			if count<4:
					count += 1
			else:
					strpkt += "\n"
					count = 1
	if pkt.len%4 != 0:
		count += -1
		while count != 4:
			strpkt += '00'
			count += 1
	DA=str.replace(strpktHdr[0:17], ' ', ':')
	SA=str.replace(strpktHdr[18:35], ' ', ':')
	ethType=str.replace(strpktHdr[36:41], ' ','')
	samplePkt=str.replace(strpktHdr[42:60], '\n', '')

	SentPktsPHYcount[toPort-1] = SentPktsPHYcount[toPort-1]+1

	f.write("// Packet "+str(SentPktsPHYcount[toPort-1])+"\n")
	f.write("// DA: "+DA+" SA: "+SA+" ["+ethType+"] "+samplePkt+"...\n")
	f.write("%08d"%CMD_SEND+" // SEND\n")

	pktLen = pkt.len
	f.write("%08x"%pktLen+" // Length without CRC\n")
	f.write("%08d"%toPort+" // Port "+str(toPort)+"\n")

	f.write(str.rstrip(strpkt))

	f.write('\neeeeffff // End of pkt marker for pkt '+str(SentPktsPHYcount[toPort-1])+' (this is not sent).\n')


############################
# Function: pktSendDMA
# Arguments: toPort - the port the packet will be sent to (1-4)
#			pkt - the packet data, class scapy.Packet
#
############################
def pktSendDMA(toPort, pkt):
	f = Test.fDMA()

	SentPktsDMAcount[toPort-1] = SentPktsDMAcount[toPort-1]+1

	f.write("// Packet "+str(SentPktsDMAcount[toPort-1])+" at port "+str(toPort)+"\n")

	pktLen = pkt.len
	f.write("%08x"%pktLen+" // Length without CRC\n")
	strpkt = ""
	count = 1
	for x in str(pkt):
			strpkt +="%02x"%ord(x)
			if count<4:
					count += 1
			else:
					strpkt += "\n"
					count = 1
	if pkt.len%4 != 0:
		count += -1
		while count != 4:
			strpkt += '00'
			count += 1
	f.write(str.rstrip(strpkt))
	f.write('\neeeeffff // End of pkt marker for pkt '+str(SentPktsDMAcount[toPort-1])+' (this is not sent).\n')

	testReg.regDMA(toPort, pkt.len)

############################
# Function: pktExpectPHY
# Arguments: atPort - the port the packet will be sent at (1-4)
#			pkt - the packet data, class scapy.Packet
#
############################
def pktExpectPHY(atPort, pkt):
	numExpectedPktsPHY[atPort-1] = numExpectedPktsPHY[atPort-1]+1
	f = Test.fExpectPHY(atPort)

	strpkt = ""
	count = 1
	for x in str(pkt):
		strpkt +="%02x "%ord(x)
		if count<16:
				count += 1
		else:
				strpkt += "\n"
				count = 1
	DA=str.replace(strpkt[0:17], ' ', ':')
	SA=str.replace(strpkt[18:35], ' ', ':')
	ethType=str.replace(strpkt[36:41], ' ','')
	samplePkt=str.replace(strpkt[42:60], '\n', '')

	ExpectedPktsPHYcount[atPort-1] = ExpectedPktsPHYcount[atPort-1]+1

	f.write("\n<!-- Packet "+str(ExpectedPktsPHYcount[atPort-1])+"-->")
	f.write("\n<!-- DA: "+DA+" SA: "+SA+" ["+ethType+"] "+samplePkt+"...-->\n")
	f.write("<PACKET Length=\""+str(pkt.len)+"\" Port=\""+str(atPort)+"\" Delay=\"0\">\n")
	f.write(str.rstrip(strpkt))
	f.write("\n</PACKET><!--pkt"+str(ExpectedPktsPHYcount[atPort-1])+"-->\n")


############################
#Function: pktExpectDMA
# Arguments: atPort - the port the packet will be expected at (1-4)
#			pkt - the packet data, class scapy.Packet
#
############################
def pktExpectDMA(atPort, pkt):
	numExpectedPktsDMA[atPort-1] = numExpectedPktsDMA[atPort-1]+1
	f = Test.fExpectDMA(atPort)

	strpkt = ""
	count = 1
	for x in str(pkt):
		strpkt +="%02x "%ord(x)
		if count<16:
				count += 1
		else:
				strpkt += "\n"
				count = 1
	DA=str.replace(strpkt[0:17], ' ', ':')
	SA=str.replace(strpkt[18:35], ' ', ':')
	ethType=str.replace(strpkt[36:41], ' ','')
	samplePkt=str.replace(strpkt[42:60], '\n', '')

	ExpectedPktsDMAcount[atPort-1] = ExpectedPktsDMAcount[atPort-1]+1

	f.write("\n<!-- Packet "+str(ExpectedPktsDMAcount[atPort-1])+"-->")
	f.write("\n<!-- DA: "+DA+" SA: "+SA+" ["+ethType+"] "+samplePkt+"...-->\n")
	f.write("<DMA_PACKET Length=\""+str(pkt.len)+"\" Port=\""+str(atPort)+"\" Delay=\"0\">\n")
	f.write(str.rstrip(strpkt))
	f.write("\n</DMA_PACKET><!--pkt"+str(ExpectedPktsDMAcount[atPort-1])+"-->\n")


###########################
#Function: pktCmp
#Arguments:
# TO BE IMPLEMENTED
# pktCmp is just a byte by byte comparison
############################
def pktCmp(pkt1, pkt2):
	return 0
	# use scapy's comparison: pkt1==pkt2


# Synchronization ########################################################

############################
# Function: resetBarrier()
#
#  Private function to be called by pktBarrier
############################
def resetBarrier():
	numExpectedPktsPHY = [0,0,0,0];
	numExpectedPktsDMA = [0,0,0,0];


############################
# Function: barrier
# Parameters: num - number of packets that must arrive
#   Modifies appropriate files for each port and ingress_dma to denote a barrier request
############################
def barrier():
	for i in range(NUM_PORTS):
		#if(numExpectedPktsPHY[i] > 0):
		Test.fPort(i+1).write("%08d"%CMD_BARRIER+" // BARRIER\n")
		Test.fPort(i+1).write(str(numExpectedPktsPHY[i])+" // Number of Packets\n")

	#if max(numExpectedPktsDMA) > 0:
	Test.fPCI().write("%08d"%CMD_PCI_BARRIER+" // BARRIER\n")
	for i in range(NUM_PORTS):
		Test.fPCI().write(str(numExpectedPktsDMA[i])+" // Number of expected pkts received via DMA port "+str(i+1)+"\n")

	resetBarrier()

MSB_MASK = (0xFFFFFFFF00000000)
LSB_MASK = (0x00000000FFFFFFF)

###########################
# Function: pktDelay
#
###########################
def delay(nanoSeconds):
	for i in range(NUM_PORTS):
		Test.fPort(i+1).write("%08d"%CMD_DELAY+" // DELAY\n")
		Test.fPort(i+1).write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) "+str(nanoSeconds)+" ns\n")
		Test.fPort(i+1).write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (LSB) "+str(nanoSeconds)+" ns\n")

	Test.fDMA().write("%08d"%CMD_DELAY+" // DELAY\n")
	Test.fDMA().write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) "+str(nanoSeconds)+" ns\n")
	Test.fDMA().write("%08x"%(LSB_MASK & nanoSeconds) + " // Delay (LSB) "+str(nanoSeconds)+" ns\n")

	Test.fPCI().write("%08d"%CMD_PCI_DELAY+" // DELAY\n")
	Test.fPCI().write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) "+str(nanoSeconds)+" ns\n")
	Test.fPCI().write("%08x"%(LSB_MASK & nanoSeconds) + " // Delay (LSB) "+str(nanoSeconds)+" ns\n")
