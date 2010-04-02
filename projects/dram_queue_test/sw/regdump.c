/* ****************************************************************************
 * $Id: regdump.c 4284 2008-07-11 23:00:51Z sbolouki $
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

/////////////////////////////
//NetFPGA related files
/////////////////////////////
//#include "reg_defines.h"
#include "../lib/C/reg_defines_dram_queue_test.h"
#include "nf2util.h"

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
	unsigned input_bytes,output_bytes,shortcut_bytes,dram_rd_bytes,dram_wr_bytes;

	nf2.device_name = DEFAULT_IFACE;

	if (check_iface(&nf2))
	{
		exit(1);
	}
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

	readReg(&nf2, DRAM_QUEUE_SHORTCUT_DISABLE_REG, &val);
	printf("DRAM queue shortcut disabled:\t%u\n", val);
	readReg(&nf2, DRAM_QUEUE_BLOCK_NUM_REG, &val);
	printf("DRAM queue size:\t\t%u\n", val==0 ? 32 : val);
	readReg(&nf2, DRAM_QUEUE_INPUT_WORDS_REG, &val);
	printf("DRAM queue input bytes:\t\t%u\n", val * 9);
	input_bytes = val * 9;
	readReg(&nf2, DRAM_QUEUE_OUTPUT_WORDS_REG, &val);
	printf("DRAM queue output bytes:\t%u\n", val * 9);
	output_bytes = val * 9;
	readReg(&nf2, DRAM_QUEUE_SHORTCUT_WORDS_REG, &val);
	printf("DRAM queue shortcut bytes:\t%u\n", val * 18);
	shortcut_bytes = val * 18;
	readReg(&nf2, DRAM_QUEUE_DRAM_WR_WORDS_REG, &val);
	printf("DRAM queue DRAM write bytes:\t%u\n", val * 18);
	dram_wr_bytes = val * 18;
	readReg(&nf2, DRAM_QUEUE_DRAM_RD_WORDS_REG, &val);
	printf("DRAM queue DRAM read bytes:\t%u\n", val * 18);
	dram_rd_bytes = val * 18;

	if(input_bytes == output_bytes)
		printf("GOOD! Input bytes equal to output bytes.\n");
	else
		printf("Ooops.. Input bytes not equal to output bytes.\n");

	if(input_bytes == dram_wr_bytes + shortcut_bytes)
		printf("GOOD! Input bytes equal to the sum of dram write bytes and shortcut bytes.\n");
	else
		printf("Ooops.. Input bytes not equal to the sum of dram write bytes and shortcut bytes.\n");

	if(output_bytes == dram_rd_bytes + shortcut_bytes)
		printf("GOOD! Output bytes equal to the sum of dram read bytes and shortcut bytes.\n");
	else
		printf("Ooops.. Input bytes not equal to the sum of dram read bytes and shortcut bytes.\n");

	closeDescriptor(&nf2);

	return 0;
}
