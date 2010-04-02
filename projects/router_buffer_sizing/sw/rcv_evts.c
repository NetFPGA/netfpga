/* ****************************************************************************
 * $Id $
 *
 * Module: rcv_evts.c
 * Project: UNET-SWITCH4-with_buffer_sizing
 * Description:
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <time.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>
#include <libnet.h>
#include <pcap.h>

#include "../../../lib/C/common/nf2.h"
#include "evts.h"
#include "../../../lib/C/common/nf2util.h"


#define PATHLEN         80

#define DEFAULT_IFACE   "nf2c0"

#define SNAPLEN 1518

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int very_verbose = 0;
static u_short cap_ethertype = CAP_ETHERTYPE;

/*  Libnet variables */
char libnet_errbuf[LIBNET_ERRBUF_SIZE];
libnet_t *lt;   // Main libnet data structure

/* Libpcap variables */
char pcap_errbuf[PCAP_ERRBUF_SIZE];
pcap_t *pcap_capture_descr; // for capturing received packets


/* Function declarations */
void processArgs (int , char **);
void usage (void);
void InitNetwork(char *);
void CloseNetwork(void);
void ReceivePackets(void);
void ReceiveSinglePacket(u_char *, const struct pcap_pkthdr*, const u_char* );
void processOfflinePkts ();

int store_events[8];
int drop_events[8];
int remove_events[8];
double running_time=0;
u_char offline=0;

int main(int argc, char *argv[])
{
  unsigned val;
  int i;

  nf2.device_name = DEFAULT_IFACE;


  processArgs(argc, argv);

  for(i=0; i<8; i++){
    store_events[i]=0;
    drop_events[i]=0;
    remove_events[i]=0;
  }

  if(!offline){
    InitNetwork(nf2.device_name);
    ReceivePackets();
    CloseNetwork();
  } else {
    processOfflinePkts();
  }

  return 0;
}

void processOfflinePkts () {
  u_char rcv_finished = 0;
  char *ebuf;

  if(very_verbose) printf("starting offline process\n");

  fflush(NULL);

  pcap_t *p_descr=pcap_open_offline("teth_file", ebuf);
  if(p_descr==NULL){
    printf("couldn't open offline file for processing. Error: %s\n", ebuf);
    return;
  }
  if(very_verbose) printf("offline file opened\n");

  fflush(NULL);

  pcap_loop(p_descr, 0, ReceiveSinglePacket, &rcv_finished);

  if(very_verbose) printf("Looping over offline file\n");
  fflush(NULL);

  pcap_close(p_descr);
}

/*
  Keep calling the pcap_dispatch forever.
*/

void ReceivePackets ()
{
  u_char rcv_finished = 0;
  int rc=1;

  time_t initial_time=time(NULL);
  double diff_time=0;

  while (rc==1)
    {
      rc=pcap_dispatch(pcap_capture_descr, 0, ReceiveSinglePacket, &rcv_finished);
      diff_time=difftime(time(NULL), initial_time);
      if(very_verbose) printf("i've been running for %u \n", diff_time);
    }
}



/*
  ReceiveSinglePacket is the callback used to process
  a single incoming packet.
*/

