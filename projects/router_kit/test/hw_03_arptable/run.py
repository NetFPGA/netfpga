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

missing_arps = nftest_contains_ARP_table_entries([
                  "10.10.0.200-01:00:00:00:00:01",
                  "10.10.1.200-02:00:00:00:00:02",
                  "10.10.2.200-03:00:00:00:00:03",
                  "10.10.3.200-04:00:00:00:00:04"])

total_errors = 0

if len(missing_arps) > 0:
    total_errors += len(missing_arps)

for missing_arp in missing_arps:
    print "Missing ARP entry: %s"%missing_arp

os.kill(pid, signal.SIGKILL)

nftest_finish(total_errors = total_errors)
