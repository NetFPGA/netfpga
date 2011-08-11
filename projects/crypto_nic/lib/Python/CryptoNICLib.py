from NFTest import *

# Where should we start encrypting/decrypting?
START_POS = 14 + 20

def encrypt_pkt(key, pkt):
    key_ary = [0, 0, 0, 0]
    for i in range(4):
        key_ary[i] = (key >> (24 - i * 8)) & 0xff

    # Identify the packet type and break up the packet as appropriate
    if pkt.haslayer(scapy.IP):
        load = pkt.load
        str_load = ''
        for i in range(len(load)):
            str_load += chr(ord(load[i]) ^ key_ary[(i+START_POS)%4])
        ret_pkt = pkt.copy()
        ret_pkt.load = str_load
        return ret_pkt
    else:
        str_pkt = str(pkt)
        hdr = str_pkt[14:21]
        load = str_pkt[START_POS:]
        str_load = ''
        for i in range(len(pkt)-START_POS):
            str_load += str(ord(load[i]) ^ key_ary[(i+START_POS)%4])
        return pkt[scapy.Ether]/load

def decrypt_pkt(key, pkt):
    return encrypt_pkt(key, pkt)
