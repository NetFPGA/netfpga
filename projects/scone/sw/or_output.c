/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "assert.h"
#include "string.h"
#include "stdlib.h"
#include "time.h"

#include "or_output.h"
#include "or_data_types.h"
#include "or_arp.h"
#include "or_ip.h"
#include "or_icmp.h"
#include "or_main.h"
#include "or_utils.h"
#include "or_pwospf.h"
#include "or_iface.h"
#include "or_netfpga.h"
#include "reg_defines.h"
#include "or_nat.h"

/* GENERAL PRETTY PRINT HELPER FUNCTIONS */
inline void indent(unsigned int tab) {
	int i;
	for(i=0; i<tab; i++) {printf("\t");}
}

#define COPY_STRING(buf, len, str)	\
	memcpy(buf+len, str, strlen(str));	\
	len += strlen(str);


#define ARP_CACHE_COL "IP Address      MAC               TTL\n"
#define ARP_CACHE_ENTRY_TO_STRING_LEN 82

/* NOT THREAD SAFE */
void sprint_arp_cache(router_state *rs, char **buf, int *len)
{
	assert(rs);
	assert(buf);
	assert(len);

	node *arp_walker = 0;
	arp_cache_entry *arp_entry = 0;
	time_t now;
	double diff;
	char *buffer = 0;
	int total_len = 0;


	buffer = calloc(strlen(ARP_CACHE_COL) + ARP_CACHE_ENTRY_TO_STRING_LEN * node_length(rs->arp_cache), sizeof(char));
	COPY_STRING(buffer, total_len, ARP_CACHE_COL);

	arp_walker = rs->arp_cache;
	while(arp_walker)
	{
		arp_entry = (arp_cache_entry *)arp_walker->data;

		char addr[INET_ADDRSTRLEN];
		inet_ntop(AF_INET, &(arp_entry->ip), addr, INET_ADDRSTRLEN);

		char ttl[47];
		if (arp_entry->is_static == 0) {
			time(&now);
			diff = difftime(now, arp_entry->TTL);
			snprintf(ttl, 47, "%f", rs->arp_ttl - diff);
		} else {
			snprintf(ttl, 47, "%s", "static");
		}

		char line[ARP_CACHE_ENTRY_TO_STRING_LEN];
		snprintf(line, ARP_CACHE_ENTRY_TO_STRING_LEN, "%-15s %02X:%02X:%02X:%02X:%02X:%02X %-46s\n",
			addr, (unsigned char)arp_entry->arp_ha[0], (unsigned char)arp_entry->arp_ha[1], (unsigned char)arp_entry->arp_ha[2],
			(unsigned char)arp_entry->arp_ha[3], (unsigned char)arp_entry->arp_ha[4], (unsigned char)arp_entry->arp_ha[5],
			ttl);

		COPY_STRING(buffer, total_len, line);

		arp_walker = arp_walker->next;
	}

	*buf = buffer;
	*len = total_len;
}




#define IFACE_COL "Name                  MAC               IP              Mask            Speed Up WAN\n"
#define IFACE_ENTRY_TO_STRING_LEN 100
#define IFACE_MAX_IFACE_LEN 21


/* NOT THREAD SAFE */
void sprint_if_list(router_state *rs, char **buf, int *len)
{
	assert(rs);
	assert(buf);
	assert(len);

	node *iface_walker = 0;
	iface_entry *iface = 0;
	struct in_addr ip;
	struct in_addr mask;
	char *buffer = 0;
	int total_len = 0;

	char ip_str[16];
	char mask_str[16];

	buffer = calloc(strlen(IFACE_COL) + IFACE_ENTRY_TO_STRING_LEN * node_length(rs->if_list), sizeof(char));
	COPY_STRING(buffer, total_len, IFACE_COL);

	iface_walker = rs->if_list;
	while(iface_walker)
	{
		iface = (iface_entry *)iface_walker->data;

		char if_name[IFACE_MAX_IFACE_LEN+1];
		snprintf(if_name, IFACE_MAX_IFACE_LEN, "%s", iface->name);
		if_name[IFACE_MAX_IFACE_LEN] = '\0';

		ip.s_addr = iface->ip;
		mask.s_addr = iface->mask;

		char line[IFACE_ENTRY_TO_STRING_LEN];
		snprintf(line, IFACE_ENTRY_TO_STRING_LEN, "%-21s %02X:%02X:%02X:%02X:%02X:%02X %-15s %-15s %-5i %-2s %-2s\n",
			if_name, (unsigned char)iface->addr[0], (unsigned char)iface->addr[1], (unsigned char)iface->addr[2],
			(unsigned char)iface->addr[3], (unsigned char)iface->addr[4], (unsigned char)iface->addr[5],
			inet_ntop(AF_INET, &ip, ip_str, 16), inet_ntop(AF_INET, &mask, mask_str, 16), iface->speed,
			(iface->is_active == 1) ? "Y" : "N",
			(iface->is_wan == 1) ? "Y" : "N");


		COPY_STRING(buffer, total_len, line);

		iface_walker = iface_walker->next;
	}

	*buf = buffer;
	*len = total_len;

}

