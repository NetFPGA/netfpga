/*
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
 * Module: send_pkts.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Send sequences of raw ethernet pakts - used to test interfaces,
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>
#include <libnet.h>
#include <pcap.h>

#include "../../common/nf2.h"
#include "../../common/nf2util.h"


#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

#define SNAPLEN 30

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;
static int num_pkts = 1;
static int am_sender = 0;
static int delay = 0;
static int exp_total_pkts = 0;
static int pkts_rcvd = 0;
static u_short port = 0x1234;
static int e_count[65536];
static u_int length = 0;     // packet length 0=random
static u_int check_pkt = 0;

static u_int dest = 0x03;
static u_int src  = 0x00;

/*  Libnet variables */
char libnet_errbuf[LIBNET_ERRBUF_SIZE];
libnet_t *lt;

/* Libpcap variables */
char pcap_errbuf[PCAP_ERRBUF_SIZE];
pcap_t *pcap_capture_descr; // for capturing received packets


/* Function declarations */
void processArgs (int , char **);
void usage (void);
void InitNetwork(char *);
void CloseNetwork(void);
void SendPackets(int);
void ReceivePackets(void);
void ReceiveSinglePacket(u_char *, const struct pcap_pkthdr*, const u_char* );
int SendEthernetPacket(char *, char *, short, char *, int , int);
void millisec_sleep(int );

int main(int argc, char *argv[])
{
   unsigned val;

   nf2.device_name = DEFAULT_IFACE;


   processArgs(argc, argv);

   /*
    *

   if (check_iface(&nf2))
      {
	 exit(1);
      }
   if (openDescriptor(&nf2))
      {
	 exit(1);
      }

   closeDescriptor(&nf2);
   *
   */

   InitNetwork(nf2.device_name);

   if (am_sender)
      {
	 SendPackets(num_pkts);
      }
   else
      {
	 ReceivePackets();
      }

   CloseNetwork();

   return 0;
}


/* Send a single packet */

void SendPackets(int num_pkts)
{
   char DA[6], SA[6], data[1500];

   short EtherType = port;

   u_int len, n_len;

   // DA
   DA[0] = 0;
   DA[1] = 0xd1;
   DA[2] = 0xd2;
   DA[3] = 0xd3;
   DA[4] = 0xd4;
   DA[5] = dest;

   // SA
   SA[0] = 0;
   SA[1] = 0xd1;
   SA[2] = 0xd2;
   SA[3] = 0xd3;
   SA[4] = 0xd4;
   SA[5] = src;

   int i;
   for (i=0;i <1500;i++) { data[i] = (char) 0; }

   // write in the TOTAL number of packets to be sent.
   int n_num_pkts = htonl(num_pkts);
   memcpy(data, &n_num_pkts, sizeof(num_pkts));

   // use time as random number seed
   srand48((long int) time(NULL));

   int pkt;
   int n_pkt;
   for (pkt = 0; pkt < num_pkts; pkt++)
      {

         // write in the seq num for this packet
	 n_pkt = htonl(pkt+1);
	 memcpy(data+4, &n_pkt, sizeof(pkt));

         // compute random pkt len if length is zero else use length
         len = (length) ? length : ((lrand48() % (1514-60))+60);
 	 n_len = htonl(len);
     	 memcpy(data+8, &n_len, sizeof(n_len));
	 // printf("\nsent len %d\n", len);

         // If we are doing packet content checking then change the
	 // packet contents each time based on length field.
	 if (check_pkt) {
	    for (i = 12 ; i < (len-14) ; i++) {
	       data[i] = (len + i)%256;
	    }
	 }

	    // for (i=0;i<8;i++) { fprintf(stderr,"%02x ", *(data+i)); }
	    SendEthernetPacket(DA,SA,EtherType, data, (len - 14), len);
	    millisec_sleep(delay);
	 }

}


void ReceivePackets ()
{
   u_char rcv_finished = 0;

   int i;

   // clear counters
   for (i=0;i<65536;i++) { e_count[i] = 0; }

   while (!rcv_finished)
      {
	 pcap_dispatch(pcap_capture_descr, 1, ReceiveSinglePacket, &rcv_finished);
      }

   fprintf(stderr,"\nRcv done: Received %6.2f %% of packets.\n",
	   (100.0*pkts_rcvd/exp_total_pkts));

   for (i=0;i<65536;i++) {
      if (e_count[i]) {
	 fprintf(stderr, "Ethertype 0x%04x saw %d pkts.\n", i, e_count[i]);
      }
   }

}



/*
  ReceiveSinglePacket is the callback used to process
  a single incoming packet.
  It exploits knowledge of the packet structure to figure out
  how many packets we expect to receive (total) and what is
  the sequence number for this particular packet.
*/

