#!/usr/bin/env python
# Author: James Hsi, Eric Lo
# Date: 1/31/2011

import simLib
import simReg

NUM_PORTS = 4

CMD_SEND = 1
CMD_BARRIER = 2
CMD_DELAY = 3

CMD_PCI_BARRIER = 4
CMD_PCI_DELAY = 5

# Global counters for synchronization
numExpectedPktsPHY = [0, 0, 0, 0]; numExpectedPktsDMA = [0, 0, 0, 0]

# Packet counters
SentPktsPHYcount = [0, 0, 0, 0]; SentPktsDMAcount = [0, 0, 0, 0]
ExpectedPktsPHYcount = [0, 0, 0, 0]; ExpectedPktsDMAcount = [0, 0, 0, 0]


############################
# Function: pktSendPHY
# Arguments: toPort - the port the packet will be sent to (1-4)
#            pkt - the packet data, class scapy.Packet
#
############################
def pktSendPHY(toPort, pkt):
    f = simLib.fPort(toPort)

    # convert packet to string
    strpkt = ""
    strpktHdr = ""
    count = 1
    for x in str(pkt):
        strpktHdr += "%02x "%ord(x)
        strpkt += "%02x"%ord(x)
        if count < 4:
            count += 1
        else:
            strpkt += "\n"
            count = 1
    # pad if pkt ends in incomplete word
    if len(pkt)%4 != 0:
        count -= 1
        while count != 4:
            strpkt += '00'
            count += 1
    # format nicely
    DA = str.replace(strpktHdr[0:17], ' ', ':')
    SA = str.replace(strpktHdr[18:35], ' ', ':')
    ethType = str.replace(strpktHdr[36:41], ' ', '')
    samplePkt = str.replace(strpktHdr[42:60], '\n', '')

    # increment counter
    SentPktsPHYcount[toPort-1] += 1

    # write packet
    f.write("// Packet " + str(SentPktsPHYcount[toPort-1]) + "\n")
    f.write("// DA: " + DA + " SA: " + SA + " [" + ethType + "] " +
            samplePkt + "...\n")
    f.write("%08d"%CMD_SEND + " // SEND\n")

    pktLen = len(pkt)
    f.write("%08x"%pktLen + " // Length without CRC\n")
    f.write("%08d"%toPort + " // Port " + str(toPort) + "\n")

    f.write(str.rstrip(strpkt))

    f.write('\neeeeffff // End of pkt marker for pkt ' +
            str(SentPktsPHYcount[toPort-1]) + ' (this is not sent).\n')


############################
# Function: pktSendDMA
# Arguments: toPort - the port the packet will be sent to (1-4)
#            pkt - the packet data, class scapy.Packet
#
############################
def pktSendDMA(toPort, pkt):
    f = simLib.fDMA()

    pktLen = len(pkt)
    # convert packet to string
    strpkt = ""
    count = 1
    for x in str(pkt):
        strpkt += "%02x"%ord(x)
        if count < 4:
            count += 1
        else:
            strpkt += "\n"
            count = 1
    # pad packet if needed
    if len(pkt)%4 != 0:
        count -= 1
        while count != 4:
            strpkt += '00'
            count += 1

    # increment counter
    SentPktsDMAcount[toPort-1] += 1

    # write packet
    f.write("// Packet " + str(SentPktsDMAcount[toPort-1]) + " at port " +
            str(toPort) + "\n")

    f.write("%08x"%pktLen + " // Length without CRC\n")
    f.write(str.rstrip(strpkt))
    f.write('\neeeeffff // End of pkt marker for pkt ' +
            str(SentPktsDMAcount[toPort-1]) + ' (this is not sent).\n')

    simReg.regDMA(toPort, len(pkt))

############################
# Function: pktExpectPHY
# Arguments: atPort - the port the packet will be sent at (1-4)
#            pkt - the packet data, class scapy.Packet
#            mask - mask packet data, class scapy.Packet
#
############################
def pktExpectPHY(atPort, pkt, mask = None):
    numExpectedPktsPHY[atPort-1] += 1
    f = simLib.fExpectPHY(atPort)

    # convert packet to string
    pktArr = [ord(x) for x in str(pkt)]
    if mask:
        maskArr = [ord(x) for x in str(mask)]
    else:
        maskArr = [0] * len(pkt)

    strpkt = ""
    count = 1
    for i in xrange(len(pktArr)):
        octet = "%02x "%pktArr[i]

        # Handle masks
        if (maskArr[i] & 0xf0) != 0:
            octet = "X" + octet[1:]
        if (maskArr[i] & 0x0f) != 0:
            octet = octet[0] + "X "

        strpkt += octet

        if count < 16:
            count += 1
        else:
            strpkt += "\n"
            count = 1

    DA = str.replace(strpkt[0:17], ' ', ':')
    SA = str.replace(strpkt[18:35], ' ', ':')
    ethType = str.replace(strpkt[36:41], ' ', '')
    samplePkt = str.replace(strpkt[42:60], '\n', '')

    # increment counter
    ExpectedPktsPHYcount[atPort-1] += 1

    # write packet
    f.write("\n<!-- Packet " + str(ExpectedPktsPHYcount[atPort-1]) + "-->")
    f.write("\n<!-- DA: " + DA + " SA: " + SA + " ["+ethType+"] " +
            samplePkt + "...-->\n")
    f.write("<PACKET Length=\"" + str(len(pkt)) + "\" Port=\"" +
            str(atPort) + "\" Delay=\"0\">\n")
    f.write(str.rstrip(strpkt))
    f.write("\n</PACKET><!--pkt" + str(ExpectedPktsPHYcount[atPort-1]) +
            "-->\n")


