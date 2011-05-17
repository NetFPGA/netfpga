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

############################
# Function: make_MAC_hdr
# Keyword Arguments: src_MAC, dst_MAC, EtherType
# Description: creates and returns a scapy Ether layer
#              if keyword arguments are not specified, scapy defaults are used
############################
def make_MAC_hdr(src_MAC = None, dst_MAC = None, EtherType = None, **kwargs):
    hdr = scapy.Ether()
    if src_MAC:
        hdr.src = src_MAC
    if dst_MAC:
        hdr.dst = dst_MAC
    if EtherType:
        hdr.type = EtherType
    return hdr

############################
# Function: make_IP_hdr
# Keyword Arguments: src_IP, dst_IP, TTL
# Description: creates and returns a scapy Ether layer
#              if keyword arguments are not specified, scapy defaults are used
############################
def make_IP_hdr(src_IP = None, dst_IP = None, TTL = None, **kwargs):
    hdr = scapy.IP()
    if src_IP:
        hdr[scapy.IP].src = src_IP
    if dst_IP:
        hdr[scapy.IP].dst = dst_IP
    if TTL:
        hdr[scapy.IP].ttl = TTL
    return hdr

############################
# Function: make_ARP_hdr
# Keyword Arguments: src_IP, dst_IP, TTL
# Description: creates and returns a scapy ARP layer
#              if keyword arguments are not specified, scapy defaults are used
############################
def make_ARP_hdr(src_MAC = None, dst_MAC = None, src_IP = None, dst_IP = None, **kwargs):
    hdr = scapy.ARP()
    if src_MAC:
        hdr.hwsrc = src_MAC
    if dst_MAC:
        hdr.hwdst = dst_MAC
    if src_IP:
        hdr.psrc = src_IP
    if dst_IP:
        hdr.pdst = dst_IP
    return hdr

############################
# Function: make_IP_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
#                    pkt_len
# Description: creates and returns a complete IP packet of length pkt_len
############################
def make_IP_pkt(pkt_len = 60, **kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_IP_hdr(**kwargs)/generate_load(pkt_len - 34)
    return pkt

############################
# Function: make_ICMP_reply_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
# Description: creates and returns a complete ICMP reply packet
############################
def make_ICMP_reply_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_IP_hdr(**kwargs)/scapy.ICMP(type="echo-reply", code=0, id=0x0, seq=0x0)
    # do code, id, seq need to be set?
    return pkt

############################
# Function: make_ICMP_request_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
# Description: creates and returns a complete ICMP request packet
############################
def make_ICMP_request_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_IP_hdr(**kwargs)/scapy.ICMP(type="echo-request", code=0, id=0x0, seq=0x0)
    return pkt

############################
# Function: make_ICMP_ttl_exceed_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
# Description: creates and returns a complete ICMP reply packet
############################
def make_ICMP_ttl_exceed_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_IP_hdr(**kwargs)/scapy.ICMP(type=11, code=0)
    return pkt

############################
# Function: make_ICMP_host_unreach_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
# Description: creates and returns a complete ICMP reply packet
############################
def make_ICMP_host_unreach_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_IP_hdr(**kwargs)/scapy.ICMP(type=3, code=0)
    return pkt

############################
# Function: make_ARP_request_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#                    src_IP, dst_IP, TTL
# Description: creates and returns a complete ICMP reply packet
############################
def make_ARP_request_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_ARP_hdr(op="who-has", **kwargs)
    return pkt

############################
# Function: make_ARP_reply_pkt
# Keyword Arguments: src_MAC, dst_MAC, EtherType
#
# Description: creates and returns a complete ARP reply packet
############################
def make_ARP_reply_pkt(**kwargs):
    pkt = make_MAC_hdr(**kwargs)/make_ARP_hdr(op="is-at", **kwargs)
    return pkt

############################
# Function: generate_load
# Keyword Arguments: length
# Description: creates and returns a payload of the specified length
############################
def generate_load(length):
    load = ''
    for i in range(length):
        load += chr(randint(0,255))
    return load