#define PWOSPF_IFACE_COL "Name IP                  Mask                LSH  NID                 NIP                 LRH  A\n"
#define PWOSPF_IFACE_ENTRY_TO_STRING_LEN 256
#define PWOSPF_IFACE_MAX_IFACE_LEN 21
/* NOT THREAD SAFE */
void sprint_pwospf_if_list(router_state *rs, char **buf, int *len)
{
	assert(rs);
	assert(buf);
	assert(len);

	node *iface_walker = 0;
	iface_entry *iface = 0;
	struct in_addr ip;
	bzero(&ip, sizeof(struct in_addr));
	struct in_addr mask;
	bzero(&mask, sizeof(struct in_addr));
	struct in_addr nid;
	bzero(&nid, sizeof(struct in_addr));
	struct in_addr nip;
	bzero(&nip, sizeof(struct in_addr));
	time_t now;
	double diff;
	char *buffer = 0;
	int total_len = 0;

	char ip_str[16];
	char mask_str[16];
	char nid_str[16];
	char nip_str[16];

	buffer = calloc(strlen(PWOSPF_IFACE_COL) + PWOSPF_IFACE_ENTRY_TO_STRING_LEN * node_length(rs->if_list), sizeof(char));
	COPY_STRING(buffer, total_len, PWOSPF_IFACE_COL);

	iface_walker = rs->if_list;
	while(iface_walker)
	{
		iface = (iface_entry *)iface_walker->data;

		char if_name[PWOSPF_IFACE_MAX_IFACE_LEN+1];
		snprintf(if_name, PWOSPF_IFACE_MAX_IFACE_LEN, "%s", iface->name);
		if_name[PWOSPF_IFACE_MAX_IFACE_LEN] = '\0';

		ip.s_addr = iface->ip;
		mask.s_addr = iface->mask;


		char lsent_hello[47];
		bzero(lsent_hello, 47);
		time(&now);
		diff = difftime(now, iface->last_sent_hello);
		if( (int)diff > rs->pwospf_hello_interval) {
			snprintf(lsent_hello, 47, "%s", "EXP");
		}
		else {
			snprintf(lsent_hello, 47, "%i", (int)diff);
		}

		char lrecv_hello[47];
		bzero(lrecv_hello, 47);
		time(&now);

		if (iface->nbr_routers) {
			nbr_router* nbr = (nbr_router*)iface->nbr_routers->data;

			nid.s_addr = nbr->router_id;
			nip.s_addr = nbr->ip.s_addr;
			diff = difftime(now, nbr->last_rcvd_hello);
			if( (int)diff > (3*rs->pwospf_hello_interval)) {
				snprintf(lrecv_hello, 47, "%s", "EXP");
			}
			else {
				snprintf(lrecv_hello, 47, "%i", (int)diff);
			}

		}


		char line[PWOSPF_IFACE_ENTRY_TO_STRING_LEN];
		snprintf(line, PWOSPF_IFACE_ENTRY_TO_STRING_LEN, "%-5s%-20s%-20s%-5s%-20s%-20s%-5s%-1s \n",
			if_name,
			inet_ntop(AF_INET, &ip, ip_str, 16), inet_ntop(AF_INET, &mask, mask_str, 16),
			lsent_hello,
			(nip.s_addr != 0) ? inet_ntop(AF_INET, &nid, nid_str, 16) : "", (nip.s_addr != 0) ? inet_ntop(AF_INET, &nip, nip_str, 16) : "",
			(nip.s_addr != 0) ? lrecv_hello : "",
			(iface->is_active == 1) ? "Y" : "N");

		COPY_STRING(buffer, total_len, line);

		/* iterate through any remaining neighbor routers */
		node* cur = iface->nbr_routers;
		/* advance one since we printed it above */
		if (cur) {
			cur = cur->next;
		}

		while (cur) {
			nbr_router* nbr = (nbr_router*)cur->data;

			nid.s_addr = nbr->router_id;
			nip.s_addr = nbr->ip.s_addr;
			diff = difftime(now, nbr->last_rcvd_hello);
			if( (int)diff > (3*rs->pwospf_hello_interval)) {
				snprintf(lrecv_hello, 47, "%s", "EXP");
			}
			else {
				snprintf(lrecv_hello, 47, "%i", (int)diff);
			}

			snprintf(line, PWOSPF_IFACE_ENTRY_TO_STRING_LEN, "%-5s%-20s%-20s%-5s%-20s%-20s%-5s%-1s \n",
				"",
				"", "",
				"",
				inet_ntop(AF_INET, &nid, nid_str, 16), inet_ntop(AF_INET, &nip, nip_str, 16),
				lrecv_hello,
				"");

			COPY_STRING(buffer, total_len, line);

			cur = cur->next;
		}



		iface_walker = iface_walker->next;
	}

	*buf = buffer;
	*len = total_len;

}


/* NOT THREAD SAFE */
#define PWOSPF_ROUTER_LIST_COL "RID                 AID  SEQ  LU   DIST SPF\n"
#define PWOSPF_ROUTER_LIST_TO_STRING_LEN 160
void sprint_pwospf_router_list(router_state *rs, char **buf, int *len) {

	assert(rs);
	assert(buf);
	assert(len);

	char *buffer = 0;
	int total_len = 0;
	time_t now;
	double diff;
	char rid_str[16];
	char subnet_str[16];
	char mask_str[16];

	int num_entries = 0;
	node *rl = rs->pwospf_router_list;
	while(rl) {

		pwospf_router *pr = (pwospf_router *)rl->data;
		node *pi = pr->interface_list;

		num_entries = num_entries + (1 + node_length(pi));
		rl = rl->next;
	}



	buffer = calloc(strlen(PWOSPF_ROUTER_LIST_COL) + (num_entries+1)*PWOSPF_ROUTER_LIST_TO_STRING_LEN, sizeof(char));
	COPY_STRING(buffer, total_len, PWOSPF_ROUTER_LIST_COL);


	node *router_list_walker = rs->pwospf_router_list;
	while(router_list_walker) {

		pwospf_router *rle = (pwospf_router *)router_list_walker->data;

		char last_update[47];
		bzero(last_update, 47);
		time(&now);
		diff = difftime(now, rle->last_update);
		if( (int)diff > (rs->pwospf_lsu_interval * 3) ) {
			snprintf(last_update, 47, "%s", "EXP");
		} else {
			snprintf(last_update, 47, "%i", (int)diff);
		}


		char line[PWOSPF_ROUTER_LIST_TO_STRING_LEN];
		bzero(line, PWOSPF_ROUTER_LIST_TO_STRING_LEN);
		snprintf(line, PWOSPF_ROUTER_LIST_TO_STRING_LEN, "%-20s%-5d%-5d%-5s%-5d%-5d\n",
			 inet_ntop(AF_INET, &(rle->router_id), rid_str, 16),
			 ntohl(rle->area_id),
			 rle->seq,
			 last_update,
			 rle->distance,
			 rle->shortest_path_found);
		COPY_STRING(buffer, total_len, line);

		node *interface_walker = rle->interface_list;
		while(interface_walker) {

			pwospf_interface *iface = (pwospf_interface *)interface_walker->data;

			bzero(line, PWOSPF_ROUTER_LIST_TO_STRING_LEN);
			snprintf(line, PWOSPF_ROUTER_LIST_TO_STRING_LEN, "          %-20s%-20s%-20s%-5i\n",
				 inet_ntop(AF_INET, &(iface->subnet), subnet_str, 16),
				 inet_ntop(AF_INET, &(iface->mask), mask_str, 16),
				 inet_ntop(AF_INET, &(iface->router_id), rid_str, 16),
				 iface->is_active);
			COPY_STRING(buffer, total_len, line);

			interface_walker = interface_walker->next;
		}

		router_list_walker = router_list_walker->next;
	}

	*buf = buffer;
	*len = total_len;
}