############################
# Function: pktExpectDMA
# Arguments: atPort - the port the packet will be expected at (1-4)
#            pkt - the packet data, class scapy.Packet
#            mask - mask packet data, class scapy.Packet
#
############################
def pktExpectDMA(atPort, pkt, mask = None):
    numExpectedPktsDMA[atPort-1] += 1
    f = simLib.fExpectDMA(atPort)

    # convert packet to string
    pktArr = [ord(x) for x in str(pkt)]
    if mask:
        maskArr = [ord(x) for x in str(mask)]
    else:
        maskArr = [0] * len(pkt)

    strpkt = ""
    count = 1
    for i in xrange(len(pktArr)):
        octet = "%02x "%pktArr[i]

        # Handle masks
        if (maskArr[i] & 0xf0) != 0:
            octet = "X" + octet[1:]
        if (maskArr[i] & 0x0f) != 0:
            octet = octet[0] + "X "

        strpkt += octet

        if count < 16:
            count += 1
        else:
            strpkt += "\n"
            count = 1

    DA = str.replace(strpkt[0:17], ' ', ':')
    SA = str.replace(strpkt[18:35], ' ', ':')
    ethType = str.replace(strpkt[36:41], ' ', '')
    samplePkt = str.replace(strpkt[42:60], '\n', '')

    # increment counter
    ExpectedPktsDMAcount[atPort-1] += 1

    # write packet
    f.write("\n<!-- Packet " + str(ExpectedPktsDMAcount[atPort-1]) + "-->")
    f.write("\n<!-- DA: " + DA + " SA: " + SA + " [" + ethType + "] " +
            samplePkt + "...-->\n")
    f.write("<DMA_PACKET Length=\"" + str(len(pkt)) + "\" Port=\"" +
            str(atPort) + "\" Delay=\"0\">\n")
    f.write(str.rstrip(strpkt))
    f.write("\n</DMA_PACKET><!--pkt" + str(ExpectedPktsDMAcount[atPort-1]) +
            "-->\n")

# Synchronization ########################################################

############################
# Function: resetBarrier()
#
#  Private function to be called by pktBarrier
############################
def resetBarrier():
    global numExpectedPktsPHY; global numExpectedPktsDMA
    numExpectedPktsPHY = [0, 0, 0, 0]
    numExpectedPktsDMA = [0, 0, 0, 0]


############################
# Function: barrier
# Parameters: num - number of packets that must arrive
#   Modifies appropriate files for each port and ingress_dma to denote
#   a barrier request
############################
def barrier():
    for i in range(NUM_PORTS):
        simLib.fPort(i + 1).write("%08d"%CMD_BARRIER + " // BARRIER\n")
        simLib.fPort(i + 1).write("%08x"%(numExpectedPktsPHY[i]) +
                                    " // Number of Packets\n")

    simLib.fPCI().write("%08d"%CMD_PCI_BARRIER + " // BARRIER\n")
    for i in range(NUM_PORTS):
        simLib.fPCI().write("%08x"%(numExpectedPktsDMA[i]) +
                            " // Number of expected pkts received via DMA port " +
                            str(i + 1) + "\n")

    resetBarrier()

MSB_MASK = (0xFFFFFFFF00000000)
LSB_MASK = (0x00000000FFFFFFF)

###########################
# Function: pktDelay
#
###########################
def delay(nanoSeconds):
    for i in range(NUM_PORTS):
        simLib.fPort(i+1).write("%08d"%CMD_DELAY + " // DELAY\n")
        simLib.fPort(i+1).write("%08x"%(MSB_MASK & nanoSeconds) +
                                " // Delay (MSB) " + str(nanoSeconds)+" ns\n")
        simLib.fPort(i+1).write("%08x"%(MSB_MASK & nanoSeconds) +
                                " // Delay (LSB) " + str(nanoSeconds)+" ns\n")

    simLib.fPCI().write("%08d"%CMD_PCI_DELAY+" // DELAY\n")
    simLib.fPCI().write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) " +
                        str(nanoSeconds) + " ns\n")
    simLib.fPCI().write("%08x"%(LSB_MASK & nanoSeconds) + " // Delay (LSB) " +
                        str(nanoSeconds) + " ns\n")
