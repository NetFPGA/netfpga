#!/bin/env python

from NFTest import *
from RegressRouterLib import *
import os
import time
import signal
import subprocess

rkd = os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/sw/rkd"

nftest_init(hw_config=[("../connections/conn", [])])
nftest_start()

pid = subprocess.Popen(rkd).pid
time.sleep(1)

# format: ip-mask-nexthop-outputport
missing_routes = nftest_contains_LPM_table_entries([
                  "10.10.0.0-255.255.255.0-0.0.0.0-0x01",
                  "10.10.1.0-255.255.255.0-0.0.0.0-0x04",
                  "10.10.2.0-255.255.255.0-0.0.0.0-0x10",
                  "10.10.3.0-255.255.255.0-0.0.0.0-0x40"])

total_errors = 0

if len(missing_routes) > 0:
    total_errors += len(missing_routes)

for missing_route in missing_routes:
    print "Missing Route: %s"%missing_route

os.kill(pid, signal.SIGKILL)

nftest_finish(total_errors = total_errors)
