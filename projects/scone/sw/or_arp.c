/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 *   The or_arp module:
 *   	- processes an ARP request/reply packet
 *   	- sends an ARP request
 *   	- maintainins the ARP cache
 *
 *   TO DO : maintaining the ARP queue
 */

#include "or_arp.h"
#include "or_main.h"
#include "or_utils.h"
#include "or_iface.h"
#include "sr_base_internal.h"
#include "or_output.h"
#include "or_ip.h"
#include "or_icmp.h"
#include "or_rtable.h"
#include "reg_defines.h"


#include <assert.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

void process_arp_packet( struct sr_instance *sr, const uint8_t *packet, unsigned int len, const char *interface) {

	assert(sr);
	assert(packet);
	assert(interface);

	arp_hdr *arp_packet = get_arp_hdr(packet, len);
	switch(ntohs(arp_packet->arp_op)) {

		case ARP_OP_REQUEST:
			process_arp_request(sr, packet, len, interface);
			break;

		case ARP_OP_REPLY:
			process_arp_reply(sr, packet, len, interface);
			break;

		default: return;
	}
}



void process_arp_request( struct sr_instance *sr, const uint8_t *packet, unsigned int len, const char *interface)
{

	assert(sr);
	assert(packet);
	assert(interface);

	arp_hdr* arp = get_arp_hdr(packet, len);
	router_state *rs = get_router_state(sr);

	/* get interface list read lock */
	lock_if_list_rd(rs);

	/* scan the interface list
	 * match the requested ip
	 */
	node* n = get_router_state(sr)->if_list;
	while (n) {
		/* see if we have an interface matching the requested ip */
		if (((iface_entry*)n->data)->ip == arp->arp_tip.s_addr) {
			send_arp_reply(sr, packet, len, (iface_entry*)(n->data));
			break;
		}
		n = n->next;
	}

	/* release the interface list lock */
	unlock_if_list(rs);
}

/*
 * Send an arp reply out of the given interface, as a reply to the given packet
 */
void send_arp_reply(struct sr_instance *sr, const uint8_t *packet, unsigned int len, iface_entry* iface) {
	eth_hdr* eth = (eth_hdr*)packet;
	arp_hdr* arp_req = get_arp_hdr(packet, len);

	uint8_t* new_packet = (uint8_t*)malloc(sizeof(eth_hdr) + sizeof(arp_hdr));

	/* Setup the ETHERNET header */
	eth_hdr* new_eth = (eth_hdr*)new_packet;
	populate_eth_hdr(new_eth, eth->eth_shost, iface->addr, ETH_TYPE_ARP);

	/* Setup the ARP header */
	arp_hdr* new_arp = get_arp_hdr(new_packet, sizeof(eth_hdr) + sizeof(arp_hdr));
	populate_arp_hdr(new_arp, arp_req->arp_sha, arp_req->arp_sip.s_addr, iface->addr, iface->ip, ARP_OP_REPLY);

	/* Send the reply */
	if (send_packet(sr, new_packet, sizeof(eth_hdr) + sizeof(arp_hdr), iface->name) != 0) {
		printf("Error sending ARP reply\n");
	}

	free(new_packet);
}

void send_arp_request(struct sr_instance* sr, uint32_t tip /* Net byte order */, const char* interface)
{

	assert(sr);
	assert(interface);

	iface_entry *inter = get_interface(sr, interface);
	uint8_t *request_packet = 0;
	eth_hdr *eth_request = 0;
	arp_hdr *arp_request = 0;
	uint32_t len = 0;
	uint8_t default_addr[ETH_ADDR_LEN] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

	/* construct the ARP request */
	len = sizeof(eth_hdr) + sizeof(arp_hdr);
	request_packet = calloc(len, sizeof(uint8_t));
	eth_request = (eth_hdr *)request_packet;
	arp_request = (arp_hdr *)(request_packet + sizeof(eth_hdr));

	populate_eth_hdr(eth_request, default_addr, inter->addr,
			 ETH_TYPE_ARP);
	populate_arp_hdr(arp_request, NULL, tip, inter->addr, inter->ip,
		         ARP_OP_REQUEST);


	/* send the ARP reply */
	if (send_packet(sr, request_packet, len, interface) != 0) {
		printf("Failure sending arp request\n");
	}

	/* recover allocated memory */
	free(request_packet);
}


