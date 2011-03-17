#!/usr/bin/python

import testPktHW
import sys

import time
import random

try:
   import scapy.all as scapy
except:
   try:
      import scapy as scapy
   except:
      sys.exit("Error: need to install scapy for packet handling")

ifaceArray = []
captureThreads = {}
openSockets = {}
packets = {}
toIgnore = {}

############################
# Function: nftest_init
# Arguments: arguments passed to script
#            list of interfaces to sniff
# Description: handles options, populates ifaceArray
############################
def nftest_init(argv, active_ports):
    # process argv
    for iface in active_ports:
        ifaceArray.append(iface)

############################
# Function: nftest_start
# Arguments: none
# Description: starts capture threads
############################
def nftest_start():
    for iface in ifaceArray:
        captureThreads[iface] = testPktHW.pktExpect(iface)
        openSockets[iface] = testPktHW.pktSend(iface)
        packets[iface] = {}
        toIgnore['layer'] = []
        toIgnore['method'] = []
        captureThreads[iface].start()
        openSockets[iface].start()
    alive = False
    # block until all capture threads are ready
    while not alive:
        alive = True
        for iface in ifaceArray:
            alive &= captureThreads[iface].isAlive()

############################
# Function: nftest_restart
# Arguments: none
# Description: resets all packet lists
############################
def nftest_restart():
    for pkts in packets:
        pkts = {}
    for iface in ifaceArray:
        captureThreads[iface].restart()

############################
# Function: nftest_send
# Arguments: interface name
#            packet to send
#            (optional) expect packet
# Description: sends packet on an interface, expect the packet if expect is True
############################
def nftest_send(ifaceName, pkt, expect = True):
    try:
        openSockets[ifaceName].sendPkt(pkt)
    except(KeyError):
        print 'Error: invalid interface name'
    if expect:
        nftest_expect(ifaceName, pkt)

############################
# Function: nftest_expect
# Arguments: interface name
#            packet to expect
# Description: expects a packet on an interface
############################
def nftest_expect(ifaceName, pkt):
    captureThreads[ifaceName].expectPkt(pkt)

############################
# Function: nftest_barrier
# Arguments: (optional) timeout in seconds
# Description: blocks execution until all expected packets arrive, or times out
#              returns False if timed out
############################
def nftest_barrier(timeout = 10):
    start = time.clock()
    good = False
    while timeout + start - time.clock() > 0:
        good = True
        for iface in ifaceArray:
            captureThreads[iface].compareEvent.set()
        for iface in ifaceArray:
            good &= captureThreads[iface].barrierEvent.wait(timeout-start)
        if good:
            break
    if not good:
        print 'Error: barrier timed out after', str(timeout), 'seconds'
        for iface in ifaceArray:
            numUnexp = captureThreads[iface].pkts.__len__()
            numExp = captureThreads[iface].exp_pkts.__len__()
            if numUnexp > 0:
                print 'Error: device', iface, 'saw', str(numUnexp), 'unexpected packets'
            if numExp > 0:
                print 'Error: device', iface, 'missed', str(numExp), 'expected packets'
        print ''
    return good

############################
# Function: nftest_compare
# Arguments: list of expected packets
#            list of unexpected packets
# Description: compares expected packets to unexpected packets, enumerating differences
############################
def nftest_compare(exp, unexp):
    numExp = exp.__len__()
    numUnexp = unexp.__len__()
    # check if there is anything to compare
    if numExp is 0 and numUnexp is 0:
        return 0
    elif numExp is 0:
        print 'Error:', str(numUnexp), 'unexpected packets seen'
        return numUnexp
    elif numUnexp is 0:
        print 'Error:', str(numExp), 'expected packets not seen'
        return numExp

    # print differences between exp and unexp pkts
    print str(numExp), 'expected packets not seen'
    print str(numUnexp), 'unexpected packets'
    for i in range(numExp):
        print 'Expected packet', str(i)
        for j in range(numUnexp):
            if len(exp[i]) is not len(unexp[j]):
                print '   Unexpected packet ' + str(j) + ': Packet lengths do not match, expecting', str(len(exp[i])), 'but saw', str(len(unexp[j]))
            else:
                str_exp_pkt = ''
                str_unexp_pkt = ''
                # generate a hex string
                for x in str(exp[i]):
                    str_exp_pkt += "%02X"%ord(x)
                for x in str(unexp[j]):
                    str_unexp_pkt += "%02X"%ord(x)
                for k in range(len(str_exp_pkt)):
                    if str_unexp_pkt[k] is not str_exp_pkt[k]:
                        print '   Unexpected packet ' + str(j) + ': byte', str(k/2), '(starting from 0) not equivalent (EXP:', str_exp_pkt[i:i+2] + ', ACTUAL:', str_unexp_pkt[k:k+2] + ')'
                        break

    return numExp + numUnexp

