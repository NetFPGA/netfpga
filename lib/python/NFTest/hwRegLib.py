#!/usr/bin/env python

import hwReg
import time

from hwPktLib import ifaceArray # for ifaceArray

import sys
import os

# Import __main__ to access the reverse register map...
import __main__

sys.path.append(os.path.abspath(os.environ['NF_DESIGN_DIR']+'/lib/Python'))
project = os.path.basename(os.path.abspath(os.environ['NF_DESIGN_DIR']))
reg_defines = __import__('reg_defines_'+project)

badReads = {}

############################
# Function: regwrite
# Arguments: nf2 interface to write to, register, value
# Description: writes value to register
############################
def regwrite(ifaceName, reg, val):
    if ifaceName.startswith('nf2c'):
        hwReg.writeReg(reg, val, ifaceName)

############################
# Function: regread
# Arguments: nf2 interface to read from, register
# Description: reads value from register
############################
def regread(ifaceName, reg):
    if ifaceName.startswith('nf2c'):
        return hwReg.readReg(reg,ifaceName)

############################
# Function: regread_expect
# Arguments: nf2 interface to read from, register, expected value, (optional) mask
# Description: reads value from register and compares with expected value
############################
def regread_expect(ifaceName, reg, exp, mask = 0xffffffff):
    val = hwReg.readReg(reg,ifaceName)
    if (val & mask) != (exp & mask):
        name = __main__.nf_regmap.get(reg, "unknown")
        print 'ERROR: Register read expected 0x%08x but found 0x%08x at address 0x%08x (%s)'%(exp, val, reg, name)
        if ifaceName not in badReads:
            badReads[ifaceName] = []
        badReads[ifaceName].append({'Expected':exp, 'Value':val, 'Register':reg, 'RegName':name})
    return val

############################
# Function: fpga_reset
# Arguments: none
# Description: resets the fpga
############################
def fpga_reset():
    hwReg.resetNETFPGA('nf2c0')

############################
# Function: reset_phy
# Arguments: none
# Description: resets the phy
############################
def reset_phy():
    for iface in ifaceArray:
        if iface.startswith('nf2c'):
            phy_reset(iface)
    time.sleep(6)

############################
# Function: phy_loopback
# Arguments: nf2 interface to put in loopback
# Description: puts the specified nf2 interface in loopback
############################
def phy_loopback(ifaceName):
    if ifaceName.startswith('nf2c') and ifaceName[4:5].isdigit():
        portNum = int(ifaceName[4:5])
    else:
        print 'Interface has to be an nf2cX interface\n'
        return
    addr = (reg_defines.MDIO_PHY_0_CONTROL_REG(),
            reg_defines.MDIO_PHY_1_CONTROL_REG(),
            reg_defines.MDIO_PHY_2_CONTROL_REG(),
            reg_defines.MDIO_PHY_3_CONTROL_REG())
    regwrite(ifaceName, addr[portNum], 0x5140)

############################
# Function: phy_isolate
# Arguments: nf2 interface to isolate
# Description: puts the specified nf2 interface in isolation
############################
def phy_isolate(ifaceName):
    if ifaceName.startswith('nf2c') and ifaceName[4:5].isdigit():
        portNum = int(ifaceName[4:5])
    else:
        print 'Interface has to be an nf2cX interface\n'
        return
    addr = (reg_defines.MDIO_PHY_0_CONTROL_REG(),
            reg_defines.MDIO_PHY_1_CONTROL_REG(),
            reg_defines.MDIO_PHY_2_CONTROL_REG(),
            reg_defines.MDIO_PHY_3_CONTROL_REG())
    regwrite(ifaceName, addr[portNum], 0x1540)

############################
# Function: phy_reset
# Arguments: nf2 interface to reset
# Description: resets the phy for the specified interface
############################
def phy_reset(ifaceName):
    if ifaceName.startswith('nf2c') and ifaceName[4:5].isdigit():
        portNum = int(ifaceName[4:5])
    else:
        print 'Interface has to be an nf2cX interface\n'
        return
    addr = (reg_defines.MDIO_PHY_0_CONTROL_REG(),
            reg_defines.MDIO_PHY_1_CONTROL_REG(),
            reg_defines.MDIO_PHY_2_CONTROL_REG(),
            reg_defines.MDIO_PHY_3_CONTROL_REG())
    regwrite(ifaceName, addr[portNum], 0x8000)

############################
# Function: get_bad_reads
# Arguments: none
# Description: returns the dictionary of bad reads
############################
def get_bad_reads():
    return badReads
