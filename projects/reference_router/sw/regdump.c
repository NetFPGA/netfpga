/* ****************************************************************************
 * $Id: regdump.c 5456 2009-05-05 18:22:05Z g9coving $
 *
 * Module: regdump.c
 * Project: NetFPGA 2.1 reference
 * Description: Test program to dump the switch registers
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

#include "../lib/C/reg_defines_reference_router.h"
#include "../../../lib/C/common/nf2util.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
void print (void);
void printMAC (unsigned, unsigned);
void printIP (unsigned);

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
	unsigned val, val2;
	int i;

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
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 0:      %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 0 full): %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 0):     %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 0: %u\n\n", val);

	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 0:             %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 0:           %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 0: %u\n", val);
	readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_PKTS_ENQUEUED_REG, &val);
	printf("Num pkts enqueued to tx queue 0: %u\n\n", val);

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
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 1:      %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 1 full): %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 1):     %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 1: %u\n\n", val);

	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 1:             %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 1:           %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 1: %u\n", val);
	readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 1: %u\n", val);
        readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 1: %u\n\n", val);

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
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
	printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 2:      %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 2 full): %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 2):     %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 2: %u\n\n", val);

	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 2:             %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 2:           %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 2: %u\n", val);
	readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 2: %u\n", val);
        readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 2: %u\n\n", val);

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
	  printf("reset on\n");
	}
	else {
	  printf("reset off\n");
	}
        printf("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG, &val);
	printf("Num pkts enqueued to rx queue 3:      %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG, &val);
	printf("Num pkts dropped (rx queue 3 full): %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG, &val);
	printf("Num pkts dropped (bad fcs q 3):     %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of rx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DEQUEUED_REG, &val);
	printf("Num pkts dequeued from rx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in rx queue 3: %u\n\n", val);

	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG, &val);
	printf("Num pkts in tx queue 3:             %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG, &val);
	printf("Num pkts dequeued from tx queue 3:           %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_WORDS_PUSHED_REG, &val);
	printf("Num words pushed out of tx queue 3: %u\n", val);
	readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
	printf("Num bytes pushed out of tx queue 3: %u\n", val);
        readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_PKTS_ENQUEUED_REG, &val);
        printf("Num pkts enqueued to tx queue 3: %u\n\n", val);
/*
	readReg(&nf2, CPU_REG_Q_0_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_0_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_0_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_0_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_0_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_0_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_0_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_0_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_0_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_0_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_0_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_0_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_1_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_1_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_1_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_1_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_1_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_1_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_1_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_1_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_1_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_1_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_1_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_1_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_2_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_2_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_2_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_2_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_2_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_2_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_2_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_2_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_2_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_2_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_2_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_2_TX_NUM_BYTES_SENT_REG: %u\n\n", val);

	readReg(&nf2, CPU_REG_Q_3_WR_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_3_WR_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_3_WR_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_NUM_WORDS_LEFT_REG, &val);
	printf("CPU_REG_Q_3_WR_NUM_WORDS_LEFT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_WR_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_3_WR_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_DATA_WORD_REG, &val);
	printf("CPU_REG_Q_3_RD_DATA_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_CTRL_WORD_REG, &val);
	printf("CPU_REG_Q_3_RD_CTRL_WORD_REG: 0x%08x\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_NUM_WORDS_AVAIL_REG, &val);
	printf("CPU_REG_Q_3_RD_NUM_WORDS_AVAIL_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RD_NUM_PKTS_IN_Q_REG, &val);
	printf("CPU_REG_Q_3_RD_NUM_PKTS_IN_Q_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_PKTS_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_PKTS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_PKTS_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_PKTS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_WORDS_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_WORDS_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_WORDS_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_WORDS_SENT_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_RX_NUM_BYTES_RCVD_REG, &val);
	printf("CPU_REG_Q_3_RX_NUM_BYTES_RCVD_REG: %u\n", val);
	readReg(&nf2, CPU_REG_Q_3_TX_NUM_BYTES_SENT_REG, &val);
	printf("CPU_REG_Q_3_TX_NUM_BYTES_SENT_REG: %u\n\n", val);
*/
	for(i=0; i<ROUTER_OP_LUT_ARP_TABLE_DEPTH; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG, i);
	  printf("   ARP table entry %02u: mac: ", i);
	  readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, &val);
	  readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, &val2);
	  printMAC(val, val2);
	  printf(" ip: ");
	  readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, &val);
	  printIP(val);
	  printf("\n", val);
	}
	printf("\n");

	for(i=0; i<ROUTER_OP_LUT_ROUTE_TABLE_DEPTH; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG, i);
	  readReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, &val);
	  printf("   IP table entry %02u: ip: ", i);
	  printIP(val);
	  readReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, &val);
	  printf(" mask: 0x%08x", val);
	  readReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, &val);
	  printf(" next hop: ");
	  printIP(val);
	  readReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, &val);
	  printf(" output port: 0x%04x\n", val);
	}
	printf("\n");

	for(i=0; i<ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH; i=i+1){
	  writeReg(&nf2, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG, i);
	  readReg(&nf2, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG, &val);
	  printf("   Dst IP Filter table entry %02u: ", i);
	  printIP(val);
	  printf("\n");
	}
	printf("\n");

	readReg(&nf2, ROUTER_OP_LUT_ARP_NUM_MISSES_REG, &val);
	printf("ROUTER_OP_LUT_ARP_NUM_MISSES: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_LPM_NUM_MISSES_REG, &val);
	printf("ROUTER_OP_LUT_LPM_NUM_MISSES: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG, &val);
	printf("ROUTER_OP_LUT_NUM_CPU_PKTS_SENT: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_OPTS_VER: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_CHKSUMS: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_BAD_TTLS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_BAD_TTLS: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG, &val);
	printf("ROUTER_OP_LUT_NUM_NON_IP_RCVD: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG, &val);
	printf("ROUTER_OP_LUT_NUM_PKTS_FORWARDED: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_WRONG_DEST_REG, &val);
	printf("ROUTER_OP_LUT_NUM_WRONG_DEST: %u\n", val);
	readReg(&nf2, ROUTER_OP_LUT_NUM_FILTERED_PKTS_REG, &val);
	printf("ROUTER_OP_LUT_NUM_FILTERED_PKTS: %u\n", val);
	printf("\n");

	readReg(&nf2, ROUTER_OP_LUT_MAC_0_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_0: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_1: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_2: ");
	printMAC(val, val2);
	printf("\n");
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_HI_REG, &val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_LO_REG, &val2);
	printf("ROUTER_OP_LUT_MAC_3: ");
	printMAC(val, val2);
	printf("\n");

	/*
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_0_HI: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_0_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_0_LO: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_1_HI: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_1_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_1_LO: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_2_HI: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_2_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_2_LO: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_HI_REG, &val);
	printf("ROUTER_OP_LUT_MAC_3_HI: 0x%08x\n", val);
	readReg(&nf2, ROUTER_OP_LUT_MAC_3_LO_REG, &val);
	printf("ROUTER_OP_LUT_MAC_3_LO: 0x%08x\n\n", val);
	*/

	readReg(&nf2, IN_ARB_NUM_PKTS_SENT_REG, &val);
	printf("IN_ARB_NUM_PKTS_SENT                  %u\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_LO             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_0_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_0_HI             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_0_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_0                0x%02x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_LO_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_LO             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_WORD_1_HI_REG, &val);
	printf("IN_ARB_LAST_PKT_WORD_1_HI             0x%08x\n", val);
	readReg(&nf2, IN_ARB_LAST_PKT_CTRL_1_REG, &val);
	printf("IN_ARB_LAST_PKT_CTRL_1                0x%02x\n", val);
	readReg(&nf2, IN_ARB_STATE_REG, &val);
	printf("IN_ARB_STATE                          %u\n\n", val);

	readReg(&nf2, OQ_QUEUE_0_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_0_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_0_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_0_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_0_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_0_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_0_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_0_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_0_CTRL_REG, &val);
	printf("OQ_QUEUE_0_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_1_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_1_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_1_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_1_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_1_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_1_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_1_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_1_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_1_CTRL_REG, &val);
	printf("OQ_QUEUE_1_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_2_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_2_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_2_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_2_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_2_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_2_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_2_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_2_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_2_CTRL_REG, &val);
	printf("OQ_QUEUE_2_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_3_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_3_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_3_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_3_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_3_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_3_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_3_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_3_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_3_CTRL_REG, &val);
	printf("OQ_QUEUE_3_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_4_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_4_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_4_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_4_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_4_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_4_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_4_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_4_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_4_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_4_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_4_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_4_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_4_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_4_CTRL_REG, &val);
	printf("OQ_QUEUE_4_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_5_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_5_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_5_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_5_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_5_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_5_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_5_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_5_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_5_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_5_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_5_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_5_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_5_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_5_CTRL_REG, &val);
	printf("OQ_QUEUE_5_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_6_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_6_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_6_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_6_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_6_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_6_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_6_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_6_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_6_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_6_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_6_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_6_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_6_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_6_CTRL_REG, &val);
	printf("OQ_QUEUE_6_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_7_NUM_WORDS_LEFT_REG, &val);
	printf("OQ_QUEUE_7_NUM_WORDS_LEFT                   %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKT_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKT_BYTES_STORED             %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_OVERHEAD_BYTES_STORED_REG, &val);
	printf("OQ_QUEUE_7_NUM_OVERHEAD_BYTES_STORED        %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_STORED_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKTS_STORED                  %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_DROPPED_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKTS_DROPPED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKT_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKT_BYTES_REMOVED            %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_OVERHEAD_BYTES_REMOVED_REG, &val);
	printf("OQ_QUEUE_7_NUM_OVERHEAD_BYTES_REMOVED       %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_REMOVED_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKTS_REMOVED                 %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_ADDR_LO_REG, &val);
	printf("OQ_QUEUE_7_ADDR_LO                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_7_ADDR_HI_REG, &val);
	printf("OQ_QUEUE_7_ADDR_HI                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_7_WR_ADDR_REG, &val);
	printf("OQ_QUEUE_7_WR_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_7_RD_ADDR_REG, &val);
	printf("OQ_QUEUE_7_RD_ADDR                       0x%08x\n", val);
	readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_7_NUM_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_MAX_PKTS_IN_Q_REG, &val);
	printf("OQ_QUEUE_7_MAX_PKTS_IN_Q                    %u\n", val);
	readReg(&nf2, OQ_QUEUE_7_CTRL_REG, &val);
	printf("OQ_QUEUE_7_CTRL                          0x%08x\n\n", val);

	readReg(&nf2, OQ_QUEUE_0_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_0_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_1_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_1_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_2_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_2_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_3_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_3_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_4_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_4_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_5_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_5_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_6_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_6_FULL_THRESH                      %u\n",val);
	readReg(&nf2, OQ_QUEUE_7_FULL_THRESH_REG, &val);
	printf("OQ_QUEUE_7_FULL_THRESH                      %u\n\n",val);
/*
	readReg(&nf2, DELAY_ENABLE_REG, &val);
	printf("DELAY_ENABLE_REG                          0x%08x\n",val);
	readReg(&nf2, DELAY_1ST_WORD_HI_REG, &val);
	printf("DELAY_1ST_WORD_HI_REG                     0x%08x\n",val);
	readReg(&nf2, DELAY_1ST_WORD_LO_REG, &val);
	printf("DELAY_1ST_WORD_LO_REG                     0x%08x\n",val);
	readReg(&nf2, DELAY_LENGTH_REG, &val);
	printf("DELAY_LENGTH_REG                          0x%08x\n\n",val);

	readReg(&nf2, RATE_LIMIT_ENABLE_REG, &val);
	printf("RATE_LIMIT_ENABLE_REG                     0x%08x\n",val);
	readReg(&nf2, RATE_LIMIT_SHIFT_REG, &val);
	printf("RATE_LIMIT_SHIFT_REG                      0x%08x\n\n",val);
*/

}

//
// printMAC: print a MAC address as a : separated value. eg:
//    00:11:22:33:44:55
//
void printMAC(unsigned hi, unsigned lo)
{
	printf("%02x:%02x:%02x:%02x:%02x:%02x",
			((hi>>8)&0xff), ((hi>>0)&0xff),
			((lo>>24)&0xff), ((lo>>16)&0xff), ((lo>>8)&0xff), ((lo>>0)&0xff)
		);
}


//
// printIP: print an IP address in dotted notation. eg: 192.168.0.1
//
void printIP(unsigned ip)
{
	printf("%u.%u.%u.%u",
			((ip>>24)&0xff), ((ip>>16)&0xff), ((ip>>8)&0xff), ((ip>>0)&0xff)
		);
}
