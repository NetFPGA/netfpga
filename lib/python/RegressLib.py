#!/usr/bin/python

import RegAccess
import time

import TestLib # for ifaceArray

import sys
import os
sys.path.append(os.environ['NF_DESIGN_DIR']+'/lib/Python')
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
reg_defines = __import__('reg_defines_'+project)

badReads = {}

def nftest_regwrite(ifaceName, reg, val):
    RegAccess.writeReg(reg, val, ifaceName)

def nftest_regread(ifaceName, reg):
    return RegAccess.readReg(reg,ifaceName)

def nftest_regread_expect(ifaceName, reg, exp, mask = 0xffffffff):
    val = RegAccess.readReg(reg,ifaceName)
    if (val & mask) != (exp & mask):
        print 'ERROR: Register read expected 0x', "%08X"%exp
        print 'but found 0x', "%08X"%val, ' at address 0x', "%08X"%reg
        print ''
        try:
            badReads[ifaceName].append({'Expected':exp, 'Value':val, 'Register':reg})
        except(KeyError):
            badReads[ifaceName] = []
            badReads[ifaceName].append({'Expected':exp, 'Value':val, 'Register':reg})
    return val

def nftest_fpga_reset():
    TestLib.ifaceArray
    for iface in TestLib.ifaceArray: # fix
        RegAccess.resetNETFPGA(iface)

def nftest_reset_phy():
    TestLib.ifaceArray
    for iface in TestLib.ifaceArray:
        nftest_phy_reset(iface)
    time.sleep(6)

def nftest_phy_loopback(ifaceName):
    if ifaceName.startswith('nf2c') and ifaceName[4:5].isdigit():
        portNum = int(ifaceName[4:5])
    else:
        print 'Interface has to be an nf2cX interface\n'
        return
    addr = (reg_defines.MDIO_PHY_0_CONTROL_REG(), reg_defines.MDIO_PHY_1_CONTROL_REG(), reg_defines.MDIO_PHY_2_CONTROL_REG(), reg_defines.MDIO_PHY_3_CONTROL_REG())
    nftest_regwrite(ifaceName, addr[portNum], 0x5140)

def nftest_phy_reset(ifaceName):
    if ifaceName.startswith('nf2c') and ifaceName[4:5].isdigit():
        portNum = int(ifaceName[4:5])
    else:
        print 'Interface has to be an nf2cX interface\n'
        return
    addr = (reg_defines.MDIO_PHY_0_CONTROL_REG(), reg_defines.MDIO_PHY_1_CONTROL_REG(), reg_defines.MDIO_PHY_2_CONTROL_REG(), reg_defines.MDIO_PHY_3_CONTROL_REG())
    nftest_regwrite(ifaceName, addr[portNum], 0x8000)
