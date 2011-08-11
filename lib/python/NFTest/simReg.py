#!/usr/bin/env python
# Author: James Hsi, Eric Lo
# Date: 1/31/2011

import simLib

# IOCTL Commands
SIOCREGREAD = 0x89F0
SIOCREGWRITE = 0x89F1

# Register Constants
CPCI_REG_CTRL = 0x008

# Register Values
CPCI_REG_CTRL_RESET = 0x00000100

CMD_READ = 1
CMD_WRITE = 2
CMD_DMA = 3
CMD_BARRIER = 4
CMD_DELAY = 5

NUM_PORTS = 4

############################
# Function: regDMA
# Arguments:
# queue is DMA queue #, length is packet length
############################
def regDMA(queue, length):
    f = simLib.fPCI()
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
    f = simLib.fPCI()
    f.write("// READ:  Address: "+hex(reg)+" Expected Data: "+hex(value)+"\n")
    f.write("00000001 // READ\n")
    f.write("%08x"%reg+" // Address ("+hex(reg)+")\n")
    f.write("%08x"%value+" // Data ("+hex(value)+")\n")
    f.write("FFFFFFFF"+" // Mask (0xFFFFFFFF)\n")

############################
# Function: regWrite
# Arguments:
# reg is an address, value is data
############################
def regWrite(reg, value):
    f = simLib.fPCI()
    f.write("// WRITE:  Address: "+hex(reg)+" Data: "+hex(value)+"\n")
    f.write("00000002"+" // WRITE\n")
    f.write("%08x"%reg + " // Address \n")
    f.write("%08x"%value+" // Data ("+hex(value)+")\n")
    f.write("00000000"+" // Mask (0x0)\n")

# Synchronization ##################################

MSB_MASK = (0xFFFFFFFF00000000)
LSB_MASK = (0x00000000FFFFFFF)

############################
# Function: regDelay
# Parameters: nanoSeconds - time to delay the entire simulation (in ns)
# Writes
############################
def regDelay(nanoSeconds):
    simLib.fPCI().write("00000005 // DELAY \n")
    simLib.fPCI().write("%08x"%(MSB_MASK & nanoSeconds) + " // Delay (MSB) "
                        + str(nanoSeconds) + " ns\n")
    simLib.fPCI().write("%08x"%(LSB_MASK & nanoSeconds) + " // Delay (LSB) "
                        + str(nanoSeconds) + " ns\n")
