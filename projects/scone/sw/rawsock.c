#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include "nf2/nf2.h"
#include "nf2/nf2util.h"
#include "reg_defines.h"
#include "or_data_types.h"
#include "or_ip.h"
#include "or_utils.h"

#define READ_BUF_SIZE 8192

int main(int argc, char** argv)
{
	/* initialize the netfpga */
	nf2device netfpga;
	netfpga.device_name = "nf2c0";
	netfpga.fd = 0;
	netfpga.net_iface = 0;

	if (check_iface(&netfpga)) {
		printf("Failure connecting to NETFPGA\n");
		exit(1);
	}

	if (openDescriptor(&netfpga)) {
		printf("Failure connecting to NETFPGA\n");
		exit(1);
	}

	/* reset the netfpga */
	writeReg(&netfpga, CPCI_REG_CTRL, 0x00010100);
	sleep(2);
	/* enable dma */
	//writeReg(&netfpga, DMA_ENABLE_REG, 0x1);

	/* end netfpga initialization */

	int s = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL));

	/* find the nf2c0 index */
	struct ifreq ifr;
	strncpy(ifr.ifr_ifrn.ifrn_name, "nf2c0", IFNAMSIZ);
	if (ioctl(s, SIOCGIFINDEX, &ifr) < 0) {
		perror("ioctl SIOCGIFINDEX");
		exit(1);
	}

	struct sockaddr_ll saddr;
	saddr.sll_family = AF_PACKET;
	saddr.sll_protocol = htons(ETH_P_ALL);
	saddr.sll_ifindex = ifr.ifr_ifru.ifru_ivalue;

	if (bind(s, (struct sockaddr*)(&saddr), sizeof(saddr)) < 0) {
		perror("bind error");
		exit(1);
	}

	char readBuf[READ_BUF_SIZE];
	bzero(readBuf, READ_BUF_SIZE);

	/* build the packet we want to send */
	char packet[60];
	bzero(packet, 60);
	char eth_src[6] = {0x0, 0x0, 0x0, 0x0, 0x0, 0x1};
	char eth_dst[6] = {0x0, 0x15, 0x17, 0x20, 0xbb, 0xde};
	populate_eth_hdr((eth_hdr*)packet, eth_dst, eth_src, 0x0800);
	uint32_t ip_src = 0xc0a80002; /* 192.168.0.2 */
	uint32_t ip_dst = 0xc0a80001; /* 192.168.0.1 */
	ip_hdr* iphdr = (ip_hdr*)(packet+ETH_HDR_LEN);
	populate_ip(iphdr, 26, 1, htonl(ip_src), htonl(ip_dst)); /* 26 byte payload, icmp type */
	iphdr->ip_sum = htons(compute_ip_checksum(iphdr));
	char icmp[26] = {0x8, 0x0, 0x9, 0x80, 0xcf, 0x64, 0x04, 0x0,
		0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58,
		0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58, 0x58};
	memcpy((packet + ETH_HDR_LEN + 20), icmp, 26);

	/* setup select */
	fd_set read_set, write_set;
	FD_ZERO(&read_set);
	FD_ZERO(&write_set);

	while (1) {
		FD_SET(s, &read_set);
		FD_SET(s, &write_set);

		if (select(s+1, &read_set, &write_set, NULL, NULL) < 0) {
			perror("select");
			exit(1);
		}

		if (FD_ISSET(s, &read_set)) {
			int read_bytes = read(s, readBuf, READ_BUF_SIZE);
			printf("Read: %i bytes\n", read_bytes);
		}

		if (FD_ISSET(s, &write_set)) {
			int written_bytes = write(s, packet, 60);
			printf("Wrote: %i bytes\n", written_bytes);
		}
	}
}
