#!/usr/bin/python
# Author: James Hsi
# Date: 7/30/10

#might need sim/hardware specific fns

import Test

#import array;
#import fcntl;
#import IN;
#import re;
#import socket;
#import struct;
#import time;

connectedSockets = {};

# IOCTL Commands
SIOCREGREAD = 0x89F0;
SIOCREGWRITE = 0x89F1;

# Register Constants
CPCI_REG_CTRL = 0x008;

# Register Values
CPCI_REG_CTRL_RESET = 0x00010100;

numExpectedRegs = 0

CMD_READ = 1
CMD_WRITE = 2
CMD_DMA = 3
CMD_BARRIER = 4
CMD_DELAY = 5

#NUM_FORMAT = eight digits... pad with zeros
NUM_PORTS = 4;

#numExpected


############################
# Function: regDMA
# Arguments:
############################
def regDMA(reg, value):
        f = Test.fPCI()
	f.write("// DMA:  Time: ns  QUEUE: "+str(1)+"  LENGTH: 0x0\n")
	f.write("00000003 // DMA\n")
	f.write("00000001"+" // Queue ("+str(1)+")\n") #should be the port number
	f.write("00000000"+" // Length ("+str()+")\n")
	f.write("00000000"+" // Mask (0)\n")

############################
# Function: regRead // NEEDS TO BE IMPLEMENTED
# Arguments:
# reg is an address, value is data
############################
def regRead(reg, value):
	f = Test.fPCI()
	f.write("// DMA \n")
	#f.write("// DMA:  Time: ns  QUEUE: "+str(1)+"  LENGTH: 0x0\n")
	#f.write("00000003 // DMA\n")
	#f.write("00000001"+" // Queue ("+str(1)+")\n") #should be the port number
	#f.write("00000000"+" // Length ("+str(1)+")\n")
	#f.write("00000000"+" // Mask (0)\n")

############################
# Function: regWrite
# Arguments:
############################
def regWrite(reg, value):
	f = Test.fPCI()
	f.write("// WRITE:  Time: ns  QUEUE: x  LENGTH: 0x3c\n")
	f.write("00000002"+" // WRITE\n")
	f.write("%08x"%reg + " // Address \n")
	f.write(str(value)+" // Data (0)\n")
	f.write("00000000"+" // Mask (0)\n")
	++numExpectedRegs


############################
# compare two registers, where reg2 can be used as an expected value
############################
def regCmp(reg1, reg2):
	return 0

# Synchronization ##################################

def resetBarrier():
	numExpectedRegs = 0

############################
# Function: barrier
# Parameters: num - number of registers
#   Writes the number of expected packets. Simulation will wait for all packets to be recieved.
############################
def barrier():
    Test.fPCI().write("00000004 // BARRIER \n")
    Test.fPCI().write(str(numExpectedRegs)+" // ("+str(numExpectedRegs)+")\n")
    resetBarrier()

MSB_MASK = (0xFFFFFFFF00000000)
LSB_MASK = (0x00000000FFFFFFF)

############################
# Function: regDelay
# Parameters: nanoSeconds - time to delay the entire simulation (in nanoseconds)
# Writes
############################
def regDelay(nanoSeconds):
    Test.fPCI().write("00000005 // DELAY \n");
    Test.fPCI().write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) "+str(nanoSeconds)+" ns\n")
    Test.fPCI().write("%08x"%(LSB_MASK & nanoSeconds) + " // Delay (LSB) "+str(nanoSeconds)+" ns\n")

############################
# from old...
############################
def resetNETFPGA(device_name):
	print "resetNETFPGA\n"

############################
# from old...
############################
def parseRegisterDefines(fileNames):
	print "parseRegisterDefines\n"
