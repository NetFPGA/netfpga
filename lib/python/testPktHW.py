#1/usr/bin/env python
# Author: Eric Lo
# Date: 2/9/2011

import sys
from threading import Thread
from threading import Lock
import time

try:
   import scapy.all as scapy
except:
   try:
      import scapy as scapy
   except:
      sys.exit("Error: need to install scapy for packet handling")

# Override sniff from scapy to implement custom stopper
def sniff(count=0, store=1, offline=None, prn = None, lfilter=None, L2socket=None, timeout=None, stopperTimeout=None, stopper = None, *arg, **karg):
    """Sniff packets
sniff([count=0,] [prn=None,] [store=1,] [offline=None,] [lfilter=None,] + L2ListenSocket args) -> list of packets

  count: number of packets to capture. 0 means infinity
  store: wether to store sniffed packets or discard them
    prn: function to apply to each packet. If something is returned,
         it is displayed. Ex:
         ex: prn = lambda x: x.summary()
lfilter: python function applied to each packet to determine
         if further action may be done
         ex: lfilter = lambda x: x.haslayer(Padding)
offline: pcap file to read packets from, instead of sniffing them
timeout: stop sniffing after a given time (default: None)
stopperTimeout: break the select to check the returned value of
         stopper() and stop sniffing if needed (select timeout)
stopper: function returning true or false to stop the sniffing process
L2socket: use the provided L2socket
    """
    c = 0

    if offline is None:
        if L2socket is None:
            L2socket = scapy.conf.L2listen
        s = L2socket(type=scapy.ETH_P_ALL, *arg, **karg)
    else:
        s = PcapReader(offline)

    lst = []
    if timeout is not None:
        stoptime = time.time()+timeout
    remain = None

    if stopperTimeout is not None:
        stopperStoptime = time.time()+stopperTimeout
    remainStopper = None
    while 1:
        try:
            if timeout is not None:
                remain = stoptime-time.time()
                if remain <= 0:
                    break

            if stopperTimeout is not None:
                remainStopper = stopperStoptime-time.time()
                if remainStopper <=0:
                    if stopper and stopper():
                        break
                    stopperStoptime = time.time()+stopperTimeout
                    remainStopper = stopperStoptime-time.time()

                sel = scapy.select([s],[],[],remainStopper)
                if s not in sel[0]:
                    if stopper and stopper():
                        break
            else:
                sel = scapy.select([s],[],[],remain)

            if s in sel[0]:
                p = s.recv(scapy.MTU)
                if p is None:
                    break
                if lfilter and not lfilter(p):
                    continue
                if store:
                    lst.append(p)
                c += 1
                if prn:
                    r = prn(p)
                    if r is not None:
                        print r
                if count > 0 and c >= count:
                    break
        except KeyboardInterrupt:
            break
    s.close()
    return scapy.plist.PacketList(lst,"Sniffed")



