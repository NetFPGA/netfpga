/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <netinet/in.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>

#include "or_main.h"
#include "or_iface.h"
#include "or_arp.h"
#include "or_icmp.h"
#include "or_rtable.h"
#include "or_output.h"
#include "or_utils.h"
#include "or_rtable.h"
#include "or_ip.h"
#include "or_pwospf.h"
#include "sr_lwtcp_glue.h"
#include "or_nat.h"
#include "or_data_types.h"

void process_ip_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {

	router_state *rs = get_router_state(sr);


	/* Check if the packet is invalid, if so drop it */
	if (!is_packet_valid(packet, len)) {
		return;
	}

	lock_arp_cache_rd(rs);
	lock_arp_queue_wr(rs);
	lock_if_list_rd(rs);
	lock_rtable_rd(rs);

	/* check for incoming wan interface */
	iface_entry* iface = get_iface(rs, interface);
	if(iface->is_wan ==1) {
		lock_nat_table(rs);
		process_nat_ext_packet(rs, packet, len);
		unlock_nat_table(rs);
	}

	/* Check if the packet is headed to one of our interfaces */
	if (iface_match_ip(rs, (get_ip_hdr(packet, len))->ip_dst.s_addr)) {
		ip_hdr* ip = get_ip_hdr(packet, len);

		switch (ip->ip_p) {
			case IP_PROTO_TCP:
				/* If TCP, forward up the stack */
		 		sr_transport_input((uint8_t *)ip);
				break;
			case IP_PROTO_ICMP:
				process_icmp_packet(sr, packet, len, interface);
				break;
			case IP_PROTO_PWOSPF:
				process_pwospf_packet(sr, packet, len, interface);
				break;
			case IP_PROTO_UDP:
				/* We don't accept UDP so ICMP reply port unreachable*/
				if (send_icmp_packet(sr, packet, len, ICMP_TYPE_DESTINATION_UNREACHABLE, ICMP_CODE_PORT_UNREACHABLE) != 0) {
					//printf("Failure sending icmp reply\n");
				}
				break;
			default:
				/* If other? return ICMP protocol unreachable */
				//printf("Unknown protocol, sending ICMP unreachable\n");
				if (send_icmp_packet(sr, packet, len, ICMP_TYPE_DESTINATION_UNREACHABLE, ICMP_CODE_PROTOCOL_UNREACHABLE) != 0) {
					//printf("Failure sending icmp reply\n");
				}
				break;
		}
	} else if ((get_ip_hdr(packet, len))->ip_dst.s_addr == htonl(PWOSPF_HELLO_TIP)) {
		/* if the packet is destined to the PWOSPF address then process it */
		process_pwospf_packet(sr, packet, len, interface);
	} else {
		/* Need to forward this packet to another host */
		struct in_addr next_hop;
		char next_hop_iface[IF_LEN];
		bzero(next_hop_iface, IF_LEN);


		/* is there an entry in our routing table for the destination? */
		if(get_next_hop(&next_hop, next_hop_iface, IF_LEN,
			 	rs,
			 	&((get_ip_hdr(packet, len))->ip_dst))) {

			/* send ICMP no route to host */
			uint8_t icmp_type = ICMP_TYPE_DESTINATION_UNREACHABLE;
			uint8_t icmp_code = ICMP_CODE_NET_UNKNOWN;
			send_icmp_packet(sr, packet, len, icmp_type, icmp_code);
		}	else {


			if(strncmp(interface, next_hop_iface, IF_LEN) == 0){
				/* send ICMP net unreachable */
				uint8_t icmp_type = ICMP_TYPE_DESTINATION_UNREACHABLE;
				uint8_t icmp_code = ICMP_CODE_NET_UNREACHABLE;
				send_icmp_packet(sr, packet, len, icmp_type, icmp_code);
			}
			else {

				/* check for outgoing interface is WAN */
				iface_entry* iface = get_iface(rs, next_hop_iface);
				if(iface->is_wan) {

					lock_nat_table(rs);
					process_nat_int_packet(rs, packet, len, iface->ip);
					unlock_nat_table(rs);
				}

				ip_hdr *ip = get_ip_hdr(packet, len);

				/* is ttl < 1? */
				if(ip->ip_ttl == 1) {

					/* send ICMP time exceeded */
					uint8_t icmp_type = ICMP_TYPE_TIME_EXCEEDED;
					uint8_t icmp_code = ICMP_CODE_TTL_EXCEEDED;
					send_icmp_packet(sr, packet, len, icmp_type, icmp_code);

				} else {
					/* decrement ttl */
					ip->ip_ttl--;

					/* recalculate checksum */
					bzero(&ip->ip_sum, sizeof(uint16_t));
					uint16_t checksum = htons(compute_ip_checksum(ip));
					ip->ip_sum = checksum;

					eth_hdr *eth = (eth_hdr *)packet;
					iface_entry* sr_if = get_iface(rs, next_hop_iface);
					assert(sr_if);

					/* update the eth header */
					populate_eth_hdr(eth, NULL, sr_if->addr, ETH_TYPE_IP);

					/* duplicate this packet here because the memory will be freed
				 	 * by send_ip, and our copy of the packet is only on loan
				 	 */

				 	uint8_t* packet_copy = (uint8_t*)malloc(len);
				 	memcpy(packet_copy, packet, len);

					/* forward packet out the next hop interface */
					send_ip(sr, packet_copy, len, &(next_hop), next_hop_iface);
				}
			} /* end of strncmp(interface ... */
		} /* end of if(get_next_hop) */
	}

	unlock_rtable(rs);
	unlock_if_list(rs);
	unlock_arp_queue(rs);
	unlock_arp_cache(rs);
}

