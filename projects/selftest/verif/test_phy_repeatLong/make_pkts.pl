#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;

use SimLib;

use reg_defines_selftest;

$delay = 0;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay and $batch are declared
use strict;
use vars qw($delay $batch);


# In hardware, worst case running time should be 2ms.
# That's assuming each packet has 15us transmission delay

########### start the test ################

### test 1 ###

my $data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 01 ". '00 'x44;
my $data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 01 ". '00 'x44;
my $data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 01 ". '00 'x44;
my $data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 01 ". '00 'x44;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 2000, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 2000, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 2000, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 2000, 0, $data_from_4);




### test 2 ###

$data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 02 ". 'ff 'x44;
$data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 02 ". 'ff 'x44;
$data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 02 ". 'ff 'x44;
$data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 02 ". 'ff 'x44;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 200, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 200, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 200, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 200, 0, $data_from_4);




### test 3 ###

$data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 04 ". '55 'x44;
$data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 04 ". '55 'x44;
$data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 04 ". '55 'x44;
$data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 04 ". '55 'x44;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 200, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 200, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 200, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 200, 0, $data_from_4);




### test 4 ###

$data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 08 ". 'aa 'x44;
$data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 08 ". 'aa 'x44;
$data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 08 ". 'aa 'x44;
$data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 08 ". 'aa 'x44;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 200, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 200, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 200, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 200, 0, $data_from_4);




### test 5 ###

my $randnum = 0x001;
my $rand_data = "00 00 00 01";
for (my $i = 1; $i < 44 / 4; $i++) {
   $rand_data .= sprintf(" %02x %02x %02x %02x",
	   		($randnum >> 24) & 0xff,
			($randnum >> 16) & 0xff,
			($randnum >> 8) & 0xff,
			($randnum >> 0) & 0xff);
   $randnum = ($randnum << 1) |
   	       ((($randnum & 0x80000000) >> 31) ^
   	        (($randnum & 0x40000000) >> 30) ^
   	        (($randnum & 0x20000000) >> 29) ^
   	        (($randnum & 0x00000200) >> 9));
}

$data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 10 ". $rand_data;
$data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 10 ". $rand_data;
$data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 10 ". $rand_data;
$data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 10 ". $rand_data;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 200, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 200, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 200, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 200, 0, $data_from_4);





########### Restart the test in repeat mode ################
nf_PCI_write32( 15000, $batch, PHY_TEST_PATTERN_REG(), 0x00000010 );
nf_PCI_write32( 0, $batch, PHY_TEST_CTRL_REG(), 0x00000002 );
#nf_PCI_write32( 15000, $batch, PHY_TEST_SIZE_REG(), 1514 );

########### Stop the test in repeat mode ################
# Note: This is delayed
nf_PCI_write32( 50000, $batch, PHY_TEST_CTRL_REG(), 0x00000000 );


########### Repeat -- Iteration 1 ################

### test 5 ###

$randnum = 0x001;
$rand_data = "00 00 00 01";
for (my $i = 1; $i < 44 / 4; $i++) {
   $rand_data .= sprintf(" %02x %02x %02x %02x",
	   		($randnum >> 24) & 0xff,
			($randnum >> 16) & 0xff,
			($randnum >> 8) & 0xff,
			($randnum >> 0) & 0xff);
   $randnum = ($randnum << 1) |
   	       ((($randnum & 0x80000000) >> 31) ^
   	        (($randnum & 0x40000000) >> 30) ^
   	        (($randnum & 0x20000000) >> 29) ^
   	        (($randnum & 0x00000200) >> 9));
}

$data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 10 ". $rand_data;
$data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 10 ". $rand_data;
$data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 10 ". $rand_data;
$data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 10 ". $rand_data;


# expect a packet from port 1 and send it into port 2
nf_expected_packet(1, 60, $data_from_1);
nf_packet_in(2, 60, 12000, 0, $data_from_1);

# expect a packet from port 2 and send it into port 1
nf_expected_packet(2, 60, $data_from_2);
nf_packet_in(1, 60, 12000, 0, $data_from_2);

# expect a packet from port 3 and send it into port 4
nf_expected_packet(3, 60, $data_from_3);
nf_packet_in(4, 60, 12000, 0, $data_from_3);

# expect a packet from port 4 and send it into port 3
nf_expected_packet(4, 60, $data_from_4);
nf_packet_in(3, 60, 12000, 0, $data_from_4);




########### Repeat -- Iteration 2 --  ################

for (my $i = 2; $i <= 107 ; $i++) {

   ### test 5 ###

   $randnum = $i;
   $rand_data = sprintf(" %02x %02x %02x %02x",
   	   		($randnum >> 24) & 0xff,
   			($randnum >> 16) & 0xff,
   			($randnum >> 8) & 0xff,
   			($randnum >> 0) & 0xff);
   for (my $i = 1; $i < 44 / 4; $i++) {
      $rand_data .= sprintf(" %02x %02x %02x %02x",
   	   		($randnum >> 24) & 0xff,
   			($randnum >> 16) & 0xff,
   			($randnum >> 8) & 0xff,
   			($randnum >> 0) & 0xff);
      $randnum = ($randnum << 1) |
      	       ((($randnum & 0x80000000) >> 31) ^
      	        (($randnum & 0x40000000) >> 30) ^
      	        (($randnum & 0x20000000) >> 29) ^
      	        (($randnum & 0x00000200) >> 9));
   }

   $data_from_1 = "00 ca fe 00 01 01 00 ca fe 00 00 01 f0 3c 00 10 ". $rand_data;
   $data_from_2 = "00 ca fe 00 01 02 00 ca fe 00 00 02 f0 3c 00 10 ". $rand_data;
   $data_from_3 = "00 ca fe 00 01 03 00 ca fe 00 00 03 f0 3c 00 10 ". $rand_data;
   $data_from_4 = "00 ca fe 00 01 04 00 ca fe 00 00 04 f0 3c 00 10 ". $rand_data;


   # expect a packet from port 1 and send it into port 2
   nf_expected_packet(1, 60, $data_from_1);
   nf_packet_in(2, 60, 0, 0, $data_from_1);

   # expect a packet from port 2 and send it into port 1
   nf_expected_packet(2, 60, $data_from_2);
   nf_packet_in(1, 60, 0, 0, $data_from_2);

   # expect a packet from port 3 and send it into port 4
   nf_expected_packet(3, 60, $data_from_3);
   nf_packet_in(4, 60, 0, 0, $data_from_3);

   # expect a packet from port 4 and send it into port 3
   nf_expected_packet(4, 60, $data_from_4);
   nf_packet_in(3, 60, 0, 0, $data_from_4);
}



### All tests have ended, read the registers to ensure that nothing failed
nf_PCI_read32( 40000, $batch, PHY_TEST_STATUS_REG(), 0x00000110 );

for (my $i = 0; $i < 4; $i++) {
   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_TX_STATUS_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x00010001 );
   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_TX_ITER_CNT_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x0000006b );
   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_TX_PKT_CNT_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x0000006b );

   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_RX_STATUS_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), (0x00001111 | ((($i ^ 1) + 1) << 16)) );
   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_RX_GOOD_PKT_CNT_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x0000006b);
   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_RX_ERR_PKT_CNT_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x00000000);

   nf_PCI_read32( 0, $batch, PHY_TEST_PHY_0_RX_LOG_STATUS_REG() + $i * PHY_TEST_PHY_GROUP_INST_OFFSET(), 0x00000000);
}



# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