void process_arp_reply( struct sr_instance *sr, const uint8_t *packet, unsigned int len, const char *interface)
{

	assert(sr);
	assert(packet);
	assert(interface);

	router_state *rs = get_router_state(sr);

	/* update the arp cache */
	arp_hdr *arp = get_arp_hdr(packet, len);

	lock_arp_cache_wr(rs);
	update_arp_cache(sr, &(arp->arp_sip), arp->arp_sha, 0);
	unlock_arp_cache(rs);

	lock_arp_cache_rd(rs);
	lock_arp_queue_wr(rs);
	send_queued_packets(sr, &(arp->arp_sip), arp->arp_sha);
	unlock_arp_queue(rs);
	unlock_arp_cache(rs);
}

/*
 * NOT THREAD SAFE! Lock cache rd, queue wr
 *
 *
 */
void send_queued_packets(struct sr_instance* sr, struct in_addr* dest_ip, char* dest_mac) {
	node* n = get_router_state(sr)->arp_queue;
	node* next = NULL;

	while (n) {
		next = n->next;

		arp_queue_entry* aqe = (arp_queue_entry*)n->data;

		/* match the arp reply sip to our entry next hop ip */
		if (dest_ip->s_addr == aqe->next_hop.s_addr) {
			node* cur_packet_node = aqe->head;
			node* next_packet_node = NULL;

			while (cur_packet_node) {
				next_packet_node = cur_packet_node->next;

				/* send the packet */
				arp_queue_packet_entry* aqpe = (arp_queue_packet_entry*)cur_packet_node->data;

				send_ip(sr, aqpe->packet, aqpe->len, &(aqe->next_hop), aqe->out_iface_name);
				node_remove(&(aqe->head), cur_packet_node);

				cur_packet_node = next_packet_node;
			}

			/* free the arp queue entry for this destination ip, and patch the list */
			node_remove(&(get_router_state(sr)->arp_queue), n);
		}

		n = next;
	}
}


arp_hdr* get_arp_hdr(const uint8_t* packet, unsigned int len) {
	eth_hdr* eth = (eth_hdr*)packet;
	assert((ntohs(eth->eth_type) == ETH_TYPE_ARP));
	return (arp_hdr*)(packet + ETH_HDR_LEN);
}



/*
 * Not thread safe:
 * 	Acquire arp cache lock before invoking this procedure
 * 	This procedure is helper function to:
 * 		- update_arp_cache
 * 		- present_in_arp_cache
 * 	The two procedures are defined below.
 */
arp_cache_entry *in_arp_cache(router_state *rs, struct in_addr* next_hop) {
	node *arp_walker = 0;
	arp_cache_entry *arp_entry = 0;

	arp_walker = rs->arp_cache;
	while(arp_walker)
	{
		arp_entry = (arp_cache_entry *)arp_walker->data;

		if (next_hop->s_addr == arp_entry->ip.s_addr) {
			break;
		}

		arp_entry = 0;
		arp_walker = arp_walker->next;
	}

	return arp_entry;
}


/*
 * NOT THREAD SAFE, LOCK THE ARP CACHE
 * Return: 0 on success, 1 on failure
 */
int update_arp_cache(struct sr_instance* sr, struct in_addr* remote_ip, char* remote_mac, int is_static) {
	assert(sr);
	assert(remote_ip);
	assert(remote_mac);

	router_state *rs = (router_state *)sr->interface_subsystem;
	arp_cache_entry *arp_entry = 0;

	arp_entry = in_arp_cache(rs, remote_ip);
	if(arp_entry) {

		/* if this remote ip is in the cache, update its data */
		memcpy(arp_entry->arp_ha, remote_mac, ETH_ADDR_LEN);
		if (is_static == 1) {
			arp_entry->TTL = 0;
		} else {
			time(&arp_entry->TTL);
		}
		arp_entry->is_static = is_static;

	}	else {

		/* if this interface is not in the cache, create a new entry */
		node* n = node_create();
		arp_entry = calloc(1, sizeof(arp_cache_entry));

		arp_entry->ip.s_addr = remote_ip->s_addr;
		memcpy(arp_entry->arp_ha, remote_mac, ETH_ADDR_LEN);
		if (is_static == 1) {
			arp_entry->TTL = 0;
		} else {
			time(&arp_entry->TTL);
		}
		arp_entry->is_static = is_static;

		n->data = (void *)arp_entry;
		if(rs->arp_cache == NULL) {
			rs->arp_cache = n;
		} else {
			node_push_back(rs->arp_cache, n);
		}

	}

	/* update the hw arp cache copy */
	trigger_arp_cache_modified(rs);

	return 0;
}

