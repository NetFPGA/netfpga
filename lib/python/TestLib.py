#!/usr/bin/python

import testPktHW
import sys

ifaceArray = []
captureThreads = {}
pktArray = {}
toIgnore = {}

def nftest_init(argv, active_ports):
    # process argv
    for iface in active_ports:
        ifaceArray.append(iface)

def nftest_start(active_ports):
    for iface in ifaceArray:
        captureThreads[iface] = testPktHW.pktExpect(iface)
        pktArray[iface] = []
        toIgnore[iface] = []
        captureThreads[iface].start()
    alive = False
    while not alive:
        alive = True
        for iface in ifaceArray:
            alive &= captureThreads[iface].isAlive()

def nftest_restart():
    for pkts in pktArray:
        pkts = []

def nftest_send(ifaceName, pkt, expect = True):
    testPktHW.pktSend(ifaceName, pkt)
    if expect:
        nftest_expect(ifaceName, pkt)

def nftest_expect(ifaceName, pkt):
    captureThreads[ifaceName].expectPkt(pkt)

def nftest_barrier(timeout = 10, exit_on_failure = True):
    good = True
    for iface in ifaceArray:
        good &= captureThreads[iface].barrier(timeout)
    if exit_on_failure and not good:
        nftest_finish()
        sys.exit()

def nftest_finish():
    for iface in ifaceArray:
        # close capture threads, record packets
        pktArray[iface] = captureThreads[iface].finish()
        # filter packets
        try:
            for layer in toIgnore['layer']:
                pktArray[iface] = pktArray[iface].filter(lambda x: x.haslayer(layer))
        except(KeyError):
            pass
        try:
            for method in toIgnore['method']:
                pktArray[iface] = pktArray[iface].filter(method)
        except(KeyError):
            pass

def nftest_ignore(filter, method = False):
    # filter by layer
    if not method:
        toIgnore['layer'].append(filter)
    # filter by method(pkt), returning truth value
    else:
        toIgnore['method'].append(filter)
