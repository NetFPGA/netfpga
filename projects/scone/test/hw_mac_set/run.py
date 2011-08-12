#!/usr/bin/python
# Author: David Erickson
# Date: 10/31/07

from NFTest import *
import os
import signal
import sys
import time
import subprocess

nftest_init(hw_config=[('../connections/conn', [])])
nftest_start()

cwd = os.getcwd()
os.chdir(os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/sw")
scone = os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/sw/scone"

# Start SCONE
pid = subprocess.Popen([scone, '-r', 'rtable.netfpga']).pid
time.sleep(1)

# Check that it correctly wrote the MAC Addresses to HW
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_0_HI_REG(), 0x0)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_0_LO_REG(), 0x1)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_1_HI_REG(), 0x0)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_1_LO_REG(), 0x2)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_2_HI_REG(), 0x0)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_2_LO_REG(), 0x3)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_3_HI_REG(), 0x0)
nftest_regread_expect(reg_defines.ROUTER_OP_LUT_MAC_3_LO_REG(), 0x4)

# Kill SCONE
os.kill(pid, signal.SIGKILL);

os.chdir(cwd)

hwPktLib.restart()

nftest_finish()
