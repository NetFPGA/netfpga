#!/usr/local/bin/python
# make_pkts.py
#
# - write the MAC addresses
# - read the MAC addresses
# - write the port IP addresses
# - read the port IP addresses
# - send 3 packets from port 1 to any IP address
# - check num words in cpu queue and read the same 3 packets from CPU port 1
# - send 3 packets from port 2 to any IP address
# - read the same 3 packets from CPU port 2
# - send 3 packets from port 3 to any IP address
# - read the same 3 packets from CPU port 3
# - send 3 packets from port 4 to any IP address
# - read the same 3 packets from CPU port 4
# - read the number of pkts sent to cpu b/c of lpm miss=3*4
# - add lpm entry
# - send 3 packets from port 1 to lpm entry address
# - read the same 3 packets from CPU port 1 (arp misses)
# - check the number of arp misses = 3
# - add arp entry
# - send the same packets and expect them to be forwarded
# - check the number of forwarded packets
# - remove arp entry and send packets, read packets back from cpu
# - remove lpm entry and send packets, read packets back from cpu
# - send broadcast ARP packets and read from the CPU
# - add multiple LPM entries and arp entries
# - read LPM entries
# - send packets to multiple match LPMs
# - send bad ttl pkt
# - send pkts to wrong destination mac
# - send pkts to the cpu ip addresses
# - send max size pkt
# - send arp pkt

import testReg
import testPkt
import Test
import Packet

Test.init()

ROUTER_PORT_1_MAC = '00:ca:fe:00:00:01';
ROUTER_PORT_2_MAC = '00:ca:fe:00:00:02';
ROUTER_PORT_3_MAC = '00:ca:fe:00:00:03';
ROUTER_PORT_4_MAC = '00:ca:fe:00:00:04';

ROUTER_PORT_1_IP = '192.168.1.1';
ROUTER_PORT_2_IP = '192.168.2.1';
ROUTER_PORT_3_IP = '192.168.3.1';
ROUTER_PORT_4_IP = '192.168.4.1';

DEST_IP_1 = '192.168.1.5';
DEST_IP_2 = '192.168.2.5';
DEST_IP_3 = '192.168.3.5';
DEST_IP_4 = '192.168.4.5';
DEST_IP_4a = '192.168.4.128';
DEST_IP_4b = '192.168.4.129';

NEXT_IP_1 = '192.168.1.2';
NEXT_IP_2 = '192.168.2.2';
NEXT_IP_3 = '192.168.3.2';
NEXT_IP_4 = '192.168.4.2';

next_hop_1_DA = '00:fe:ed:01:d0:65';
next_hop_2_DA = '00:fe:ed:02:d0:65';
next_hop_3_DA = '00:fe:ed:03:d0:65';
next_hop_4_DA = '00:fe:ed:04:d0:65';

testReg.regWrite(0x08, 0)
testReg.regWrite(0x40, 0)


# Write the ip addresses and mac addresses, routing table and ARP entries #ONE REG WRITE EACH
testReg.regWrite(0x2000, ROUTER_PORT_1_MAC) #set_router_MAC(1, $ROUTER_PORT_1_MAC);
testReg.regWrite(0x2000, ROUTER_PORT_2_MAC) #set_router_MAC(2, $ROUTER_PORT_2_MAC);
testReg.regWrite(0x2030, ROUTER_PORT_3_MAC) #set_router_MAC(3, $ROUTER_PORT_3_MAC);
testReg.regWrite(0x2040, ROUTER_PORT_4_MAC) #set_router_MAC(4, $ROUTER_PORT_4_MAC);

# write the IP addresses to ip  #ONE REG READ EACH
testReg.regRead(0x2030, ROUTER_PORT_1_IP) # add_dst_ip_filter_entry(0,$ROUTER_PORT_1_IP);
testReg.regRead(0x2300, ROUTER_PORT_2_IP) # add_dst_ip_filter_entry(1,$ROUTER_PORT_2_IP);
testReg.regRead(0x2302, ROUTER_PORT_3_IP) # add_dst_ip_filter_entry(2,$ROUTER_PORT_3_IP);
testReg.regRead(0x2300, ROUTER_PORT_4_IP) # add_dst_ip_filter_entry(3,$ROUTER_PORT_4_IP);

testPkt.barrier()
length = 100;
TTL = 30;
DA = 0;
SA = 0;
dst_ip = 0;
src_ip = 0;


