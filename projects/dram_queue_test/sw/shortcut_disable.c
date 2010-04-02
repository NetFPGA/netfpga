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
#include <string.h>

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

	if(argc != 2){
		closeDescriptor(&nf2);
		return 0;
	}
	if(strcmp(argv[1], "1") == 0) val = 1;
	else val = 0;


	writeReg(&nf2, DRAM_QUEUE_SHORTCUT_DISABLE_REG, val);
	readReg(&nf2, DRAM_QUEUE_SHORTCUT_DISABLE_REG, &val);
	printf("DRAM queue shortcut disabled:\t%u\n", val);

	closeDescriptor(&nf2);

	return 0;
}