/*
 * NOT THREAD SAFE
 * Returns: # of deleted arp cache entries (should only be 1)
 */
int del_arp_cache(struct sr_instance* sr, struct in_addr* ip) {
	router_state* rs = get_router_state(sr);
	node* cur = rs->arp_cache;
	node* next = NULL;
	int retval = 0;

	while (cur) {
		next = cur->next;
		arp_cache_entry* entry = (arp_cache_entry*)cur->data;

		if (entry->ip.s_addr == ip->s_addr) {
			node_remove(&(rs->arp_cache), cur);
			++retval;
		}

		cur = next;
	}

	return retval;
}


void update_arp_queue(struct sr_instance* sr, arp_hdr* arp_header, const char* interface) {
	router_state* rs = get_router_state(sr);
	node* n = rs->arp_queue;
	node* next = NULL;

	while (n) {
		next = n->next;
		arp_queue_entry* aqe = (arp_queue_entry*)n->data;

		/* Does this arp reply match an entry waiting for it? */
		if (arp_header->arp_sip.s_addr == aqe->next_hop.s_addr) {
			/* send out the packets */
			node* cur_packet_node = aqe->head;
			node* next_packet_node = NULL;

			while (cur_packet_node) {
				next_packet_node = cur_packet_node->next;
				arp_queue_packet_entry* aqpe = (arp_queue_packet_entry*)cur_packet_node->data;

				/* send_ip takes responsibility for the packet so we don't need to free it */
				send_ip(sr, aqpe->packet, aqpe->len, &(aqe->next_hop), aqe->out_iface_name);

				node_remove(&(aqe->head), cur_packet_node);
				cur_packet_node = next_packet_node;
			}

			node_remove(&(rs->arp_queue), n);
		}
		n = next;
	}
}


arp_cache_entry* get_from_arp_cache(struct sr_instance* sr, struct in_addr* next_hop) {

	assert(sr);
	assert(next_hop);

	return in_arp_cache(get_router_state(sr), next_hop);
}


void lock_arp_cache_rd(router_state *rs) {

	assert(rs);

	/* get the arp cache lock */
	if(pthread_rwlock_rdlock(rs->arp_cache_lock) != 0) {
		perror("Failure getting arp cache read lock");
	}
}

void lock_arp_cache_wr(router_state *rs) {

	assert(rs);

	/* get the arp cache lock */
	if(pthread_rwlock_wrlock(rs->arp_cache_lock) != 0) {
		perror("Failure getting arp cache write lock");
	}
}

void unlock_arp_cache(router_state *rs) {

	assert(rs);

	/* release the arp cache lock */
	if(pthread_rwlock_unlock(rs->arp_cache_lock) != 0) {
		perror("Failure releasing arp cache lock");
	}

}

/*
 * Helper function for arp_queue_add, not to be called externally
 */
void arp_queue_entry_add_packet(arp_queue_entry* aqe, uint8_t* packet, unsigned int len) {
	node* n = node_create();
	arp_queue_packet_entry* aqpe = (arp_queue_packet_entry*)malloc(sizeof(arp_queue_packet_entry));

	aqpe->packet = packet;
	aqpe->len = len;
	/* set the new nodes data to point to the packet entry */
	n->data = aqpe;
	/* add the new node to the arp queue entry */
	if (aqe->head == NULL) {
		aqe->head = n;
	} else {
		node_push_back(aqe->head, n);
	}
}


