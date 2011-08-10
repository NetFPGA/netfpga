from NFTest import *
from NFTest.hwRegLib import regread
import NFTest.simReg

import sys
import os

import re

import socket
import struct

CPCI_Control_reg = 0x0000008
CPCI_Interrupt_Mask_reg = 0x0000040

################################################################
#
# Setting and getting the router MAC addresses
#
################################################################
def set_router_MAC(port, MAC):
	port = int(port)
	if port < 1 or port > 4:
		print 'bad port number'
		sys.exit(1)
	mac = MAC.split(':')
	mac_hi = int(mac[0],16)<<8 | int(mac[1],16)
	mac_lo = int(mac[2],16)<<24 | int(mac[3],16)<<16 | int(mac[4],16)<<8 | int(mac[5],16)

	port -= 1

	nftest_regwrite(reg_defines.ROUTER_OP_LUT_MAC_0_HI_REG() + port * 8, mac_hi)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_MAC_0_LO_REG() + port * 8, mac_lo)

def get_router_MAC(port, MAC):
	port = int(port)
	if port < 1 or port > 4:
		print 'bad port number'
	port -= 1
	mac_hi = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_0_HI_REG() + port * 8 )
	mac_lo = regread('nf2c0', reg_defines.ROUTER_OP_LUT_MAC_0_LO_REG() + port * 8 )
	mac_tmp = "%04x%08x"%(mac_hi, mac_lo)
        grp_mac = re.search("^(..)(..)(..)(..)(..)(..)$", mac_tmp).groups()
        str_mac = ''
        for octet in grp_mac:
            str_mac += grp_mac + ":"
        str_mac.rstrip(':')
	return str_mac

################################################################
#
# LPM table stuff
#
################################################################
def add_LPM_table_entry(index, IP, mask, next_IP, next_port):
        if index < 0 or index > reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH() - 1 or next_port < 0 or next_port > 255:
                print 'Bad data'
                sys.exit(1)
        if re.match("(\d+)\.", IP):
                IP = dotted(IP)
        if re.match("(\d+)\.", mask):
                mask = dotted(mask)
        if re.match("(\d+)\.", next_IP):
                next_IP = dotted(next_IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), mask)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), next_IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), next_port)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(), index)

def check_LPM_table_entry(index, IP, mask, next_IP, next_port):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH() - 1 or next_port < 0 or next_port > 255:
		print 'Bad data'
		sys.exit(1)
        if re.match("(\d+)\.", IP):
		IP = dotted(IP)
        if re.match("(\d+)\.", IP):
		mask = dotted(mask)
        if re.match("(\d+)\.", IP):
		next_IP = dotted(next_IP)

	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), index)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), IP)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), mask)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), next_IP)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), next_port)

def invalidate_LPM_table_entry(index):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH()-1:
		print 'Bad data'
		sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), 0)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), 0xffffffff)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), 0)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(), index)

def get_LPM_table_entry(index):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH() - 1:
		print 'get_LPM_table_entry_generic: Bad data'
		sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), index)
	IP = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG())
	mask = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG())
	next_hop = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG())
	output_port = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG())

	ip_str = socket.inet_ntoa(struct.pack('!L', IP))
	mask_str = socket.inet_ntoa(struct.pack('!L', mask))
	next_hop_str = socket.inet_ntoa(struct.pack('!L', next_hop))
	return ip_str + '-' + mask_str + '-' + next_hop_str + "-0x%02x"%output_port

################################################################
#
# Destination IP filter table stuff
#
################################################################
def add_dst_ip_filter_entry(index, IP):
        if index < 0 or index > reg_defines.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH() - 1:
                print 'Bad data'
                sys.exit(1)
        if re.match("(\d+)\.", IP):
                IP = dotted(IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG(), index)

def invalidate_dst_ip_filter_entry(index):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH()-1:
		print 'Bad data'
		sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), 0)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG(), index)

def get_dst_ip_filter_entry(index):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH()-1:
		print 'Bad data'
		sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), index)
	return regread('nf2c0', reg_defines.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG())

################################################################
#
# ARP stuff
#
################################################################
def add_ARP_table_entry(index, IP, MAC):
        if re.match("(\d+)\.", IP):
                IP = dotted(IP)
        mac = MAC.split(':')
        mac_hi = int(mac[0],16)<<8 | int(mac[1],16)
        mac_lo = int(mac[2],16)<<24 | int(mac[3],16)<<16 | int(mac[4],16)<<8 | int(mac[5],16)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), IP)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), mac_hi)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), mac_lo)
        nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(), index)

def invalidate_ARP_table_entry(index):
        if index < 0 or index > reg_defines.ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1:
                print 'Bad data'
                sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), 0)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), 0)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(), index)

def check_ARP_table_entry(index, IP, MAC):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_ARP_TABLE_DEPTH() - 1:
		print 'check_ARP_table_entry: Bad data'
		sys.exit(1)
        if re.match("(\d+)\.", IP):
                IP = dotted(IP)
	mac = MAC.split(':')
	mac_hi = int(mac[0],16)<<8 | int(mac[1],16)
	mac_lo = int(mac[2],16)<<24 | int(mac[3],16)<<16 | int(mac[4],16)<<8 | int(mac[5],16)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), index)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), IP)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), mac_hi)
	nftest_regread_expect(reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), mac_lo)

def get_ARP_table_entry(index):
	if index < 0 or index > reg_defines.ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1:
		print 'check_ARP_table_entry: Bad data'
		sys.exit(1)
	nftest_regwrite(reg_defines.ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), index)
	IP = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG())
	mac_hi = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG())
	mac_lo = regread('nf2c0', reg_defines.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG())

	IP_str = socket.inet_ntoa(struct.pack('!L', IP))
	mac_tmp = "%04x%08x"%(mac_hi, mac_lo)
        grp_mac = re.search("^(..)(..)(..)(..)(..)(..)$", mac_tmp).groups()
        str_mac = ''
        for octet in grp_mac:
            str_mac += octet + ":"
        str_mac = str_mac.rstrip(':')
	return IP_str + '-' + str_mac


################################################################
#
# Misc routines
#
################################################################
def dotted(strIP):
	octet = strIP.split('.')
	newip = int(octet[0])<<24 | int(octet[1])<<16 | int(octet[2])<<8 | int(octet[3])
	return newip
