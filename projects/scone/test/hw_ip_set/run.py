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

# List of expected addresses
# 192.168.0.2, 192.168.1.2, 192.168.2.2, 192.168.3.2, 224.0.0.5
expectedAddrs = [0xC0A80002, 0xC0A80102, 0xC0A80202, 0xC0A80302, 0xE0000005]

# Check IP Filter 0
for i in range(32):
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), i)
	val = hwRegLib.regread('nf2c0', reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG())
	print "0x%08x"%val
	if (val in expectedAddrs):
		expectedAddrs.remove(val)

# Kill SCONE
os.kill(pid, signal.SIGKILL)

if (len(expectedAddrs) > 0):
	print "Failed to set the following ip filters: ",
	for addr in expectedAddrs:
		print hex(addr),
	print ''

os.chdir(cwd)

hwPktLib.restart()

nftest_finish(total_errors = len(expectedAddrs))