void arp_queue_add(struct sr_instance* sr, uint8_t* packet, unsigned int len, const char* out_iface_name, struct in_addr *next_hop)
{
	assert(sr);
	assert(packet);
	assert(out_iface_name);
	assert(next_hop);

	router_state *rs = get_router_state(sr);

	/* Is there an existing queue entry for this IP? */
	arp_queue_entry* aqe = get_from_arp_queue(sr, next_hop);
	if (!aqe) {
		/* create a new queue entry */
		aqe = (arp_queue_entry*)malloc(sizeof(arp_queue_entry));
		bzero(aqe, sizeof(arp_queue_entry));
		memcpy(aqe->out_iface_name, out_iface_name, IF_LEN);
		aqe->next_hop = *next_hop;

		/* send a request */
		time(&(aqe->last_req_time));
		aqe->requests = 1;
		send_arp_request(sr, next_hop->s_addr, out_iface_name);

		arp_queue_entry_add_packet(aqe, packet, len);

		/* create a node, add this entry to the node, and push it into our linked list */
		node* n = node_create();
		n->data = aqe;

		if (rs->arp_queue == NULL) {
			rs->arp_queue = n;
		} else {
			node_push_back(rs->arp_queue, n);
		}
	} else {
		/* entry exists, just add the packet */
		arp_queue_entry_add_packet(aqe, packet, len);
	}
}

/*
 * THIS FUNCTION IS NOT THREAD SAFE
 * Lock the ARP Queue before using it
 */
arp_queue_entry* get_from_arp_queue(struct sr_instance* sr, struct in_addr* next_hop) {
	router_state* rs = get_router_state(sr);
	node* n = rs->arp_queue;

	while (n) {
		arp_queue_entry* aqe = (arp_queue_entry*)n->data;
		if (aqe->next_hop.s_addr == next_hop->s_addr) {
			return aqe;
		}

		n = n->next;
	}

	return NULL;
}

void lock_arp_queue_rd(router_state *rs) {
	//printf("LOCK ARP QUEUE-RD %u\n", pthread_self());
	assert(rs);

	if(pthread_rwlock_rdlock(rs->arp_queue_lock) != 0) {
		perror("Failure getting arp queue read lock");
	}
}

void lock_arp_queue_wr(router_state *rs) {
	//printf("LOCK ARP QUEUE-WR %u\n", pthread_self());

	assert(rs);

	if(pthread_rwlock_wrlock(rs->arp_queue_lock) != 0) {

		perror("Failure getting arp queue write lock");
	}
	//printf("GOT LOCK ARP QUEUE-WR %u\n", pthread_self());

}

void unlock_arp_queue(router_state *rs) {
	//printf("UNLOCK ARP QUEUE-WR %u\n", pthread_self());

	assert(rs);

	if(pthread_rwlock_unlock(rs->arp_queue_lock) != 0) {
		perror("Failure releasing arp queue lock");
	}
}

/*
 * HELPER function called from arp_thread
 * NOT THREAD SAFE
 */
void expire_arp_cache(struct sr_instance* sr) {
	assert(sr);

	router_state *rs = (router_state *)sr->interface_subsystem;
	node *arp_walker = 0;
	arp_cache_entry *arp_entry = 0;
	time_t now;
	double diff;
	int timedout_entry = 0;

	arp_walker = rs->arp_cache;
	while(arp_walker) {
		arp_entry = (arp_cache_entry *)arp_walker->data;
		node *tmp = arp_walker;
		arp_walker = arp_walker->next;

		/** if not static, check that is TTL is within reason **/
		if (arp_entry->is_static != 1) {
			time(&now);
			diff = difftime(now, arp_entry->TTL);

			if (diff > rs->arp_ttl) {
				node_remove(&rs->arp_cache, tmp);
				timedout_entry = 1;
			}
		}
	}

	/* update the hw arp cache */
	if(timedout_entry == 1) {
		trigger_arp_cache_modified(rs);
	}
}

/*
 * HELPER function called from arp_thread
 */
