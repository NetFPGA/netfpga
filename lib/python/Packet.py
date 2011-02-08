#!/usr/bin/env python
import sys

try:
    import scapy.all as scapy
except:
    try:
        import scapy as scapy
    except:
        sys.exit("Error: Need to install scapy for packet handling")

def make_IP_pkt(pktlen, dl_dst, dl_src, something, ip_src, ip_dst,):
    pkt = scapy.IP(len=pktlen, src=ip_src, dst=ip_dst)
    pkt = pkt/("D" * (pktlen - len(pkt)))
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
