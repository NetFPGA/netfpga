#!/usr/bin/python
# Author: James Hsi
# Date: 7/30/2010

import os
import Test

NUM_PORTS = 4

CMD_SEND = 1
CMD_BARRIER = 2
CMD_DELAY = 3

CMD_PCI_BARRIER = 4
CMD_PCI_DELAY = 5

# Global counters for synchronization
numExpectedPktsPHY = [0,0,0,0]; numExpectedPktsDMA = [0,0,0,0];


############################
# Function: pktSendPHY
# Arguments: toPort - the port the packet will be sent to (1-4)
#            pkt - the packet data
#
############################
def pktSendPHY(toPort, pkt):
    print "[x]sendPHY TEST"

    f = Test.fPort(toPort)
    f.write("// Packet DEADBEEF_NUM\n")
    f.write("// Len:000003C DA: 00:dd:dd:dd:dd:dd SA: 00:55:55:55:55:55 [0800] 45 00 00 2e 00 00...\n") #needs to be updated
    f.write("%08d"%CMD_SEND+" // SEND\n")

    pktLen = int(pkt.sprintf("%IP.len%"))
    f.write('0000003C // Length without CRC\n')
    f.write("%08d"%toPort+" // Port "+str(toPort)+"\n")

    PACKET_LINES=15 #number of lines of hex in file, not counting end of pkt marker
    for i in range(PACKET_LINES):
        f.write("deadbeef\n") #write packet data. eventually should get length of packet then create an array

    f.write('eeeeffff // End of pkt marker for pkt (this is not sent).\n') #f.write('eeeeffff // End of pkt marker for pkt '+str(packetNum)+' (this is not sent).')


############################
# Function: pktSendDMA
# Arguments: toPort - the port the packet will be sent to (1-4)
#            pkt - the packet data
#
############################
def pktSendDMA(toPort, pkt):
    print "[o]sendDMA"
    f = Test.fDMA()

    f.write("%08d"%CMD_SEND+" // SEND\n")#f.write("\n%08d"%CMD_SEND+" // SEND\n")
    f.write("// Packet # of #\n") #need to change this line

    pktLen = int(pkt.sprintf("%IP.len%"))
    f.write('0000003C // Length without CRC\n')
    PACKET_LINES = 15
    for i in range(PACKET_LINES):
        f.write("deadbeef\n")

    f.write('eeeeffff // End of pkt marker for pkt (this is not sent).\n') #f.write('eeeeffff // End of pkt marker for pkt '+str(packetNum)+' (this is not sent).')


############################
# Function: pktExpectPHY
# Arguments:
#  TO BE IMPLEMENTED
############################
def pktExpectPHY(atPort, pkt):
    print "[O]expectPHY"
    numExpectedPktsPHY[atPort-1] = numExpectedPktsPHY[atPort-1]+1
    #write XML to file: expected_port_fromPort


############################
#Function: pktExpectDMA
#Arguments:
#  TO BE IMPLEMENTED
############################
def pktExpectDMA(atPort, pkt):
    print "[X]expectDMA"
    numExpectedPktsDMA[atPort-1] = numExpectedPktsDMA[atPort-1]+1
    #write XML to file: expected_dma_fromPort


###########################
#Function: pktCmp
#Arguments:
#  ...
# pktCmp is just a byte by byte comparison
############################
def pktCmp(pkt1, pkt2):
    print "[testPkt] pktcmp("+" "+")\n"


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
