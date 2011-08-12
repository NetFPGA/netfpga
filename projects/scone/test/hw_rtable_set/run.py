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
pid = subprocess.Popen([scone, '-r', 'rtable.regress1']).pid
time.sleep(3)

# Expected Static Routes
# 192.168.1.1 192.168.1.1 255.255.255.0 eth1
route1 = {"ip":"0xC0A80101L", "gw":"0xC0A80101L", "mask":"0xFFFFFF00L", "port":"0x4L"};
# 0.0.0.0 192.168.0.1 0.0.0.0 eth0
route2 = {"ip":"0x0L", "gw":"0xC0A80001L", "mask":"0x0L", "port":"0x1L"};
expectedRoutes = [route1, route2];

# Check IP Filter 0
for i in range(32):
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), i)
	ip = hwRegLib.regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG())
	mask = hwRegLib.regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG())
	gw = hwRegLib.regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG())
	port = hwRegLib.regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG())

	found = -1;
	for route in expectedRoutes:
		if ((long(route["ip"], 16) == ip) and (long(route["gw"], 16) == gw) and (long(route["mask"], 16) == mask) and (long(route["port"], 16) == port)):
			found = expectedRoutes.index(route);
			break;
	if (found != -1):
		expectedRoutes.pop(found);

# Kill SCONE
os.kill(pid, signal.SIGKILL);

if (len(expectedRoutes) > 0):
	print "Failed to find the following routes: ";
	for route in expectedRoutes:
		print route["ip"] + " " + route["gw"] + " " + route["mask"] + " " + route["port"];

hwPktLib.restart()

nftest_finish(total_errors=len(expectedRoutes))


