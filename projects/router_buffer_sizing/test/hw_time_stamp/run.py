#!/bin/env python

import os
import sys
import time
import signal
import subprocess

rcv_evts = [os.path.abspath(os.environ['NF_DESIGN_DIR']) + "/sw/rcv_evts", '-v']
time1 = open('time1.txt', 'w')

pid = subprocess.Popen(rcv_evts, stdout=time1).pid

time.sleep(1)

send_pkts = "./send_pkts.py"
for arg in sys.argv:
    send_pkts += " %s"%arg
subprocess.call(send_pkts.split())

time.sleep(1)

os.kill(pid, signal.SIGKILL)
time1.close()

time.sleep(1)

time1 = open('time1.txt', 'r')
time2 = open('time2.txt', 'w')

for line in time1:
    if line.startswith("Store  Event     : Q: 2"):
        time2.write(line)

time1.close()
time2.close()

time3 = open('time3.txt', 'w')

subprocess.call(['awk', '{print $10}',  'time2.txt'], stdout=time3)

time3.close()

time3 = open('time3.txt', 'r')

h = 0
last_line = '0'
time_diff = 0
line_number = 0

for line in time3:
    h = int(line.strip(), 16) - int(last_line, 16)
    time_diff = 8E-9 * h
    #print line.strip(), last_line, time_diff
    if line_number > 0 and time_diff > 0.05:
       print "FAIL: time difference between packets more than 50ms"
       sys.exit(1)
    last_line = line.strip()
    line_number += 1

time3.close()

os.remove('time1.txt')
os.remove('time2.txt')
os.remove('time3.txt')

print 'SUCCESS!'
sys.exit(0)