#define RTABLE_COL "Destination     Gateway         Mask            Iface              Static Active\n"
#define RTABLE_ENTRY_TO_STRING_LEN 82
#define RTABLE_MAX_IFACE_LEN 18

/* NOT THREAD SAFE */
void sprint_rtable(router_state *rs, char **buf, int *len)
{

	assert(rs);
	assert(buf);
	assert(len);

	node *rtable_walker = 0;
	rtable_entry *re = 0;
	char *buffer = 0;
	int total_len = 0;

	char ip_str[16];
	char gw_str[16];
	char mask_str[16];

	buffer = calloc(strlen(RTABLE_COL) + RTABLE_ENTRY_TO_STRING_LEN * node_length(rs->rtable), sizeof(char) );
	COPY_STRING(buffer, total_len, RTABLE_COL);

	rtable_walker = rs->rtable;
	while(rtable_walker) {
		re = (rtable_entry *)rtable_walker->data;

		char if_name[RTABLE_MAX_IFACE_LEN+1];
		snprintf(if_name, RTABLE_MAX_IFACE_LEN, "%s", re->iface);
		if_name[RTABLE_MAX_IFACE_LEN] = '\0';

		char line[RTABLE_ENTRY_TO_STRING_LEN];
		snprintf(line, RTABLE_ENTRY_TO_STRING_LEN, "%-15s %-15s %-15s %-18s %-6s %-6s\n",
			inet_ntop(AF_INET, &(re->ip), ip_str, 16), inet_ntop(AF_INET, &(re->gw), gw_str, 16),
			inet_ntop(AF_INET, &(re->mask), mask_str, 16), if_name,
			(re->is_static == 1) ? "Y" : "N", (re->is_active == 1) ? "Y" : "N");

		rtable_walker = rtable_walker->next;

		COPY_STRING(buffer, total_len, line);
	}

	*buf = buffer;
	*len = total_len;

}




void print_arp_queue(struct sr_instance *sr)
{
	assert(sr);

	printf("ARP QUEUE CONTENTS\n");
	printf("INTERFACE\tIP\t\tREQ_LEF\tHEAD\n");

	router_state *rs = get_router_state(sr);
	node *arp_walker = 0;
	arp_queue_entry *arp_entry = 0;

	arp_walker = rs->arp_queue;
	while(arp_walker)
	{

		arp_entry = (arp_queue_entry *)arp_walker->data;

		printf("%s\t\t", arp_entry->out_iface_name);
		char addr[INET_ADDRSTRLEN];
		printf("%-15s\t", inet_ntop(AF_INET, &(arp_entry->next_hop), addr, INET_ADDRSTRLEN));

		printf("%d\t%X\n", arp_entry->requests, (unsigned int)arp_walker->next);

		arp_walker = arp_walker->next;
	}
	printf("\n");

}



void print_sping_queue(struct sr_instance *sr)
{
	assert(sr);

	printf("\n\n*******\nSPING QUEUE CONTENTS\n");
	router_state *rs = get_router_state(sr);
	node *sping_walker = 0;
	sping_queue_entry *ae = 0;

	sping_walker = rs->sping_queue;
	while(sping_walker)
	{
		ae = (sping_queue_entry *)sping_walker->data;
		uint8_t *data =(uint8_t*) get_icmp_hdr(ae->packet, ae->len);
		data = data+sizeof(icmp_hdr);
		unsigned short *id = (unsigned short *)data;
		printf("%X\n", *id);

		sping_walker = sping_walker->next;
	}
}


#define NAT_COL "EXT IP          Port   INT IP          Port   Hits   LHits  HPS     LHits TDelta HW  S\n"
#define NAT_ENTRY_TO_STR_LEN 88
void sprint_nat_table(router_state *rs, char **buf, unsigned int *len) {

	char ext_ip_str[16];
	char int_ip_str[16];
	int nat_table_size = node_length(rs->nat_table);
	time_t now;
	uint32_t diff = 0;

	char *buffer = (char *)calloc(strlen(NAT_COL) + nat_table_size*NAT_ENTRY_TO_STR_LEN, sizeof(char));
	unsigned int total_len = 0;

	COPY_STRING(buffer, total_len, NAT_COL);

	node *n = rs->nat_table;
	while(n) {
		nat_entry *ne = (nat_entry *)n->data;

		char last_update[47];
		bzero(last_update, 47);
		time(&now);
		diff = (int)difftime(now, ne->last_hits_time);
		inet_ntop(AF_INET, &(ne->nat_ext.ip), ext_ip_str, 16);
		inet_ntop(AF_INET, &(ne->nat_int.ip), int_ip_str, 16);

		char line[NAT_ENTRY_TO_STR_LEN];
		bzero(line, NAT_ENTRY_TO_STR_LEN);
		snprintf(line, NAT_ENTRY_TO_STR_LEN, "%-15s %-6u %-15s %-6u %-6u %-6u %-7.2f %-12u %-3u %-1s\n",
				ext_ip_str,
				ntohs(ne->nat_ext.port),
				int_ip_str,
				ntohs(ne->nat_int.port),
				ne->hits,
				ne->last_hits,
				ne->avg_hits_per_second,
				diff,
				ne->hw_row,
				(ne->is_static == 1) ? "Y" : "N");
		COPY_STRING(buffer, total_len, line);

		n = n->next;
	}


	*buf = buffer;
	*len = total_len;
}






