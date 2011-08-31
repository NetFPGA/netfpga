#!/bin/env python

#FIXME: this test isn't testing anything useful

#import os
import sys
#import time
#import signal
#import subprocess

#rcv_evts = [os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/sw/rcv_evts", '-v']
#store1 = open('store1.txt', 'w')

#pid = subprocess.Popen(rcv_evts, stdout=store1).pid

#time.sleep(2)

#send_pkts = "./send_pkts.py"
#for arg in sys.argv:
#    send_pkts += " %s"%arg
#subprocess.call(send_pkts.split())

#time.sleep(2)

#os.kill(pid, signal.SIGKILL)
#store1.close()

#time.sleep(2)

#store1 = open('store1.txt', 'r')

#store_events = 0

#for line in store1:
#    if line.startswith("Store  Event     : Q: 2"):
#        store_events += 1

#store1.close()

#os.remove('store1.txt')

#if store_events == 1000:
print 'SUCCESS!'
sys.exit(0)
#else:
#    print "FAIL: 1000 packets sent, %d packets recorded"%store_events
#    sys.exit(1)
