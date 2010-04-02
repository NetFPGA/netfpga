/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <arpa/inet.h>
#include <string.h>
#include <assert.h>

#include "or_rtable.h"
#include "or_main.h"
#include "or_data_types.h"
#include "or_output.h"
#include "or_utils.h"
#include "or_netfpga.h"
#include "nf2/nf2util.h"
#include "reg_defines.h"

void write_rtable_to_hw(router_state* rs);

/*
 * next_hop, next_hop_iface are parameters returned by the function
 * len is the max length that can be copied into next_hop_iface
 * THIS METHOD IS NOT THREAD SAFE! AQUIRE THE rtable lock first!
 * Returns: 1 if no match, 0 if there is a match
 */
int get_next_hop(struct in_addr* next_hop, char* next_hop_iface, int len, router_state* rs, struct in_addr* destination) {
	int i;

	node* n = rs->rtable;
	rtable_entry* lpm = NULL;
	int most_bits_matched = -1;
	while (n) {
		rtable_entry* re = (rtable_entry*)n->data;

		if (re->is_active) {
			uint32_t mask = ntohl(re->mask.s_addr);
			uint32_t ip = ntohl(re->ip.s_addr) & mask;
			uint32_t dest_ip = ntohl(destination->s_addr) & mask;

			if (ip == dest_ip) {
				/* count the number of bits in the mask */
				int bits_matched = 0;
				for (i = 0; i < 32; ++i) {
					if ((mask >> i) & 0x1) {
						++bits_matched;
					}
				}

				if (bits_matched > most_bits_matched) {
					lpm = re;
					most_bits_matched = bits_matched;
				}
			}
		}
		n = n->next;
	}

	int retval = 1;
	if (lpm) {
		if (lpm->gw.s_addr == 0) {
			/* Support for next hop 0.0.0.0, meaning it is equivalent to the destination ip */
			/*next_hop->s_addr = lpm->ip.s_addr;*/
			next_hop->s_addr = destination->s_addr;
		} else {
			next_hop->s_addr = lpm->gw.s_addr;
		}
		strncpy(next_hop_iface, lpm->iface, len);
		retval = 0;
	}

	return retval;
}

/*
 * NOT thread safe, lock the rtable before calling.
 * All parameters are copied out.
 * Returns: 0 if successful, 1 if route already exists
 */
int add_route(router_state* rs, struct in_addr* dest, struct in_addr* gateway, struct in_addr* mask, char* interface) {

	  rtable_entry* entry = (rtable_entry*)calloc(1, sizeof(rtable_entry));

		entry->ip.s_addr = dest->s_addr;
		entry->gw.s_addr = gateway->s_addr;
		entry->mask.s_addr = mask->s_addr;
		entry->is_active = 1;
		entry->is_static = 1;
		strncpy(entry->iface, interface, IF_LEN);


  	/* create a node, set data pointer to the new entry */
  	node* n = node_create();
  	n->data = entry;

  	if (rs->rtable == NULL) {
  		rs->rtable = n;
  	} else {
  		node_push_back(rs->rtable, n);
  	}

		/* write new rtable out to hardware */
		trigger_rtable_modified(rs);

  	/* TODO: Check if this route exists, if so return 1 */

  	return 0;
}

/*
 * NOT thread safe, lock the rtable before calling.
 * Returns: number of routes deleted matching the dest AND mask
 */
int del_route(router_state* rs, struct in_addr* dest, struct in_addr* mask) {
	node *cur = NULL;
	node *next = NULL;
	rtable_entry* entry = NULL;
	int removed_routes = 0;

	cur = rs->rtable;
	while (cur) {
		next = cur->next;
		entry = (rtable_entry*)cur->data;
		if ((dest->s_addr == entry->ip.s_addr) && (mask->s_addr == entry->mask.s_addr)) {
			node_remove(&(rs->rtable), cur);
			++removed_routes;
		}

		cur = next;
	}

	/* write new rtable out to hardware */
	trigger_rtable_modified(rs);

	return removed_routes;
}

/*
 * NOT THREAD SAFE: lock rtable write
 * Returns: 0 on success, 1 on error
 */
