#!/usr/bin/env python
# Author: Eric Lo
# Date: 3/16/2011

import sys
from threading import Thread, Lock, Event
import time
import socket
import os
from collections import deque
from select import select

try:
   import scapy.all as scapy
except:
   try:
      import scapy as scapy
   except:
      sys.exit("Error: need to install scapy for packet handling")

# Override sniff from scapy to implement custom stopper
# from http://trac.secdev.org/scapy/wiki/PatchSelectStopperTimeout
def sniff(count=0, store=1, offline=None, prn = None, lfilter=None, L2socket=None, timeout=None, stopperTimeout=None, stopper = None, lst = [], *arg, **karg):
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

    #lst = []
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
        self.daemon = True
        self.device = device
        self.done = False
        self.ready = False
        self.count = 0
        self.pkts = []
        self.exp_pkts = []
        self.matched =[]
        self.lock = Lock()
        self.status = -1
        self.compareEvent = Event()
        self.compare = pktCompare(self)
        self.barrierEvent = Event()

    ############################
    # Function: run
    # Arguments: calling object
    # Description: starts background comparison thread, runs sniff
    ############################
    def run(self):
        self.compare.start()
        while not self.done:
            try:
                sniff(prn=self.addPkt,iface=self.device, store=0,
                      stopperTimeout=1, stopper=self.isDone)
            except(KeyboardInterrupt):
                self.finish()

    ############################
    # Function: addPkt
    # Arguments: calling object
    #            packet to add to pkts
    # Description: adds packet to either matched or received packets list
    #              notifies background thread to compare packet lists
    ############################
    def addPkt(self,pkt):
        self.pkts.append(pkt)
        self.count += 1
        self.barrierEvent.clear()
        if self.compareEvent.is_set():
            pass
        else:
            self.compareEvent.set()

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
    # Description: adds packet to list of packets to expect
    ############################
    def expectPkt(self, pkt):
        self.exp_pkts.append(pkt)
        self.barrierEvent.clear()

    ############################
    # Function: resolvePkts
    # Arguments: calling object
    # Description: checks unmatched received packets against unmatched expected packets
    #              notifies barrierEvent if expected and received packet lists are empty
    ############################
    def resolvePkts(self):
        self.lock.acquire()
        if (len(self.pkts) > 0) and  (len(self.exp_pkts) > 0):
            self.barrierEvent.clear()
            i = 0
            numPkts = len(self.pkts)
            while i < numPkts:
                strpkt = str(self.pkts[i])
                for exp in self.exp_pkts:
                    strexp = str(exp)
                    matches = (strexp == strpkt)
                    if not matches and len(exp) < 60 and self.pkts[i].haslayer(scapy.Padding):
                        if ''.join([strexp,str(self.pkts[i][scapy.Padding])]) == strpkt:
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
        if (len(self.pkts) is 0) and  (len(self.exp_pkts) is 0):
            self.barrierEvent.set()
            return True
        return False

    ############################
    # Function: restart
    # Arguments: calling object
    # Description: resets all packet lists
    ############################
    def restart(self):
        self.lock.acquire()
        self.exp_pkts = []
        self.pkts = []
        self.matched = []
        self.lock.release()


    ############################
    # Function: finish
    # Arguments: calling object
    # Description: tells sniff to stop sniffing
    #              returns packets
    ############################
    def finish(self):
        print self.device, 'finishing up'
        self.done = True
        self.lock.acquire()
        return (self.matched, self.pkts, self.exp_pkts)

class pktSend(Thread):
    ############################
    # Function: __init__
    # Arguments: calling object
    #            device name
    #            socket configuration options
    # Description: overrides Thread.__init__, initializes vars, opens socket
    ############################
    def __init__(self, device, family = socket.AF_PACKET,
                 type = socket.SOCK_RAW, proto = socket.htons(3)):
        Thread.__init__(self)
        self.daemon = True
        self.lock = Lock()
        self.closed = False
        self.toSend = deque()
        self.sock = socket.socket(family, type, proto)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 0)
        while True:
            r,w,x = select([self.sock.fileno()], [], [], 0)
            if r:
                os.read(self.sock.fileno(),1600)
            else:
                break
        self.sock.bind((device,3))
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 2**30)
        self.sentcount = 0
        self.sendcount = 0

    ############################
    # Function: run
    # Arguments: calling object
    # Description: overrides Thread.run, sends packets in queue
    ############################
    def run(self):
        while not self.closed:
            try:
                if len(self.toSend) > 0:
                    self.lock.acquire()
                    self.sock.send(self.toSend.popleft().__str__())
                    self.sentcount += 1
                    self.lock.release()
            except(KeyboardInterrupt):
                self.close()

    ############################
    # Function: sendPkt
    # Arguments: calling object
    #            packet to send
    # Description: adds packets to queue to be sent
    #              delays so scapy doesn't drop packets
    ############################
    def sendPkt(self, pkt):
        self.lock.acquire()
        self.toSend.append(pkt)
        self.sendcount += 1
        time.sleep(0.008)
        self.lock.release()

    ############################
    # Function: close
    # Arguments: calling object
    # Description: waits for packets to drain, then closes socket
    ############################
    def close(self):
        while len(self.toSend) > 0:
            pass
        if self.closed:
            return
        self.closed = True
        self.sock.close()

class pktCompare(Thread):
    ############################
    # Function: __init__
    # Arguments: calling object
    #            pktExpect object
    # Description: overrides Thread.__init__, initializes vars
    ############################
    def __init__ (self, expect):
        Thread.__init__(self)
        self.daemon = True
        self.done = False
        self.compareEvent = expect.compareEvent
        self.compare = expect.resolvePkts

    ############################
    # Function: run
    # Arguments: calling object
    # Description: waits until woken by addPkt, then calls resolvePkts
    ############################
    def run(self):
        while not self.done:
            self.compareEvent.wait()
            self.compareEvent.clear()
            self.compare()
