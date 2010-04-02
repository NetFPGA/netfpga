#include "or_utils.h"
#include "or_data_types.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

void populate_eth_hdr(eth_hdr* ether_hdr, uint8_t* dhost, uint8_t *shost, uint16_t type) {
	if (dhost) {
		memcpy(ether_hdr->eth_dhost, dhost, ETH_ADDR_LEN);
	}
	memcpy(ether_hdr->eth_shost, shost, ETH_ADDR_LEN);
	ether_hdr->eth_type = htons(type);
}

/*
 * Populates an IP header with the usual data.  Note source_ip and dest_ip must be passed into
 * the function in network byte order.
 */
void populate_ip(ip_hdr* ip, uint16_t payload_size, uint8_t protocol, uint32_t source_ip, uint32_t dest_ip) {
	bzero(ip, sizeof(ip_hdr));
	ip->ip_hl = 5;
	ip->ip_v = 4;

	ip->ip_off = htons(IP_FRAG_DF);

	ip->ip_len = htons(20 + payload_size);
	ip->ip_ttl = 0x40;
	ip->ip_p = protocol;
	ip->ip_src.s_addr = source_ip;
	ip->ip_dst.s_addr = dest_ip;
}