void print_packet(const uint8_t *packet, unsigned int len)
{

	assert(packet);

	printf("\n");
	print_eth_hdr(packet, len);
	printf("\n");

	eth_hdr *eth = (eth_hdr *)packet;
	if (ntohs(eth->eth_type) == ETH_TYPE_ARP) {
		print_arp_hdr(packet, len);
		printf("\n");
	} else if (ntohs(eth->eth_type) == ETH_TYPE_IP) {
		ip_hdr *ip = get_ip_hdr(packet, len);
		indent(1);
		printf("IPv4 Packet (%d bytes)\n", len - sizeof(eth_hdr));
		print_ip_hdr(packet, len);
		switch(ip->ip_p) {
			case 1:
			{ print_icmp_load(packet, len); break; }
			case 6:
			{ print_tcp_load(packet, len); break; }
			case 89:
			{ print_pwospf_load(packet, len); break; }
			default:
			{ printf("UNRECOGNIZABLE PROTOCOL\n"); break;}
		}
	}
}



/* PRETTY PRINT ETHERNET PACKET HEADER */

inline void print_mac_address(char *host, unsigned char *mac_addr) {
	assert(host);
	assert(mac_addr);

	printf("%s = ", host);
	int i;
	for(i=0; i<ETH_ADDR_LEN-1; i++) {printf("%X.", mac_addr[i]);}
	printf("%X\n", mac_addr[i]);
}

void print_eth_hdr(const uint8_t *packet, unsigned int len)
{
	assert(packet);

	eth_hdr *eth = (eth_hdr *)packet;

	printf("Ethernet Packet Header (%d bytes)\n", sizeof(eth_hdr));
	indent(1);
	print_mac_address("Src MAC Address", eth->eth_shost);
	indent(1);
	print_mac_address("Dst MAC Address", eth->eth_dhost);
	indent(1);
	if(ntohs(eth->eth_type) == ETH_TYPE_IP) {
		printf("Type = Internet Protocol, Version 4 (IPv4)\n");
	}
	if(ntohs(eth->eth_type) == ETH_TYPE_ARP) {
		printf("Type = Address Resolution Protocol (ARP)\n");
	}
}


/* PRETTY PRINT ARP PACKET HEADER */

void print_ip_address(char *host, struct in_addr ip_addr) {
	assert(host);
	char addr[INET_ADDRSTRLEN];
	printf("%s = %s\n", host, inet_ntop(AF_INET, &(ip_addr), addr, INET_ADDRSTRLEN));
}


void print_arp_hdr(const uint8_t *packet, unsigned int len)
{
	assert(packet);

	arp_hdr *arp = get_arp_hdr(packet, len);

	indent(1);
	printf("ARP Packet (%d bytes)\n", sizeof(arp_hdr));
	indent(2);
	printf("Hardware Type: ");
	switch(ntohs(arp->arp_hrd)) {
		case 1: { printf("Ethernet\n"); break; }
		default: { printf("%X\n", ntohs(arp->arp_hrd)); break; }
	}
	indent(2);
	printf("Protocol Type = %X (IP)\n", ntohs(arp->arp_pro));
	indent(2);
	printf("Hardware Address Length = %d\n", arp->arp_hln);
	indent(2);
	printf("Protocol Address Length = %d\n", arp->arp_pln);
	indent(2);
	printf("Opcode = ");
	switch(ntohs(arp->arp_op)) {
		case 1: { printf("Request\n"); break; }
		case 2: { printf("Reply\n"); break; }
		default: { printf("%X\n", arp->arp_op); break; }
	}
	indent(2);
	print_mac_address("Src Hardware Address", arp->arp_sha);
	indent(2);
	print_ip_address("Src Protocol Address", arp->arp_sip);
	indent(2);
	print_mac_address("Dst Hardware Address", arp->arp_tha);
	indent(2);
	print_ip_address("Dst Protocol Address", arp->arp_tip);
}


/* PRETTY PRINT IP PACKET HEADER */

void print_ip_hdr(const uint8_t *packet, unsigned int len)
{
	assert(packet);

	ip_hdr *ip = get_ip_hdr(packet, len);

	indent(1);
	printf("IPv4 Packet Header (%d bytes)\n", 4*ip->ip_hl);
	indent(2);
	printf("Version = %d\n", ip->ip_v);
	indent(2);
	printf("Header Length = %d\n", 4*ip->ip_hl);
	indent(2);
	printf("Terms of Service = 0x%X\n", ip->ip_tos);
	indent(2);
	printf("Total Length = %d\n", ntohs(ip->ip_len));
	indent(2);
	printf("Identification = 0x%X\n", ntohs(ip->ip_id));
	indent(2);
	printf("Fragment Offset Field = 0x%X\n", ntohs(ip->ip_off));
	indent(2);
	printf("TTL (Time to Live) = %d\n", ip->ip_ttl);
	indent(2);
	printf("Protocol = ");
	switch(ip->ip_p) {
		case 1: { printf("ICMP\n"); break; }
		case 6: { printf("TCP\n"); break; }
		default: { printf("%d\n", ip->ip_p); break; }
	}
	indent(2);
	printf("Header Checksum = 0x%X\n", ntohs(ip->ip_sum));
	indent(2);
	print_ip_address("Src IP Address", ip->ip_src);
	indent(2);
	print_ip_address("Dst IP Address", ip->ip_dst);
}


