#include <stdio.h>
#include <stdlib.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <net/if.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include "../../../lib/C/common/nf2util.h"
#include "or_data_types.h"
#include "or_ip.h"
#include "or_utils.h"
#include "selftest_dma.h"

extern struct nf2device nf2;

unsigned long dmaGood;
unsigned long dmaBad;

int dmaTst();

/*
 * Reset the interface and configure it for continuous operation
 */
void dmaResetContinuous(void) {
  dmaGood = 0;
  dmaBad = 0;

  return;
}


/*
 * Show the status of the DMA test when running in continuous mode
 *
 * Return -- boolean indicatin success
 */
int dmaShowStatusContinuous(void) {
  int success = dmaTst();

  printw("DMA test: Iteration(one pkt write, read, compare): %d   Good: %d   Bad: %d\n",
	 (dmaGood+dmaBad), dmaGood, dmaBad);

  return success;
}


/*
 * Stop the interface
 */
void dmaStopContinuous(void) {
  return;
}



/*
 * Get the test result
 *
 * Return -- boolean indicatin success
 */
int dmaGetResult(void) {
  return dmaTst();

}

/*
iterate a number of times. each time send and read one pkt to/from each
nf2c interface through DMA
*/
int dmaTst() {

  //loop variables
  int i, k;

  //for 4 nf2c"i" interfaces
  int s[4];
  struct ifreq ifr[4];
  struct sockaddr_ll saddr[4];

  // Variables used in select
  fd_set read_set, write_set;
  struct timeval timeout;
  int max_sd;

  int portBaseNum = 0;
  sscanf(nf2.device_name, "nf2c%d", &portBaseNum);

  int maxS = -1;
  for (i=0; i<4; i++) {
    s[i] = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (maxS < s[i])
      maxS = s[i];


    char nfIfcName[20];
    bzero(nfIfcName, 20);
    sprintf(nfIfcName, "nf2c%d", portBaseNum + i);

    /* find the nf2c"portBaseNum + i" index */
    strncpy(ifr[i].ifr_ifrn.ifrn_name, nfIfcName, IFNAMSIZ);

    if (ioctl(s[i], SIOCGIFINDEX, &(ifr[i])) < 0) {
      //printf("ioctl SIOCGIFINDEX at intfc=%d", portBaseNum + i);
      dmaBad++;
      goto error_found;
    }

    saddr[i].sll_family = AF_PACKET;
    saddr[i].sll_protocol = htons(ETH_P_ALL);
    saddr[i].sll_ifindex = ifr[i].ifr_ifru.ifru_ivalue;

    if (bind(s[i], (struct sockaddr*)(&(saddr[i])), sizeof(saddr[i])) < 0) {
      //printf("bind error at intfc=%d", portBaseNum + i);
      dmaBad++;
      goto error_found;
    }

  } // for (i=0; ...

  //j is the "write, read, compare" iteration counter
  long j;

  // Here is a loop for 10 times
  for (j=0; j<10; j++) {

    for (i=0; i<4; i++) { // four interfaces
      // to/from each nf2Ifc
      /* build the packet we want to send */
      char packet[DMA_WRITE_BUF_SIZE]; // null termination
      bzero(packet, DMA_WRITE_BUF_SIZE);

      char eth_src[6] = {0x0, 0x0, 0x0, 0x0, 0x0, 0x1};
      char eth_dst[6] = {0x0, 0x15, 0x17, 0x20, 0xbb, 0xde};
      populate_eth_hdr((eth_hdr*)packet, eth_dst, eth_src, 0x0800);//IPv4

      uint32_t ip_src, ip_dst;

      switch (i) {
      case 0:
	ip_src = 0xc0a80002; /* 192.168.0.2 */
	ip_dst = 0xc0a80001; /* 192.168.0.1 */
	break;
      case 1:
	ip_src = 0xc0a80102; /* 192.168.1.2 */
	ip_dst = 0xc0a80101; /* 192.168.1.1 */
	break;
      case 2:
	ip_src = 0xc0a80202; /* 192.168.2.2 */
	ip_dst = 0xc0a80201; /* 192.168.2.1 */
	break;
      case 3:
	ip_src = 0xc0a80302; /* 192.168.3.2 */
	ip_dst = 0xc0a80301; /* 192.168.3.1 */
	break;
      }

      ip_hdr* iphdr = (ip_hdr*)(packet+ETH_HDR_LEN);
      populate_ip(iphdr, DMA_PKT_LEN - ETH_HDR_LEN - 20, 10, htonl(ip_src), htonl(ip_dst)); /* (DMA_PKT_LEN - ETH_HDR_LEN - 20) byte payload, type=10 */
      iphdr->ip_sum = htons(compute_ip_checksum(iphdr));

      for (k=0; k<DMA_PKT_LEN - ETH_HDR_LEN - 20; k++) {
	char oneByte = random() & 0xff;
	memcpy((packet + ETH_HDR_LEN + 20 + k), &oneByte, 1);
      }

      /* setup select */
      FD_ZERO(&read_set);
      FD_ZERO(&write_set);

      FD_SET(s[i], &read_set);
      FD_SET(s[i], &write_set);

      if (select(maxS+1, &read_set, &write_set, NULL, NULL) < 0) {
	//printf("select at intfc=%d", portBaseNum + i);
	dmaBad++;
	goto error_found;
      }

      int written_bytes=0;
      if (FD_ISSET(s[i], &write_set)) {
	written_bytes = write(s[i], packet, DMA_PKT_LEN);

	if (written_bytes < 0) {
	  //printf("at nf2c%d, write error\n", portBaseNum + i);
	  dmaBad++;
	  goto error_found;
	}

	if (written_bytes != DMA_PKT_LEN) {
	  //printf("at nf2c%d, request to write %d bytes, but written_bytes %d bytes\n",
	  //  portBaseNum + i, DMA_PKT_LEN, written_bytes);
	  dmaBad++;
	  goto error_found;
	}

	//printf("Wrote: at nf2c%d, %d bytes\n", portBaseNum + i, written_bytes);
      }

      char readBuf[DMA_READ_BUF_SIZE];
      bzero(readBuf, DMA_READ_BUF_SIZE);
      timeout.tv_sec = 0;
      timeout.tv_usec = 50000;
      FD_ZERO(&read_set);
      max_sd = s[i] + 1;
      FD_SET(s[i], &read_set);
      int read_bytes = 0;
      if (select(max_sd, &read_set, NULL, NULL, &timeout) == 1) {
        read_bytes = read(s[i], readBuf, DMA_READ_BUF_SIZE);
      }

      if (read_bytes <= 0) {
	//printf("read error at intfc=%d\n", portBaseNum + i);
	dmaBad++;
	goto error_found;
      }

      //printf("Read: nf2c%d, %d bytes\n", portBaseNum + i, read_bytes);

      if (strcmp(packet, readBuf) != 0) {
        //printf("The wrote data do not match the read data.\n");
	//printf("wrote data(written bytes=%d):\n", written_bytes);
	//for (k=0; k<DMA_PKT_LEN; k++)
	//  printf("%02x ", (unsigned char) packet[k]);
	//printf("\n");

	//printf("read data(read bytes=%d):\n", read_bytes);
	//for (k=0; k<read_bytes; k++)
	//  printf("%02x ", (unsigned char) readBuf[k]);
	//printf("\n");

	dmaBad++;
	goto error_found;
      }
      else
	dmaGood++;

    } // for each nf2c"portBaseNum + i" interface

  } // for (j=...) or while (1)

 not_error_found:
  for (i=0; i<4; i++) {
    shutdown(s[i], SHUT_RDWR);
    close(s[i]);
  }
  return 1;


 error_found:
  for (i=0; i<4; i++) {
    shutdown(s[i], SHUT_RDWR);
    close(s[i]);
  }
  return 0;


} // dmaTst(...