############################
# Function: nftest_finish
# Arguments: none
# Description: closes capture threads, filters by toIgnore, calls pktCmp, writes pcap files, return # errors
############################
def nftest_finish():
    pkts = ()
    ignored = []
    error_count = 0

    for iface in ifaceArray:
        openSockets[iface].close()
        # close capture threads, record packets
        pkts = captureThreads[iface].finish()

        # filter packets
        packets[iface]['Matched'] = pkts[0]
        packets[iface]['Unexpected'] = pkts[1]
        packets[iface]['Expected'] = pkts[2]
        nftest_filter(packets[iface]['Matched'], ignored)
        nftest_filter(packets[iface]['Unexpected'], ignored)
        nftest_filter(packets[iface]['Expected'], ignored)

        # show differences between packets
        error_count += nftest_compare(packets[iface]['Expected'], packets[iface]['Unexpected'])

        # write pcap files - TO IMPLEMENT: write to tmp dir
        if packets[iface]['Matched'].__len__() > 0:
            scapy.wrpcap(iface+"_matched.pcap", packets[iface]['Matched'])
        if packets[iface]['Expected'].__len__() > 0:
            scapy.wrpcap(iface+"_expected.pcap", packets[iface]['Expected'])
        if packets[iface]['Unexpected'].__len__() > 0:
            scapy.wrpcap(iface+"_extra.pcap", packets[iface]['Unexpected'])
        if ignored.__len__() > 0:
            scapy.wrpcap(iface+"_ignored.pcap", ignored)
    return error_count

############################
# Function: nftest_filter
# Arguments: list of packets to filter, list to add ignored packets to
# Description: removes packets to be ignored
############################
def nftest_filter(pktlist, ignorelist):
    if pktlist.__len__() <= 0:
        return
    ignored = []
    for layer in toIgnore['layer']:
        for pkt in pktlist:
            if pkt.haslayer(layer):
                duplicate = False
                for ignorepkt in ignored:
                    if pkt is ignorepkt:
                        duplicate = True
                if not duplicate:
                    ignored.append(pkt)
    for method in toIgnore['method']:
        for pkt in pktlist:
            if method(pkt):
                duplicate = False
                for ignorepkt in ignored:
                    if pkt is ignorepkt:
                        duplicate = True
                if not duplicate:
                    ignored.append(pkt)
    for pkt in ignored:
        pktlist.remove(pkt)
    ignorelist.extend(ignored)

############################
# Function: nftest_ignore
# Arguments: filter
#            (optional) method
# Description: adds string name of scapy layer to ignore
#              or adds method to ignore if method is True
############################
def nftest_ignore(filter, method = False):
    # filter by layer
    if not method:
        toIgnore['layer'].append(filter)
    # filter by method(pkt), returning truth value
    else:
        toIgnore['method'].append(filter)

############################
# Function: len
# Arguments: packet
# Description: overrides len(pkt) to account for packets of length < 60
############################
def len(pkt):
    length = pkt.__str__().__len__()
    if length < 60:
        return 60
    return length

############################
# Function: generate_load
# Arguments: min_len
#            (optional) max_len
# Description: generates a random payload of min_len
#              if max_len is specified, payload will be random length between min_len and max_len
############################
def generate_load(min_len, max_len = 0):
    if max_len == 0:
        max_len = min_len
    load = ''
    for i in range(random.randint(min_len,max_len)):
        load += chr(random.randint(0,255))
    return load
