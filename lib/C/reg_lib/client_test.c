/*-
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Jad Naous <jnaous@stanford.edu>
 *
 * We are making the NetFPGA tools and associated documentation (Software)
 * available for public use and benefit with the expectation that others will
 * use, modify and enhance the Software and contribute those enhancements back
 * to the community. However, since we would like to make the Software
 * available for broadest use, with as few restrictions as possible permission
 * is hereby granted, free of charge, to any person obtaining a copy of this
 * Software) to deal in the Software under the copyrights without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any derivatives
 * without specific, written prior permission.
 */

/*
 * Filename: client_test.c
 * Description:
 * Makes a few requests to the NetFPGA via the register proxy
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

int main(int argc, char **argv)
{
	unsigned val;

	nf2.device_name = DEFAULT_IFACE;

	if (argc < 3) {
		printf("Usage: client_test <ip_addr> <port_num>\n");
		printf("   ip_addr is the address to connect to.\n");
		printf("   port_num is the port number to connect to.\n");
		exit(0);
	}

	nf2.server_port_num = strtol(argv[2], NULL, 0);

	if (nf2.server_port_num < 1024 || nf2.server_port_num > 65535) {
	   fprintf(stderr, "Error: port number has to be between 1024 and 65535. Saw %s.\n", argv[2]);
          exit(1);
	}

	strncpy(nf2.server_ip_addr, argv[1], strlen(argv[1]));

	printf("Checking iface\n");

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

	for(val=0; val<10; val++){
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
