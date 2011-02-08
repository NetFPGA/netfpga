#!/usr/bin/python
# make_pkts.py

import testReg
import testPkt
import Test
import Packet
import reg_defines_reference_nic

Test.init()
testReg.regWrite(0x08, 0) #CPCI_Control_reg
testReg.regWrite(0x40, 0) #CPCI_Interrupt_Mask
testPkt.barrier()

# read and write some data to PHY using MDIO regs
testReg.regRead(reg_defines_reference_nic.DEV_ID_MD5_0_REG(), 0x5e461ffe)
testReg.regRead(reg_defines_reference_nic.DEV_ID_MD5_1_REG(), 0x439725c9)
testReg.regRead(reg_defines_reference_nic.DEV_ID_MD5_2_REG(), 0x279a22a1)
testReg.regRead(reg_defines_reference_nic.DEV_ID_MD5_3_REG(), 0x855f6c53)
testReg.regRead(reg_defines_reference_nic. DEV_ID_CPCI_ID_REG(), 0x01000004)

# *********** Finishing Up - need this in all scripts ! ****************************
testPkt.barrier()

print  "--- make_pkts.py: Read and Write configuration registers.\n"
Test.close()
