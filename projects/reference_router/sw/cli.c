/* ****************************************************************************
 * $Id: cli.c 5456 2009-05-05 18:22:05Z g9coving $
 *
 * Module: cli.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Manage the NetFPGA router's ARP and IP tables.
 *
 * Change history:
 *
 *   Jan 23 2006: greg: lisip was not correctly displaying the port.
 *   Apr 7, 2007: jad modified for NF2.1 reference design
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>
#include <inttypes.h>

#include "../lib/C/reg_defines_reference_router.h"
#include "../../../lib/C/common/nf2util.h"
#include "../../../lib/C/common/util.h"

#define PATHLEN         80

#define DEFAULT_IFACE   "nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

static unsigned MAC_HI_REGS[] = {
  ROUTER_OP_LUT_MAC_0_HI_REG,
  ROUTER_OP_LUT_MAC_1_HI_REG,
  ROUTER_OP_LUT_MAC_2_HI_REG,
  ROUTER_OP_LUT_MAC_3_HI_REG
};

static unsigned MAC_LO_REGS[] = {
  ROUTER_OP_LUT_MAC_0_LO_REG,
  ROUTER_OP_LUT_MAC_1_LO_REG,
  ROUTER_OP_LUT_MAC_2_LO_REG,
  ROUTER_OP_LUT_MAC_3_LO_REG
};

/* Function declarations */
void prompt (void);
void help (void);
int  parse (char *);
void board (void);
void setip (void);
void setarp (void);
void setmac (void);
void setpkts(void);
void listip (void);
void listarp (void);
void listmac (void);
void loadip (void);
void loadarp (void);
void loadmac (void);
void clearip (void);
void cleararp (void);
void showq(void);
void setq(void);

void processArgs (int , char **);
void usage();

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

  prompt();

  closeDescriptor(&nf2);

  return 0;
}

/*
 *  Process the arguments.
 */
void processArgs (int argc, char **argv )
{
	char c;

	/* don't want getopt to moan - I can do that just fine thanks! */
	opterr = 0;

	while ((c = getopt (argc, argv, "i:h")) != -1)
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
	printf("Usage: ./cli <options> \n\n");
	printf("Options: -i <iface> : interface name (default nf2c0)\n");
	printf("         -h : Print this message and exit.\n");
}

void prompt(void) {
  while (1) {
    printf("> ");
    char c[10], d[10], e[10], f[10];
    scanf("%s", c);
    int res = parse(c);
    switch (res) {
    case 0:
      listip();
      break;
    case 1:
      listarp();
      break;
    case 2:
      setip();
      break;
    case 3:
      setarp();
      break;
    case 4:
      loadip();
      break;
    case 5:
      loadarp();
      break;
    case 6:
      clearip();
      break;
    case 7:
      cleararp();
      break;
    case 10:
      setq();
      break;
    case 11:
      setpkts();
      break;
    case 12:
      listmac();
      break;
    case 13:
      setmac();
      break;
    case 14:
      loadmac();
      break;
    case 8:
      help();
      break;
    case 9:
      return;
    default:
      printf("Unknown command, type 'help' for list of commands\n");
    }
  }
}

void help(void) {
  printf("Commands:\n");
  printf("  listip        - Lists entries in IP routing table\n");
  printf("  listarp       - Lists entries in the ARP table\n");
  printf("  listmac       - Lists the MAC addresses of the router ports\n");
  printf("  setip         - Set an entry in the IP routing table\n");
  printf("  setarp        - Set an entry in the ARP table\n");
  printf("  setmac        - Set the MAC address of a router port\n");
  printf("  loadip        - Load IP routing table entries from a file\n");
  printf("  loadarp       - Load ARP table entries from a file\n");
  printf("  loadmac       - Load MAC addresses of router ports from a file\n");
  printf("  clearip       - Clear an IP routing table entry\n");
  printf("  cleararp      - Clear an ARP table entry\n");
  printf("  setq          - Set Queue limits\n");
  printf("  setpkts       - Set Packet limits (max packets per queue)\n");
  printf("  help          - Displays this list\n");
  printf("  quit          - Exit this program\n");
}