void process_arp_queue(struct sr_instance* sr) {
	router_state* rs = get_router_state(sr);
	node* n = get_router_state(sr)->arp_queue;
	node* next = NULL;
	time_t now;
	double diff;

	while (n) {
		next = n->next;

		arp_queue_entry* aqe = (arp_queue_entry*)n->data;

		/* has it been over a second since the last arp request was sent? */
		time(&now);
		diff = difftime(now, aqe->last_req_time);
		if (diff > 1) {
			/* have we sent less than 5 arp requests? */
			if (aqe->requests < 5) {
				/* send another */
				time(&(aqe->last_req_time));
				++(aqe->requests);
				send_arp_request(sr, aqe->next_hop.s_addr, aqe->out_iface_name);
			} else {
				/* we have exceeded the max arp requests, return packets to sender */
				node* cur_packet_node = aqe->head;
				node* next_packet_node = NULL;

				while (cur_packet_node) {
					/* send icmp for the packet, free it, and its encasing entry */
					arp_queue_packet_entry* aqpe = (arp_queue_packet_entry*)cur_packet_node->data;

					/* only send an icmp error if the packet is not icmp, or if it is, its an echo request or reply
					 * also ensure we don't send an icmp error back to one of our interfaces
					 */
					if ((get_ip_hdr(aqpe->packet, aqpe->len)->ip_p != IP_PROTO_ICMP) ||
							(get_icmp_hdr(aqpe->packet, aqpe->len)->icmp_type == ICMP_TYPE_ECHO_REPLY) ||
							(get_icmp_hdr(aqpe->packet, aqpe->len)->icmp_type == ICMP_TYPE_ECHO_REQUEST)) {

					 	/* also ensure we don't send an icmp error back to one of our interfaces */
						if (!iface_match_ip(rs, get_ip_hdr(aqpe->packet, aqpe->len)->ip_src.s_addr)) {
							/* Total hack here to increment the TTL since we already decremented it earlier in the pipeline
							 * and the ICMP error should return the original packet.
							 * TODO: Don't decrement the TTL until the packet is ready to be put on the wire
							 * and we have the next hop ARP address, although checking should be done
							 * where it is currently being decremented to minimize effort on a doomed packet */
							ip_hdr *ip = get_ip_hdr(aqpe->packet, aqpe->len);
							if (ip->ip_ttl < 255) {
								ip->ip_ttl++;

								/* recalculate checksum */
								bzero(&ip->ip_sum, sizeof(uint16_t));
								uint16_t checksum = htons(compute_ip_checksum(ip));
								ip->ip_sum = checksum;
							}

							send_icmp_packet(sr, aqpe->packet, aqpe->len, ICMP_TYPE_DESTINATION_UNREACHABLE, ICMP_CODE_HOST_UNREACHABLE);
						}
					}

					free(aqpe->packet);
					next_packet_node = cur_packet_node->next;
					//free(cur_packet_node);   /* IS THIS CORRECT TO FREE IT ? */
					node_remove(&(aqe->head), cur_packet_node);
					cur_packet_node = next_packet_node;
				}

				/* free the arp queue entry for this destination ip, and patch the list */
				node_remove(&(get_router_state(sr)->arp_queue), n);
			}
		}

		n = next;
	}
}



/*
 * NOT Threadsafe, ensure arp cache locked at least for read
 */
void trigger_arp_cache_modified(router_state* rs) {
	if (rs->is_netfpga) {

		/*
		char *info;
		int len;

		sprint_arp_cache(rs, &info, &len);
		printf("SW ARP CACHE \n%s", info);
		free(info);
		*/

		write_arp_cache_to_hw(rs);

		/*
		sprint_hw_arp_cache(rs, &info, &len);
		printf("HW ARP CACHE \n%s", info);
		free(info);
		*/
	}
}

void write_arp_cache_to_hw(router_state* rs) {

	/* iterate sequentially through the 16 slots in hw updating all entries */
	int i = 0;

	/* first write all the static entries */
	node *cur = rs->arp_cache;
	while((cur != NULL) && (i < ROUTER_OP_LUT_ARP_TABLE_DEPTH)) {
		arp_cache_entry* entry = (arp_cache_entry *)cur->data;

		if(entry->is_static) {
			write_arp_cache_entry_to_hw(rs, entry, i);
			i++;
		}

		cur = cur->next;
	}

	/* second write all the non-static entries and zero out remaining entries in hw */
	cur = rs->arp_cache;
	while(i < ROUTER_OP_LUT_ARP_TABLE_DEPTH) {

		if(cur) {
			arp_cache_entry* entry = (arp_cache_entry *)cur->data;
			if(entry->is_static == 0) {
				write_arp_cache_entry_to_hw(rs, entry, i);
				i++;
			}
			cur = cur->next;

		} else {
			/* zero out the rest of the rows */
			write_arp_cache_entry_to_hw(rs, NULL, i);
			i++;
		}
	}
}