void ReceiveSinglePacket(u_char *rcv_finished,
                         const struct pcap_pkthdr* pkthdr,
                         const u_char* packet) {

  unsigned int* payload = NULL;
  u_short ethertype;

  u_int len;
  u_int len_off_wire;
  char c;
  unsigned char *pkt_ptr=(unsigned char *)packet;

  long total_time=0;
  long time_diff;
  long time_LSB;
  long time_MSB;

  unsigned char oq;
  int evt_len;

  // fprintf(stderr,"\ncaplen %d  len %d\n", pkthdr->caplen, pkthdr->len );

  int i;
  //for (i=0;i<26;i++) { c = packet[i]; fprintf(stderr, "%02x ", (uint8_t) c); }
  //fprintf(stderr,"\n");

  /*
     Extract the ethertype and just return if the ethertype doesnt match the
     ethertype of packets we care about.
  */

  memcpy(&ethertype, (u_char *)(packet+12), sizeof(u_short)); // get ethertype
  ethertype = ntohs(ethertype);

  if (ethertype != cap_ethertype)
    {
      if (very_verbose) { fprintf(stderr,"Ethertype 0x%04x doesn't match desired ethertype 0x%04x\n",
                                  ethertype, cap_ethertype); }
      return;
    }

  len_off_wire =  pkthdr->len;
  if(very_verbose) { //print out the raw data
    for (i=0; i<len_off_wire; i+=4){
      printf("[%04u] %02x %02x %02x %02x\n", i, pkt_ptr[i], pkt_ptr[i+1], pkt_ptr[i+2], pkt_ptr[i+3]);
    }
  }
  payload = (unsigned int *) packet;

  // print the packet header
  printf("Dst Mac          : %08x%04x\n", ntohl(*payload++), (ntohl(*payload)&0xffff0000)>>16);
  printf("Src Mac          : %04x%08x\n", (ntohl(*payload++) & 0xffff), ntohl(*payload++));
  printf("Ethertype        : %04x\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("IP version       : %u\n", (ntohl(*payload) & 0x0000f000)>>12);
  printf("IP Hdr length    : %u\n", (ntohl(*payload) & 0x00000f00)>>8);
  printf("TOS              : %02x\n", (ntohl(*payload++) & 0x000000ff));
  printf("IP total length  : %u\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("IP id            : %04x\n", (ntohl(*payload++) & 0xffff));
  printf("IP flags & frags : %04x\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("IP TTL           : %u\n", (ntohl(*payload) & 0x0000ff00)>>8);
  printf("IP protocol      : %02x\n", (ntohl(*payload++) & 0xff));
  printf("IP checksum      : %04x\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("IP src addr      : %08x\n", (ntohl(*payload++) & 0xffff), (ntohl(*payload) & 0xffff0000)>>16);
  printf("IP dst addr      : %08x\n", (ntohl(*payload++) & 0xffff), (ntohl(*payload) & 0xffff0000)>>16);
  printf("UDP src port     : %u\n", (ntohl(*payload++) & 0xffff));
  printf("UDP dst port     : %u\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("UDP length       : %u\n", (ntohl(*payload++) & 0xffff));
  printf("UDP checksum     : %04x\n", (ntohl(*payload) & 0xffff0000)>>16);
  printf("Evt system ver   : %01x\n", (ntohl(*payload) & 0x0f00)>>8);
  printf("Num mon'ed evts  : %u\n", (ntohl(*payload++) & 0x00ff));
  printf("Packet seq num   : %u\n", ntohl(*payload++));
  printf("Queue 0 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 0 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 1 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 1 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 2 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 2 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 3 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 3 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 4 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 4 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 5 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 5 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 6 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 6 size (packet)    : %u\n", ntohl(*payload++));
  printf("Queue 7 size (word)      : %u\n", ntohl(*payload++));
  printf("Queue 7 size (packet)    : %u\n", ntohl(*payload++));

  printf("Real Packet len  : %u\n", len_off_wire);
  //len=len_off_wire-14-20-8-6-8*4; // remove header length
  len = len_off_wire-14*8;
  len=len/4;    // turn into 32-bit words

  for (i=0;i<len;i++){
    if(very_verbose){
      printf("Payload word: 0x%08x\n", ntohl(*payload));
      printf("Event type: 0x%08x\n", ntohl(*payload)&EVENT_TYPE_MASK);
    }
    switch(ntohl(*payload)&EVENT_TYPE_MASK){
    case TS_EVENT:

      total_time=0;
      time_MSB = ntohl(*payload++) & (~EVENT_TYPE_MASK);
      time_LSB = ntohl(*payload++) & (~TIME_MASK); payload = payload - 2;

      if (verbose) {
         printf("Timestamp Event  : 0x%08x", ntohl(*payload++)&(~EVENT_TYPE_MASK));
         printf("%08x\n", ntohl(*payload++));
        payload = payload - 2;
      }
      payload = payload + 2;
      i++;
      break;
    case ST_EVENT:
      oq = ((ntohl(*payload) & OQ_MASK)>>OQ_SHIFT);
      evt_len = (ntohl(*payload) & LENGTH_MASK) >> LEN_SHIFT;
      time_diff = ((ntohl(*payload++) & TIME_MASK));
      total_time += time_diff;
      if (verbose) {
         printf("Store  Event     : Q: %u, Pkt len: %u, Time: %08x", oq, evt_len, time_MSB);
         printf("%08x\n", time_diff + time_LSB);
      }
      store_events[oq]+=1;
      break;

    case RM_EVENT:
      oq = ((ntohl(*payload) & OQ_MASK)>>OQ_SHIFT);
      evt_len = (ntohl(*payload) & LENGTH_MASK) >> LEN_SHIFT;
      time_diff = ((ntohl(*payload++) & TIME_MASK));
      total_time += time_diff;
      if (verbose) {
        printf("Remove Event     : Q: %u, Pkt len: %u, Time: %08x", oq, evt_len, time_MSB);
        printf("%08x\n", time_diff + time_LSB);
      }
      remove_events[oq]+=1;
      break;
    case DR_EVENT:
      oq = ((ntohl(*payload) & OQ_MASK)>>OQ_SHIFT);
      evt_len = (ntohl(*payload) & LENGTH_MASK) >> LEN_SHIFT;
      time_diff = ((ntohl(*payload++) & TIME_MASK));
      total_time += time_diff;
      if (verbose) {
        printf("Drop   Event     : Q: %u, Pkt len: %u, Time: %08x", oq, evt_len, time_MSB);
        printf("%08x\n", time_diff + time_LSB);
      }
      drop_events[oq]+=1;
      break;
    }
  }
  printf("Total store  events: oq0: %d, oq1: %d, oq2: %d, oq3: %d, oq4: %d, oq5: %d, oq6: %d, oq7: %d\n",store_events[0], store_events[1], store_events[2], store_events[3], store_events[4], store_events[5], store_events[6], store_events[7]);
  printf("Total drop   events: oq0: %d, oq1: %d, oq2: %d, oq3: %d, oq4: %d, oq5: %d, oq6: %d, oq7: %d\n",drop_events[0], drop_events[1], drop_events[2], drop_events[3], drop_events[4], drop_events[5], drop_events[6], drop_events[7]);
  printf("Total remove events: oq0: %d, oq1: %d, oq2: %d, oq3: %d, oq4: %d, oq5: %d, oq6: %d, oq7: %d\n",remove_events[0], remove_events[1], remove_events[2], remove_events[3], remove_events[4], remove_events[5], remove_events[6], remove_events[7]);
  fflush(NULL);
}

/*
 *  Process the arguments.
 */
void processArgs (int argc, char **argv )
{
  char c;

  /* don't want getopt to moan - I can do that just fine thanks! */
  opterr = 0;

  while ((c = getopt (argc, argv, "vVi:e:r:o")) != -1)
    {
      switch (c)
        {
        case 'v':       /* Verbose */
          verbose = 1;
          break;
        case 'V':       /* VERY Verbose */
          very_verbose = 1;
          break;
        case 'i':   /* interface name */
          nf2.device_name = optarg;
          break;
        case 'e':       /* Ethertype to use */
          if (sscanf(optarg,"0x%x",&cap_ethertype) != 1) {
            printf("Bad value for ethertype - expected number of format 0xHHHH\n");
            exit(1);
          }
          cap_ethertype &= 0xffff;
          printf("Info: Will look for ethertype: 0x%04x\n", cap_ethertype);
          break;
        case 'r':       /* number of seconds to run */
          if (sscanf(optarg,"%u",&running_time) != 1) {
            printf("Bad value for running time - expected a decimal number \n");
            exit(1);
          }
          printf("Running for %u seconds.\n",running_time);
          break;
        case 'o':
          offline = 1;
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
  printf("Usage: ./show_events <options>  filename.bin\n");
  printf("\nOptions: \n");
  printf("         -i <iface> : interface name such nf2c0 (default nf2c0).\n");
  printf("         -v : be verbose.\n");
  printf("         -V : be REALLY verbose.\n");
  printf("         -e <ethertype>: Specify ethertype of packets containing events.\n");
  printf("                         e.g. -e 0x5678.  Default: 0x%x\n", CAP_ETHERTYPE);
  printf("         -r <running time>: the number of seconds to run. Default: forever.\n");
  printf("         -o : process the offline data store din file \"teth_out\".\n");
}

/*
  Initialize the pcap and libnet interfaces
*/

void InitNetwork(char *device_name) {

  printf("Opening interface:%s\n", device_name);

  int snaplen;  // num bytes to actually vapture. More == slower...

  // NOTE: defaults to promiscuous mode
  //

  snaplen = SNAPLEN;
  // only change minimum snaplen if we have packet content checking turned on.

  pcap_capture_descr = pcap_open_live(device_name, snaplen, 1, running_time*1000, pcap_errbuf);
  if(pcap_capture_descr == NULL) {
    fprintf(stderr, "pcap_open_live(): %s\n",pcap_errbuf);
    fprintf(stderr, "This error may be caused by a non-root user running this file.  Make sure that this binary is SETUID.");
  }
}


/*
  Closes down the dats structures used by libpcap an libnet, prints out pcap stats.
  If your dump file is not properly formatted, it is likely the result of not calling
  this function at the end of packet capture.
*/
void CloseNetwork(){

  struct pcap_stat p_stats;

  if (pcap_stats(pcap_capture_descr ,&p_stats)) {
    fprintf(stderr, "Err: unable to get pcap stats\n");
  } else {
    fprintf(stderr, "Pcap stats: %0d packets captured.  Dropped %0d due to lack of resources\n",
            p_stats.ps_recv, p_stats.ps_drop);
  }
  pcap_close(pcap_capture_descr);
}