# send 3 pkts from port 1 to ip 2 should go to cpu (lpm miss)
length = 60;
DA = ROUTER_PORT_1_MAC;
SA = '01:55:55:55:55:55';
dst_ip = DEST_IP_2;
src_ip = '171.64.8.1';
in_port = 1;

pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);

testPkt.barrier()

# send 3 pkts from port 2 to ip 3 should go to cpu (lpm miss)
length = 60;
DA = ROUTER_PORT_2_MAC;
SA = '02:55:55:55:55:55';
dst_ip = DEST_IP_3;
src_ip = '171.64.8.2';
in_port = 2;

for i in range(3):
    pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
    testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
    testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
testPkt.barrier()

# read the number of pkts sent to cpu b/c of lpm miss
testReg.regRead(1337, 0) #nf_PCI_read32($delay, $batch, ROUTER_OP_LUT_LPM_NUM_MISSES_REG(), 3*2);

# send 3 pkts from port 3 to ip 4 should go to cpu (lpm miss)
length = 60;
DA = ROUTER_PORT_3_MAC;
SA = '03:55:55:55:55:55';
dst_ip = DEST_IP_4;
src_ip = '171.64.8.3';
in_port = 3;

for i in range(3):
    pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip)
    testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
    testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
testPkt.barrier()

# send 3 pkts from port 4 to ip 1 should go to cpu (lpm miss)
length = 60;
DA = ROUTER_PORT_4_MAC;
SA = '04:55:55:55:55:55';
dst_ip = DEST_IP_1;
src_ip = '171.64.8.4';
in_port = 4;

for i in range(3):
    pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
    testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
    testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
testPkt.barrier()

# read the number of pkts sent to cpu b/c of lpm miss
testReg.regRead(0, 111)

# add lpm entry for ip 2
testReg.regWrite(0, 1337)
testReg.regWrite(1, 1337)
testReg.regWrite(2, 1337)
testReg.regWrite(3, 1337)
testReg.regWrite(4, 1337) #add_LPM_table_entry(0,'192.168.2.0', '255.255.255.0', $NEXT_IP_2, 0x4); 5 REG WRITES

# send 3 pkts from port 1 to ip 2 should go to cpu (arp miss)
#$delay = '@100us';
#$length = 60;
#$DA = $ROUTER_PORT_1_MAC;
#$SA = '05:55:55:55:55:55';
#$dst_ip = $DEST_IP_2;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$delay = 0;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
testPkt.delay(100)

# add arp entry for next hop
#$delay = '@120us';
#add_ARP_table_entry(0, $NEXT_IP_2, $next_hop_2_DA); #4 REG WRITES
testReg.regWrite(0, 1337)
testReg.regWrite(1, 1337)
testReg.regWrite(2, 1337)
testReg.regWrite(3, 1337)

# send the same packets again
# send 3 pkts from port 1 to ip 2 should be forwarded out of port 2
length = 60;
DA = ROUTER_PORT_1_MAC;
SA = '06:55:55:55:55:55';
dst_ip = DEST_IP_2;
src_ip = '171.64.8.1';
in_port = 1;
out_port = 2;

for i in range(3):
    pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
    testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
    testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($out_port, $length, $pkt);
testPkt.barrier()

#pkt = Packet.make_IP_pkt(length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$delay = 0;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

#$DA = $next_hop_2_DA;
#$SA = $ROUTER_PORT_2_MAC;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
#nf_expected_packet($out_port, $length, $pkt);
#nf_expected_packet($out_port, $length, $pkt);
#nf_expected_packet($out_port, $length, $pkt);

# check the number of forwarded packets
#$delay = '@150us';
#nf_PCI_read32($delay, $batch, ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 3);
testPkt.delay(150)

# remove arp entry
#$delay = 0;
#nf_PCI_write32($delay, $batch, ROUTER_OP_LUT_ARP_NUM_MISSES_REG(), 0);
#invalidate_ARP_table_entry(0); #4 REG WRITES
testReg.regWrite(0, 1337)
testReg.regWrite(0, 1337)
testReg.regWrite(0, 1337)
testReg.regWrite(0, 1337)

# send 3 pkts from port 1 to ip 2 should go to cpu (arp miss)
#$delay = '@165us';
#$length = 60;
#$DA = $ROUTER_PORT_1_MAC;
#$SA = '07:55:55:55:55:55';
#$dst_ip = $DEST_IP_2;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$delay = 0;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
testPkt.delay(165)

