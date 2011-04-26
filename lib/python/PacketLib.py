#!/usr/bin/env python
import sys
from random import randint

try:
    import scapy.all as scapy
except:
    try:
        import scapy as scapy
    except:
        sys.exit("Error: Need to install scapy for packet handling")

def make_MAC_hdr(*args, **kwargs):
    hdr = scapy.Ether(*args, **kwargs)
    #if dst:
    #    hdr.dst = dst
    #if src:
    #    hdr.src = src
    #if eth_type:
    #    hdr.eth_type = eth_type
    return hdr

def make_IP_pkt(len = 0, src = '', dst = ''):
    pkt = scapy.IP()
    if len: # questionable - scapy auto?
        pkt.len = len
    if src:
        pkt.src = src
    if dst:
        pkt.dst = dst
    pkt = pkt/generate_load(pktlen - len(pkt))
    return pkt

def make_ICMP_reply_pkt(pktlen, dl_dst, dl_src, something, ip_src, ip_dst,):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)/scapy.ICMP(type="echo-reply", code=0, id=0x0, seq=0x0)
    return pkt

def make_ICMP_request_pkt(pktlen, dl_dst, dl_src, something, ip_src, ip_dst,):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)/scapy.ICMP(type="echo-request", code=0, id=0x0, seq=0x0)
    return pkt

def make_ICMP_ttl_exceed_pkt(pktlen, dl_dst, dl_src, something, ip_src, ip_dst,):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)/scapy.ICMP(type=11, code=0)
    return pkt

def make_ICMP_host_unreach_pkt(pktlen, dl_dst, dl_src, something,
                               ip_src, ip_dst,):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)/scapy.ICMP(type=3, code=0)
    return pkt

def make_ARP_request_pkt(dl_dst, dl_src,  ip_src, ip_dst,):
    pkt = scapy.Ether(src=dl_src, dst=dl_dst, type=0x0806)/scapy.ARP(op="who-has", psrc=ip_src, pdst=ip_dst)
    return pkt

def make_ARP_reply_pkt(dl_dst, dl_src, ip_src, ip_dst,):
    pkt = scapy.Ether(src=dl_src, dst=dl_dst, type=0x0806)/scapy.ARP(op="is-at", psrc=ip_src, pdst=ip_dst)
    return pkt

def generate_load(min_len, max_len = 0):
    if max_len == 0:
        max_len = min_len
    load = ''
    for i in range(randint(min_len, max_len)):
        load += chr(randint(0,255))
    return load