void ReceiveSinglePacket(u_char *rcv_finished,
			 const struct pcap_pkthdr* pkthdr,
			 const u_char* packet) {

   unsigned char* payload = NULL;
   u_short ethertype;
   long seq_num;
   float percent;
   u_int len;
   u_int len_off_wire;
   char c;

   // fprintf(stderr,"\ncaplen %d  len %d\n", pkthdr->caplen, pkthdr->len );

   int i;
   //for (i=0;i<26;i++) { c = packet[i]; fprintf(stderr, "%02x ", (uint8_t) c); }
   //fprintf(stderr,"\n");


   memcpy(&ethertype, (u_char *)(packet+12), sizeof(u_short)); // get ethertype
   ethertype = ntohs(ethertype);

   /* pcap may capture outbound packets. So we use different ports so that we
    * can ignore them here.
    */
   e_count[ethertype]++;
   if (ethertype != port)
   {
      // fprintf(stderr,"E:0x%x %d\n",ethertype, e_count[ethertype]);
      return;
   }

   payload = (u_char *)packet + LIBNET_ETH_H;

   // get total count.
   memcpy(&exp_total_pkts, payload, sizeof(long));
   exp_total_pkts = ntohl(exp_total_pkts);

   // get seq num
   memcpy(&seq_num, payload+4, sizeof(long));
   seq_num = ntohl(seq_num);

   // get expected len
   memcpy(&len, payload+8, sizeof(long));
   len = ntohl(len);
   // see what len actually arrived
   len_off_wire =  pkthdr->len;
   if (len_off_wire != len) {
      fprintf(stderr,"\nLen off wire: %d   but in pkt len was %d\n",
	      len_off_wire, len);
   }

   // check contents
   if (check_pkt) {
      u_char exp_byte;
      for (i = 12 ; i < (len_off_wire - 14) ; i++) {
	 exp_byte = (u_char) (( len + i ) % 256);
         if (*(payload + i) != exp_byte) {
	    fprintf(stderr,"ERROR: byte %d expected to be 0x%x but saw 0x%x\n",
		    i+14, exp_byte, *(payload + i));
	 }
      }
   }


   pkts_rcvd++;

   percent = (100.0 * pkts_rcvd/ seq_num);

   fprintf(stderr,"total: %6d  seq: %6d dropped: %d    \r",
	   exp_total_pkts, seq_num, (seq_num - pkts_rcvd));

   if (seq_num == exp_total_pkts) {
      *rcv_finished = 1;
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

   while ((c = getopt (argc, argv, "i:s:d:vfp:l:cS:D:")) != -1)
      {
	 switch (c)
	    {
	    case 'v':	/* Verbose */
	       verbose = 1;
	       break;
	    case 'i':	/* interface name */
	       nf2.device_name = optarg;
	       break;
	    case 's':	/* I'm sender! see how many pkts */
	       num_pkts = atoi(optarg);
	       am_sender = 1;
	       printf("sender: %d packets\n", num_pkts);
	       break;
	    case 'd':	/* I'm sender! set delay in msec between pkts */
	       delay = atoi(optarg);
	       printf("sender: %d msec delay\n", delay);
	       break;
	    case 'p':	/* Port (ethertype) to use. default 0x1234 */
	       port = (u_short) (atoi(optarg) & 0xffff);
	       printf("use port %d (0x%x)\n", port, port);
	       break;
	    case 'c':	/* check packet contents */
	       check_pkt = 1;
	       printf("Will check packet on receive.\n", port, port);
	       break;
	    case 'l':	/* length in bytes. Default is 0 which means random */
	       length = atoi(optarg);
	       if ((length < 60) || (length > 1514)) {
		  fprintf(stderr,"ERROR: length must be between 60 and 1514\n");
		  exit(1);
	       }
	       printf("use fixed packet length %d bytes (excl CRC)\n", length);
	       break;
	    case 'S': /* last byte of source address */
	       src = atoi(optarg);
	       if(src>255) {
	          fprintf(stderr, "ERROR: last byte of src should be < 255\n");
	          exit(1);
	       }
               printf("Last byte of source set to 0x%02x\n", src);
               break;
	    case 'D': /* last byte of destination address */
	       dest = atoi(optarg);
	       if(dest>255) {
	          fprintf(stderr, "ERROR: last byte of dest should be < 255\n");
	          exit(1);
	       }
               printf("Last byte of destination set to 0x%02x\n", dest);
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
	printf("Usage: ./send_pkts <options>  filename.bin\n");
	printf("\nOptions: \n");
	printf("         -i <iface> : interface name such nf2c0 (default nf2c0).\n");
	printf("         -v : be verbose.\n");
	printf("         -s <num_pkts>: I am sender. Specify number pkts to send.\n");
	printf("         -d <delay ms>: (sender only) specify inter-packet delay in ms (default 0)\n");
	printf("         -p <port>:  specify ethertype to use (sender and receiver) default: 0x1234\n");
	printf("         -S <src byte>:  specify last byte of src mac address\n");
	printf("         -D <dest byte>:  specify last byte of dest mac address\n");
	printf("         -c :  receive process should check every packet byte (slow)\n");
	printf("               NOTE: Must be set for both Tx and Rx processes.\n");
}


/*
   Initialize the pcap and libnet interfaces
*/

void InitNetwork(char *device_name) {

   printf("Opening interface:%s\n", device_name);

   int snaplen;  // num bytes to actually vapture. More == slower...

   if (!am_sender)
      {
	 // NOTE: defaults to promiscuous mode
	 //

	 snaplen = SNAPLEN;
	 // only change minimum snaplen if we have packet content checking turned on.
	 if (check_pkt) {
	    // if we have fixed packet size then onlyy capture that much, otherwise get all...
	    snaplen = (length) ? length : 1514;
	    fprintf(stderr,"Packet checking is ON so we use a SNAPLEN of %d bytes.\n",snaplen);
	 }

	 pcap_capture_descr = pcap_open_live(device_name, snaplen, 1, 0, pcap_errbuf);
	 if(pcap_capture_descr == NULL) {
	    fprintf(stderr, "pcap_open_live(): %s\n",pcap_errbuf);
	    fprintf(stderr, "This error may be caused by a non-root user running this file.  Make sure that this binary is SETUID.");
	 }
/* 	 if( (pcap_setdirection(pcap_capture_descr, PCAP_D_IN)) != 0 ){ */
/* 	    fprintf(stderr, "pcap_setdirection(): %s\n",pcap_errbuf); */
/* 	    fprintf(stderr, "setdirection is not supported. Will capture packets going out *and* coming into the interface."); */
/* 	 } */
      }
   else
      {
	 if ((lt = libnet_init(LIBNET_LINK, device_name, libnet_errbuf)) == NULL) {
	    fprintf (stderr, "ERROR opening interface: %s\n", libnet_errbuf);
	    fprintf (stderr, "(Check that interface is up (/sbin/ifconfig) and has IP address)\n");
	    exit(1);
	 }
      }
}


/*
  Closes down the dats structures used by libpcap an libnet, prints out pcap stats.
  If your dump file is not properly formatted, it is likely the result of not calling
  this function at the end of packet capture.
*/
void CloseNetwork(){

   struct pcap_stat p_stats;

   if (am_sender)
      {
	 libnet_destroy(lt);
      }
   else
      {
	 if (pcap_stats(pcap_capture_descr ,&p_stats)) {
	    fprintf(stderr, "Err: unable to get pcap stats\n");
	 }  else {
	    fprintf(stderr, "Pcap stats: %0d packets captured.  Dropped %0d due to lack of resources\n"
		    ,
		    p_stats.ps_recv, p_stats.ps_drop);
	 }

	 pcap_close(pcap_capture_descr);
      }
}




/*
  Uses libnet to send a ethernet packet with the specified attributes.
  returns the number of bytes sent by libnet.
*/
int SendEthernetPacket(char *DA,
		       char *SA,
		       short EtherType,
		       char *payload,
		       int payloadLen,
		       int packet_size
		       ) {

   int bytes_sent;
   char * err;

   // clear packet data
   libnet_clear_packet(lt);

   // build libnet ethernet packet
   if (libnet_build_ethernet(DA, SA, EtherType, payload, (long) payloadLen, lt, 0) ==
       -1) {
      fprintf(stderr, "ERROR: libnet_build_ethernet failed:\n");
      if (err = libnet_geterror(lt)) {
	 fprintf(stderr, "%s\n",err);
      }
   }

   bytes_sent = libnet_write(lt);
   if (bytes_sent != packet_size) {
      fprintf(stderr, "ERROR libnet_write_link_layer only wrote %d bytes\n", bytes_sent);
   }
   //   fprintf(stderr, "SEP: libnet wrote packet of size: %d \n", bytes_sent);

   return bytes_sent;
}


/*
 *
  Puts the calling function to sleep for the specified # of milli seconds
  *
  */
void millisec_sleep(int msec){

  struct timeval tv;

  tv.tv_sec = 0;
  tv.tv_usec = 1000 * msec;
  select(0, NULL, NULL, NULL, &tv);

}