# read the number of pkts sent to cpu b/c of arp miss
#$delay = '@185us';
#nf_PCI_read32($delay, $batch, ROUTER_OP_LUT_ARP_NUM_MISSES_REG(), 3);
#$delay = 0;
testPkt.delay(185)

# add arp entry for next hop
#add_ARP_table_entry(5, $NEXT_IP_2, $next_hop_2_DA); #4 REG WRITES
testReg.regWrite(0, next_hop_2_DA)
testReg.regWrite(1, next_hop_2_DA)
testReg.regWrite(2, next_hop_2_DA)
testReg.regWrite(3, next_hop_2_DA)

# send the same packets again
# send 3 pkts from port 1 to ip 2 should be forwarded out of port 2
length = 60;
DA = ROUTER_PORT_1_MAC;
SA = '08:55:55:55:55:55';
dst_ip = DEST_IP_2;
src_ip = '171.64.8.1';
in_port = 1;
out_port = 2;

for i in range(3):
    pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
    testPkt.pktSendPHY(in_port, pkt) #nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
    testPkt.pktExpectDMA(in_port, pkt) #nf_expected_dma_data($out_port, $length, $pkt);
testPkt.barrier()
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$delay = 0;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
#$DA = $next_hop_2_DA;
#$SA = $ROUTER_PORT_2_MAC;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
#nf_expected_packet($out_port, $length, $pkt);
#nf_expected_packet($out_port, $length, $pkt);
#nf_expected_packet($out_port, $length, $pkt);

# remove lpm entry for ip 2
#$delay = '@215us';
#invalidate_LPM_table_entry(0); #4 REG WRITES
testReg.regWrite(0, 0)
testReg.regWrite(1, 0)
testReg.regWrite(2, 0)
testReg.regWrite(3, 0)

# send 3 pkts from port 1 to ip 2 should go to cpu (lpm miss)
#$delay = '@220us';
#$length = 60;
#$DA = $ROUTER_PORT_1_MAC;
#$SA = '09:55:55:55:55:55';
#$dst_ip = $DEST_IP_2;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
#$delay = 0;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);

#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);

# Add LPM entries
#$delay = '@240us';
#add_LPM_table_entry(0,'192.168.1.0', '255.255.255.0', $NEXT_IP_1, 0x1); #5 REG WRITES
#$delay = 0;
#add_LPM_table_entry(1,'192.168.2.0', '255.255.255.0', $NEXT_IP_2, 0x4);
#add_LPM_table_entry(2,'192.168.3.0', '255.255.255.0', $NEXT_IP_3, 0x10);
#add_LPM_table_entry(3,'192.168.4.129', '255.255.255.255', $NEXT_IP_3, 0x10);
#add_LPM_table_entry(4,'192.168.4.128', '255.255.255.128', $NEXT_IP_1, 0x1);
#add_LPM_table_entry(5,'192.168.4.0', '255.255.255.0', $NEXT_IP_4, 0x40);
for i in range(30):
    testReg.regWrite(i/5, NEXT_IP_1)

# Add ARP entries
#add_ARP_table_entry(0, $NEXT_IP_1, $next_hop_1_DA); #4 REG WRITES EACH
#add_ARP_table_entry(1, $NEXT_IP_2, $next_hop_2_DA);
#add_ARP_table_entry(2, $NEXT_IP_3, $next_hop_3_DA);
#add_ARP_table_entry(3, $NEXT_IP_4, $next_hop_4_DA);
for i in range(16):
    testReg.regWrite(i/4, next_hop_1_DA)

# send 2 packets that have multiple LPM matches
#delay = '@300us';
#length = 60;
#DA = $ROUTER_PORT_2_MAC;
#SA = '0a:55:55:55:55:55';
#dst_ip = $DEST_IP_4a;
#src_ip = '171.64.8.1';
#in_port = 2;
#out_port = 1;
#pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
#$DA = $next_hop_1_DA;
#$SA = $ROUTER_PORT_1_MAC;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
#nf_expected_packet($out_port, $length, $pkt);
#$length = 60;
#$DA = $ROUTER_PORT_1_MAC;
#$SA = '0b:55:55:55:55:55';
#$dst_ip = $DEST_IP_4b;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$out_port = 3;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
#$DA = $next_hop_3_DA;
#$SA = $ROUTER_PORT_3_MAC;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
#nf_expected_packet($out_port, $length, $pkt);
testPkt.delay(300)
testPkt.delay(300)

