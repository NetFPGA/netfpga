/* ****************************************************************************
 * $Id$
 *
 * Module: unetwbs_ctrl.c
 * Project: NetFPGA 2.1 Event capture system control
 * Description: modifies registers of event capture system
 *              to control its behavior
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

#include "../../../lib/C/common/nf2util.h"
#include "../../../lib/C/common/nf2.h"
#include "evts.h"

#define PATHLEN         80

#define DEFAULT_IFACE   "nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;

static unsigned dst_mac_lo32=0xccddeeff;
static unsigned dst_mac_hi16=0xaabb;
static unsigned src_mac_lo32=0x33445566;
static unsigned src_mac_hi16=0x1122;
static unsigned enable_evts=0;
static unsigned send_now = 0;
static unsigned ethertype = CAP_ETHERTYPE;
static unsigned ip_dst = 0x004488cc;
static unsigned ip_src = 0x2266aaee;
static unsigned ip_ttl = 64;
static unsigned ip_proto = 17;
static unsigned ip_chksum = 0;
static unsigned udp_src_port = 9955;
static unsigned udp_dst_port = 9988;
static unsigned output_ports = 0x40;
static unsigned reset_timers = 0;
static unsigned monitor_mask = 0xf;
static unsigned timer_res = 0;
static unsigned oq_mask = 0xffbf;
static unsigned load_default = 0;

static int print_stat=0;

/* Function declarations */
void usage (void);
u_int getMACLow32(const char * s);
u_int getMACHigh16(const char * s);
void processArgs (int , char **);
void printMACsp(unsigned MAC_hi, unsigned MAC_lo);
void display_ctrl(unsigned ctrl_reg);


void printMACsp(unsigned MAC_hi, unsigned MAC_lo) {
  printf("%02x:%02x:%02x:%02x:%02x:%02x\n",
         (MAC_hi >> 8)&0xff,
         (MAC_hi)&0xff,
         (MAC_lo >> 24)&0xff,
         (MAC_lo >> 16)&0xff,
         (MAC_lo >> 8)&0xff,
         (MAC_lo)&0xff
         );
}

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

  processArgs(argc, argv);

  if(load_default) {
    printf("Loading default values...\n");
    writeReg(&nf2, EVT_CAP_DST_MAC_HI_REG, dst_mac_hi16);
    writeReg(&nf2, EVT_CAP_DST_MAC_LO_REG, dst_mac_lo32);
    writeReg(&nf2, EVT_CAP_SRC_MAC_HI_REG, src_mac_hi16);
    writeReg(&nf2, EVT_CAP_SRC_MAC_LO_REG, src_mac_lo32);
    writeReg(&nf2, EVT_CAP_ETHERTYPE_REG, ethertype);
    writeReg(&nf2, EVT_CAP_IP_DST_REG, ip_dst);
    writeReg(&nf2, EVT_CAP_IP_SRC_REG, ip_src);
    // writeReg(&nf2, EVT_CAP_IP_TTL_REG, ip_ttl);
    // writeReg(&nf2, EVT_CAP_IP_PROTO_REG, ip_proto);
    // writeReg(&nf2, EVT_CAP_IP_CHKSUM_REG, ip_chksum);
    writeReg(&nf2, EVT_CAP_UDP_SRC_PORT_REG, udp_src_port);
    writeReg(&nf2, EVT_CAP_UDP_DST_PORT_REG, udp_dst_port);
    writeReg(&nf2, EVT_CAP_OUTPUT_PORTS_REG, output_ports);
    writeReg(&nf2, EVT_CAP_MONITOR_MASK_REG, monitor_mask);
    writeReg(&nf2, EVT_CAP_TIMER_RESOLUTION_REG, timer_res);
    writeReg(&nf2, EVT_CAP_SIGNAL_ID_MASK_REG, oq_mask);
    writeReg(&nf2, EVT_CAP_ENABLE_CAPTURE_REG, 1);
  }

  if(print_stat){

    readReg(&nf2, EVT_CAP_ENABLE_CAPTURE_REG, &val);
    printf("EVT_CAP_ENABLE_CAPTURE_REG      0x%08x\n", val);

    readReg(&nf2, EVT_CAP_SEND_PKT_REG, &val);
    printf("EVT_CAP_SEND_PKT_REG            0x%08x\n", val);

    readReg(&nf2, EVT_CAP_DST_MAC_HI_REG, &val);
    printf("EVT_CAP_DST_MAC_HI_REG          0x%08x\n", val);

    readReg(&nf2, EVT_CAP_DST_MAC_LO_REG, &val);
    printf("EVT_CAP_DST_MAC_LO_REG          0x%08x\n", val);

    readReg(&nf2, EVT_CAP_SRC_MAC_HI_REG, &val);
    printf("EVT_CAP_SRC_MAC_HI_REG          0x%08x\n", val);

    readReg(&nf2, EVT_CAP_SRC_MAC_LO_REG, &val);
    printf("EVT_CAP_SRC_MAC_LO_REG          0x%08x\n", val);

    readReg(&nf2, EVT_CAP_ETHERTYPE_REG, &val);
    printf("EVT_CAP_ETHERTYPE_REG           0x%08x\n", val);

    readReg(&nf2, EVT_CAP_IP_DST_REG, &val);
    printf("EVT_CAP_IP_DST_REG              0x%08x\n", val);

    readReg(&nf2, EVT_CAP_IP_SRC_REG, &val);
    printf("EVT_CAP_IP_SRC_REG              0x%08x\n", val);

    // readReg(&nf2, EVT_CAP_IP_TTL_REG, &val);
    // printf("EVT_CAP_IP_TTL_REG              0x%08x\n", val);

    // readReg(&nf2, EVT_CAP_IP_PROTO_REG, &val);
    // printf("EVT_CAP_IP_PROTO_REG            0x%08x\n", val);

    // readReg(&nf2, EVT_CAP_IP_CHKSUM_REG, &val);
    // printf("EVT_CAP_IP_CHKSUM_REG           0x%08x\n", val);

    readReg(&nf2, EVT_CAP_UDP_SRC_PORT_REG, &val);
    printf("EVT_CAP_UDP_SRC_PORT_REG        0x%08x\n", val);

    readReg(&nf2, EVT_CAP_UDP_DST_PORT_REG, &val);
    printf("EVT_CAP_UDP_DST_PORT_REG        0x%08x\n", val);

    readReg(&nf2, EVT_CAP_OUTPUT_PORTS_REG, &val);
    printf("EVT_CAP_OUTPUT_PORTS_REG        0x%08x\n", val);

    readReg(&nf2, EVT_CAP_RESET_TIMERS_REG, &val);
    printf("EVT_CAP_RESET_TIMERS_REG        0x%08x\n", val);

    readReg(&nf2, EVT_CAP_MONITOR_MASK_REG, &val);
    printf("EVT_CAP_MONITOR_MASK_REG        0x%08x\n", val);

    readReg(&nf2, EVT_CAP_TIMER_RESOLUTION_REG, &val);
    printf("EVT_CAP_TIMER_RESOLUTION_REG    0x%08x\n", val);

    readReg(&nf2, EVT_CAP_SIGNAL_ID_MASK_REG, &val);
    printf("EVT_CAP_SIGNAL_ID_MASK_REG      0x%08x\n", val);

    readReg(&nf2, EVT_CAP_NUM_EVT_PKTS_SENT_REG, &val);
    printf("Number of evt pkts sent   : %u,\n", val);

    readReg(&nf2, EVT_CAP_NUM_EVTS_SENT_REG, &val);
    printf("Number of evts sent       : %u,\n", val);

    readReg(&nf2, EVT_CAP_NUM_EVTS_DROPPED_REG, &val);
    printf("Number of evts dropped    : %u\n", val);
  }

  return 0;
}

