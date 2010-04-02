/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "or_utils.h"
#include "or_nat.h"
#include "or_data_types.h"
#include "or_output.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#ifdef _NOLWIP_
	#include <unistd.h>
#else
	#define LWIP_COMPAT_SOCKETS
	#include "lwip/sockets.h"
#endif


node* node_create(void) {
	node* n = (node*)malloc(sizeof(node));
	bzero(n, sizeof(node));
	return n;
}

void node_push_back(node* head, node* n) {
	node* cur = head;
	while (cur->next != NULL) {
		cur = cur->next;
	}
	cur->next = n;
	n->prev = cur;
}

void node_remove(node** head, node* n) {

	/* list has only one element */
	if(n->next == NULL && n->prev == NULL) {
		*head = NULL;
		free(n->data);
		free(n);
		return;
	}

	/* remove first element of the list */
	if(n->prev == NULL) {
		*head = n->next;
		(*head)->prev = NULL;

		free(n->data);
		free(n);
		return;
	}

	/* remove last element of the list */
	if(n->next == NULL) {
		n->prev->next = NULL;

		free(n->data);
		free(n);
		return;
	}

	/* remove an enterior element */
	n->prev->next = n->next;
	n->next->prev = n->prev;

	free(n->data);
	free(n);
}

int node_length(node* head) {
	int len = 0;
	node *walker = head;

	while(walker) {
		len++;
		walker = walker->next;
	}

	return len;
}


void populate_eth_hdr(eth_hdr* ether_hdr, uint8_t* dhost, uint8_t *shost, uint16_t type) {
	if (dhost) {
		memcpy(ether_hdr->eth_dhost, dhost, ETH_ADDR_LEN);
	}
	memcpy(ether_hdr->eth_shost, shost, ETH_ADDR_LEN);
	ether_hdr->eth_type = htons(type);
}

