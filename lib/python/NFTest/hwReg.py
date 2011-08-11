#!/usr/bin/env python
# Author: David Erickson
# Date: 10/31/07

import array
import fcntl
import IN
import re
import socket
import struct
import time

connectedSockets = {}

# IOCTL Commands
SIOCREGREAD = 0x89F0
SIOCREGWRITE = 0x89F1

# Register Constants
CPCI_REG_CTRL = 0x008

# Register Values
CPCI_REG_CTRL_RESET = 0x00010100

def readReg(reg, device_name = "nf2c0"):
    """ Read a register value from a NETFPGA device

    Args:
        reg: unsigned integer representing the register identifier
        device_name: name of the NETFPGA device, defaults to nf2c0

    Returns:
        Integer value read from the specified register
    """

    global SIOCREGREAD
    inner_struct = struct.pack("II", reg, 0x0)
    inner_struct_pinned = array.array('c', inner_struct)
    __netfpgaIOCTL(inner_struct_pinned.buffer_info()[0], SIOCREGREAD, device_name)
    retval = struct.unpack("II", inner_struct_pinned)
    return retval[1]

def writeReg(reg, val, device_name = "nf2c0"):
    """ Write a register value from a NETFPGA device

    Args:
        reg: unsigned integer representing the register identifier
        value: unsigned integer to write to the specified register
        device_name: name of the NETFPGA device, defaults to nf2c0
    """

    global SIOCREGWRITE
    inner_struct = struct.pack("II", reg, val)
    inner_struct_pinned = array.array('c', inner_struct)
    __netfpgaIOCTL(inner_struct_pinned.buffer_info()[0], SIOCREGWRITE, device_name)
    retval = struct.unpack("II", inner_struct_pinned)
    return

def resetNETFPGA(device_name = "nf2c0"):
    """Reset the NETFPGA device specified

    Args:
        device_name: the name of the NETFPGA device, defaults to nf2c0
    """
    currVal = readReg(CPCI_REG_CTRL, device_name)
    currVal |= 0x100

    writeReg(CPCI_REG_CTRL, currVal, device_name)
    time.sleep(2)

def parseRegisterDefines(fileNames):
    dict = {}
    for fileName in fileNames:
        f = open(fileName, 'r')
        pattern = re.compile("^#define[\s]+([\S]+)[\s]+([\S]+)$")
        while 1:
            line = f.readline()
            if (not line):
                break

            m = pattern.match(line)
            if (m):
                groups = m.groups()
                try:
                    dict[groups[0]] = int(groups[1],16)
                except:
                    # means our defined value probably wasnt an integer
                    nullop = 1

        f.close()
    return dict

def __netfpgaIOCTL(inner_struct_ptr, op, device_name = "nf2c0"):
    global connectedSockets

    if (not(device_name in connectedSockets)):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.getprotobyname('udp'))
        sock.setsockopt(socket.SOL_SOCKET, IN.SO_BINDTODEVICE, struct.pack("6s", device_name))
        connectedSockets[device_name] = sock

    sock = connectedSockets[device_name]
    outer_struct = struct.pack("16sP12x", device_name, inner_struct_ptr)
    outer_struct_pinned = array.array('c', outer_struct)
    fcntl.ioctl(sock, op, outer_struct_pinned, 1)