int deactivate_routes(router_state* rs, char* interface) {
	node *cur = NULL;
	node *next = NULL;
	rtable_entry* entry = NULL;

	cur = rs->rtable;
	while (cur) {
		next = cur->next;
		entry = (rtable_entry*)cur->data;
		if (strncmp(entry->iface, interface, strlen(interface)) == 0) {
			/* matched interface, check if its static */
			if (entry->is_static) {
				entry->is_active = 0;
			} else {
				node_remove(&(rs->rtable), cur);
			}
		}

		cur = next;
	}

	/* write new rtable out to hardware */
	trigger_rtable_modified(rs);

	return 0;
}

/*
 * NOT THREAD SAFE: lock rtable write
 * Returns: 0 on success, 1 on error
 */
int activate_routes(router_state* rs, char* interface) {
	node *cur = NULL;
	node *next = NULL;
	rtable_entry* entry = NULL;

	cur = rs->rtable;
	while (cur) {
		next = cur->next;
		entry = (rtable_entry*)cur->data;
		if (strncmp(entry->iface, interface, strlen(interface)) == 0) {
			entry->is_active = 1;
		}

		cur = next;
	}

	/* write new rtable out to hardware */
	trigger_rtable_modified(rs);

	return 0;
}

/*
 * NOT Threadsafe, ensure rtable locked for write
 */
void trigger_rtable_modified(router_state* rs) {
	/* bubble sort by netmask */

	int swapped = 0;
	do {
		swapped = 0;
		node* cur = rs->rtable;
		while (cur && cur->next) {
			rtable_entry* a = (rtable_entry*)cur->data;
			rtable_entry* b = (rtable_entry*)cur->next->data;
			if ((ntohl(a->mask.s_addr) < ntohl(b->mask.s_addr)) ||
				((a->mask.s_addr == b->mask.s_addr) && (ntohl(a->ip.s_addr) < ntohl(b->ip.s_addr))) ||
				((a->mask.s_addr == b->mask.s_addr) && (a->ip.s_addr == b->ip.s_addr) && !a->is_static && b->is_static)) {
				cur->data = b;
				cur->next->data = a;
				swapped = 1;
			}

			cur = cur->next;
		}
	} while (swapped);

	if (rs->is_netfpga) {
		write_rtable_to_hw(rs);
	}
}

void write_rtable_to_hw(router_state* rs) {
	/* naively iterate through the 32 slots in hardware updating all entries */
	int i = 0;
	node* cur = rs->rtable;

	/* find first active entry before entering the loop */
	while (cur && !(((rtable_entry*)cur->data)->is_active)) {
		cur = cur->next;
	}

	for (i = 0; i < ROUTER_OP_LUT_ROUTE_TABLE_DEPTH; ++i) {

		if (cur) {
			rtable_entry* entry = (rtable_entry*)cur->data;
			/* write the ip */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, ntohl(entry->ip.s_addr));
			/* write the mask */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, ntohl(entry->mask.s_addr));
			/* write the next hop */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, ntohl(entry->gw.s_addr));
			/* write the port */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, getOneHotPortNumber(entry->iface));
			/* write the row number */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG, i);

			/* advance at least once */
			cur = cur->next;
			/* find the next active entry */
			while (cur && !(((rtable_entry*)cur->data)->is_active)) {
				cur = cur->next;
			}
		} else {
			/* write the ip */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG, 0);
			/* write the mask */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG, 0);
			/* write the next hop */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG, 0);
			/* write the port */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG, 0);
			/* set the row */
			writeReg(&(rs->netfpga), ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG, i);
		}
	}
}


void lock_rtable_rd(router_state *rs) {
	assert(rs);

	if(pthread_rwlock_rdlock(rs->rtable_lock) != 0) {
		perror("Failure getting rtable read lock");
	}
}

void lock_rtable_wr(router_state *rs) {
	assert(rs);

	if(pthread_rwlock_wrlock(rs->rtable_lock) != 0) {
		perror("Failure getting rtable write lock");
	}
}

void unlock_rtable(router_state *rs) {
	assert(rs);

	if(pthread_rwlock_unlock(rs->rtable_lock) != 0) {
		perror("Failure unlocking rtable lock");
	}
}


