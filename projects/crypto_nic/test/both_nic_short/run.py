#!/bin/env python

from NFTest import *

phy2loop0 = ('../connections/conn', [])

nftest_init(sim_loop = [], hw_config = [phy2loop0])
nftest_start()

# send and receive 1 via port 1
DA = "00:11:11:11:11:11"
SA = "00:22:22:22:22:22"

pkt = make_IP_pkt(dst_MAC = DA, src_MAC = SA, dst_IP = '192.168.0.1',
                  src_IP = '192.168.0.2', pkt_len = 60)
nftest_send_phy('nf2c0', pkt)
nftest_expect_dma('nf2c0', pkt)

DA = "00:33:33:33:33:33"
SA = "00:44:44:44:44:44"
pkt = make_IP_pkt(dst_MAC = DA, src_MAC = SA, dst_IP = '192.168.0.3',
                  src_IP = '192.168.0.4', pkt_len = 60)
nftest_send_dma('nf2c0', pkt)
nftest_expect_phy('nf2c0', pkt)

nftest_finish()