void addmac(int port, uint8_t *mac) {
  // adjust port 1-4 to be an array index 0-3
  port--;

  writeReg(&nf2, MAC_HI_REGS[port], mac[0] << 8 | mac[1]);
  writeReg(&nf2, MAC_LO_REGS[port], mac[2] << 24 | mac[3] << 16 | mac[4] << 8 | mac[5]);
}

void addarp(int entry, uint8_t *ip, uint8_t *mac) {
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, ip[0] << 24 | ip[1] << 16 | ip[2] << 8 | ip[3]);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, mac[0] << 8 | mac[1]);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, mac[2] << 24 | mac[3] << 16 | mac[4] << 8 | mac[5]);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG, entry);
}

void addip(int entry, uint8_t *subnet, uint8_t *mask, uint8_t *nexthop, int port) {
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, subnet[0] << 24 | subnet[1] << 16 | subnet[2] << 8 | subnet[3]);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, mask[0] << 24 | mask[1] << 16 | mask[2] << 8 | mask[3]);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, nexthop[0] << 24 | nexthop[1] << 16 | nexthop[2] << 8 | nexthop[3]);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, port);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG, entry);
}

void setip(void) {
  printf("Enter [entry] [subnet]      [mask]       [nexthop] [port]:\n");
  printf("e.g.     0   192.168.1.0  255.255.255.0  15.1.3.1     4:\n");
  printf(">> ");

  char subnet[15], mask[15], nexthop[15];
  int port, entry;
  scanf("%i %s %s %s %x", &entry, subnet, mask, nexthop, &port);

  if ((entry < 0) || (entry > 15)) {
    printf("Entry must be between 0 and 15. Aborting\n");
    return;
  }

  if ((port < 1) || (port > 255)) {
    printf("Port must be between 1 and ff.  Aborting\n");
    return;
  }

  uint8_t *sn = parseip(subnet);
  uint8_t *m = parseip(mask);
  uint8_t *nh = parseip(nexthop);

  addip(entry, sn, m, nh, port);
}

void setarp(void) {
  printf("Enter [entry] [ip] [mac]:\n");
  printf(">> ");

  char nexthop[15], mac[30];
  int entry;
  scanf("%i %s %s", &entry, nexthop, mac);

  if ((entry < 0) || (entry > 15)) {
    printf("Entry must be between 0 and 15. Aborting\n");
    return;
  }

  uint8_t *nh = parseip(nexthop);
  uint8_t *m = parsemac(mac);

  addarp(entry, nh, m);
}

void setmac(void) {
  printf("Enter [port] [mac]:\n");
  printf(">> ");

  char mac[30];
  int port;
  scanf("%i %s", &port, mac);

  if ((port < 1) || (port > 4)) {
    printf("Port must be between 1 and 4. Aborting\n");
    return;
  }

  uint8_t *m = parsemac(mac);

  addmac(port, m);
}

