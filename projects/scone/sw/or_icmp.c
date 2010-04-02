/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "or_icmp.h"
#include "or_ip.h"
#include "or_utils.h"
#include "or_rtable.h"
#include "or_main.h"
#include "or_arp.h"
#include "or_iface.h"
#include "or_output.h"
#include "or_sping.h"
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <assert.h>

void process_icmp_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {
	icmp_hdr* icmp = get_icmp_hdr(packet, len);
	/*
	 * TODO:
	 * if interface is wan, and type error unwrap
	 * check internal packet for a hit on nat table
	 * if so, rewrite the ip of icmp packet and send it to the hit
	 *
	 */
	if (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) {
		send_icmp_packet(sr, packet, len, ICMP_TYPE_ECHO_REPLY, ICMP_CODE_ECHO);
	}
	if(icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) {
		process_icmp_echo_reply_packet(sr, packet, len);
	}
}

/*
 * This method is NOT thread safe, accesses rtable (which currently is locking itself),
 * ARP cache, and potentially ARP queue
 *
 * Returns 0 on success, 1 on failure
 */
int send_icmp_packet(struct sr_instance* sr, const uint8_t* src_packet, unsigned int len, uint8_t icmp_type, uint8_t icmp_code) {

	int new_packet_len;
	int icmp_payload_len;

	if (icmp_type == ICMP_TYPE_ECHO_REPLY) {
		new_packet_len = len;
		icmp_payload_len = new_packet_len - (sizeof(eth_hdr) + sizeof(ip_hdr) + sizeof(icmp_hdr));
	} else {
		new_packet_len = sizeof(eth_hdr) + sizeof(ip_hdr) + sizeof(icmp_hdr) + 4 + sizeof(ip_hdr) + 8;
		icmp_payload_len = 4 + sizeof(ip_hdr) + 8;
	}

	uint8_t* new_packet = (uint8_t*)malloc(new_packet_len);

	bzero(new_packet, new_packet_len);

	eth_hdr* new_eth = (eth_hdr*)new_packet;
	ip_hdr* ip = get_ip_hdr(src_packet, len);
	ip_hdr* new_ip = get_ip_hdr(new_packet, new_packet_len);
	icmp_hdr* new_icmp = get_icmp_hdr(new_packet, new_packet_len);

	struct in_addr next_hop;
	char iface[32];
	bzero(iface, 32);

	/* Check that we have a next hop, and if so get the next hop IP, and outgoing interface name */
	if (get_next_hop(&next_hop, iface, 32, (router_state*)sr->interface_subsystem, &ip->ip_src) != 0) {
		//printf("Failure getting next hop address\n");
		return 1;
	}

	/* Grab the interface struct for the outgoing interface so we have its MAC address */
	iface_entry* iface_struct = get_iface(get_router_state(sr), iface);
	assert(iface_struct);

	if (icmp_type == ICMP_TYPE_ECHO_REPLY) {
		populate_icmp(new_icmp, icmp_type, icmp_code, ((uint8_t*)get_icmp_hdr(src_packet, len)) + sizeof(icmp_hdr), icmp_payload_len);
	} else {
		uint8_t *new_payload = calloc(icmp_payload_len, sizeof(uint8_t));
		bcopy(ip, new_payload+4, icmp_payload_len-4);
		populate_icmp(new_icmp, icmp_type, icmp_code, new_payload, icmp_payload_len);
		free(new_payload);
	}


	new_icmp->icmp_sum = htons(compute_icmp_checksum(new_icmp, icmp_payload_len));


	/* populate the ip header and checksum */
	if ((icmp_type == ICMP_TYPE_ECHO_REPLY) ||
			((icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) && (icmp_code == ICMP_CODE_PORT_UNREACHABLE))) {

		/* If we are sending back a port unreachable, that means the packet was destined to one of our interfaces,
		 * which may not be the ingress interface, thus we need to set the reply IP packets source address
		 * with the address it was initialy sent to
		 *
		 * Or if we are sending back an echo reply, then it was destined to our router, so send it
		 * back with the proper ip
		 */
		populate_ip(new_ip, sizeof(icmp_hdr) + icmp_payload_len, IP_PROTO_ICMP, ip->ip_dst.s_addr, ip->ip_src.s_addr);
	} else {
		populate_ip(new_ip, sizeof(icmp_hdr) + icmp_payload_len, IP_PROTO_ICMP, iface_struct->ip, ip->ip_src.s_addr);
	}
	new_ip->ip_sum = htons(compute_ip_checksum(new_ip));

	/* populate the packet with the eth information we have */
	populate_eth_hdr(new_eth, NULL, iface_struct->addr, ETH_TYPE_IP);

	/* ship the packet */
	return send_ip(sr, new_packet, new_packet_len, &(next_hop), iface_struct->name);
}

