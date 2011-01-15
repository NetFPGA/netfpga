/* ****************************************************************************
 * $Id: regread.c 2267 2007-09-18 00:09:14Z grg $
 *
 * Module: regread.c
 * Project: NetFPGA 2 Register Access
 * Description: Reads a register
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <net/if.h>

#include "../common/nf2.h"
#include "../common/nf2util.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
void readRegisters (int , char **);
void processArgs (int , char **);
void usage (void);

int main(int argc, char *argv[])
{
	unsigned val;

	nf2.device_name = DEFAULT_IFACE;

	processArgs(argc, argv);

	// Open the interface if possible
	if (check_iface(&nf2))
	{
		exit(1);
	}
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

	// Increment the argument pointer
	argc -= optind;
	argv += optind;

	// Read the registers
	readRegisters(argc, argv);

	closeDescriptor(&nf2);

	return 0;
}

/*
 * Read the register(s)
 */
void readRegisters(int argc, char** argv)
{
	int i;
	unsigned addr;
	unsigned value;

	// Verify that we actually have some registers to display
	if (argc == 0) {
		usage();
		exit(1);
	}

	// Process the registers one by one
	for (i = 0; i < argc; i++)
	{
		// Work out if we're dealing with decimal or hexadecimal
		if (strncmp(argv[i], "0x", 2) == 0 || strncmp(argv[i], "0X", 2) == 0)
		{
			sscanf(argv[i] + 2, "%x", &addr);
		}
		else
		{
			sscanf(argv[i], "%u", &addr);
		}

		// Perform the actual register read
		readReg(&nf2, addr, &value);

		printf("Reg 0x%08x (%u):   0x%08x (%u)\n", addr, addr, value, value);
	}
}

/*
 *  Process the arguments.
 */
void processArgs (int argc, char **argv )
{
	char c;

	/* don't want getopt to moan - I can do that just fine thanks! */
	opterr = 0;

	while ((c = getopt (argc, argv, "i:a:p:h")) != -1)
	{
		switch (c)
	 	{
	 		case 'i':	/* interface name */
		 		nf2.device_name = optarg;
		 		break;
	 		case '?':
		 		if (isprint (optopt))
		         		fprintf (stderr, "Unknown option `-%c'.\n", optopt);
		 		else
		         		fprintf (stderr,
		                  		"Unknown option character `\\x%x'.\n",
		                  		optopt);
			case 'p':
				nf2.server_port_num = strtol(optarg, NULL, 0);
				break;
			case 'a':
				strncpy(nf2.server_ip_addr, optarg, strlen(optarg));
				break;
			case 'h':
	 		default:
		 		usage();
		 		exit(1);
	 	}
	}

	/* optind starts at first non-option argument (register address) */

	if (argv[optind] == NULL) {
		usage(); exit(1);
	}
}

/*
 *  Describe usage of this program.
 */
void usage (void)
{
	printf("Usage: ./regread <options> [addr...] \n\n");
	printf("Options: -i <iface> : interface name (default nf2c0)\n");
	printf("         -a <IP-Addr> : IP Address of socket listen.\n");
	printf("         -p <Port-num> : Port Number of socket listen.\n");
	printf("         -h : Print this message and exit.\n");
	printf("         [addr...] is a list of one or more addresses to read\n");
}