void write_arp_cache_entry_to_hw(router_state* rs, arp_cache_entry *entry, int row) {

	if(entry != NULL) {
		unsigned int mac_hi = 0;
		unsigned int mac_lo = 0;

		/* write the mac hi data */
		mac_hi |= ((unsigned int)entry->arp_ha[0]) << 8;
		mac_hi |= ((unsigned int)entry->arp_ha[1]);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, mac_hi);

		/* write the mac lo data */
		mac_lo |= ((unsigned int)entry->arp_ha[2]) << 24;
		mac_lo |= ((unsigned int)entry->arp_ha[3]) << 16;
		mac_lo |= ((unsigned int)entry->arp_ha[4]) << 8;
		mac_lo |= ((unsigned int)entry->arp_ha[5]);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, mac_lo);

		/* write the next hop ip data */
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, ntohl(entry->ip.s_addr));

	} else {

		/* zero out the rest of the rows */
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, 0);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, 0);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, 0);
	}

	/* set the row */
	writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG, row);
}


void cli_show_ip_arp(router_state* rs, cli_request* req) {
	char *arp_cache_info;
	int len;

	char ttl_info[32];
	snprintf(ttl_info, 32, "Arp Cache TTL: %5u seconds\n\n", rs->arp_ttl);
	send_to_socket(req->sockfd, ttl_info, strlen(ttl_info));

	lock_arp_cache_rd(rs);
	sprint_arp_cache(rs, &arp_cache_info, &len);
	unlock_arp_cache(rs);

	send_to_socket(req->sockfd, arp_cache_info, len);
	free(arp_cache_info);
}

void cli_show_ip_arp_help(router_state* rs, cli_request* req) {
	char *usage = "usage: show ip arp\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_ip_arp_help(router_state *rs, cli_request* req) {
	char *usage0 = "usage: ip arp <args>\n";
	send_to_socket(req->sockfd, usage0, strlen(usage0));

	char *usage1 = "ip arp add ip MAC\n";
	send_to_socket(req->sockfd, usage1, strlen(usage1));

	char *usage2 = "ip arp del ip\n";
	send_to_socket(req->sockfd, usage2, strlen(usage2));
}



void* arp_thread(void *param) {
	assert(param);
	struct sr_instance *sr = (struct sr_instance *)param;
	router_state *rs = get_router_state(sr);

	while (1) {
		lock_arp_cache_wr(rs);
		expire_arp_cache(sr);
		unlock_arp_cache(rs);

		lock_arp_cache_rd(rs);
		lock_arp_queue_wr(rs);
		lock_if_list_rd(rs);
		lock_rtable_rd(rs); /* because we may send an icmp packet back, requiring get next hop */

		process_arp_queue(sr);

		unlock_rtable(rs);
		unlock_if_list(rs);
		unlock_arp_queue(rs);
		unlock_arp_cache(rs);

		sleep(1);
	}
}

void cli_ip_arp_add_help(router_state *rs, cli_request *req) {
	char *usage = "usage ip arp add ip MAC\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_ip_arp_add(router_state *rs, cli_request *req) {
	char *ip_str;
	unsigned char mac[ETH_ADDR_LEN];
	unsigned int mac_int[ETH_ADDR_LEN];

	if (sscanf(req->command, "ip arp add %as %2X:%2X:%2X:%2X:%2X:%2X", &ip_str,
			mac_int, (mac_int+1), (mac_int+2), (mac_int+3), (mac_int+4), (mac_int+5)) != 7) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	int i;
	for (i = 0; i < 6; ++i) {
		mac[i] = (unsigned char)mac_int[i];
	}

	struct in_addr ip;
	if (inet_pton(AF_INET, ip_str, &ip) != 1) {
		send_to_socket(req->sockfd, "Failure reading ip.\n", strlen("Failure reading ip.\n"));
		return;
	}


	lock_arp_cache_wr(rs);

	int result = update_arp_cache(rs->sr, &ip, mac, 1);

	unlock_arp_cache(rs);

	char* message;
	if (result != 0) {
		message = "Failure adding arp cache entry.\n";
	} else {
		message = "Successfully added arp cache entry.\n";
	}
	send_to_socket(req->sockfd, message, strlen(message));

	free(ip_str);
}