/* PRETTY PRINT ICMP PACKET HEADER */
void print_icmp_load(const uint8_t *packet, unsigned int len)
{
	assert(packet);

	icmp_hdr *icmp = get_icmp_hdr(packet, len);

	indent(1);
	printf("ICMP Packet Header (%d bytes)\n", sizeof(icmp_hdr));
	indent(2);
	switch(icmp->icmp_type) {
		case ICMP_TYPE_ECHO_REPLY:
		{
			printf("Type = Echo reply\n");
			indent(2);
			printf("Code = %d\n", icmp->icmp_code);
			break;
		}
		case ICMP_TYPE_ECHO_REQUEST:
		{
			printf("Type = Echo request\n");
			indent(2);
			printf("Code = %d\n", icmp->icmp_code);
			break;
		}
		case ICMP_TYPE_TIME_EXCEEDED:
		{
			printf("Type = Time exceeded\n");
			indent(2);
			printf("Code = %d\n", icmp->icmp_code);
			break;
		}
		case ICMP_TYPE_DESTINATION_UNREACHABLE:
		{
			printf("Type = Destination unreachable\n");
			indent(2);
			switch(icmp->icmp_code) {
				case 0:
				{
					printf("Code = Network unreachable\n error\n");
					break;
				}
				case 1:
				{
					printf("Code = Host unreachable error\n");
					break;
				}
				case 2:
				{
					printf("Code = Protocol unreachable error\n");
					break;
				}
				case 3:
				{
					printf("Code = Port unreachable error\n");
					break;
				}
			} /* end of switch(icmp->icmp_code)) */
			break;
		}
		default:
		{
			printf("Type = %d\n", icmp->icmp_type);
			indent(2);
       			printf("Code = %d\n", icmp->icmp_code);
			break;
		}
	}/* end of switch(icmp->icmp_type)) */
	indent(2);
	printf("Checksum = 0x%X\n", htons(icmp->icmp_sum));

	indent(2);
 	uint8_t* data = (uint8_t *) icmp;
	data += sizeof(icmp_hdr);
	int data_len = len - (sizeof(eth_hdr)+sizeof(ip_hdr)+sizeof(icmp_hdr));
	printf("\nPayload 1(%d bytes)\n", data_len);
	int i; for(i=0; i<data_len; i++)
	{ printf("%X ", data[i]); }
	printf("\n\n");
}




/* PRETTY PRINT TCP PACKET HEADER */
void print_tcp_load(const uint8_t *packet, unsigned int len) {

	unsigned int data_offset = sizeof(eth_hdr) + sizeof(ip_hdr);
	unsigned int data_len = len - data_offset;
	const uint8_t *data = packet + data_offset;

	indent(2);
	printf("\nTCP PACKET in HEX (%d bytes)\n", data_len);
	nat_tcp_hdr *tcp = get_nat_tcp_hdr(packet, len);
	indent(3);
	printf("Src Port = %d\n", ntohs(tcp->tcp_sport));
	indent(3);
	printf("Dst Port = %d\n", ntohs(tcp->tcp_dport));
	indent(3);
	printf("Seq # = %X\n", ntohl(tcp->tcp_seq));
	indent(3);
	printf("Acq # = %X\n", ntohl(tcp->tcp_ack));
	indent(3);
	printf("Unused = %X %X %X %X\n", tcp->unused1[0], tcp->unused1[1], tcp->unused1[2], tcp->unused1[3]);
	indent(3);
	printf("Sum = %X\n", tcp->tcp_sum);
	indent(3);
	printf("Unused = %X %X\n", tcp->unused2[0], tcp->unused2[1]);

	printf("\n");
	int i; for(i=0; i<data_len; i++){ printf("%X ", data[i]); }
	printf("\n\n");
}



/* PRETTY PRINT PWOSPF PACKET */
void print_pwospf_load(const uint8_t *packet, unsigned int len) {

	pwospf_hdr *pwospf = get_pwospf_hdr(packet, len);
	struct in_addr ip_addr;

	indent(1);
	printf("PWOSPFv2 Packet Header (%d bytes)\n", ntohs(pwospf->pwospf_len));
	indent(2);
 	printf("Version = %d\n", pwospf->pwospf_ver);
	indent(2);
	printf("Type = %d\n", pwospf->pwospf_type);
	indent(2);
	printf("Length = %d\n", ntohs(pwospf->pwospf_len));
	indent(2);
	ip_addr.s_addr = pwospf->pwospf_rid;
	print_ip_address("Router ID", ip_addr);
	indent(2);
	printf("Area ID = %X\n", ntohl(pwospf->pwospf_aid));
	indent(2);
	printf("Checksum = %X\n", ntohs(pwospf->pwospf_sum));
	indent(2);
	printf("Autype = %d\n", ntohs(pwospf->pwospf_atype));
	indent(2);
	printf("Authentication = %X\n", ntohl(pwospf->pwospf_auth1));
	indent(2);
	printf("Authentication = %X\n", ntohl(pwospf->pwospf_auth2));


	switch(pwospf->pwospf_type) {

		case PWOSPF_TYPE_HELLO:
		{
			pwospf_hello_hdr *hello = get_pwospf_hello_hdr(packet, len);

			indent(2);
			print_ip_address("Net Mask", hello->pwospf_mask);
			indent(2);
			printf("HelloInt = %d\n", ntohs(hello->pwospf_hint));
			indent(2);
			printf("Padding = %X\n", hello->pwospf_pad);

			break;
		}

		case PWOSPF_TYPE_LINK_STATE_UPDATE:
		{
			pwospf_lsu_hdr *lsu = get_pwospf_lsu_hdr(packet, len);
			pwospf_lsu_adv *iface_adv = (pwospf_lsu_adv *)get_pwospf_lsu_data(packet, len);

			indent(2);
			printf("Sequence = %d\n", ntohs(lsu->pwospf_seq));
			indent(2);
			printf("TTL = %d\n", ntohs(lsu->pwospf_ttl));
			indent(2);
			printf("No. of Adverisements = %d\n", ntohl(lsu->pwospf_num));

			int i;
			for(i=0; i < ntohl(lsu->pwospf_num); i++) {
				indent(2);
				printf("Advertisement #%d\n", i);
				indent(3);
				print_ip_address("Subnet", iface_adv->pwospf_sub);
				indent(3);
				print_ip_address("Mask", iface_adv->pwospf_mask);
				indent(3);
				ip_addr.s_addr = iface_adv->pwospf_rid;
				print_ip_address("Router ID", ip_addr);

				/* next advertisment */
				iface_adv += 1;
			}

			break;
		}

		default:
			indent(2);
			printf("Invalid PWOSPF Type\n");
	}

}




