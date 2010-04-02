/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: nf_info.c 6054 2010-04-01 16:33:06Z grg $
 *
 * Module: regdump.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Test program to dump the CPCI registers
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
