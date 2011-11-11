#!/usr/bin/env python

import hwPkt
import sys
import os

import time

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
barrier_timeouts = 0

pcap_dir = "hw_pcaps/"

############################
# Function: init
# Arguments: list of interfaces to sniff
# Description: populates ifaceArray
############################
def init(active_ports):
    for iface in active_ports:
        ifaceArray.append(iface)

############################
# Function: start
# Arguments: none
# Description: starts capture threads
############################
def start():
    for iface in ifaceArray:
        captureThreads[iface] = hwPkt.pktExpect(iface)
        openSockets[iface] = hwPkt.pktSend(iface)
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
            if not captureThreads[iface].isAlive() and captureThreads[iface].hasStarted():
                raise RuntimeError("Thread on %s started and terminated..."%iface)

############################
# Function: restart
# Arguments: none
# Description: resets all packet lists
############################
def restart():
    for pkts in packets:
        pkts = {}
    for iface in ifaceArray:
        captureThreads[iface].restart()

############################
# Function: send
# Arguments: interface name
#            packet to send
#            (optional) expect packet, default is true
# Description: sends packet on an interface, expect the packet if specified
############################
def send(ifaceName, pkt, exp = True):
    try:
        openSockets[ifaceName].sendPkt(pkt)
    except(KeyError):
        print 'Error: invalid interface name'
    if exp:
        expect(ifaceName, pkt)

############################
# Function: expect
# Arguments: interface name
#            packet to expect
#            optional mask to apply to packet
# Description: expects a packet on an interface
############################
def expect(ifaceName, pkt, mask = None):
    captureThreads[ifaceName].expectPkt(pkt, mask)

############################
# Function: barrier
# Arguments: (optional) timeout in seconds, default is 10 sec
# Description: blocks execution until expected packets arrive, or times out
#              returns False if timed out
############################
def barrier(timeout = 10):
    start = time.clock()
    good = False
    while timeout + start - time.clock() > 0:
        good = True
        for iface in ifaceArray:
            captureThreads[iface].compareEvent.set()
        for iface in ifaceArray:
            captureThreads[iface].barrierEvent.wait(timeout-start)
            good &= captureThreads[iface].barrierEvent.is_set()
        if good:
            break
    if not good:
        print 'Error: barrier timed out after', str(timeout), 'seconds'
        for iface in ifaceArray:
            numUnexp = captureThreads[iface].pkts.__len__()
            numExp = captureThreads[iface].exp_pkts.__len__()
            if numUnexp > 0:
                print 'Error: device', iface, 'saw',
                print  str(numUnexp), 'unexpected packets'
            if numExp > 0:
                print 'Error: device', iface, 'missed',
                print str(numExp), 'expected packets'
        print ''
        global barrier_timeouts
        barrier_timeouts += 1
    return good

############################
# Function: compare
# Arguments: list of expected packets
#            list of unexpected packets
# Description: compares expected packets to unexpected packets
#              prints comparison
############################
def compare(exp, unexp):
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
            if len(exp[i]) != len(unexp[j]):
                print '   Unexpected packet ' + str(j),
                print ': Packet lengths do not match, expecting',
                print str(len(exp[i])), 'but saw', str(len(unexp[j]))
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
                        print '   Unexpected packet ' + str(j) + ': byte',
                        print str(k/2),
                        print '(starting from 0) not equivalent (EXP:',
                        print str_exp_pkt[i:i+2] + ', ACTUAL:',
                        print str_unexp_pkt[k:k+2] + ')'
                        break

    return numExp + numUnexp

############################
# Function: finish
# Arguments: none
# Description: closes capture threads, filters by toIgnore,
#              calls pktCmp, writes pcap files, return # errors
############################
def finish():
    pkts = ()
    ignored = []
    from hwRegLib import get_bad_reads
    bad_reads = get_bad_reads()
    error_count = 0

    if not os.path.isdir(pcap_dir):
        os.mkdir(pcap_dir)
    for iface in ifaceArray:
        openSockets[iface].close()
        # close capture threads, record packets
        pkts = captureThreads[iface].finish()

        # filter packets
        packets[iface]['Matched'] = pkts[0]
        packets[iface]['Unexpected'] = pkts[1]
        packets[iface]['Expected'] = pkts[2]
        filter(packets[iface]['Matched'], ignored)
        filter(packets[iface]['Unexpected'], ignored)
        filter(packets[iface]['Expected'], ignored)

        # show differences between packets
        error_count += compare(packets[iface]['Expected'],
                               packets[iface]['Unexpected'])

        # write pcap files - TO IMPLEMENT: write to tmp dir
        if packets[iface]['Matched'].__len__() > 0:
            scapy.wrpcap(pcap_dir + iface+"_matched.pcap", packets[iface]['Matched'])
        if packets[iface]['Expected'].__len__() > 0:
            scapy.wrpcap(pcap_dir + iface+"_expected.pcap", packets[iface]['Expected'])
        if packets[iface]['Unexpected'].__len__() > 0:
            scapy.wrpcap(pcap_dir + iface+"_extra.pcap", packets[iface]['Unexpected'])
        if ignored.__len__() > 0:
            scapy.wrpcap(pcap_dir + iface + "_ignored.pcap", ignored)
        # check for bad regread_expect
        try:
            num_bad_reads = bad_reads[iface].__len__()
            error_count += num_bad_reads
        except(KeyError):
            pass
    error_count += barrier_timeouts
    return error_count

############################
# Function: filter
# Arguments: list of packets to filter, list to add ignored packets to
# Description: removes packets to be ignored
############################
def filter(pktlist, ignorelist):
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
# Function: ignore
# Arguments: filter
#            (optional) method
# Description: adds string name of scapy layer to ignore
#              or adds method to ignore if method is True
############################
def ignore(filter, method = False):
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