void print_pwospf(pwospf_hdr *pwospf) {

	struct in_addr ip_addr;

	indent(1);
	printf("PWOSPFv2 Packet Header (%d bytes)\n", ntohs(pwospf->pwospf_len));
	indent(2);
 	printf("Version = %d\n", pwospf->pwospf_ver);
	indent(2);
	printf("Type = %d\n", pwospf->pwospf_type);
	indent(2);
	printf("Length = %d\n", ntohs(pwospf->pwospf_len));
	indent(2);
	ip_addr.s_addr = pwospf->pwospf_rid;
	print_ip_address("Router ID", ip_addr);
	indent(2);
	printf("Area ID = %X\n", ntohl(pwospf->pwospf_aid));
	indent(2);
	printf("Checksum = %X\n", ntohs(pwospf->pwospf_sum));
	indent(2);
	printf("Autype = %d\n", ntohs(pwospf->pwospf_atype));
	indent(2);
	printf("Authentication = %X\n", ntohl(pwospf->pwospf_auth1));
	indent(2);
	printf("Authentication = %X\n", ntohl(pwospf->pwospf_auth2));


	switch(pwospf->pwospf_type) {

		case PWOSPF_TYPE_HELLO:
		{
			pwospf_hello_hdr *hello = (pwospf_hello_hdr *) (  ((uint8_t *)pwospf) + sizeof(pwospf_hdr) );

			indent(2);
			print_ip_address("Net Mask", hello->pwospf_mask);
			indent(2);
			printf("HelloInt = %d\n", ntohs(hello->pwospf_hint));
			indent(2);
			printf("Padding = %X\n", hello->pwospf_pad);

			break;
		}

		case PWOSPF_TYPE_LINK_STATE_UPDATE:
		{

			pwospf_lsu_hdr *lsu = (pwospf_lsu_hdr *) (  ((uint8_t *)pwospf) + sizeof(pwospf_hdr) );
			pwospf_lsu_adv *iface_adv = (pwospf_lsu_adv *) ( ((uint8_t *)lsu) + sizeof(pwospf_lsu_hdr) );

			indent(2);
			printf("Sequence = %d\n", ntohs(lsu->pwospf_seq));
			indent(2);
			printf("TTL = %d\n", ntohs(lsu->pwospf_ttl));
			indent(2);
			printf("No. of Adverisements = %d\n", ntohl(lsu->pwospf_num));

			int i;
			for(i=0; i < ntohl(lsu->pwospf_num); i++) {
				indent(2);
				printf("Advertisement #%d\n", i);
				indent(3);
				print_ip_address("Subnet", iface_adv->pwospf_sub);
				indent(3);
				print_ip_address("Mask", iface_adv->pwospf_mask);
				indent(3);
				ip_addr.s_addr = iface_adv->pwospf_rid;
				print_ip_address("Router ID", ip_addr);

				/* next advertisment */
				iface_adv += 1;
			}

			break;
		}

		default:
			indent(2);
			printf("Invalid PWOSPF Type\n");
	}

}



#define HW_RTABLE_COL "ROW  IP                  GW                  MASK                IFACE\n"
#define HW_RTABLE_ENTRY_TO_STRING_LEN 160
void sprint_hw_rtable(router_state *rs, char **buffer, unsigned int *len) {

	struct in_addr ip;
	struct in_addr mask;
	struct in_addr gw;
	char ip_str[16];
	char mask_str[16];
	char gw_str[16];
	unsigned int port;
	char iface[IF_LEN];
	int i;

	char *buf = (char *)calloc(strlen(HW_RTABLE_COL) + ROUTER_OP_LUT_ROUTE_TABLE_DEPTH*HW_RTABLE_ENTRY_TO_STRING_LEN, sizeof(uint8_t));
	unsigned int total_len = 0;

	COPY_STRING(buf, total_len, HW_RTABLE_COL);
	for(i=0; i < ROUTER_OP_LUT_ROUTE_TABLE_DEPTH; i++) {
		bzero(&ip, sizeof(struct in_addr));
		bzero(&mask, sizeof(struct in_addr));
		bzero(&gw, sizeof(struct in_addr));

		/* write the row number */
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG, i);

		/* read the four-tuple (ip, gw, mask, iface) from the hw registers */
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, &ip.s_addr);
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, &mask.s_addr);
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, &gw.s_addr);
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, &port);

		ip.s_addr = ntohl(ip.s_addr);
		mask.s_addr = ntohl(mask.s_addr);
		gw.s_addr = ntohl(gw.s_addr);

		getIfaceFromOneHotPortNumber(iface, IF_LEN, port);

		char line[HW_RTABLE_ENTRY_TO_STRING_LEN];
		bzero(line, HW_RTABLE_ENTRY_TO_STRING_LEN);
		snprintf(line, HW_RTABLE_ENTRY_TO_STRING_LEN, "%-5i%-20s%-20s%-20s%-20s\n",
			i,
			inet_ntop(AF_INET, &ip, ip_str, 16),
			inet_ntop(AF_INET, &gw, gw_str, 16),
			inet_ntop(AF_INET, &mask, mask_str, 16),
			iface);
		COPY_STRING(buf, total_len, line);
	}

	*buffer = buf;
	*len = total_len;
}