void listip(void) {
  int i;
  for (i = 0; i < 16; i++) {
    unsigned subnet, mask, nh, valport;

    writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG, i);

    readReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, &subnet);

    readReg(&nf2,ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG , &mask);

    readReg(&nf2,ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG , &nh);

    readReg(&nf2,ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG , &valport);

    printf("Entry #%i:   ", i);
    int port = valport & 0xff;
    if (subnet!=0 || mask!=0xffffffff || port!=0) {
      printf("Subnet: %i.%i.%i.%i, ", subnet >> 24, (subnet >> 16) & 0xff, (subnet >> 8) & 0xff, subnet & 0xff);
      printf("Mask: 0x%x, ", mask);
      printf("Next Hop: %i.%i.%i.%i, ", nh >> 24, (nh >> 16) & 0xff, (nh >> 8) & 0xff, nh & 0xff);
      printf("Port: 0x%02x\n", port);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void listarp(void) {
  int i = 0;
  for (i = 0; i < 16; i++) {
    unsigned ip, machi, maclo;

    writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG, i);

    readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, &ip);

    readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, &machi);

    readReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, &maclo);

    printf("Entry #%i:   ", i+1);
    if (ip!=0) {
      printf("IP: %i.%i.%i.%i, ", ip >> 24, (ip >> 16) & 0xff, (ip >> 8) & 0xff, ip & 0xff);
      printf("MAC: %x:%x:%x:%x:%x:%x\n", (machi >> 8) & 0xff, machi & 0xff,
              (maclo >> 24) & 0xff, (maclo >> 16) & 0xff,
              (maclo >> 8) & 0xff, (maclo) & 0xff);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void listmac(void) {
  int i = 0;
  for (i = 0; i < 4; i++) {
    unsigned ip, machi, maclo;
    readReg(&nf2, MAC_HI_REGS[i], &machi);
    readReg(&nf2, MAC_LO_REGS[i], &maclo);

    printf("Port #%i:   ", i+1);
    if (ip!=0) {
      printf("MAC: %x:%x:%x:%x:%x:%x\n", (machi >> 8) & 0xff, machi & 0xff,
              (maclo >> 24) & 0xff, (maclo >> 16) & 0xff,
              (maclo >> 8) & 0xff, (maclo) & 0xff);
    }
    else {
      printf("--Invalid--\n");
    }
  }
}

void loadip(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp;
  char subnet[20], mask[20], nexthop[20];
  int entry, port;
  if((fp = fopen(fn, "r")) ==NULL) {
    printf("Error: cannot open file %s.\n", fn);
    return;
  }
  while (fscanf(fp, "%i %s %s %s %x", &entry, subnet, mask, nexthop, &port) != EOF) {
    uint8_t *sn = parseip(subnet);
    uint8_t *m = parseip(mask);
    uint8_t *nh = parseip(nexthop);

    addip(entry, sn, m, nh, port);
  }
}

void loadarp(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp = fopen(fn, "r");
  char ip[20], mac[20];
  int entry;
  while (fscanf(fp, "%i %s %s", &entry, ip, mac) != EOF) {
    uint8_t *i = parseip(ip);
    uint8_t *m = parsemac(mac);

    addarp(entry, i, m);
  }
}

void loadmac(void) {
  char fn[30];
  printf("Enter filename:\n");
  printf(">> ");
  scanf("%s", fn);

  FILE *fp = fopen(fn, "r");
  char mac[20];
  int port;
  while (fscanf(fp, "%i %s", &port, mac) != EOF) {
    uint8_t *m = parsemac(mac);

    addmac(port, m);
  }
}

void clearip(void) {
  int entry;
  printf("Specify entry:\n");
  printf(">> ");
  scanf("%i", &entry);

  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, 0);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, 0xffffffff);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, 0);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, 0);
  writeReg(&nf2, ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG, entry);
}

void cleararp(void) {
  int entry;
  printf("Specify entry:\n");
  printf(">> ");
  scanf("%i", &entry);

  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG,0);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG,0);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG,0);
  writeReg(&nf2, ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG, entry);
}

