#!/usr/bin/env python

from NFTest import *
from CryptoNICLib import *

phy2loop0 = ('../connections/conn', [])

nftest_init(sim_loop = [], hw_config = [phy2loop0])
nftest_start()

MAC = ['00:ca:fe:00:00:01', '00:ca:fe:00:00:02',
       '00:ca:fe:00:00:03', '00:ca:fe:00:00:04']

IP = ['192.168.1.1', '192.168.2.1', '192.168.3.1', '192.168.4.1']

TTL = 30

#
###############################
#

# Enable encryption
key = 0x55aaff33

nftest_regwrite(reg_defines.CRYPTO_KEY_REG(), key)

#
###############################
#

# Send an IP packet in port 1
length = 64
DA = MAC[1]
SA = MAC[2]
dst_ip = IP[1]
src_ip = IP[2]
pkt = make_IP_pkt(dst_MAC=DA, src_MAC=SA, TTL=TTL, dst_IP=dst_ip,
                  src_IP=src_ip, pkt_len=length)
encrypted_pkt = encrypt_pkt(key, pkt)
nftest_send_dma('nf2c0', pkt)

nftest_expect_phy('nf2c0', encrypted_pkt)

nftest_finish()