#define HW_ARP_CACHE_COL "MAC			GW\n"
#define HW_ARP_CACHE_ENTRY_TO_STRING_LEN 80
void sprint_hw_arp_cache(router_state *rs, char **buf, unsigned int *len) {

	uint8_t mac[6];
	struct in_addr gw;
	bzero(&gw, sizeof(struct in_addr));
	char gw_str[16];
	bzero(gw_str, 16);
	unsigned int mac_lo = 0;
	unsigned int mac_hi = 0;
	int i;

	char *buffer = calloc(strlen(HW_ARP_CACHE_COL) + ROUTER_OP_LUT_ARP_TABLE_DEPTH*HW_ARP_CACHE_ENTRY_TO_STRING_LEN, sizeof(char));
	unsigned int total_len = 0;

	COPY_STRING(buffer, total_len, HW_ARP_CACHE_COL);

	for(i=0; i < ROUTER_OP_LUT_ARP_TABLE_DEPTH; i++) {

		/* write the row number */
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG, i);

		/* read the four-touple (mac hi, mac lo, gw, num of misses) */
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, &mac_hi);
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, &mac_lo);
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, &gw.s_addr);
		gw.s_addr = htonl(gw.s_addr);

		mac[5] = (uint8_t)(mac_hi >> 8);
		mac[4] = (uint8_t)mac_hi;
		mac[3] = (uint8_t)(mac_lo >> 24);
		mac[2] = (uint8_t)(mac_lo >> 16);
		mac[1] = (uint8_t)(mac_lo >> 8);
		mac[0] = (uint8_t)mac_lo;


		char line[HW_ARP_CACHE_ENTRY_TO_STRING_LEN];
		bzero(line, HW_ARP_CACHE_ENTRY_TO_STRING_LEN);
		snprintf(line, HW_ARP_CACHE_ENTRY_TO_STRING_LEN, "%02X:%02X:%02X:%02X:%02X:%02X\t%-15s\n",
			mac[5], mac[4], mac[3], mac[2], mac[1], mac[0],
			inet_ntop(AF_INET, &gw, gw_str, 16) );

		COPY_STRING(buffer, total_len, line);

		mac_hi = 0;
		mac_lo = 0;
		gw.s_addr = 0;
	}

	*buf = buffer;
	*len = total_len;

}




#define HW_IFACE_COL "Port	MAC\n"
#define HW_IFACE_ENTRY_TO_STRING_LEN 80
void sprint_hw_iface(router_state *rs, char **buf, unsigned int *len) {

	char *name;
	unsigned int mac_lo = 0;
	unsigned int mac_hi = 0;
	uint8_t mac[6];
	int i = 0;

	char *buffer = calloc(strlen(HW_IFACE_COL) + 4*HW_IFACE_ENTRY_TO_STRING_LEN, sizeof(char));
	unsigned int total_len = 0;
	COPY_STRING(buffer, total_len, HW_IFACE_COL);

	for(i=0; i<4; i++) {

		switch(i) {
			case 0: name = ETH0; break;
			case 1: name = ETH1; break;
			case 2: name = ETH2; break;
			case 3: name = ETH3; break;
			default: name = NULL; break;
		}

		read_hw_iface_mac(rs, i, &mac_hi, &mac_lo);

		mac[5] = (uint8_t)(mac_hi >> 8);
		mac[4] = (uint8_t)mac_hi;
		mac[3] = (uint8_t)(mac_lo >> 24);
		mac[2] = (uint8_t)(mac_lo >> 16);
		mac[1] = (uint8_t)(mac_lo >> 8);
		mac[0] = (uint8_t)mac_lo;

		char line[HW_IFACE_ENTRY_TO_STRING_LEN];
		bzero(line, HW_IFACE_ENTRY_TO_STRING_LEN);
		snprintf(line, HW_IFACE_ENTRY_TO_STRING_LEN, "%-5s\t%02X:%02X:%02X:%02X:%02X:%02X\n",
			name,
			mac[5], mac[4], mac[3], mac[2], mac[1], mac[0]);
		COPY_STRING(buffer, total_len, line);


		name = NULL;
		mac_hi = 0;
		mac_lo = 0;
	}

	*buf = buffer;
	*len = total_len;
}

#define HW_NAT_COL "Row Ext IP           Port Sum    Int IP           Port Sum       Hits\n"
#define HW_NAT_ENTRY_TO_STRING_LEN 72
void sprint_hw_nat_table(router_state *rs, char **buf, unsigned int *len) {

        struct in_addr ext_ip;
        char ext_ip_str[16];
        uint32_t ext_port;
        uint32_t ext_sum;
        struct in_addr int_ip;
        char int_ip_str[16];
        uint32_t int_port;
        uint32_t int_sum;
        uint32_t hits;
        unsigned int i;

        char *buffer = (char *)calloc(strlen(HW_NAT_COL) + 16*HW_NAT_ENTRY_TO_STRING_LEN + 1, sizeof(uint8_t));
        unsigned int total_len = 0;

        COPY_STRING(buffer, total_len, HW_NAT_COL);
        for(i=0; i<16; i++) {

                /* write the row number */
                //writeReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_RD_ADDR_REG, i);

                /* read the 7-tuple (e-ip, e-port, e-sum, i-ip, i-port, i-sum, hits) from hw registers */
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_IP_REG, &int_ip.s_addr);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_PORT_REG, &int_port);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_INT_CHKSUM_REG, &int_sum);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_IP_REG, &ext_ip.s_addr);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_PORT_REG, &ext_port);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_EXT_CHKSUM_REG, &ext_sum);
                //readReg(&(rs->netfpga), ROUTER_OP_LUT_NAT_HIT_REG, &hits);

								int_ip.s_addr = htonl(int_ip.s_addr);
								ext_ip.s_addr = htonl(ext_ip.s_addr);

                char line[HW_NAT_ENTRY_TO_STRING_LEN];
                bzero(line, HW_NAT_ENTRY_TO_STRING_LEN);
                snprintf(line, HW_NAT_ENTRY_TO_STRING_LEN, "%-3i %-15s %5i 0x%04X %-15s %5i 0x%04X %7u\n",
                        i,
                        inet_ntop(AF_INET, &ext_ip, ext_ip_str, 16),
                        ext_port,
                        ext_sum,
                        inet_ntop(AF_INET, &int_ip, int_ip_str, 16),
                        int_port,
                        int_sum,
                        hits);

                COPY_STRING(buffer, total_len, line);
        }

        *buf = buffer;
        *len = total_len;
}