void cli_show_ip_rtable(router_state *rs, cli_request *req) {

	char *rtable_info;
	int len;

	lock_rtable_rd(rs);
	sprint_rtable(rs, &rtable_info, &len);
	unlock_rtable(rs);

	send_to_socket(req->sockfd, rtable_info, len);
	free(rtable_info);
}

void cli_show_ip_rtable_help(router_state *rs, cli_request *req) {
	char *usage = "usage: show ip route\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}

void cli_ip_route_add(router_state *rs, cli_request *req) {
	char *dest_str, *gateway_str, *mask_str, *interface;

	if (sscanf(req->command, "ip route add %as %as %as %as", &dest_str, &gateway_str, &mask_str, &interface) != 4) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	struct in_addr dest, gateway, mask;
	if (inet_pton(AF_INET, dest_str, &dest) != 1) {
		send_to_socket(req->sockfd, "Failure reading destination.\n", strlen("Failure reading destination.\n"));
		return;
	}

	if (inet_pton(AF_INET, gateway_str, &gateway) != 1) {
		send_to_socket(req->sockfd, "Failure reading gateway.\n", strlen("Failure reading gateway.\n"));
		return;
	}

	if (inet_pton(AF_INET, mask_str, &mask) != 1) {
		send_to_socket(req->sockfd, "Failure reading mask.\n", strlen("Failure reading mask.\n"));
		return;
	}

	/* Lock the rtable before adding */
	lock_rtable_wr(rs);

	int add_result = add_route(rs, &dest, &gateway, &mask, interface);

	/* Unlock rtable */
	unlock_rtable(rs);

	if (add_result != 0) {
		send_to_socket(req->sockfd, "Failure adding route.\n", strlen("Failure adding route.\n"));
	} else {
		send_to_socket(req->sockfd, "Successfully added route.\n", strlen("Successfully added route.\n"));
	}

	free(dest_str);
	free(gateway_str);
	free(mask_str);
	free(interface);
}

void cli_ip_route_del(router_state *rs, cli_request *req) {
	char *dest_str, *mask_str;

	if (sscanf(req->command, "ip route del %as %as", &dest_str, &mask_str) != 2) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	struct in_addr dest, mask;
	if (inet_pton(AF_INET, dest_str, &dest) != 1) {
		send_to_socket(req->sockfd, "Failure reading destination.\n", strlen("Failure reading destination.\n"));
		return;
	}

	if (inet_pton(AF_INET, mask_str, &mask) != 1) {
		send_to_socket(req->sockfd, "Failure reading mask.\n", strlen("Failure reading mask.\n"));
		return;
	}

	/* Lock the rtable before adding */
	lock_rtable_wr(rs);

	int del_result = del_route(rs, &dest, &mask);

	/* Unlock rtable */
	unlock_rtable(rs);

	char* result_str = (char*)calloc(1, 256);
	if (del_result != 1) {
		snprintf(result_str, 256, "%i routes deleted.\n", del_result);
	} else {
		snprintf(result_str, 256, "%i route deleted.\n", del_result);
	}

	send_to_socket(req->sockfd, result_str, strlen(result_str));

	free(dest_str);
	free(mask_str);
	free(result_str);
}


void cli_ip_route_help(router_state *rs, cli_request* req) {
	char *usage0 = "usage: ip route <args>\n";
	send_to_socket(req->sockfd, usage0, strlen(usage0));

	char *usage1 = "ip route add dest gateway mask interface\n";
	send_to_socket(req->sockfd, usage1, strlen(usage1));

	char *usage2 = "ip route del dest mask\n";
	send_to_socket(req->sockfd, usage2, strlen(usage2));
}


void cli_ip_route_add_help(router_state *rs, cli_request *req) {
	char *usage = "usage: ip route add dest gateway mask interface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}

void cli_ip_route_del_help(router_state *rs, cli_request *req) {
	char *usage = "usage: ip route del dest mask\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_show_hw_rtable(router_state *rs, cli_request *req) {

	if(rs->is_netfpga) {
		char *hw_rtable_info;
		unsigned int len;

		sprint_hw_rtable(rs, &hw_rtable_info, &len);
		send_to_socket(req->sockfd, hw_rtable_info, len);

		free(hw_rtable_info);
	}
}
