/***************************************************************
* Author: Jad Naous
* Filename: client_test.c
* Description:
* Makes a few requests to the NetFPGA via the register proxy
****************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>

#include "../common/reg_defines.h"
#include "../common/nf2util.h"
#include "../common/nf2.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
static inline void print (unsigned);
void printMAC (unsigned, unsigned);
void printIP (unsigned);

int main(int argc, char *argv[])
{
	unsigned val;

	nf2.device_name = DEFAULT_IFACE;

	printf("Checking iface.\n");

	if (check_iface(&nf2))
	{
		exit(1);
	}

	printf("Opening descriptor.\n");
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

	printf("Printing.\n");

	for(val=0; val<1000000; val++){
		print(val);
	}

	printf("Closing descriptor.\n");
	closeDescriptor(&nf2);

	printf("Done.\n");
	return 0;
}

static inline void print(unsigned val_in) {
	unsigned val, val2;
	int i;

	readReg(&nf2, CPCI_REG_ID, &val);
	printf("CPCI_REG_ID: %08x\n", val);

	writeReg(&nf2, CPCI_REG_DUMMY, val_in);
	readReg(&nf2, CPCI_REG_DUMMY, &val);
	printf("CPCI_REG_DUMMY: %08x\n", val);
	if(val != val_in) {
		fprintf(stderr, "Error: Failed to read back. Expected %08x found %08x\n", val_in, val);
	}
}