void cli_ip_arp_del_help(router_state *rs, cli_request *req) {
	char *usage = "usage ip arp del ip\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}




void cli_ip_arp_del(router_state *rs, cli_request *req) {
	char *ip_str;

	if (sscanf(req->command, "ip arp del %as", &ip_str) != 1) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	struct in_addr ip;
	if (inet_pton(AF_INET, ip_str, &ip) != 1) {
		send_to_socket(req->sockfd, "Failure reading ip.\n", strlen("Failure reading ip.\n"));
		return;
	}


	lock_arp_cache_wr(rs);

	int result = del_arp_cache(rs->sr, &ip);

	/* update the hw arp cache */
	if(result > 0) {
		trigger_arp_cache_modified(rs);
	}
	unlock_arp_cache(rs);

	char* result_str = (char*)calloc(1, 256);
	if (result != 1) {
		snprintf(result_str, 256, "%i arp cache entries deleted.\n", result);
	} else {
		snprintf(result_str, 256, "%i arp cache entry deleted.\n", result);
	}

	send_to_socket(req->sockfd, result_str, strlen(result_str));

	free(result_str);
	free(ip_str);
}


void cli_show_hw_arp_cache(router_state *rs, cli_request *req) {

	if(rs->is_netfpga) {
		char *arp_info = 0;
		unsigned int len;

		sprint_hw_arp_cache(rs, &arp_info, &len);
		send_to_socket(req->sockfd, arp_info, len);
		free(arp_info);
	}
}



void cli_nuke_arp_cache(router_state *rs, cli_request *req) {

	lock_arp_cache_wr(rs);

	/* destroy the sw arp cache */
	node *cur = rs->arp_cache;
	while(cur) {
		node *next = cur->next;
		node_remove(&rs->arp_cache, cur);

		cur = next;
	}

	/* zero out the hw arp cache */
	if(rs->is_netfpga) {
		trigger_arp_cache_modified(rs);
	}

	unlock_arp_cache(rs);

	char *info = "SW and HW arp cache info was nuked\n";
	send_to_socket(req->sockfd, info, strlen(info));
}



void cli_nuke_hw_arp_cache_entry(router_state *rs, cli_request *req) {

	if(rs->is_netfpga) {
		unsigned int row;

		if( sscanf(req->command, "nuke hw arp %ui", &row) != 1) {
			send_to_socket(req->sockfd, "Failure to read arguments.\n", strlen("Failure reading arguments.\n"));
			return;
		}

		if(row > (ROUTER_OP_LUT_ARP_TABLE_DEPTH - 1)) {
			send_to_socket(req->sockfd, "Specified invalid row\n", strlen("Specified invalid row\n"));
			return;
		}


		/* zero out the rest of the row */
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG, 0);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG, 0);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG, 0);
		writeReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG, row);

		char *msg = (char *)calloc(80, sizeof(char));
		snprintf(msg, 80, "Row %d has been nuked\n", row);
		send_to_socket(req->sockfd, msg, strlen(msg));
		free(msg);
	}

}

void cli_hw_arp_cache_misses(router_state *rs, cli_request *req) {

	if(rs->is_netfpga) {
		unsigned int misses = 0;
		readReg(&(rs->netfpga), ROUTER_OP_LUT_ARP_NUM_MISSES_REG, &misses);

		char *info = (char *)calloc(80, sizeof(char));
		snprintf(info, 80, "HW ARP CACHE MISSES: %d\n", ntohl(misses));
		send_to_socket(req->sockfd, info, strlen(info));
		free(info);
	}

}


void cli_hw_num_pckts_fwd(router_state *rs, cli_request *req) {

	if(rs->is_netfpga) {
		unsigned int number = 0;
		readReg(&(rs->netfpga), ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG, &number);

		char *info = (char *)calloc(80, sizeof(char));
		snprintf(info, 80, "HW NUMBER OF PACKETS FORWARDED: %d\n", ntohl(number));
		send_to_socket(req->sockfd, info, strlen(info));
		free(info);
	}

}

void cli_ip_arp_set_ttl(router_state *rs, cli_request *req) {

	unsigned int timeout;

	if( sscanf(req->command, "ip arp set ttl %ui", &timeout) != 1 ) {
		send_to_socket(req->sockfd, "Syntax error\n", strlen("Syntax error\n"));
		return;
	}

	rs->arp_ttl = timeout;

	char *info = (char *)calloc(80, sizeof(char));
	snprintf(info, 80, "Arp entry TTL has been set to: %d\n", rs->arp_ttl);
	send_to_socket(req->sockfd, info, strlen(info));
	free(info);
}