# send packet with bad TTL
#$delay = '@330us';
#$length = 60;
#$DA = $ROUTER_PORT_1_MAC;
#$SA = '0c:55:55:55:55:55';
#$dst_ip = $DEST_IP_3;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$TTL = 1;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
#nf_expected_dma_data($in_port, $length, $pkt);
testPkt.delay(330)

# Send packet with wrong MAC (dropped)
#delay = '@340us';
#$length = 200;
#$DA = $ROUTER_PORT_2_MAC;
#$SA = '0d:55:55:55:55:55';
#$dst_ip = $DEST_IP_3;
#$src_ip = '171.64.8.1';
#$in_port = 1;
#$TTL = 30;
#$pkt = Packet.make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
#testPkt.pktSendDMA($in_port, $length, $delay, $batch,  $pkt);
testPkt.delay(340)

# send a packet from cpu
length = 60;
out_port = 4;
#PCI_create_and_send_pkt($out_port, $length);

# send packet to the cpu
#length = 200;
#DA = ROUTER_PORT_3_MAC;
#SA = '0e:55:55:55:55:55';
#dst_ip = ROUTER_PORT_3_IP;
#src_ip = '171.64.8.1';
#out_port = 3;
#in_port = 3;
#pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
#testPkt.pktSendDMA(in_port, pkt);
#testPkt.pktExpectPHY(in_port, pkt) #nf_expected_dma_data($in_port, $length, $pkt);
#testPkt.barrier()
testPkt.delay(340)

# send max size packet (NOT FOR THIS TEST)
length = 60 #length = 2000; #??
DA = ROUTER_PORT_3_MAC;
SA = '0f:55:55:55:55:55';
dst_ip = DEST_IP_2;
src_ip = '171.64.8.1';
in_port = 3;
out_port = 2;
pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
testPkt.pktSendDMA(in_port, pkt);

#DA = next_hop_2_DA;
#SA = ROUTER_PORT_2_MAC;
#pkt = Packet.make_IP_pkt(length, DA, SA, TTL-1, dst_ip, src_ip);
testPkt.pktExpectPHY(in_port, pkt) #nf_expected_packet($out_port, $length, $pkt);
testPkt.barrier()

# send broadcast packet - should be dropped wrong dest MAC
length = 60;
DA = 'ff:ff:ff:ff:ff:ff';
SA = '10:55:55:55:55:55';
dst_ip = DEST_IP_4a;
src_ip = '171.64.8.1';
in_port = 2;
out_port = 1;
pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
testPkt.pktSendDMA(in_port, pkt)
testPkt.pktExpectPHY(in_port, pkt)
testPkt.barrier()

#nf_PCI_read32($delay, $batch, ROUTER_OP_LUT_NUM_WRONG_DEST_REG(), 2);
testReg.regRead(0, 0)

# send arp packet
length = 60;
DA = ROUTER_PORT_4_MAC;
SA = '11:55:55:55:55:55';
in_port = 4;
pkt = Packet.make_IP_pkt(length, DA, SA, 64, dst_ip, src_ip) # make_ethernet_pkt($length, $DA, $SA, 0x806); #estimated as IP
testPkt.pktSendDMA(in_port, pkt);
testPkt.pktExpectPHY(in_port, pkt)
testPkt.barrier()

# flood the router with random packets
for pkt_num in range(100):
  length = 60;
  DA = ROUTER_PORT_3_MAC;
  SA = '0f:55:55:55:55:55';
  dst_ip = DEST_IP_2;
  src_ip = '171.64.8.1';
  in_port = 3;
  out_port = 2;
  pkt = Packet.make_IP_pkt(length, DA, SA, TTL, dst_ip, src_ip);
  testPkt.pktSendDMA(in_port, pkt);

  #DA = next_hop_2_DA;
  #SA = ROUTER_PORT_2_MAC;
  #pkt = Packet.make_IP_pkt(length, DA, SA, TTL-1, dst_ip, src_ip);
  testPkt.pktExpectPHY(in_port, pkt); #expectPHY(out_port


testPkt.barrier()
Test.close()

Test.modelSim("jhsi")
