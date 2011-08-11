#!/bin/env python

from NFTest import *
from RegressRouterLib import *
import os
import time
import signal

rkd = os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/rkd"

nftest_init(hw_config=[("../connections/conn", [])])
nftest_start()

pid = os.spawnvp(os.P_NOWAIT, rkd, [rkd])
time.sleep(1)

missing_ips = nftest_contains_dst_ip_filter_entries([
                  "10.10.0.1",
                  "10.10.1.1",
                  "10.10.2.1",
                  "10.10.3.1"])

total_errors = 0

if len(missing_ips) > 0:
    total_errors += len(missing_ips)

for missing_ip in missing_ips:
    print "Missing Destination IP Filter: %s"%missing_ip

os.kill(pid, signal.SIGKILL)

nftest_finish(total_errors = total_errors)