class pktExpect(Thread):
    ############################
    # Function: __init__
    # Arguments: calling object
    #            device name to sniff
    # Description: overrides Thread.__init__, initializes vars
    ############################
    def __init__ (self, device):
        Thread.__init__(self)
        self.device = device
        self.pkts = []
        self.done = False
        self.exp_pkts = []
        self.unexp_pkts = []
        self.missing_pkts = []
        self.matched =[]
        self.ready = False
        self.verbose = True # default should be false
        self.lock = Lock()
        self.status = -1

    ############################
    # Function: run
    # Arguments: calling object
    # Description: runs sniff
    ############################
    def run(self):
        while not self.done:
            try:
                sniff(prn=self.addPkt,iface=self.device, store=0, stopperTimeout=1, stopper=self.isDone)
            except(KeyboardInterrupt):
                self.finish()
        else:
            sys.exit(0)

    ############################
    # Function: addPkt
    # Arguments: calling object
    #            packet to add to pkts
    # Description: adds packet to either matched or received packets list
    ############################
    def addPkt(self,pkt):
        self.pkts.append(pkt)
        self.resolvePkts()

    ############################
    # Function: isDone
    # Arguments: calling object
    # Description: tells sniff if it should stop
    #              sets ready so client knows it can start sending packets
    ############################
    def isDone(self):
        self.ready = True
        return self.done

    ############################
    # Function: isReady
    # Arguments: calling object
    # Description: tells client if sniff is ready to receive packets
    ############################
    def isReady(self):
        return self.ready

    ############################
    # Function: expectPkt
    # Arguments: calling object
    #            packet to expect
    # Description: adds packet to list of packets to expect, rechecks packet lists
    ############################
    def expectPkt(self, pkt):
        self.exp_pkts.append(pkt)
        self.resolvePkts()

    ############################
    # Function: resolvePkts
    # Arguments: calling object
    # Description: checks unmatched received packets against unmatched expected packets
    ############################
    def resolvePkts(self):
        self.lock.acquire()
        self.pkts == None
        self.exp_pkts == None
        if (len(self.pkts) != 0) and  (len(self.exp_pkts) != 0):
            i = 0
            numPkts = len(self.pkts)
            while i < numPkts:
                for exp in self.exp_pkts:
                    matches = str(exp) == str(self.pkts[i])
                    if not matches and self.pkts[i].haslayer(scapy.Padding):
                        if str(exp/self.pkts[i][scapy.Padding]) == str(self.pkts[i]):
                            matches = True
                    if matches:
                        self.matched.append(self.pkts[i])
                        self.pkts.remove(self.pkts[i])
                        self.exp_pkts.remove(exp)
                        numPkts -= 1
                        i -= 1
                        break
                i += 1
        self.lock.release()
        return True

    ############################
    # Function: barrier
    # Arguments: calling object
    #            timeout in seconds
    # Description: pauses execution until expected packets arrive or timeout passes
    ############################
    def barrier(self, timeout):
        self.resolvePkts()
        start = time.clock()
        # 10 sec timeout
        while (len(self.exp_pkts) != 0) & ((time.clock() - start) < timeout):
            pass
        else:
            if len(self.exp_pkts) == 0:
                return True
            else:
                print '\nError: barrier timed out after ', str(timeout), ' seconds'
                print 'Missing ', str(len(self.exp_pkts)), ' packet on device ', str(self.device), '\n'
        return False

    ############################
    # Function: pktCmp
    # Arguments: calling object
    # Description: compares expected packets to received packets
    #              prints differences and returns # of errors
    ############################
    def pktCmp(self):
        if len(self.pkts) == 0 and len(self.exp_pkts) == 0:
            return 0
        elif len(self.pkts) == 0:
            return len(self.exp_pkts)
        elif len(self.exp_pkts) == 0:
            return len(self.pkts)
        error = 0
        exp_matched = []
        # mark each egress packet as not matched
        for pktNum in range(len(self.exp_pkts)):
            exp_matched.append(0)

        # try to match expected pkt w/ egress pkt
        for pktNum in range(len(self.pkts)):
            pkt = self.pkts[pktNum] # pkt is packet to compare against
            exp_index = 0 # will be index of matching exp_pkt
            result = True
            while ((exp_index < len(self.exp_pkts)) and result):
                result = True # true - mismatch
                if (exp_matched[exp_index] == 0):
                    exp_pkt = self.exp_pkts[exp_index]
                    result = (exp_pkt != pkt)
                exp_index += 1

            if result:
                error += 1
                str_exp_pkt = ''
                str_pkt = ''
                for x in str(exp_pkt):
                    str_exp_pkt += "%02X"%ord(x)
                for x in str(pkt):
                    str_pkt += "%02X"%ord(x)
                if self.verbose & (len(str_exp_pkt) != len(str_pkt)):
                    print 'Packet lengths do not match, expecting ', str(len(exp_pkt)), ' but saw ', str(len(pkt))
                else:
                    for i in range(len(str_exp_pkt)):
                        if self.verbose & (str_pkt[i] != str_exp_pkt[i]):
                            print 'byte ', str(i/2), ' (starting from 0) not equivalent (EXP: ', str_exp_pkt[i:i+2], ', ACTUAL: ', str_pkt[i:i+2], ')'
                            break
            else:
                exp_index -= 1
        return error

    ############################
    # Function: finish
    # Arguments: calling object
    # Description: calls pktCmp and prints results
    #              tells sniff to stop sniffing
    #              returns received packets
    ############################
    def finish(self):
        print self.device, 'finishing up'
        #time.sleep(1) # make sure last few packets get in - DEPRECATED: barrier
        #print self.pktCmp(), ' errors\n'
        self.done = True
        #self.barrier(10)
        print 'matched ', str(len(self.matched)), ' packets'
        if len(self.exp_pkts) != 0:
            if not (len(self.exp_pkts) is 1 and self.exp_pkts[0] is None):
                print str(len(self.exp_pkts)), ' missing packets'
                scapy.wrpcap(self.device+"_missing.pcap",self.exp_pkts)
        if len(self.pkts) != 0:
            if not (len(self.pkts) is 1 and self.pkts[0] is None):
                print str(len(self.pkts)), ' extra packets'
                scapy.wrpcap(self.device+"_extra.pcap",self.pkts)
        print ''
        self.pktCmp()
        return self.pkts


############################
# Function: pktSend
# Arguments: calling object
#            name of interface to sniff
#            packet to send
# Description: sends packet on an interface
############################
def pktSend(ifaceName, pkt):
    scapy.sendp(pkt,iface=ifaceName)
