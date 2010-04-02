/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "assert.h"
#include "time.h"

#include "reg_defines.h"
#include "or_nat.h"
#include "or_data_types.h"
#include "or_netfpga.h"
#include "or_iface.h"
#include "or_utils.h"
#include "or_nat.h"
#include "or_ip.h"
#include "or_icmp.h"
#include "or_output.h"

/* NOT THREAD SAFE - acquire the NAT TABLE LOCK */
void process_nat_ext_packet(router_state *rs, const uint8_t *packet, unsigned int len) {


	/* check the nat table for an entry */
	nat_entry *ne = get_nat_table_entry(rs, packet, len, NAT_EXTERNAL);
	if(ne) {
		/* Increment Hits */
		ne->hits++;

		ip_hdr *ip = get_ip_hdr(packet, len);
		nat_tcp_hdr *tcp = NULL;
		nat_udp_hdr *udp = NULL;
		nat_icmp_hdr *icmp = NULL;
		uint32_t checksum = 0;


		/* rewrite the dst ip and port entries */
		populate_nat_packet(ip, packet, len, ne, NAT_INTERNAL);

		/* determine the type of packet */
		switch(ip->ip_p) {

			case IP_PROTO_TCP:
				tcp = get_nat_tcp_hdr(packet, len);

				/* recompute tcp checksums */
				checksum = nat_checksum(tcp->tcp_sum,  ne->nat_int.checksum, ne->nat_ext.checksum);
				bzero(&tcp->tcp_sum, sizeof(uint16_t));
				tcp->tcp_sum = (uint16_t)checksum;

				break;

			case IP_PROTO_UDP:
				udp = get_nat_udp_hdr(packet, len);

				/* recompute udp checksum */
				checksum = nat_checksum(udp->udp_sum,  ne->nat_int.checksum, ne->nat_ext.checksum);
				bzero(&udp->udp_sum, sizeof(uint16_t));
				udp->udp_sum = (uint16_t)checksum;

				break;

			case IP_PROTO_ICMP:
				icmp = get_nat_icmp_hdr(packet, len);

				/* recompute icmp checksum */
				uint32_t checksum = 0;
				if( (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {
					checksum = nat_checksum(icmp->icmp_sum, ne->nat_int.checksum_port, ne->nat_ext.checksum_port);
					bzero(&icmp->icmp_sum, sizeof(uint16_t));
					icmp->icmp_sum = (uint16_t)checksum;
				}
				else if( (icmp->icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) || (icmp->icmp_type == ICMP_TYPE_TIME_EXCEEDED) ) {
					icmp_hdr *icmp = get_icmp_hdr(packet, len);
					int payload_len = ntohs(ip->ip_len) - (sizeof(ip_hdr) + sizeof(icmp_hdr));
				        icmp->icmp_sum = htons(compute_icmp_checksum(icmp, payload_len));
				}
				break;

			default:
				printf("Invalid IP Protocol found int the ip header  while processing nat\n");

		}

		/* recompute ip checksums */
		checksum  = nat_checksum(ip->ip_sum, ne->nat_int.checksum_ip, ne->nat_ext.checksum);
		bzero(&ip->ip_sum, sizeof(uint16_t));
		ip->ip_sum = checksum;
	}
}


/* NOT THREAD SAFE */
void process_nat_int_packet(router_state *rs, const uint8_t *packet, unsigned int len, uint32_t ext_ip) {

	ip_hdr *ip = get_ip_hdr(packet, len);
	nat_entry *ne = NULL;
	uint16_t checksum = 0;

	/* check if we have a nat table entry */
	if( (ip->ip_p == IP_PROTO_TCP) || (ip->ip_p == IP_PROTO_UDP) || (ip->ip_p == IP_PROTO_ICMP) ){


		ne = get_nat_table_entry(rs, packet, len, NAT_INTERNAL);
		if(ne == NULL) {

			/* create nat table entry */
			ne = create_nat_table_entry(rs, packet, len, ext_ip);
		}

		/* rewrite src ip and src port */
		populate_nat_packet(ip, packet, len, ne, NAT_EXTERNAL);
	}

	/* Increment Hits */
	ne->hits++;

	/* rewrite the packet */
	if(ip->ip_p == IP_PROTO_TCP) {
		nat_tcp_hdr *tcp = get_nat_tcp_hdr(packet, len);

		/* recompute tcp checsum */
		checksum = nat_checksum(tcp->tcp_sum,  ne->nat_ext.checksum, ne->nat_int.checksum);
		bzero(&tcp->tcp_sum, sizeof(uint16_t));
		tcp->tcp_sum = (uint16_t)checksum;
	}
	else if(ip->ip_p == IP_PROTO_UDP) {
		nat_udp_hdr *udp = get_nat_udp_hdr(packet, len);

		/* recompute udp checksum */
		checksum = nat_checksum(udp->udp_sum,  ne->nat_ext.checksum, ne->nat_int.checksum);
		bzero(&udp->udp_sum, sizeof(uint16_t));
		udp->udp_sum = (uint16_t)checksum;
	}
	else if(ip->ip_p == IP_PROTO_ICMP) {
		nat_icmp_hdr *icmp = get_nat_icmp_hdr(packet, len);

		/* recompute icmp checksum */
		checksum = 0;
		if( (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {

			checksum = nat_checksum(icmp->icmp_sum, ne->nat_ext.checksum_port, ne->nat_int.checksum_port);
			bzero(&icmp->icmp_sum, sizeof(uint16_t));
			icmp->icmp_sum = (uint16_t)checksum;
		}
		else if( (icmp->icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) || (icmp->icmp_type == ICMP_TYPE_TIME_EXCEEDED) ) {
			icmp_hdr *icmp = get_icmp_hdr(packet, len);
			int payload_len = ntohs(ip->ip_len) - (sizeof(ip_hdr) + sizeof(icmp_hdr));
		        icmp->icmp_sum = htons(compute_icmp_checksum(icmp, payload_len));

		}
	}


	/* recompute ip checksum */
	if( (ip->ip_p == IP_PROTO_TCP) || (ip->ip_p == IP_PROTO_UDP)  || (ip->ip_p == IP_PROTO_ICMP) ) {

		checksum  = nat_checksum(ip->ip_sum, ne->nat_ext.checksum_ip, ne->nat_int.checksum);
		bzero(&ip->ip_sum, sizeof(uint16_t));
		ip->ip_sum = checksum;

	}
}


/* NOT THREAD SAFE - acquire the NAT TABLE LOCK */
nat_entry *create_nat_table_entry(router_state *rs, const uint8_t *packet, unsigned int len, uint32_t ext_ip) {
	ip_hdr *ip = get_ip_hdr(packet, len);

	/* Generate a pseudo-random port # for the ext entry */
	unsigned short port = (unsigned short) rand();

	while(1) {
		if(port > 1024 && (is_unique_nat_ext_port(rs, port) == 1)) {
			break;
		}
		port = (unsigned short) rand();
	}

	nat_entry *ne = (nat_entry *)calloc(1, sizeof(nat_entry));
	ne->last_hits = 0;
	time(&ne->last_hits_time);
	ne->hits = 0;
	ne->avg_hits_per_second = 0.0;
	ne->is_static = 0;
	ne->hw_row = 0xFF;


	ne->nat_ext.ip.s_addr = ext_ip;
	ne->nat_ext.port = htons(port);
	compute_nat_checksums(&(ne->nat_ext));

	ne->nat_int.ip.s_addr = ip->ip_src.s_addr;
	ne->nat_int.port = get_src_port_number(packet, len, ip->ip_p);
	compute_nat_checksums(&(ne->nat_int));

	node *n = (node *)calloc(1, sizeof(node));
	n->data = (void *)ne;
	if(rs->nat_table == NULL) {
		rs->nat_table = n;
	}
	else {
		node_push_back(rs->nat_table, n);
	}


	/* signal the thread that we have a new entry
	 * NOTE thread will have to wait to run until
	 * we exit the lock
	 */
	pthread_cond_broadcast(rs->nat_table_cond);

	return ne;
}


/* NOT THREAD SAFE - acquire the NAT TABLE LOCK */
nat_entry *get_nat_table_entry(router_state *rs, const uint8_t *packet, unsigned int len, int nat_type) {
	assert(rs);
	assert(packet);

	nat_ip_port_pair pair;
	node *n = rs->nat_table;
	nat_entry *ne = NULL;
	int match_found = 0;

	bzero(&pair, sizeof(nat_ip_port_pair));
	get_nat_ip_port_pair(&pair, packet, len, nat_type);
	while(n) {
		ne = (nat_entry *)n->data;
		if(found_nat_table_match(ne, &pair, nat_type) == 1) {
			match_found = 1;
			break;
		}
		n = n->next;
	}

	if(match_found == 1) {
		return ne;
	}
	else {
		return NULL;
	}
}


void get_nat_ip_port_pair(nat_ip_port_pair *pair, const uint8_t *packet, unsigned int len, int nat_type) {

	assert(pair);
	bzero(pair, sizeof(nat_ip_port_pair));
	assert(packet);

	ip_hdr* ip = get_ip_hdr(packet, len);
	if(nat_type == NAT_EXTERNAL) {
		pair->ip.s_addr = ip->ip_dst.s_addr;
	}
	else if(nat_type == NAT_INTERNAL) {
		pair->ip.s_addr = ip->ip_src.s_addr;
	}


	nat_tcp_hdr *tcp = NULL;
	nat_udp_hdr *udp = NULL;
	nat_icmp_hdr *icmp = NULL;
	switch(ip->ip_p) {
		case IP_PROTO_TCP:
			tcp = get_nat_tcp_hdr(packet, len);
			if(nat_type == NAT_EXTERNAL) { pair->port = tcp->tcp_dport; }
			else if(nat_type == NAT_INTERNAL) { pair->port = tcp->tcp_sport; }
			break;

		case IP_PROTO_UDP:
			udp = get_nat_udp_hdr(packet, len);
			if(nat_type == NAT_EXTERNAL) { pair->port = udp->udp_dport; }
			else if(nat_type == NAT_INTERNAL) { pair->port = udp->udp_sport; }
			break;

		case IP_PROTO_ICMP:
			icmp = get_nat_icmp_hdr(packet, len);
			get_nat_port_from_icmp(pair, packet, len, nat_type);
			break;

		default:
			pair->ip.s_addr = 0;
			pair->port = 0;
			break;
	}

}


void get_nat_port_from_icmp(nat_ip_port_pair *pair, const uint8_t *packet, unsigned int len, int nat_type) {

	assert(pair);
	assert(packet);

	nat_icmp_hdr *icmp = get_nat_icmp_hdr(packet, len);

	if( (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {
		/* Use the identifier field as the port */
		pair->port = icmp->icmp_opt1;
	}
	else if( (icmp->icmp_type == ICMP_TYPE_TIME_EXCEEDED) || (icmp->icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) ) {

		ip_hdr *ip_data = get_ip_hdr_from_icmp_data(packet, len);
		if( (ip_data->ip_p == IP_PROTO_UDP) || (ip_data->ip_p == IP_PROTO_TCP) ) {

			/* Look into the icmp data payload for the port */
			uint16_t *ports = get_nat_port_list_from_icmp_data(packet, len);

			if(nat_type == NAT_EXTERNAL) { pair->port = (*ports); }
			else if(nat_type == NAT_INTERNAL) { pair->port = (*(ports+1)); }

		}
		else if( (ip_data->ip_p == IP_PROTO_ICMP) ) {

			/* Look into the icmp data payload for the identifier */
			pair->port = get_nat_echo_id_from_icmp_data(packet, len);

		}
	}
}



/* get the src port number from a TCP or UDP packet */
uint16_t get_src_port_number(const uint8_t *packet, unsigned int len, uint8_t ip_protocol) {

	nat_tcp_hdr *tcp = NULL;
	nat_udp_hdr *udp = NULL;

	switch(ip_protocol) {

		case IP_PROTO_TCP:
			tcp = get_nat_tcp_hdr(packet, len);
			return tcp->tcp_sport;

		case IP_PROTO_UDP:
			udp = get_nat_udp_hdr(packet, len);
			return udp->udp_sport;

		case IP_PROTO_ICMP:
			return get_src_port_number_from_icmp(packet, len);

		default:
			printf("Invalid IP PROTOCOL passed as argument\n");
			return 0;
	}
}

uint16_t get_src_port_number_from_icmp(const uint8_t *packet, unsigned int len) {
	nat_icmp_hdr *icmp = get_nat_icmp_hdr(packet, len);

	if( (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {
		/* Use the identifier field as the source port */
		return icmp->icmp_opt1;
	}
	else if( (icmp->icmp_type == ICMP_TYPE_TIME_EXCEEDED) || (icmp->icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) ) {
		/* Look into the icmp data payload for the source port */
		uint16_t *ports = get_nat_port_list_from_icmp_data(packet, len);
		return (*ports);
	}

	return 0;
}

int found_nat_table_match(nat_entry *ne, nat_ip_port_pair *nipp, int nat_type) {
	switch(nat_type) {
		case NAT_EXTERNAL:
			if( (ne->nat_ext.ip.s_addr == nipp->ip.s_addr) && (ne->nat_ext.port == nipp->port)) {
				return 1;
			}
			else {
				return 0;
			}

			break;
		case NAT_INTERNAL:

			if( (ne->nat_int.ip.s_addr == nipp->ip.s_addr) && (ne->nat_int.port == nipp->port)) {
				return 1;
			}
			else {
				return 0;
			}
			break;
		default:
			printf("Invalid NAT type argument cannot match the pair (ip, port) into the nat table\n");
			return 0;
			break;
	}
}


int is_unique_nat_ext_port(router_state *rs, uint16_t port) {

	node *n = rs->nat_table;
	while(n) {
		nat_entry *ne = (nat_entry *)n->data;
		if(ne->nat_ext.port == port) {
			return 0;
		}
		n = n->next;
	}
	return 1;
}


nat_tcp_hdr *get_nat_tcp_hdr(const uint8_t *packet, unsigned int len) {
	return (nat_tcp_hdr *)(packet + ETH_HDR_LEN + sizeof(ip_hdr));
}

nat_udp_hdr *get_nat_udp_hdr(const uint8_t *packet, unsigned int len) {
	return (nat_udp_hdr *)(packet + ETH_HDR_LEN + sizeof(ip_hdr));
}

nat_icmp_hdr *get_nat_icmp_hdr(const uint8_t *packet, unsigned int len) {
	return (nat_icmp_hdr *)(packet + ETH_HDR_LEN + sizeof(ip_hdr));
}

uint16_t *get_nat_port_list_from_icmp_data(const uint8_t *packet, unsigned int len) {
	return (uint16_t *)(packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(nat_icmp_hdr) + sizeof(ip_hdr));
}

ip_hdr *get_ip_hdr_from_icmp_data(const uint8_t *packet, unsigned int len) {
	return (ip_hdr*) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(nat_icmp_hdr));
}


nat_icmp_hdr *get_icmp_hdr_from_icmp_data(const uint8_t *packet, unsigned int len) {
	return (nat_icmp_hdr*) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(nat_icmp_hdr) + sizeof(ip_hdr));
}

uint16_t get_nat_echo_id_from_icmp_data(const uint8_t *packet, unsigned int len) {
	nat_icmp_hdr *icmp = (nat_icmp_hdr *) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(nat_icmp_hdr) + sizeof(ip_hdr));
	return icmp->icmp_opt1;
}

/* compute the checksum differences to be cached in a nat entry */
void compute_nat_checksums(nat_ip_port_pair *pair) {

	uint16_t *s_ptr = NULL;
	uint32_t sum = 0;
	uint16_t s_sum = 0;

	/* ip & port pair */
	s_ptr = (uint16_t *) (&(pair->ip.s_addr));
	sum = ntohs((*s_ptr)) + ntohs((*(s_ptr+1))) + ntohs(pair->port);
	sum = (sum >> 16) + (sum & 0xFFFF);
	sum += (sum >> 16);

	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);
	pair->checksum = htons(s_sum);


	/* ip */
	s_ptr = (uint16_t *) (&(pair->ip.s_addr));
	sum = ntohs((*s_ptr)) + ntohs((*(s_ptr+1)));
	sum = (sum >> 16) + (sum & 0xFFFF);
	sum += (sum >> 16);

	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);
	pair->checksum_ip = htons(s_sum);


	/* port */
	sum = pair->port;
	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);
	pair->checksum_port = s_sum;

}


/* returns network byte order checksum for nat packet */
uint16_t nat_checksum(uint16_t old, uint16_t pos, uint16_t neg) {

	uint16_t new = 0;
	uint32_t word = 0;

	word = old + pos;
	word = (word >> 16) + (word & 0xFFFF);
	word = word - neg;
	if(word > 0xFFFF) { word--; }
	new = (word & 0xFFFF);

	return new;
}



void cli_nat_help(router_state *rs, cli_request *req) {
	char *msg = "Usage: \n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tshow nat table\n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tnat set\n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tnat reset\n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tnat test\n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tnat add [ip_ext] [port_ext] [ip_int] [port_int]\n";
	send_to_socket(req->sockfd, msg, strlen(msg));

	msg = "\tnat del [ip_ext] [port_ext]\n";
	send_to_socket(req->sockfd, msg, strlen(msg));
}

void cli_show_nat_table(router_state *rs, cli_request *req) {

	char *info;
	unsigned int len;

	lock_nat_table(rs);
	sprint_nat_table(rs, &info, &len);
	send_to_socket(req->sockfd, info, len);
	free(info);
	unlock_nat_table(rs);
}


void cli_show_hw_nat_table(router_state *rs, cli_request *req) {

	char *info;
	unsigned int len;

	lock_nat_table(rs);
	sprint_hw_nat_table(rs, &info, &len);
	send_to_socket(req->sockfd, info, len);
	free(info);
	unlock_nat_table(rs);
}


void cli_nat_set(router_state *rs, cli_request *req) {

	char *iface;
	char *msg;

	if(sscanf(req->command, "nat set %as", &iface) != 1) {
		msg = "Failure reading arguments\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	if( (strncmp(iface, ETH0, strlen(ETH0)) == 0) || (strncmp(iface, ETH1, strlen(ETH1)) == 0) ||
	    (strncmp(iface, ETH2, strlen(ETH2)) == 0) || (strncmp(iface, ETH3, strlen(ETH3)) == 0)   ) {

		lock_if_list_wr(rs);
		iface_entry *ie = get_iface(rs, iface);
		ie->is_wan = 1;

		if (rs->is_netfpga) {
			/*
				int oneHotPort = getOneHotPortNumber(iface);
				writeReg(&rs->netfpga, ROUTER_OP_LUT_NAT_WAN_INTERFACE, oneHotPort);
			*/
		}

		unlock_if_list(rs);

		msg = calloc(80, sizeof(char));
		snprintf(msg, 80, "Succefully set %s as the wan interface\n", iface);
		send_to_socket(req->sockfd, msg, strlen(msg));
		free(msg);

	} else if (strncmp(iface, "off", strlen("off")) == 0) {
		lock_if_list_wr(rs);
		node* cur = rs->if_list;
		while (cur) {
			iface_entry* iface = (iface_entry*)cur->data;
			iface->is_wan = 0;
			cur = cur->next;
		}

		if (rs->is_netfpga) {
			//writeReg(&rs->netfpga, ROUTER_OP_LUT_NAT_WAN_INTERFACE, 0);
		}

		unlock_if_list(rs);
		msg = "Successfully disabled NAT\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
  } else {
		msg = "Invalid arguments\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

}



void cli_nat_reset(router_state *rs, cli_request *req) {

	lock_nat_table(rs);
	/* blast out the software nat table */
	node* cur = rs->nat_table;
	node* next;
	while(cur) {
		next = cur->next;
		node_remove(&rs->nat_table, cur);
		cur = next;
	}

	/* blast out the hw nat table */
	int i;
	for (i = 0; i < 16; ++i) {
		write_nat_table_zero_to_hw(rs, i);
	}

	unlock_nat_table(rs);

	char *msg = "NAT table deleted\n";
	send_to_socket(req->sockfd, msg, strlen(msg));
}


void cli_nat_add(router_state *rs, cli_request *req) {

	char *ip_ext;
	char *ip_int;
	int port_ext;
	int port_int;
	char *msg;

	if(sscanf(req->command, "nat add %as %d %as %d", &ip_ext, &port_ext, &ip_int, &port_int) != 4) {
		msg = "Failure reading arguments.\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	/* build the nat entry */
	nat_entry *ne = (nat_entry *)calloc(1, sizeof(nat_entry));
	if(inet_pton(AF_INET, ip_ext, &(ne->nat_ext.ip)) != 1) {
		msg = "Failure reading ip ext argument\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}
	if(inet_pton(AF_INET, ip_int, &(ne->nat_int.ip)) != 1) {
		msg = "Failure reading ip int argument\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	ne->nat_ext.port = htons((uint16_t)port_ext);
	ne->nat_int.port = htons((uint16_t)port_int);
	ne->is_static = 1;
	ne->hits = 0;
	time(&ne->last_hits_time);
	ne->last_hits = 0;
	ne->avg_hits_per_second = 0.0;
	ne->hw_row = 0xFF;

	/* PROBLEM: IF I USE THE compute_nat_checksums FUNCTION INSTEAD THE TCP CHECKSUM FAILS */
	/*
	ne->nat_ext.checksum = compute_nat_ip_port_checksum(&(ne->nat_ext));
	ne->nat_int.checksum = compute_nat_ip_port_checksum(&(ne->nat_int));
	*/

	compute_nat_checksums(&(ne->nat_ext));
	compute_nat_checksums(&(ne->nat_int));

	/* check if an existing NAT entry matches this external ip/port */
	lock_nat_table(rs);

	node* cur = rs->nat_table;
	node* result = NULL;
	while (cur) {
		nat_entry* ne_existing = (nat_entry*)cur->data;
		if ((ne_existing->nat_ext.ip.s_addr == ne->nat_ext.ip.s_addr) &&
				(ne_existing->nat_ext.port == ne->nat_ext.port)) {

			result = cur;
			break;
		}
		cur = cur->next;
	}

	/* if there is an existing entry, swap data */
	if (result) {
		free(result->data);
		result->data = ne;
	} else {
		/* else append */
		node *n = (node *)calloc(1, sizeof(node));
		n->data = (void *)ne;

		if (rs->nat_table == NULL) {
			rs->nat_table = n;
		}	else {
			node_push_back(rs->nat_table, n);
		}
	}

	unlock_nat_table(rs);

	/* signal the thread that we have a new entry */
	pthread_cond_broadcast(rs->nat_table_cond);

	msg = "Succesfully added the nat table entry\n";
	send_to_socket(req->sockfd, msg, strlen(msg));
}

void cli_nat_del(router_state *rs, cli_request *req) {

	char *ip_ext;
	int port_ext;
	struct in_addr ip;
	uint16_t port;
	char *msg;

	if(sscanf(req->command, "nat del %as %d", &ip_ext, &port_ext) != 2) {
		msg = "Failure reading arguments.\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	/* build the nat entry */
	if(inet_pton(AF_INET, ip_ext, &(ip)) != 1) {
		msg = "Failure reading ip ext argument\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	port = htons((uint16_t)port_ext);

	/* check if an existing NAT entry matches this external ip/port */
	lock_nat_table(rs);

	node* cur = rs->nat_table;
	node* result = NULL;
	while (cur) {
		nat_entry* ne_existing = (nat_entry*)cur->data;
		if ((ne_existing->nat_ext.ip.s_addr == ip.s_addr) &&
				(ne_existing->nat_ext.port == port)) {

			result = cur;
			break;
		}
		cur = cur->next;
	}

	/* if there is an existing entry delete */
	if (result) {
		node_remove(&rs->nat_table, result);
	}

	unlock_nat_table(rs);

	/* signal the thread that we have a new entry */
	pthread_cond_broadcast(rs->nat_table_cond);

	if (result) {
		msg = "Succesfully deleted nat table entry\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
	} else {
		msg = "No nat table entry found\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
	}
}

void* nat_maintenance_thread(void* arg) {
	router_state* rs = (router_state*)arg;
	struct timespec wake_up_time;
	struct timeval cur_timeval;
	time_t now;

	while (1) {
		/* Determine the time when to wake up next */
		gettimeofday(&cur_timeval, NULL);
		wake_up_time.tv_sec = cur_timeval.tv_sec + 1;
		wake_up_time.tv_nsec = cur_timeval.tv_usec;

		/* sleep */
		pthread_cond_timedwait(rs->dijkstra_cond, rs->dijkstra_mutex, &wake_up_time);

		/* update our current time */
		time(&now);

		/* update the rolling average, get hits from hw if exist */
		node* cur = rs->nat_table;
		node* next;
		while (cur) {
			next = cur->next;
			nat_entry* ne = (nat_entry*)cur->data;

			/*
			if (rs->is_netfpga && (ne->hw_row != 0xFF)) {
				ne->hits += (get_hw_hits(rs, ne->hw_row) - ne->last_hits);
			}
			*/

			/* update our moving average */
			double cur_avg = ((double)(ne->hits - ne->last_hits)) / difftime(now, ne->last_hits_time);
			ne->avg_hits_per_second = (0.75 * cur_avg) + (0.25 * ne->avg_hits_per_second);

			/* update last hits */
			if (ne->last_hits != ne->hits) {
				ne->last_hits_time = now;
				ne->last_hits = ne->hits;
			}

			/* expire if not hits for a long time */
			if (!ne->is_static && (difftime(now, ne->last_hits_time) > rs->nat_timeout)) {
				node_remove(&rs->nat_table, cur);
			}

			/* reset the hw row because we will be pushing back down to hw shortly */
			ne->hw_row = 0xFF;

			cur = next;
		}

		/* bubble sort by avg hits per second */
		int swapped = 0;
		do {
			swapped = 0;
			node* cur = rs->nat_table;
			while (cur && cur->next) {
				nat_entry* a = (nat_entry*)cur->data;
				nat_entry* b = (nat_entry*)cur->next->data;
				if (a->avg_hits_per_second < b->avg_hits_per_second) {
					cur->data = b;
					cur->next->data = a;
					swapped = 1;
				}

				cur = cur->next;
			}
		} while (swapped);

		/* write to hw if we are running hw */
		if (rs->is_netfpga) {
			int i = 0;
			node* cur = rs->nat_table;

  		for(i=0; i<16; ++i) {
	  		if(cur) {
	    		nat_entry *nat = (nat_entry *)cur->data;
	    		nat->hw_row = i;
					write_nat_table_entry_to_hw(rs, nat, i);
					cur = cur->next;
				} else {
					write_nat_table_zero_to_hw(rs, i);
				}
			}
		}
	}
	return NULL;
}

uint32_t get_hw_hits(router_state *rs, uint8_t row) {

	uint32_t hits = 0;

	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_RD_ADDR_REG, row);
	//readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_HIT_REG, &hits);

	return hits;
}


void write_nat_table_entry_to_hw(router_state *rs, nat_entry *nat, uint8_t row) {

	/* write int ip */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_IP_REG, ntohl(nat->nat_int.ip.s_addr));
	/* write int port */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_PORT_REG, ntohs(nat->nat_int.port));
	/* write int checksum */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_CHKSUM_REG, ntohs(nat->nat_int.checksum));
	/* write ext ip */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_IP_REG, ntohl(nat->nat_ext.ip.s_addr));
	/* write ext port */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_PORT_REG, ntohs(nat->nat_ext.port));
	/* write ext checksum */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_CHKSUM_REG, ntohs(nat->nat_ext.checksum));
	/* write the numbe of hits */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_HIT_REG, ntohl(nat->hits));
	/* write the row number */
	//writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_WR_ADDR_REG, row);

}


void write_nat_table_zero_to_hw(router_state *rs, uint8_t row) {
	/*
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_IP_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_PORT_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_CHKSUM_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_IP_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_PORT_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_CHKSUM_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_HIT_REG, 0);
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_WR_ADDR_REG, row);
	*/
}


void lock_nat_table(router_state *rs) {
	assert(rs);
	if(pthread_mutex_lock(rs->nat_table_mutex) != 0) {
		perror("Failure getting nat table lock");
	}
}

void unlock_nat_table(router_state *rs) {
	assert(rs);
	if(pthread_mutex_unlock(rs->nat_table_mutex) != 0) {
		perror("Failure unlocking nat table lock");
	}
}

