/* ****************************************************************************
 * $Id: regdump.c 5457 2009-05-05 20:13:22Z g9coving $
 *
 * Module: regdump.c
 * Project: NetFPGA 2.1 reference
 e Description: Test program to dump the switch registers
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>

#include "../lib/C/reg_defines_reference_switch.h"
#include "../../../lib/C/common/nf2util.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
void print (void);

int main(int argc, char *argv[])
{
	unsigned val;

	nf2.device_name = DEFAULT_IFACE;

	if (check_iface(&nf2))
	{
		exit(1);
	}
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

	print();

	closeDescriptor(&nf2);

	return 0;
}

void print(void) {
	unsigned val, i;

	//	readReg(&nf2, UNET_ID, &val);
	//	printf("Board ID: Version %i, Device %i\n", GET_VERSION(val), GET_DEVICE(val));
	readReg(&nf2, MAC_GRP_0_CONTROL_REG, &val);
	printf("MAC 0 Control: 0x%08x ", val);
	if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
	  printf("reset on,    ");
	}
	else {
	  printf("reset off,   ");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts stored in rx queue 0:      %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 0 full): %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 0):     %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 0:             %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts sent tx queue 0:           %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 0: %u\n\n", val);

	readReg(&nf2, MAC_GRP_1_CONTROL_REG, &val);
	printf("MAC 1 Control: 0x%08x ", val);
	if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
	  printf("reset on,    ");
	}
	else {
	  printf("reset off,   ");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts stored in rx queue 1:      %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 1 full): %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 1):     %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 1:             %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts sent tx queue 1:           %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 1: %u\n\n", val);

	readReg(&nf2, MAC_GRP_2_CONTROL_REG, &val);
	printf("MAC 2 Control: 0x%08x ", val);
	if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
	  printf("reset on,    ");
	}
	else {
	  printf("reset off,   ");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts stored in rx queue 2:      %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 2 full): %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 2):     %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 2:             %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts sent tx queue 2:           %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 2: %u\n\n", val);

	readReg(&nf2, MAC_GRP_3_CONTROL_REG, &val);
	printf("MAC 3 Control: 0x%08x ", val);
	if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("TX disabled, ");
	}
	else {
	  printf("TX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
	  printf("RX disabled, ");
	}
	else {
	  printf("RX enabled,  ");
	}
	if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
	  printf("reset on,    ");
	}
	else {
	  printf("reset off,   ");
	}
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

	printf("Num pkts stored in rx queue 3:      %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 3 full): %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 3):     %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 3:             %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts sent tx queue 3:           %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 3: %u\n\n", val);

	readReg(&nf2, SWITCH_OP_LUT_NUM_HITS_REG, &val);
	printf("MAC lut num hits:                   %u\n", val);
	readReg(&nf2, SWITCH_OP_LUT_NUM_MISSES_REG, &val);
	printf("MAC lut num misses:                 %u\n\n", val);
	for(i=0; i<16; i=i+1){
	  writeReg(&nf2, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG, i);
	  readReg(&nf2, SWITCH_OP_LUT_PORTS_MAC_HI_REG, &val);
	  printf("   CAM table entry %02u: wr_protect: %u, ports: 0x%04x, mac: 0x%04x", i, val>>31, (val&0x7fff0000)>>16, (val&0xffff));
	  readReg(&nf2, SWITCH_OP_LUT_MAC_LO_REG, &val);
	  printf("%08x\n", val);
	}

	readReg(&nf2, IN_ARB_NUM_PKTS_SENT_REG, &val);
	printf("IN_ARB_NUM_PKTS_SENT_REG                  %u\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_LO_REG             %08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_HI_REG             %08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_0_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_0_REG                %02x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_LO_REG             %08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_HI_REG             %08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_1_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_1_REG                %02x\n", val);
	readReg(&nf2, IN_ARB_STATE_REG, &val);
	printf("IN_ARB_STATE_REG                          %u\n\n", val);

	readReg(&nf2, OQ_QUEUE_0_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_0_NUM_WORDS_LEFT_REG                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG            %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED_REG       %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_STORED_REG                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_DROPPED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG           %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED_REG      %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_REMOVED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_0_ADDR_LO_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_0_ADDR_HI_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_0_WR_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_0_RD_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_0_MAX_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_CTRL_REG, &val);
	printf("OQ_QUEUE_0_CTRL_REG                         %x\n\n", val);

	readReg(&nf2, OQ_QUEUE_1_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_1_NUM_WORDS_LEFT_REG                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKT_BYTES_STORED_REG            %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_OVERHEAD_BYTES_STORED_REG       %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_STORED_REG                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_DROPPED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKT_BYTES_REMOVED_REG           %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_OVERHEAD_BYTES_REMOVED_REG      %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_REMOVED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_1_ADDR_LO_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_1_ADDR_HI_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_1_WR_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_1_RD_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_1_MAX_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_CTRL_REG, &val);
	printf("OQ_QUEUE_1_CTRL_REG                         %x\n\n", val);

	readReg(&nf2, OQ_QUEUE_2_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_2_NUM_WORDS_LEFT_REG                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKT_BYTES_STORED_REG            %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED_REG       %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_STORED_REG                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_DROPPED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED_REG           %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED_REG      %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_REMOVED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_2_ADDR_LO_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_2_ADDR_HI_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_2_WR_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_2_RD_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_2_MAX_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_CTRL_REG, &val);
	printf("OQ_QUEUE_2_CTRL_REG                         %x\n\n", val);

	readReg(&nf2, OQ_QUEUE_3_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_3_NUM_WORDS_LEFT_REG                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKT_BYTES_STORED_REG            %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_OVERHEAD_BYTES_STORED_REG       %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_STORED_REG                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_DROPPED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKT_BYTES_REMOVED_REG           %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_OVERHEAD_BYTES_REMOVED_REG      %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_REMOVED_REG                %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_3_ADDR_LO_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_3_ADDR_HI_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_3_WR_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_3_RD_ADDR_REG                      %08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_3_MAX_PKTS_IN_Q_REG                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_CTRL_REG, &val);
	printf("OQ_QUEUE_3_CTRL_REG                         %x\n\n", val);
}