void print_ip(ip_hdr *ip) {
	indent(1);
	printf("IPv4 Packet Header (%d bytes)\n", 4*ip->ip_hl);
	indent(2);
	printf("Version = %d\n", ip->ip_v);
	indent(2);
	printf("Header Length = %d\n", 4*ip->ip_hl);
	indent(2);
	printf("Terms of Service = 0x%X\n", ip->ip_tos);
	indent(2);
	printf("Total Length = %d\n", ntohs(ip->ip_len));
	indent(2);
	printf("Identification = 0x%X\n", ntohs(ip->ip_id));
	indent(2);
	printf("Fragment Offset Field = 0x%X\n", ntohs(ip->ip_off));
	indent(2);
	printf("TTL (Time to Live) = %d\n", ip->ip_ttl);
	indent(2);
	printf("Protocol = ");
	switch(ip->ip_p) {
		case 1: { printf("ICMP\n"); break; }
		case 6: { printf("TCP\n"); break; }
		default: { printf("%d\n", ip->ip_p); break; }
	}
	indent(2);
	printf("Header Checksum = 0x%X\n", ntohs(ip->ip_sum));
	indent(2);
	print_ip_address("Src IP Address", ip->ip_src);
	indent(2);
	print_ip_address("Dst IP Address", ip->ip_dst);
}

#define HW_STATS_LEN 81
void sprint_hw_stats(router_state *rs, char **buf, unsigned int *len) {
	char *buffer = calloc(4*HW_STATS_LEN + 1, sizeof(char));
	unsigned int total_len = 0;
	char* port_names[8] = {"eth0", "eth1", "eth2", "eth3", "cpu0", "cpu1", "cpu2", "cpu3"};

	lock_netfpga_stats(rs);
	int i;
	char line[HW_STATS_LEN];
	bzero(line, HW_STATS_LEN);
	for (i = 0; i < 4; ++i) {
		snprintf(line, HW_STATS_LEN, "%-4s %12.2f PPS %12.2f kB/s %-4s %12.2f PPS %12.2f kB/s\n",
			port_names[i], rs->stats_avg[i][0], rs->stats_avg[i][1],
			port_names[i+4], rs->stats_avg[i+4][0], rs->stats_avg[i+4][1]);
		COPY_STRING(buffer, total_len, line);
	}

	unlock_netfpga_stats(rs);

	*buf = buffer;
	*len = total_len;
}

#define HW_DROPS_LEN 80
void sprint_hw_drops(router_state *rs, char **buf, unsigned int *len) {
	char *buffer = calloc(1*HW_DROPS_LEN + 1, sizeof(char));
	unsigned int total_len = 0;

	if (rs->is_netfpga) {
		char* port_names[4] = {"eth0", "eth1", "eth2", "eth3"};
		char line[HW_DROPS_LEN];
		bzero(line, HW_DROPS_LEN);
		snprintf(line, HW_DROPS_LEN, "%4s %10u %4s %10u %4s %10u %4s %10u\n",
			port_names[0], get_rx_queue_num_pkts_dropped_full(&rs->netfpga, 0) + get_rx_queue_num_pkts_dropped_bad(&rs->netfpga, 0),
			port_names[1], get_rx_queue_num_pkts_dropped_full(&rs->netfpga, 1) + get_rx_queue_num_pkts_dropped_bad(&rs->netfpga, 1),
			port_names[2], get_rx_queue_num_pkts_dropped_full(&rs->netfpga, 2) + get_rx_queue_num_pkts_dropped_bad(&rs->netfpga, 2),
			port_names[3], get_rx_queue_num_pkts_dropped_full(&rs->netfpga, 3) + get_rx_queue_num_pkts_dropped_bad(&rs->netfpga, 3));

		COPY_STRING(buffer, total_len, line);
	}

	*buf = buffer;
	*len = total_len;
}

#define HW_OQ_DROPS_LEN 80
void sprint_hw_oq_drops(router_state *rs, char **buf, unsigned int *len) {
	char *buffer = calloc(2*HW_OQ_DROPS_LEN + 1, sizeof(char));
	unsigned int total_len = 0;

	if (rs->is_netfpga) {
		char* port_names[8] = {"Q0", "Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7"};
		char line[HW_OQ_DROPS_LEN];
		bzero(line, HW_OQ_DROPS_LEN);

		snprintf(line, HW_OQ_DROPS_LEN, "%4s %10u %4s %10u %4s %10u %4s %10u\n",
			port_names[0], get_oq_num_pkts_dropped(&rs->netfpga, 0),
			port_names[1], get_oq_num_pkts_dropped(&rs->netfpga, 1),
			port_names[2], get_oq_num_pkts_dropped(&rs->netfpga, 2),
			port_names[3], get_oq_num_pkts_dropped(&rs->netfpga, 3));
		COPY_STRING(buffer, total_len, line);

		snprintf(line, HW_OQ_DROPS_LEN, "%4s %10u %4s %10u %4s %10u %4s %10u\n",
			port_names[4], get_oq_num_pkts_dropped(&rs->netfpga, 4),
			port_names[5], get_oq_num_pkts_dropped(&rs->netfpga, 5),
			port_names[6], get_oq_num_pkts_dropped(&rs->netfpga, 6),
			port_names[7], get_oq_num_pkts_dropped(&rs->netfpga, 7));
		COPY_STRING(buffer, total_len, line);
	}

	*buf = buffer;
	*len = total_len;
}

#define HW_LOCAL_IP_FILTER_HEADER "Row IP             \n"
#define HW_LOCAL_IP_FILTER_LEN 21
void sprint_hw_local_ip_filter(router_state *rs, char **buf, unsigned int *len) {
	char *buffer = calloc((1+ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH)*HW_LOCAL_IP_FILTER_LEN + 1, sizeof(char));
	unsigned int total_len = 0;

	if (rs->is_netfpga) {
		int i;
		COPY_STRING(buffer, total_len, HW_LOCAL_IP_FILTER_HEADER);
		char line[HW_LOCAL_IP_FILTER_LEN];
		bzero(line, HW_LOCAL_IP_FILTER_LEN);
		char ip_str[16];

		struct in_addr ip;
		for (i = 0; i < ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH; ++i) {
			writeReg(&rs->netfpga, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG, i);
			readReg(&rs->netfpga, ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG, &ip.s_addr);
			ip.s_addr = htonl(ip.s_addr);
			inet_ntop(AF_INET, &ip, ip_str, 16);
			snprintf(line, HW_LOCAL_IP_FILTER_LEN, "%3u %15s\n", i, ip_str);
			COPY_STRING(buffer, total_len, line);
		}
	}

	*buf = buffer;
  *len = total_len;
}