/*
 * Returns the host order checksum for the given packet
 */
uint16_t compute_icmp_checksum(icmp_hdr* icmp, int payload_len) {

	icmp->icmp_sum = 0;
	unsigned long sum = 0;
	uint16_t s_sum = 0;
	int numShorts = (sizeof(icmp_hdr) + payload_len) / 2;
	int i = 0;
	uint16_t* s_ptr = (uint16_t*)icmp;

	for (i = 0; i < numShorts; ++i) {
		if (i != 1) {
			sum += ntohs(*s_ptr);
		}
		++s_ptr;
	}

	sum = (sum >> 16) + (sum & 0xFFFF);
	sum += (sum >> 16);

	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);

	return s_sum;
}


icmp_hdr* get_icmp_hdr(const uint8_t* packet, unsigned int len) {
	ip_hdr* ip = get_ip_hdr(packet, len);
	packet = (uint8_t*)ip;
	return (icmp_hdr*)(packet + sizeof(ip_hdr));
}




int send_icmp_echo_request_packet(struct sr_instance* sr, struct in_addr dst, unsigned short id) {

	router_state *rs = get_router_state(sr);

	int icmp_payload_len = 60;
	int icmp_payload_offset = sizeof(eth_hdr) + sizeof(ip_hdr) + sizeof(icmp_hdr);
	int packet_len = icmp_payload_offset + icmp_payload_len;

	uint8_t *packet = (uint8_t *)calloc(packet_len, sizeof(char));
	eth_hdr* eth = (eth_hdr*)packet;
	ip_hdr* ip = get_ip_hdr(packet, packet_len);
	icmp_hdr* icmp = get_icmp_hdr(packet, packet_len);

	/* Get next hop IP addr and outgoing interface name */
	struct in_addr next_hop;
	char* iface = (char *) calloc(32, sizeof(iface));

	if(get_next_hop(&next_hop, iface, 32, rs, &dst) != 0) {
		//printf("Failure getting next hop address\n");
		return 1;
	}


	/* Grab the interface struct for the outgoing interface */
	iface_entry* iface_struct = get_iface(rs, iface);


	/* Construct the icmp payload: HOST BYTE ORDER */
	uint8_t *icmp_payload = calloc(icmp_payload_len, sizeof(uint8_t));
	unsigned short *icmp_payload_id = (unsigned short *)icmp_payload;

	*icmp_payload_id = id;
	populate_padding(icmp_payload + 4, icmp_payload_len-4);


	/* Populate icmp headear and checksum */
	populate_icmp(icmp, ICMP_TYPE_ECHO_REQUEST, ICMP_CODE_ECHO, icmp_payload, icmp_payload_len);

	icmp->icmp_sum = htons(compute_icmp_checksum(icmp, icmp_payload_len));
	free(icmp_payload);

	/* Populate the ip header and checksum */
	populate_ip(ip, sizeof(icmp_hdr) + icmp_payload_len, IP_PROTO_ICMP, iface_struct->ip, dst.s_addr);
	ip->ip_sum = htons(compute_ip_checksum(ip));


	/* populate the eth header */
	populate_eth_hdr(eth, NULL, iface_struct->addr, ETH_TYPE_IP);


	/* ship the packet */
	return send_ip(sr, packet, packet_len, &(next_hop), iface_struct->name);


}

int process_icmp_echo_reply_packet(struct sr_instance* sr, const uint8_t* packet, unsigned int len) {

	router_state *rs = get_router_state(sr);

	/* Create an entry in the sping queue for this echo reply */
	sping_queue_entry *sping_entry = calloc(1, sizeof(sping_queue_entry));
	sping_entry->packet = calloc(len, sizeof(uint8_t));
	memcpy(sping_entry->packet, packet, len);
	sping_entry->len = len;
	time(&(sping_entry->arrival_time));

	node *n = node_create();
	n->data = sping_entry;

	/* put the packet on the sping queue and broadcast its arrival */
	lock_mutex_sping_queue(rs);
	if(rs->sping_queue == NULL) {
		rs->sping_queue = n;
	} else {
		node_push_back(rs->sping_queue, n);
	}
	pthread_cond_broadcast(rs->sping_cond);
	unlock_mutex_sping_queue(rs);

	return 1;
}