/*
 * Return: 0 if not IPV4, options exist, is fragmented, invalid checksum. 1 otherwise.
 *
 */
int is_packet_valid(const uint8_t * packet, unsigned int len) {
	ip_hdr* ip = get_ip_hdr(packet, len);

	/* check for IPV4 */
	if (ip->ip_v != 4) {
		return 0;
	}

	/* check for options */
	if (ip->ip_hl != 5) {
		return 0;
	}

	/* check for fragmentation */
	uint16_t frag_field = ntohs(ip->ip_off);
	if ((frag_field & IP_FRAG_MF) || (frag_field & IP_FRAG_OFFMASK)) {
		return 0;
	}

	/* check the checksum */
	/*if (ntohs(ip->ip_sum) != compute_ip_checksum(ip)) {*/
	if(verify_checksum((uint8_t *)ip, 4*ip->ip_hl)) {
		return 0;
	}


	return 1;
}

/*
 * Takes raw packet pointer and length, returns pointer to ip segment
 */
ip_hdr* get_ip_hdr(const uint8_t* packet, unsigned int len) {
	return (ip_hdr*)(packet + ETH_HDR_LEN);
}

/*
 * Returns the host order checksum for the given packet
 */
uint16_t compute_ip_checksum(ip_hdr* iphdr) {
	iphdr->ip_sum = 0;
	unsigned long sum = 0;
	uint16_t s_sum = 0;
	int numShorts = iphdr->ip_hl * 2;
	int i = 0;
	uint16_t* s_ptr = (uint16_t*)iphdr;

	for (i = 0; i < numShorts; ++i) {
		/* sum all except checksum field */
		if (i != 5) {
			sum += ntohs(*s_ptr);
		}
		++s_ptr;
	}

	/* sum carries */
	sum = (sum >> 16) + (sum & 0xFFFF);
	sum += (sum >> 16);

	/* ones compliment */
	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);

	return s_sum;
}

int verify_checksum( uint8_t *data, unsigned int data_length)
{
  	uint16_t *bytes;
	size_t length;
	uint32_t sum_2_comp = 0;
        uint16_t sum_1_comp = 0;
	int i;
	bytes = (uint16_t *)data;
    	length = data_length/2;

        for(i=0; i<length; i++) { sum_2_comp += ntohs(bytes[i]); }
    	sum_1_comp = (sum_2_comp >> 16) + (sum_2_comp & 0xFFFF);

        if(sum_1_comp == 0xFFFF) { return 0; }
	//printf("%X\t", sum_1_comp);
	return 1;
}

uint32_t send_ip_packet(struct sr_instance *sr, uint8_t proto, uint32_t src, uint32_t dest, uint8_t *payload, int len)
{
	assert(sr);
	assert(payload);


	router_state *rs = get_router_state(sr);
	int data_offset = sizeof(eth_hdr) + sizeof(ip_hdr);
	int new_packet_len = data_offset + len;
	uint8_t *new_packet = (uint8_t *)calloc(new_packet_len, sizeof(uint8_t));


	lock_arp_cache_rd(rs);
	lock_arp_queue_wr(rs);
	lock_if_list_rd(rs);
	lock_rtable_rd(rs);


	eth_hdr* new_eth = (eth_hdr *)new_packet;
	ip_hdr* new_ip = get_ip_hdr(new_packet, new_packet_len);

	/* populate the ip datapayload */
	memcpy(new_packet+data_offset, payload, len);

	/* populate the ip header and checksum */
	populate_ip(new_ip, len, proto, src, dest);
	new_ip->ip_sum = htons(compute_ip_checksum(new_ip));

	char *iface = calloc(32, sizeof(char));
	struct in_addr next_hop;

	if(get_next_hop(&next_hop, iface, 32, rs, &new_ip->ip_dst)) {
		//printf("Failure getting next hop address\n");
		return 1;
	}

	/* grab the interface struct for the outgoing interface so we have its MAC address */
	iface_entry* iface_struct = get_iface(rs, iface);
	free(iface);
	/* populate the packet with the eth information we have */
	populate_eth_hdr(new_eth, NULL, iface_struct->addr, ETH_TYPE_IP);

	/* ship the packet */
	int ret = send_ip(sr, new_packet, new_packet_len, &(next_hop), iface_struct->name);

	unlock_rtable(rs);
	unlock_if_list(rs);
	unlock_arp_queue(rs);
	unlock_arp_cache(rs);

	return ret;
}

void cli_show_ip_help(router_state *rs, cli_request* req) {
	char *usage = "usage: show ip [route interface arp]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_ip_help(router_state *rs, cli_request* req) {
	char *usage0 = "usage: ip <args>\n";
	send_to_socket(req->sockfd, usage0, strlen(usage0));

	char *usage1 = "ip [route interface arp]\n";
	send_to_socket(req->sockfd, usage1, strlen(usage1));
}
