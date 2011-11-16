/* vim:set shiftwidth=2 softtabstop=2 expandtab:
 *
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Glen Gibb <grg@stanford.edu>
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
 *
 * Module: regdump.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Test program to dump the CPCI registers
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include "../../common/nf2.h"
#include "../../common/nf2util.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;

/* Function declarations */
void processArgs (int , char **);
void usage (void);
void display_info(struct nf2device *nf2);

int main(int argc, char *argv[])
{
  unsigned val;

  nf2.device_name = DEFAULT_IFACE;


  processArgs(argc, argv);
  if (check_iface(&nf2))
  {
    exit(1);
  }
  if (openDescriptor(&nf2))
  {
    exit(1);
  }

  nf2_read_info(&nf2);
  display_info(&nf2);

  closeDescriptor(&nf2);

  return 0;
}


/*
 *  Display the version info
 */
void display_info(struct nf2device *nf2)
{
  printf(getDeviceInfoStr(nf2));
}



/*
 *  Process the arguments.
 */
void processArgs (int argc, char **argv )
{
  char c;

  /* don't want getopt to moan - I can do that just fine thanks! */
  opterr = 0;

  while ((c = getopt (argc, argv, "i:vh")) != -1)
  {
    switch (c)
    {
      case 'v':	/* Verbose */
        verbose = 1;
        break;
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
        // Let this fall through to the usage

      case 'h':
      default:
        usage();
        exit(1);
    }
  }
}


/*
 *  Describe usage of this program.
 */
void usage (void)
{
  printf("Usage: ./nf_info <options> \n\n");
  printf("Options: -i <iface> : interface name (default nf2c0)\n");
  printf("         -v : be verbose.\n");
  printf("         -h : Print this message and exit.\n");
}