/*
 * Extract low 32 bits from a MAC address of 12 hex digits
 */
u_int getMACLow32(const char * s) {

  u_int num;

  if (strlen(s) != 12) {
    fprintf(stderr,"MAC address \"%s\" must be 12 chars long.\n");
    exit(1);
  }

  if (sscanf(s+4,"%x", &num) != 1) {
    printf("Bad MAC address %s\n", s);
    exit(1);
  }

  return num;
}

/*
 * Extract high 16 bits from a MAC address of 12 hex digits
 */
u_int getMACHigh16(const char * s) {

  char hex_s[5] = "    ";

  u_int num;

  if (strlen(s) != 12) {
    fprintf(stderr,"MAC address \"%s\" must be 12 chars long.\n");
    exit(1);
  }

  strncpy(hex_s, s, 4);
  sscanf(hex_s,"%4x", &num);
  return num;
}

void processArgs (int argc, char **argv )
{
  char c;
  int temp;

  /* don't want getopt to moan - I can do that just fine thanks! */
  opterr = 0;

  while ((c = getopt (argc, argv, "pdnbBe:s:c:t:r:D:S:i:v")) != -1)
    {
      switch (c)
        {
        case 'p':   /* print status */
          print_stat=1;
          break;
        case 'e':   /* ethertype */
          if (sscanf(optarg,"0x%x",&temp) != 1) {
            printf("Bad value for ethertype - expected number of format 0xHHHH\n");
            exit(1);
          }
          printf("Setting Ethertype to 0x%04x...\n", temp);
          writeReg(&nf2, EVT_CAP_ETHERTYPE_REG, temp&0xffff);
          break;
        case 'n':   /* send now */
          printf("Sending captured events now...\n");
          writeReg(&nf2, EVT_CAP_SEND_PKT_REG, 1);
          writeReg(&nf2, EVT_CAP_SEND_PKT_REG, 0);
          break;
        case 'b':   /* enable */
          printf("Enabling event capture...\n");
          writeReg(&nf2, EVT_CAP_ENABLE_CAPTURE_REG, 1);
          break;
        case 'B':   /* disable */
          printf("Disabling event capture...\n");
          writeReg(&nf2, EVT_CAP_ENABLE_CAPTURE_REG, 0);
          break;
        case 'd':   /* load default and enable */
          load_default = 1;
          break;
        case 's':   /* output ports */
          if (sscanf(optarg,"0x%x",&temp) != 1) {
            printf("Bad value for output ports - expected number of format 0xHH\n");
            exit(1);
          }
          writeReg(&nf2, EVT_CAP_OUTPUT_PORTS_REG, temp);
          break;
        case 'c':   /* capture ports */
          if (sscanf(optarg,"0x%x",&temp) != 1) {
            printf("Bad value for capture ports - expected number of format 0xH\n");
            exit(1);
          }
          printf("Changing capture ports to 0x%04x\n", temp);
          writeReg(&nf2, EVT_CAP_SIGNAL_ID_MASK_REG, temp);
          break;
        case 'r':   /* reset timers */
          printf("Resetting timers...\n");
          writeReg(&nf2, EVT_CAP_RESET_TIMERS_REG, 1);
          writeReg(&nf2, EVT_CAP_RESET_TIMERS_REG, 0);
          break;
       /* case 't':   // timer resolution
          if (sscanf(optarg,"0x%x",&temp) != 1) {
            printf("Bad value for timer resolution - expected number of format 0xH\n");
            exit(1);
          }
          printf("Changing timer resolution to 0x%04x\n", temp);
          writeReg(&nf2, EVT_CAP_TIMER_RESOLUTION_REG, temp);
          break; */
        case 'D':   /* destination mac */
          dst_mac_lo32 =  getMACLow32 (optarg);
          dst_mac_hi16 =  getMACHigh16(optarg);
          printf("Setting destination MAC to %s\n", optarg);
          writeReg(&nf2, EVT_CAP_DST_MAC_HI_REG, dst_mac_hi16);
          writeReg(&nf2, EVT_CAP_DST_MAC_LO_REG, dst_mac_lo32);
          break;
        case 'S':   /* source mac */
          src_mac_lo32 =  getMACLow32 (optarg);
          src_mac_hi16 =  getMACHigh16(optarg);
          printf("Setting src MAC to %s\n", optarg);
          writeReg(&nf2, EVT_CAP_SRC_MAC_HI_REG, src_mac_hi16);
          writeReg(&nf2, EVT_CAP_SRC_MAC_LO_REG, src_mac_lo32);
          break;
        case 'v':   /* Verbose */
          verbose = 1;
          break;
        case 'i':   /* interface name */
          closeDescriptor(&nf2);
          nf2.device_name = optarg;
          if (check_iface(&nf2))
            {
              exit(1);
            }
          if (openDescriptor(&nf2))
            {
              exit(1);
            }
          break;
        case '?':
          if (isprint (optopt))
            fprintf (stderr, "Unknown option `-%c'.\n", optopt);
          else
            fprintf (stderr,
                     "Unknown option character `\\x%x'.\n",
                     optopt);
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
  printf("Usage: ./show_stats <options>\n");
  printf("\nOptions: \n");
  printf("         -i <iface> : interface name such nf2c0 (default nf2c0).\n");
  printf("         -v : be verbose.\n");
  printf("         -p : print current ctrl reg after any modifications\n");
  printf("         -e <ethertype> : set the ethertype (least significant\n");
  printf("                          2 bytes are used)\n");
  printf("         -n : send the current evt pkt now\n");
  printf("         -b : enable event capture\n");
  printf("         -B : disable event capture\n");
  printf("         -s <ports> : There are eight outputs available to send a packet to. These\n");
  printf("                      are the 4 MAC ports and the 4 CPU ports. The ports (0,2,4,6) are\n");
  printf("                      MAC ports (0,1,2,3) and ports (1,3,5,7) are CPU ports (0,1,2,3).\n");
  printf("                      <ports> is an 8 bit field indicating which outputs to send\n");
  printf("                      the evt pkts on. 1 is output port 0 (MAC 0) and 0xff is all 8 output\n");
  printf("                      ports\n");
  printf("         -c <ports> : an 8 bit field indicating which output queues to monitor\n");
  printf("                      for events. 1 is queue 0 (MAC 0) and 0xff is all 8 queues\n");
  printf("         -r : Reset the timers (doesn't stop event capture)\n");
 // printf("         -t <timer_res>: Specify timer resolution [0-7] 0 = 8ns. 7 = 2**7 * 8ns.\n");
  printf("         -S <MAC> : set src MAC address.  e.g. -S 001234567890\n");
  printf("         -D <MAC> : set dst MAC address.  e.g. -D 001234567890\n");
}