void setq(void) {
  unsigned queue;
  char mins[30], maxs[30];
  unsigned min, max;

  printf("Enter [Queue] [Min (hex)] [Max (hex)]   (addr in range 0x0 to 0x1fffff)\n>> ");
  scanf("%d %s %s",&queue, mins, maxs);

  if ((queue < 0) || (queue > 7)) {
    printf("Queue must be between 0 and 7 -  Aborting\n");
    return;
  }

  min = strtol(mins,(char **) NULL,16);
  if ((min < 0) || (min > 0x1fffff)) {
    printf("Min must be between 0 and 0x1fffff -  Aborting\n");
    return;
  }

  max = strtol(maxs,(char **) NULL,16);
  if ((max < 0) || (max > 0x1fffff)) {
    printf("Max must be between 0 and 0x1fffff -  Aborting\n");
    return;
  }
  printf("Set Q %d to range 0x%x - 0x%x \n", queue, min, max);

  // We use word address (32 bit words), so drop bottom two bits of the byte address.

  min = min >> 2;
  max = max >> 2;

  switch(queue) {
  case 0:
    // force actual initialization of read and write pointers.
    writeReg(&nf2, OQ_QUEUE_0_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_0_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_0_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_0_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 1:
    writeReg(&nf2, OQ_QUEUE_1_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_1_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_1_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_1_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 2:
    writeReg(&nf2, OQ_QUEUE_2_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_2_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_2_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_2_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 3:
    writeReg(&nf2, OQ_QUEUE_3_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_3_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_3_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_3_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 4:
    writeReg(&nf2, OQ_QUEUE_4_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_4_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_4_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_4_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 5:
    writeReg(&nf2, OQ_QUEUE_5_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_5_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_5_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_5_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 6:
    writeReg(&nf2, OQ_QUEUE_6_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_6_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_6_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_6_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 7:
    writeReg(&nf2, OQ_QUEUE_7_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_7_ADDR_LO_REG, min);
    writeReg(&nf2, OQ_QUEUE_7_ADDR_HI_REG, max);
    writeReg(&nf2, OQ_QUEUE_7_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  default: printf("ERROR: Illegal queue number %d\n",queue);
    exit(1);
  }
}


/************************
 * Set the pkt limits for a queue
 ************************/
void setpkts(void) {
  unsigned queue, max;

  printf("Enter [Queue 1-4] [Max # Pkts (decimal 0-4000000000)]\n>> ");
  scanf("%d %d",&queue, &max);

  if ((queue < 0) || (queue > 7)) {
    printf("Queue must be between 0 and 7 -  Aborting\n");
    return;
  }

  if ((max < 0) || (max > 0xffffffff)) {
    printf("Max must be between 0 and 4000000000 -  Aborting\n");
    return;
  }
  printf("Will set max packets for Q %d to %d\n", queue, max);

  switch(queue) {
  case 0:
    // force actual initialization of read and write pointers.
    writeReg(&nf2, OQ_QUEUE_0_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_0_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_0_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 1:
    writeReg(&nf2, OQ_QUEUE_1_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_1_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_1_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 2:
    writeReg(&nf2, OQ_QUEUE_2_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_2_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_2_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 3:
    writeReg(&nf2, OQ_QUEUE_3_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_3_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_3_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 4:
    writeReg(&nf2, OQ_QUEUE_4_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_4_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_4_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 5:
    writeReg(&nf2, OQ_QUEUE_5_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_5_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_5_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 6:
    writeReg(&nf2, OQ_QUEUE_6_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_6_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_6_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  case 7:
    writeReg(&nf2, OQ_QUEUE_7_CTRL_REG, (1<<OQ_INITIALIZE_OQ_BIT_NUM) | (1<<OQ_ENABLE_SEND_BIT_NUM));
    writeReg(&nf2, OQ_QUEUE_7_MAX_PKTS_IN_Q_REG, max);
    writeReg(&nf2, OQ_QUEUE_7_CTRL_REG, (1<<OQ_ENABLE_SEND_BIT_NUM));
    break;
  default: printf("ERROR: Illegal queue number %d\n",queue);
    exit(1);
  }
}

int parse(char *word) {
  if (!strcmp(word, "listip"))
    return 0;
  if (!strcmp(word, "listarp"))
    return 1;
  if (!strcmp(word, "setip"))
    return 2;
  if (!strcmp(word, "setarp"))
    return 3;
  if (!strcmp(word, "loadip"))
    return 4;
  if (!strcmp(word, "loadarp"))
    return 5;
  if (!strcmp(word, "clearip"))
    return 6;
  if (!strcmp(word, "cleararp"))
    return 7;
  if (!strcmp(word, "setq"))
    return 10;
  if (!strcmp(word, "setpkts"))
    return 11;
  if (!strcmp(word, "listmac"))
    return 12;
  if (!strcmp(word, "setmac"))
    return 13;
  if (!strcmp(word, "loadmac"))
    return 14;
  if (!strcmp(word, "help"))
    return 8;
  if (!strcmp(word, "quit"))
    return 9;
  return -1;
}