void populate_arp_hdr(arp_hdr* arp_header, uint8_t* arp_tha, uint32_t arp_tip, uint8_t* arp_sha, uint32_t arp_sip, uint16_t op) {

	arp_header->arp_hrd = htons(ARP_HRD_ETHERNET);
	arp_header->arp_pro = htons(ARP_PRO_IP);
	arp_header->arp_hln = ETH_ADDR_LEN;
	arp_header->arp_pln = 4;
	arp_header->arp_op = htons(op);

	memcpy(arp_header->arp_sha, arp_sha, ETH_ADDR_LEN);
	arp_header->arp_sip.s_addr = arp_sip;
	if(arp_tha != NULL) {
		memcpy(arp_header->arp_tha, arp_tha, ETH_ADDR_LEN);
	}
	arp_header->arp_tip.s_addr = arp_tip;
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

/*
 * Populates the ICMP header and its payload.  You must set the checksum yourself. *
 */
void populate_icmp(icmp_hdr* icmp, uint8_t icmp_type, uint8_t icmp_code, uint8_t* payload, int payload_len) {
	bzero(icmp, sizeof(icmp_hdr));
	icmp->icmp_type = icmp_type;
	icmp->icmp_code = icmp_code;

	uint8_t* p = (uint8_t*)icmp;
	p += sizeof(icmp_hdr);
	memcpy(p, payload, payload_len);
}

void populate_pwospf(pwospf_hdr*pwospf, uint8_t type, uint16_t len, uint32_t rid, uint32_t aid) {
	bzero(pwospf, sizeof(pwospf_hdr));
	pwospf->pwospf_ver = PWOSPF_VERSION;
	pwospf->pwospf_type = type;
	pwospf->pwospf_len = htons(len);
	pwospf->pwospf_rid = rid;
	pwospf->pwospf_aid = htonl(aid);
}


void populate_pwospf_hello(pwospf_hello_hdr* hello, uint32_t mask, uint16_t helloint) {
	bzero(hello, sizeof(pwospf_hello_hdr));
	hello->pwospf_mask.s_addr = mask;
	hello->pwospf_hint = htons(helloint);
	hello->pwospf_pad = 0x0;
}


void populate_pwospf_lsu(pwospf_lsu_hdr* lsu, uint16_t seq, uint32_t num) {
	bzero(lsu, sizeof(pwospf_lsu_hdr));
	lsu->pwospf_seq = htons(seq);
	lsu->pwospf_ttl = htons(64);
	lsu->pwospf_num = htonl(num);
}


/*
 * Populate padding
 */
void populate_padding(uint8_t *start, unsigned int len) {
	int i;
    uint8_t pad = 1;
    for(i=0; i<len; i++) {
		start[i] = pad;
        pad++;
	}
}


/*
 * Overwrite the ip and port of a packet for nat
 */
void populate_nat_packet(ip_hdr *ip, const uint8_t *packet, unsigned int len, nat_entry *ne, int nat_type) {
	nat_tcp_hdr *tcp = NULL;
	nat_udp_hdr *udp = NULL;
	nat_icmp_hdr *icmp = NULL;

	/* rewrite the ip address */
	if(nat_type == NAT_EXTERNAL) { ip->ip_src.s_addr = ne->nat_ext.ip.s_addr; }
       	else if(nat_type == NAT_INTERNAL) { ip->ip_dst.s_addr = ne->nat_int.ip.s_addr; }

	switch(ip->ip_p) {

		case IP_PROTO_TCP:
			tcp = get_nat_tcp_hdr(packet, len);
			if(nat_type == NAT_EXTERNAL) { tcp->tcp_sport = ne->nat_ext.port; }
			else if(nat_type == NAT_INTERNAL) { tcp->tcp_dport = ne->nat_int.port; }
			break;

		case IP_PROTO_UDP:
			udp = get_nat_udp_hdr(packet, len);
			if(nat_type == NAT_EXTERNAL) { udp->udp_sport = ne->nat_ext.port; }
			else if(nat_type == NAT_INTERNAL) { udp->udp_dport = ne->nat_int.port; }
			break;

		case IP_PROTO_ICMP:

			icmp = get_nat_icmp_hdr(packet, len);
			if( (icmp->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {
				/* overwrite the identifier */
				if(nat_type == NAT_EXTERNAL) { icmp->icmp_opt1 = ne->nat_ext.port; }
				else if(nat_type == NAT_INTERNAL) { icmp->icmp_opt1 = ne->nat_int.port; }
			}
			else if( (icmp->icmp_type == ICMP_TYPE_TIME_EXCEEDED) || (icmp->icmp_type == ICMP_TYPE_DESTINATION_UNREACHABLE) ) {

				/* overwrite the ip and ip sum inside the icmp data */
				uint16_t checksum = 0;
				ip_hdr *data_ip = get_ip_hdr_from_icmp_data(packet, len);


				if(nat_type == NAT_EXTERNAL) {
					data_ip->ip_dst.s_addr = ne->nat_ext.ip.s_addr;
					checksum = nat_checksum(data_ip->ip_sum, ne->nat_ext.checksum_ip, ne->nat_int.checksum_ip);
				}
				else if(nat_type == NAT_INTERNAL) {
					data_ip->ip_src.s_addr = ne->nat_int.ip.s_addr;
					checksum = nat_checksum(data_ip->ip_sum, ne->nat_int.checksum_ip, ne->nat_ext.checksum_ip);
				}
				bzero(&ip->ip_sum, sizeof(uint16_t));
				data_ip->ip_sum = checksum;


				if( (data_ip->ip_p == IP_PROTO_TCP) || (data_ip->ip_p == IP_PROTO_UDP) ) {

					/* overwrite the port inside the icmp data */
					uint16_t *ports = get_nat_port_list_from_icmp_data(packet, len);
					if(nat_type == NAT_EXTERNAL) { *(ports+1) = ne->nat_ext.port; }
					else if(nat_type == NAT_INTERNAL) { *ports = ne->nat_int.port; }
				}
				else if( data_ip->ip_p == IP_PROTO_ICMP ) {
					nat_icmp_hdr *icmp_data = get_icmp_hdr_from_icmp_data(packet, len);

					/* overwrite the id and checksum of the original echo packet */
					if( (icmp_data->icmp_type == ICMP_TYPE_ECHO_REQUEST) || (icmp_data->icmp_type == ICMP_TYPE_ECHO_REPLY) ) {
						if(nat_type == NAT_EXTERNAL) {
							icmp_data->icmp_opt1 = ne->nat_ext.port;
							checksum = nat_checksum(icmp_data->icmp_sum, ne->nat_ext.checksum_port, ne->nat_int.checksum_port);
						}
						else if(nat_type == NAT_INTERNAL) {
							icmp_data->icmp_opt1 = ne->nat_int.port;
							checksum = nat_checksum(icmp_data->icmp_sum, ne->nat_int.checksum_port, ne->nat_ext.checksum_port);
						}

						bzero(&icmp_data->icmp_sum, sizeof(uint16_t));
						icmp_data->icmp_sum = checksum;
					}
				}
			}
			break;

		default:
			printf("Invalid IP protocol found in the ip header while overwriting the packet with nat entries\n");
			break;
	}
}



/*
 * Helper function for register_cli_command
 * Takes a given string c, mallocs memory from the heap, copies it to the memory, and returns it
 */
char* mallocCopy(const char* c) {
	char* retval = (char *)calloc(strlen(c)+1, sizeof(char));
	strncpy(retval, c, strlen(c));
	return retval;
}

/*
 * Helper function for register_cli_command
 * Creates a cli_entry from command and handler
 */
cli_entry* create_cli_entry(char* command, cli_command_handler handler) {
	cli_entry* entry = (cli_entry*)malloc(sizeof(cli_entry));
	entry->command = mallocCopy(command);
	entry->handler = handler;
	return entry;
}

void register_cli_command(node** head, char* command, cli_command_handler handler) {
	node* n = node_create();
	n->data = create_cli_entry(command, handler);

	if (!(*head)) {
		(*head) = n;
	} else {
		node_push_back(*head, n);
	}
}

void cleanCRLFs(char* c) {
 int i;
 int len = strlen(c);
 for (i = 0; i < len; ++i) {
 	if (('\r' == c[i]) || ('\n' == c[i])) {
 		c[i] = '\0';
 	}
 }
}

void send_to_socket(int sockfd, char *buf, int len) {

	if(send(sockfd, buf, len, 0) == -1 ) {
		printf("send(cli output) error %d\n", len);
	}
}

char* my_strncat(char* left, char* right, int* left_alloc_size) {
	int size = *left_alloc_size;
	while ((strlen(left) + strlen(right) + 1) > size) {
		size *= 2;
		if ((left = realloc(left, size)) == 0) {
			perror("failure allocating memory for strncat");
			exit(1);
		}
	}

	strncat(left, right, strlen(right) + 1);

	*left_alloc_size = size;
	return left;
}

char* urlencode(char* str) {
	// going to be lazy here and triple it, worst case
	char* ret = malloc((3*strlen(str)) + 1);
	int len = strlen(str);
	int i = 0;
	int pos = 0;
	for (i = 0; i < len; ++i) {
		char c = str[i];
		if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
			ret[pos] = c;
			++pos;
		} else {
			ret[pos] = '%';
			// convert high order byte to hex
			char buf[2];
			sprintf(buf, "%X", ((c >> 4) & 0x0F));
			ret[pos+1] = buf[0];
			// lower order byte
			sprintf(buf, "%X", (c & 0x0F));
			ret[pos+2] = buf[0];
			pos += 3;
		}
	}
	ret[pos] = '\0';

	return ret;
}

char* urldecode(char* str) {
	// going to be lazy here and just duplicate it, worst case
	char* ret = malloc(strlen(str) + 1);
	int len = strlen(str);
	int i = 0;
	int pos = 0;
	for (i = 0; i < len; ++i) {
		char c = str[i];
		if ((c == '%') && ((i+2) < len)) {
			char buf[2];
			buf[0] = str[i+1];
			buf[1] = '\0';
			int high = 0;
			sscanf(buf, "%X", &high);
			int low = 0;
			buf[0] = str[i+2];
			sscanf(buf, "%X", &low);

			ret[pos] = (high << 4) | low;
			pos++;
			i += 2;
		} else if (c == '+') {
			ret[pos] = ' ';
			++pos;
		} else {
			ret[pos] = c;
			++pos;
		}
	}
	ret[pos] = '\0';

	return ret;
}

int getMax(int* int_array, int len) {
	int i;
	int max = INT32_MIN;
	for (i = 0; i < len; ++i) {
		if (int_array[i] > max) {
			max = int_array[i];
		}
	}

	return max;
}
