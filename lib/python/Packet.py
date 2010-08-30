#!/usr/bin/env python
import sys

try:
    import scapy.all as scapy
except:
    try:
        import scapy as scapy
    except:
        sys.exit("Error: Need to install scapy for packet handling")

def make_IP_pkt(pktlen=100,
                   dl_dst=':00:01:02:03:04',
                   dl_src=':55:55:55:55:55',
                   something = "64", #not sure what this is?
                   ip_src='192.168.0.1',
                   ip_dst='192.168.0.2',
                   ):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)
    pkt = pkt/("D" * (pktlen - len(pkt)))
    return pkt
