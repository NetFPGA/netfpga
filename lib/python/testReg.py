#!/usr/bin/python
# Author: James Hsi, Eric Lo
# Date: 1/31/2011

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
# queue is DMA queue #, length is packet length
############################
def regDMA(queue, length):
	f = Test.fPCI()
	f.write("// DMA: QUEUE: "+hex(queue)+ " LENGTH: "+hex(length)+"\n")
	f.write("00000003 // DMA\n")
	f.write("%08x"%queue +" // Queue ("+hex(queue)+")\n")
	f.write("%08x"%length+" // Length ("+hex(length)+")\n")
	f.write("00000000"+" // Mask (0x0)\n")

############################
# Function: regRead
# Arguments:
# reg is an address, value is data
############################
def regRead(reg, value):
	f = Test.fPCI()
	f.write("// Read:  Address: "+hex(reg)+" Expected Data: "+hex(value)+"\n")
	f.write("00000001 // DMA\n")
	f.write("%08x"%reg+" // Address ("+hex(reg)+")\n")
	f.write("%08x"%value+" // Data ("+hex(value)+")\n")
	f.write("FFFFFFFF"+" // Mask (0xFFFFFFFF)\n")

############################
# Function: regWrite
# Arguments:
# reg is an address, value is data
############################
def regWrite(reg, value):
	f = Test.fPCI()
	f.write("// WRITE:  Address: "+hex(reg)+" Data: "+hex(value)+"\n")
	f.write("00000002"+" // WRITE\n")
	f.write("%08x"%reg + " // Address \n")
	f.write("%08x"%value+" // Data ("+hex(value)+")\n")
	f.write("00000000"+" // Mask (0x0)\n")
	++numExpectedRegs


############################
# compare two registers, where reg2 can be used as an expected value
# TO BE IMPLEMENTED
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
