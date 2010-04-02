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
#include "or_data_types.h"
#include "or_pwospf.h"
#include "or_utils.h"
#include "or_iface.h"
#include "or_output.h"
#include "or_rtable.h"
#include "or_ip.h"
#include "or_dijkstra.h"
#include "or_arp.h"

void process_pwospf_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {

	assert(sr);
	assert(packet);
	assert(interface);

	router_state *rs = get_router_state(sr);

	/* Check if the packet is invalid, if so drop it */
	if (!is_pwospf_packet_valid(rs, packet, len)) {
		return;
	}

	pwospf_hdr* pwospf = get_pwospf_hdr(packet, len);

	if (pwospf->pwospf_type == PWOSPF_TYPE_HELLO) {
		process_pwospf_hello_packet(sr, packet, len, interface);
	} else if (pwospf->pwospf_type == PWOSPF_TYPE_LINK_STATE_UPDATE) {
		process_pwospf_lsu_packet(sr, packet, len, interface);
	}
}

void process_pwospf_hello_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {
	router_state* rs = get_router_state(sr);
	ip_hdr* iphdr = get_ip_hdr(packet, len);
	pwospf_hdr* pwospf = get_pwospf_hdr(packet, len);
	pwospf_hello_hdr* hello_hdr = get_pwospf_hello_hdr(packet, len);
	int update_neighbors = 0;


	/** Drop the packet if the hello values don't match **/
	if (rs->pwospf_hello_interval != ntohs(hello_hdr->pwospf_hint)) {
		return;
	}

	/* We got a hello packet so we definitely need to unlock and relock interface in write mode */
	unlock_rtable(rs);
	unlock_if_list(rs);
	lock_if_list_wr(rs);
	lock_rtable_rd(rs);
	lock_mutex_pwospf_router_list(rs);

	iface_entry* iface = get_iface(rs, interface);

	/* Drop the packet if the masks don't match */
	if (iface->mask != hello_hdr->pwospf_mask.s_addr) {
		return;
	}

	/* do we have a neighbor with this info ? */
	node* cur = iface->nbr_routers;
	nbr_router* match = NULL;
	while (cur) {
		nbr_router* nbr = (nbr_router*)cur->data;
		if ((nbr->ip.s_addr == iphdr->ip_src.s_addr) &&
				(iface->mask == hello_hdr->pwospf_mask.s_addr) &&
				(nbr->router_id == pwospf->pwospf_rid)) {

			match = nbr;
		}

		cur = cur->next;
	}

	/* if we didn't find this neighbor, update with this packet info */
	if (match == NULL) {
		//printf("HELLO updated interface %s with a new neighbor\n", iface->addr);
		nbr_router* nbr = (nbr_router*)calloc(1, sizeof(nbr_router));
		time(&(nbr->last_rcvd_hello));
		nbr->ip.s_addr = iphdr->ip_src.s_addr;
		nbr->router_id = pwospf->pwospf_rid;

		node* n = node_create();
		n->data = nbr;
		if (iface->nbr_routers == NULL) {
			iface->nbr_routers = n;
		} else {
			node_push_back(iface->nbr_routers, n);
		}

		/* update our router's associated interface neighbor */
		pwospf_router* r = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
		assert(r);


		/* find the pwospf_interface on our router so we can update the neighboring rid */
		node* cur = r->interface_list;
		int found = 0;
		while (cur) {
			pwospf_interface* interface = (pwospf_interface*)cur->data;
			/* check if we have an interface with a blank router id */
			if ((interface->subnet.s_addr == (iface->ip & iface->mask)) && (interface->mask.s_addr == iface->mask) && (interface->router_id == 0)) {
				interface->router_id = nbr->router_id;
				found = 1;
				break;
			}
			cur = cur->next;
		}
		if (!found) {
			/* add a new interface */
			pwospf_interface *interface = (pwospf_interface*)calloc(1, sizeof(pwospf_interface));
			interface->subnet.s_addr = (iface->ip & iface->mask);
			interface->mask.s_addr = iface->mask;
			interface->router_id = pwospf->pwospf_rid;
			node *n = node_create();
			n->data = interface;

			assert(r->interface_list);
			node_push_back(r->interface_list, n);
		}


		/*received a hello from a new neighbor interfaces */
		update_neighbors = 1;


	} else {
		/* Update an existing interface */

		/* this is an update from our neighbor */
		time(&(match->last_rcvd_hello));
	}


	/* Build packets to inform all our neighbors */
	if (update_neighbors == 1) {
		propagate_pwospf_changes(rs, NULL);
	}


	unlock_mutex_pwospf_router_list(rs);
	/* unlocking of the above will be automatically performed in process ip packet */


	/* Signal thread to send new information to all our neigbors */
	if (update_neighbors == 1) {
		pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
	}

}

void broadcast_pwospf_hello_packet(struct sr_instance* sr) {

	assert(sr);

	router_state *rs = get_router_state(sr);
	unsigned int len = sizeof(eth_hdr) + sizeof(ip_hdr) + sizeof(pwospf_hdr) + sizeof(pwospf_hello_hdr);
	uint8_t *packet = malloc(len*sizeof(char));
	iface_entry *ie = 0;
	eth_hdr *eth = (eth_hdr *)packet;
	ip_hdr *ip = get_ip_hdr(packet, len);
	pwospf_hdr *pwospf = get_pwospf_hdr(packet, len);
	pwospf_hello_hdr *hello = get_pwospf_hello_hdr(packet, len);
	uint8_t default_addr[ETH_ADDR_LEN] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
	int interface_has_timedout = 0;

	/* send one hello packet per interface */
	node *iface_walker = rs->if_list;
	while(iface_walker) {
		ie = (iface_entry *)iface_walker->data;
		bzero(packet, len);

		if(ie->is_active & 0x1) {

			/* construct the hello packet */
			populate_pwospf_hello(hello, ie->mask, rs->pwospf_hello_interval);
			populate_pwospf(pwospf, PWOSPF_TYPE_HELLO, sizeof(pwospf_hdr)+sizeof(pwospf_hello_hdr), rs->router_id, rs->area_id);
			pwospf->pwospf_sum = htons(compute_pwospf_checksum(pwospf));
			populate_ip(ip, sizeof(pwospf_hdr)+sizeof(pwospf_hello_hdr), IP_PROTO_PWOSPF, ie->ip, htonl(PWOSPF_HELLO_TIP));
			ip->ip_sum = htons(compute_ip_checksum(ip));
			populate_eth_hdr(eth, default_addr, ie->addr, ETH_TYPE_IP);

			/* send hello packet and update the time sent */
			send_packet(sr, packet, len, ie->name);
			time((time_t *)(&ie->last_sent_hello));


			/* disable timed out interface */
			/* have to lock the router list because we update our pwospf router from inside */
			lock_mutex_pwospf_router_list(rs);
			if(determine_timedout_interface(rs, ie) == 1) {
				/* the outer loop checks all interfaces, so we need this if statement */
				interface_has_timedout = 1;
			}
			unlock_mutex_pwospf_router_list(rs);

		}

		iface_walker = iface_walker->next;
	}


	/* One of neighbor interfaces has timed out */
	if(interface_has_timedout == 1) {

		/* flood with lsu updates */
		lock_mutex_pwospf_router_list(rs);
		propagate_pwospf_changes(rs, NULL);
		unlock_mutex_pwospf_router_list(rs);

		/*send it to every neighbor */
		pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
	}

	free(packet);

}



int determine_timedout_interface(router_state *rs, iface_entry *iface) {

	int interface_has_timedout = 0;
	time_t now;
	int diff;

	node* cur = iface->nbr_routers;
	while (cur) {
		node* next = cur->next;
		nbr_router* nbr = (nbr_router*)cur->data;
		/* disable timed out interfaces  */
		time(&now);
		diff = (int)difftime(now, (time_t)nbr->last_rcvd_hello);
		if (diff > (3 * rs->pwospf_hello_interval)) {
			//printf("HELLO Timed Out %s\n", iface->name);
			interface_has_timedout = 1;

			/* delete this interface from our router entry */
			pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
			node *n = our_router->interface_list;

			/* first count how many routers are on this same subnet */
			int count = 0;
			while(n) {
				pwospf_interface *pi = (pwospf_interface *)n->data;

				if( (pi->subnet.s_addr == (iface->ip & iface->mask)) && (pi->mask.s_addr == iface->mask)) {
					++count;
				}

				n = n->next;
			}

			assert(count > 0);
			if (count == 1) {
				/* if there is only one then we zero out its neighbor router, else we delete it */

				/* find this interface */
				n = our_router->interface_list;
				while(n) {
					pwospf_interface *pi = (pwospf_interface *)n->data;

					if( (pi->subnet.s_addr == (iface->ip & iface->mask)) && (pi->mask.s_addr == iface->mask)) {
						pi->router_id = 0;
						break;
					}

					n = n->next;
				}

			} else {
				/* delete this interface */

				n = our_router->interface_list;
				while(n) {
					pwospf_interface *pi = (pwospf_interface *)n->data;

					if( (pi->subnet.s_addr == (iface->ip & iface->mask)) && (pi->mask.s_addr == iface->mask) && (nbr->router_id == pi->router_id)) {
						node_remove(&our_router->interface_list, n);
						break;
					}

					n = n->next;
				}
			}

			/* delete this neighbor from our physical interface list */
			node_remove(&iface->nbr_routers, cur);

		}

		cur = next;
	}

	return interface_has_timedout;
}



void process_pwospf_lsu_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {

	assert(sr);
	assert(packet);


	//print_packet(packet, len);

	router_state *rs = get_router_state(sr);
	pwospf_hdr *pwospf = get_pwospf_hdr(packet, len);
	pwospf_lsu_hdr *lsu = get_pwospf_lsu_hdr(packet, len);
	pwospf_router *router = 0;
	int update_neighbors = 0;
	int bcast_incoming_lsu_packet = 0;
	int rebroadcast_packet = 0;

	/* If our router id == the lsu update id, drop pckt */
	if(rs->router_id == pwospf->pwospf_rid) {
		return;
	}


	/* Lock rtable and router_list for writes */
	unlock_rtable(get_router_state(sr));
	lock_rtable_wr(get_router_state(sr));
	lock_mutex_pwospf_router_list(rs);


	/* Get the pwospf_router with the matching rid with this packet */
	router = get_router_by_rid(pwospf->pwospf_rid, rs->pwospf_router_list);

	if (router) {

		/* If the seq # match, drop packet, ow update this router's info */
		if( (router->seq != ntohs(lsu->pwospf_seq)) && ( ntohs(lsu->pwospf_seq) > router->seq  ) ) {
			rebroadcast_packet = 1;
			time(&(router->last_update));
			router->seq = htons(lsu->pwospf_seq);

			/* If contents differ from last LSU update, update our neighbors */
			if(populate_pwospf_router_interface_list(router, (uint8_t *)packet, len) == 1) {
				update_neighbors = 1;
			}

		}

	} else {
		rebroadcast_packet = 1;
		add_new_router_neighbor(rs, packet, len);


		/* new neighbor */
		update_neighbors = 1;
	}


	/* does it have a valid ttl? */
	uint16_t ttl = ntohs(lsu->pwospf_ttl) - 1;
	if((rebroadcast_packet == 1) && (ttl > 0)) {

		/* need to forward a copy of this lsu packet to the other neighbors */
		unsigned int bcasted_pwospf_packet_len = ntohs(pwospf->pwospf_len);
		uint8_t *bcasted_pwospf_packet = calloc(bcasted_pwospf_packet_len, sizeof(uint8_t));
		memcpy(bcasted_pwospf_packet, pwospf, bcasted_pwospf_packet_len);

		/* update ttl */
		pwospf_lsu_hdr *bcasted_lsu = (pwospf_lsu_hdr *)(bcasted_pwospf_packet + sizeof(pwospf_hdr));
		bcasted_lsu->pwospf_ttl = htons(ttl);

		/* recompute checksum */
		pwospf_hdr *bcasted_pwospf = (pwospf_hdr *)(bcasted_pwospf_packet);
		bcasted_pwospf->pwospf_sum = htons(compute_pwospf_checksum(bcasted_pwospf));

		/* broadcast the packet to the other neighbors */
		ip_hdr* ip = get_ip_hdr(packet, len);
		broadcast_pwospf_lsu_packet(sr, bcasted_pwospf, &ip->ip_src);
		free(bcasted_pwospf_packet);
		bcast_incoming_lsu_packet = 1;
	}

	/* lsu packet has changed our known world, build data to inform the other 3 neighbors */
	if(update_neighbors == 1) {
		propagate_pwospf_changes(rs, NULL);
	}


	/* unlock the pwospf_router_list */
	unlock_mutex_pwospf_router_list(rs);


	/* updated neighbor, signal to send the constructed lsu flood */
	if( (update_neighbors == 1)  || (bcast_incoming_lsu_packet == 1) ) {
		pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
	}
}



void add_new_router_neighbor(router_state *rs, const uint8_t *packet, unsigned int len) {

	pwospf_hdr *pwospf = get_pwospf_hdr(packet, len);
	pwospf_lsu_hdr *lsu = get_pwospf_lsu_hdr(packet, len);


	/* Unkwnown host: update database */
	pwospf_router *new_router = (pwospf_router *)calloc(1, sizeof(pwospf_router));
	new_router->router_id = pwospf->pwospf_rid;
	new_router->area_id = ntohl(pwospf->pwospf_aid);
	new_router->seq = ntohs(lsu->pwospf_seq);
	time(&new_router->last_update);
	new_router->distance = 0;
	new_router->shortest_path_found = 0;


	/* copy the LS advs into the interface list */
	populate_pwospf_router_interface_list(new_router, (uint8_t *)packet, len);


	/* update the pwospf router list */
	node *n = node_create();
	n->data = (void *)new_router;
	if(rs->pwospf_router_list == NULL) {
		rs->pwospf_router_list = n;
	}
	else {
		node_push_back(rs->pwospf_router_list, n);
	}

}






/*
 * NOT THREAD SAFE
 * It accesses:
 * 	if_list - locally
 * 	arp_cache, arp_queue - via send_ip
 */
void broadcast_pwospf_lsu_packet(struct sr_instance *sr, pwospf_hdr *pwospf, struct in_addr* src_ip) {

	assert(sr);

	router_state *rs = get_router_state(sr);
	node *iface_walker = rs->if_list;
	//pwospf_lsu_hdr *lsu = (pwospf_lsu_hdr *)( ((uint8_t *) pwospf) + sizeof(pwospf_hdr));

	/*
	 * encapsulate the pwospf data in a new ip packet
	 * send it to every neighbor except *potentially* the one who sent the packet in the first place
	 */
	int send_on_this_interface = 1;
	while(iface_walker) {
		iface_entry *iface = (iface_entry *)iface_walker->data;

		if (iface->is_active && (iface->nbr_routers != NULL)) {
			node* cur = iface->nbr_routers;
			while (cur) {
				nbr_router* nbr = (nbr_router*)cur->data;

				/* if we are rebroadcasting, don't send back to the person who sent to us */
				if (!src_ip || (src_ip->s_addr != nbr->ip.s_addr)) {

					unsigned int len = sizeof(eth_hdr) + sizeof(ip_hdr) + ntohs(pwospf->pwospf_len);
					uint8_t *packet = (uint8_t *) malloc(len*sizeof(uint8_t));
					eth_hdr *eth_packet = (eth_hdr *)packet;
					ip_hdr *ip_packet = get_ip_hdr(packet, len);
					pwospf_hdr *pwospf_packet = get_pwospf_hdr(packet, len);
					bzero(packet, len);

					/* construct and put the packet on the sending queue */
					int foo = ntohs(pwospf->pwospf_len);
					memcpy(pwospf_packet, pwospf, foo);
					populate_ip(ip_packet, ntohs(pwospf->pwospf_len), IP_PROTO_PWOSPF, iface->ip, nbr->ip.s_addr);
					ip_packet->ip_sum = htons(compute_ip_checksum(ip_packet));
					populate_eth_hdr(eth_packet, NULL, iface->addr, ETH_TYPE_IP);


					//print_packet(packet, len);

					/* put it on the queue */
					lock_mutex_pwospf_lsu_queue(rs);

					pwospf_lsu_queue_entry *lqe = (pwospf_lsu_queue_entry *)calloc(1, sizeof(pwospf_lsu_queue_entry));
					memcpy(lqe->iface, iface->name, IF_LEN);
					lqe->ip.s_addr = iface->ip;
					lqe->packet = packet;
					lqe->len = len;

					node *n = node_create();
					n->data = (void *)lqe;

					if(rs->pwospf_lsu_queue == NULL) {
						rs->pwospf_lsu_queue = n;
					}
					else {
						node_push_back(rs->pwospf_lsu_queue, n);
					}

					unlock_mutex_pwospf_lsu_queue(rs);
				}

				cur = cur->next;
			}
		}

		iface_walker = iface_walker->next;
		send_on_this_interface = 1;

	} /* end of while(iface_walker) */

}



int is_pwospf_packet_valid(router_state *rs, const uint8_t *packet, unsigned int len) {

	pwospf_hdr *pwospf = get_pwospf_hdr(packet, len);


	/* Check for PWOSPFV2 */
	if(pwospf->pwospf_ver != 2) {
		return 0;
	}

	uint16_t pckt_sum = htons(pwospf->pwospf_sum);
	uint16_t sum = compute_pwospf_checksum(pwospf);

	/* Check the checksum */
	if(pckt_sum != sum) {
		return 0;
	}


	/* Check authtype is set to 0 */
	if(ntohs(pwospf->pwospf_atype) != 0) {
		return 0;
	}

	/* Check for area id */
	if(ntohl(pwospf->pwospf_aid) != rs->area_id) {
		return 0;
	}

	/* if router id is equal to hours we need to dump the packet */
	if (ntohl(pwospf->pwospf_rid) == rs->router_id) {
		return 0;
	}

	return 1;
}



uint16_t compute_pwospf_checksum(pwospf_hdr *pwospf) {

	pwospf->pwospf_sum = 0;
	unsigned long sum = 0;
	uint16_t s_sum = 0;
	int numShorts = ntohs(pwospf->pwospf_len) / 2;
	int i = 0;
	uint16_t* s_ptr = (uint16_t*)pwospf;

	for (i = 0; i < numShorts; ++i) {
		/* sum all except checksum and authentication fields */
		if ( i < 8 ||  11 < i ) {
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





int populate_pwospf_router_interface_list(pwospf_router *router, uint8_t *packet, unsigned int len) {

	pwospf_lsu_hdr *lsu = get_pwospf_lsu_hdr(packet, len);
	uint32_t pwospf_num = ntohl(lsu->pwospf_num);

	uint8_t *packet_adv = get_pwospf_lsu_data(packet, len);
	pwospf_lsu_adv *next_packet_adv = (pwospf_lsu_adv *)packet_adv;

	int changed_list = 0;
	int i;

	if(router->interface_list == NULL) {

		/* add all advs to the interface list */
		for(i=0; i < pwospf_num; i++) {

			/* allocate memory for this ad */
			node *new_iface_list_node = node_create();
			pwospf_interface *new_iface_list_entry = (pwospf_interface *) calloc(1, sizeof(pwospf_interface));

			/* populate the new adv */
			new_iface_list_entry->subnet.s_addr = next_packet_adv->pwospf_sub.s_addr & next_packet_adv->pwospf_mask.s_addr;
			new_iface_list_entry->mask.s_addr =  next_packet_adv->pwospf_mask.s_addr;
			new_iface_list_entry->router_id = next_packet_adv->pwospf_rid;
			new_iface_list_entry->is_active = 0;


			/* insert the new adv into the list */
			new_iface_list_node->data = (void *)new_iface_list_entry;
			if(router->interface_list == NULL) {
				router->interface_list = new_iface_list_node;
			}
			else {
				node_push_back(router->interface_list, new_iface_list_node);
			}


			/* move to the next adv */
			next_packet_adv += 1;
		} /* end of for loop */

		changed_list = 1;
	}	else {

		/* CHECK IF WE HAVE NEW ADVERTISEMENTS FROM THIS INCOMING PACKET */
		for (i=0; i<pwospf_num; i++) {
			int is_new_adv = 1;

			/* iterate over the router's pwospf ifaces */
			node *interface_list_walker = router->interface_list;
			node *interface_list_next = NULL;
			while (interface_list_walker) {
				interface_list_next = interface_list_walker->next;

				pwospf_interface *interface_list_entry = (pwospf_interface *)interface_list_walker->data;

				/* Compare this entries subnet & mask to the pckt adv */
				if( (interface_list_entry->subnet.s_addr == (next_packet_adv->pwospf_sub.s_addr & next_packet_adv->pwospf_mask.s_addr)) &&
				    (interface_list_entry->mask.s_addr == next_packet_adv->pwospf_mask.s_addr) &&
				    interface_list_entry->router_id == next_packet_adv->pwospf_rid) {

					is_new_adv = 0;
					break;
				}

				/* move to the next interface entry */
				interface_list_walker = interface_list_next;
			}

			/* add the new adv to the list */
			if(is_new_adv) {

				/* allocate memory for this adv */
				node *new_iface_list_node = node_create();
				pwospf_interface *new_iface_list_entry = (pwospf_interface *) calloc(1, sizeof(pwospf_interface));

				/* populate the new adv */
				new_iface_list_entry->subnet.s_addr = next_packet_adv->pwospf_sub.s_addr & next_packet_adv->pwospf_sub.s_addr;
				new_iface_list_entry->mask.s_addr =  next_packet_adv->pwospf_mask.s_addr;
				new_iface_list_entry->router_id = next_packet_adv->pwospf_rid;
				new_iface_list_entry->is_active = 0;


				/* insert the new adv into the list */
				new_iface_list_node->data = (void *)new_iface_list_entry;
				node_push_back(router->interface_list, new_iface_list_node);

				changed_list = 1;
			}

			next_packet_adv += 1;

		} /* end of for loop */

		/* CHECK IF THERE ARE ANY MISSING ADVERTISEMENTS */
		node *interface_list_walker = router->interface_list;
		node *interface_list_next = NULL;
		while (interface_list_walker) {
			interface_list_next = interface_list_walker->next;
			pwospf_interface* interface_list_entry = (pwospf_interface*)interface_list_walker->data;

			/* see if there is a matching advertisement */
			packet_adv = get_pwospf_lsu_data(packet, len);
			next_packet_adv = (pwospf_lsu_adv *)packet_adv;
			int found = 0;

			for (i=0; i<pwospf_num; i++) {
				/* Compare this entries subnet & mask to the pckt adv */
				if ((interface_list_entry->subnet.s_addr == (next_packet_adv->pwospf_sub.s_addr & next_packet_adv->pwospf_mask.s_addr)) &&
				    (interface_list_entry->mask.s_addr == next_packet_adv->pwospf_mask.s_addr) &&
				    (interface_list_entry->router_id == next_packet_adv->pwospf_rid)) {

						found = 1;
						break;
				}

				next_packet_adv++;
			}

			if (!found) {
				node_remove(&(router->interface_list), interface_list_walker);
				changed_list = 1;
			}

			interface_list_walker = interface_list_next;
		}

	}

	return changed_list;
}


void propagate_pwospf_changes(router_state *rs, char *exclude_this_interface) {

	/* update the interface entries in every router entry */
	node *n = rs->pwospf_router_list;
	while(n) {
		pwospf_router *router = (pwospf_router *)n->data;
		determine_active_interfaces(rs, router);

		n = n->next;
	}

	/* recompute fwd table */
	dijkstra_trigger(rs);

	/* build a new IP-LSU update packet */
	start_lsu_bcast_flood(rs, exclude_this_interface);
}

void determine_active_interfaces(router_state *rs, pwospf_router *router) {

	node *il_this_walker = router->interface_list;
	while(il_this_walker) {

		pwospf_interface *pi_this = (pwospf_interface *)il_this_walker->data;
		pi_this->is_active = 0;

		pwospf_router *another_router = get_router_by_rid(pi_this->router_id, rs->pwospf_router_list);
		if(another_router) {

			node *il_another_walker = another_router->interface_list;
			while(il_another_walker) {

				pwospf_interface *pi_another = (pwospf_interface *)il_another_walker->data;

				if( (pi_this->subnet.s_addr == pi_another->subnet.s_addr) &&
				    (pi_this->mask.s_addr == pi_another->mask.s_addr) &&
				    (!( (pi_this->router_id == 0) || (pi_another->router_id == 0) ) )
				    ) {
					pi_this->is_active = 1;
					pi_another->is_active = 1;
				}

				il_another_walker = il_another_walker->next;
			}
		}

		il_this_walker = il_this_walker->next;
	}

}




void start_lsu_bcast_flood(router_state *rs, char *exclude_this_interface) {
	/* If the flag is set to not broadcast, exit */
	if (!rs->pwospf_lsu_broadcast) {
		return;
	}

	//printf("* LSU FLOOD TRIGGERED *\n");
	/* SEND LSU PACKETS */
	uint8_t *pwospf_packet = 0;
	unsigned int pwospf_packet_len = 0;
	pwospf_hdr *pwospf = 0;

	construct_pwospf_lsu_packet(rs, &pwospf_packet, &pwospf_packet_len);

	pwospf = (pwospf_hdr *)pwospf_packet;

	broadcast_pwospf_lsu_packet((struct sr_instance *)rs->sr, pwospf, NULL);
	free(pwospf_packet);

	/* update the last sent flood time */
	pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
	time(&(our_router->last_update));
}




void construct_pwospf_lsu_packet(router_state *rs, uint8_t **pwospf_packet, unsigned int *pwospf_packet_len) {

	assert(rs);
	assert(pwospf_packet);
	assert(pwospf_packet_len);

	pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
	assert(our_router);

	/* build the advertisements */
	pwospf_lsu_adv *iface_adv = 0;
	uint32_t pwospf_num = 0;
	construct_pwospf_lsu_adv(rs, &iface_adv, &pwospf_num);


	/* allocate memory for the packet */
	unsigned int len = sizeof(pwospf_hdr) + sizeof(pwospf_lsu_hdr) + pwospf_num * sizeof(pwospf_lsu_adv);
	uint8_t *packet = (uint8_t *)calloc(len, sizeof(uint8_t));
	pwospf_hdr *pwospf = (pwospf_hdr *)packet;
	pwospf_lsu_hdr *lsu = (pwospf_lsu_hdr *) (packet + sizeof(pwospf_hdr));
	uint8_t *lsu_adv = packet + sizeof(pwospf_hdr) + sizeof(pwospf_lsu_hdr);


	/* populate the fields of the packet */
	populate_pwospf(pwospf, PWOSPF_TYPE_LINK_STATE_UPDATE, len, rs->router_id, rs->area_id);
	populate_pwospf_lsu(lsu, our_router->seq, pwospf_num);
	memcpy(lsu_adv, iface_adv, pwospf_num*sizeof(pwospf_lsu_adv));


	/* populate the checksum */
	pwospf->pwospf_sum = htons(compute_pwospf_checksum(pwospf));


	*pwospf_packet = packet;
	*pwospf_packet_len = len;
	free(iface_adv);


	/* update our router entry */
	time(&our_router->last_update);
	our_router->seq += 1;

}


void construct_pwospf_lsu_adv(router_state *rs, pwospf_lsu_adv **lsu_adv, uint32_t *pwospf_num) {
	assert(rs);
	assert(lsu_adv);
	assert(pwospf_num);

	node* cur = NULL;
	pwospf_lsu_adv *iface_adv = 0;
	pwospf_lsu_adv *iface_adv_walker = 0;
	uint32_t num = 0;

	pwospf_router* r = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
	assert(r);

	num = node_length(r->interface_list);
	iface_adv = (pwospf_lsu_adv *)calloc(num, sizeof(pwospf_lsu_adv));
	iface_adv_walker = iface_adv;

	cur = r->interface_list;
	while (cur) {
		pwospf_interface* iface = (pwospf_interface*)cur->data;

		iface_adv_walker->pwospf_sub.s_addr = iface->subnet.s_addr;
		iface_adv_walker->pwospf_mask.s_addr = iface->mask.s_addr;
		iface_adv_walker->pwospf_rid = iface->router_id;

		cur = cur->next;
		iface_adv_walker++;
	}

	*lsu_adv = iface_adv;
	*pwospf_num = num;
}


pwospf_interface *default_route_present(router_state *rs) {

	pwospf_interface *DEFAULT_ROUTE = 0;
	node *rtable_walker = rs->rtable;
	while(rtable_walker) {

			rtable_entry *re = (rtable_entry *)rtable_walker->data;
			if (re->is_static && (re->ip.s_addr == 0) && (re->mask.s_addr == 0)) {

				DEFAULT_ROUTE = calloc(1, sizeof(pwospf_interface));

				DEFAULT_ROUTE->subnet.s_addr = re->ip.s_addr & re->mask.s_addr;
				DEFAULT_ROUTE->mask.s_addr = re->mask.s_addr;
				DEFAULT_ROUTE->router_id = 0;

				break;
			}

			rtable_walker = rtable_walker->next;
		}

	return DEFAULT_ROUTE;
}


int is_route_present(pwospf_router *router, pwospf_interface *iface) {

	int is_present = 0;
	node *il_walker = router->interface_list;
	while(il_walker) {

		pwospf_interface *pi = (pwospf_interface *)il_walker->data;

		if( (pi->subnet.s_addr == iface->subnet.s_addr) &&
		    (pi->mask.s_addr == iface->mask.s_addr) &&
		    (pi->router_id == iface->router_id)) {
			is_present = 1;
			break;
		}

		il_walker = il_walker->next;
	}

	return is_present;

}




pwospf_hdr *get_pwospf_hdr(const uint8_t *packet, unsigned int len) {
	return (pwospf_hdr *) (packet + ETH_HDR_LEN + sizeof(ip_hdr));
}

pwospf_hello_hdr *get_pwospf_hello_hdr(const uint8_t *packet, unsigned int len) {
	return (pwospf_hello_hdr *) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(pwospf_hdr));
}

pwospf_lsu_hdr *get_pwospf_lsu_hdr(const uint8_t *packet, unsigned int len) {
	return (pwospf_lsu_hdr *) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(pwospf_hdr));
}

uint8_t *get_pwospf_lsu_data(const uint8_t *packet, unsigned int len) {
	return (uint8_t *) (packet + ETH_HDR_LEN + sizeof(ip_hdr) + sizeof(pwospf_hdr) + sizeof(pwospf_lsu_hdr));
}

void cli_show_pwospf_iface(router_state *rs, cli_request *req) {
	char *if_list_info;
	int len;

	lock_if_list_rd(rs);
	sprint_pwospf_if_list(rs, &if_list_info, &len);
	unlock_if_list(rs);

	send_to_socket(req->sockfd, if_list_info, len);
	free(if_list_info);
}


void cli_show_pwospf_iface_help(router_state *rs, cli_request *req) {
	char *usage = "usage: show pwospf interface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_show_pwospf_router_list(router_state *rs, cli_request *req) {
	char *router_list_info;
	int len;

	lock_mutex_pwospf_router_list(rs);
	sprint_pwospf_router_list(rs, &router_list_info, &len);
	unlock_mutex_pwospf_router_list(rs);

	send_to_socket(req->sockfd, router_list_info, len);
	free(router_list_info);
}



void cli_pwospf_set_aid(router_state *rs, cli_request *req) {

	uint32_t area_id = 0;
	if (sscanf(req->command, "set aid %u", &area_id) != 1) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	rs->area_id = area_id;
	send_to_socket(req->sockfd, "Area id has been set\n", strlen("Area id has been set\n"));
}

void cli_pwospf_set_aid_help(router_state *rs, cli_request *req) {
	char *usage = "usage: aid set [number]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_pwospf_set_hello(router_state *rs, cli_request *req) {

	uint32_t hello_interval = 0;
	if(sscanf(req->command, "set hello interval %u", &hello_interval) != 1) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
	}

	rs->pwospf_hello_interval = (uint16_t)hello_interval;
	send_to_socket(req->sockfd, "Hello interval has been set\n", strlen("Hello interval has been set\n"));
}

void cli_pwospf_set_lsu_broadcast(router_state *rs, cli_request *req) {
	char* value_str;

	if(sscanf(req->command, "set lsu broadcast %as", &value_str) != 1) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
		return;
	}

	char* msg;
	if (strcmp("on", value_str) == 0) {
		rs->pwospf_lsu_broadcast = 1;
		msg = "LSU Broadcasting set to ON.\n";
	} else if (strcmp("off", value_str) == 0) {
		rs->pwospf_lsu_broadcast = 0;
		msg = "LSU Broadcasting set to OFF.\n";
	} else {
		msg = "Failure reading arguments.\n";
	}

	send_to_socket(req->sockfd, msg, strlen(msg));
}

void cli_pwospf_set_lsu_interval(router_state *rs, cli_request *req) {
	uint32_t lsu_interval = 0;
	if(sscanf(req->command, "set lsu interval %u", &lsu_interval) != 1) {
		send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
	}

	rs->pwospf_lsu_interval = lsu_interval;
	char* msg = "LSU Interval set.\n";
	send_to_socket(req->sockfd, msg, strlen(msg));
}

void cli_pwospf_help(router_state *rs, cli_request *req) {
	char *usage = 0;

	usage = "pwospf usage: \n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow pwospf interface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow pwospf router\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset aid [value]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset hello interval [value]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset lsu broadcast [on/off]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset lsu interval [value]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tsend hello\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tsend lsu\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_show_pwospf_info(router_state *rs, cli_request *req) {
	char *info;
	int len;

	info = "PWOSPF INFORMATION:\n";
	send_to_socket(req->sockfd, info, strlen(info));
	char buf[512];
	bzero(buf, 512);

	sprintf(buf, "Area ID: %u\nHello Interval: %u\nLSU Interval: %u\n\n",
		rs->area_id, rs->pwospf_hello_interval, rs->pwospf_lsu_interval);
	send_to_socket(req->sockfd, buf, strlen(buf));

	lock_mutex_pwospf_router_list(rs);
	sprint_pwospf_router_list(rs, &info, &len);
	unlock_mutex_pwospf_router_list(rs);

	send_to_socket(req->sockfd, info, len);
	free(info);

	info =  "\n\n";
	send_to_socket(req->sockfd, info, strlen(info));

	lock_if_list_rd(rs);
	sprint_pwospf_if_list(rs, &info, &len);
	unlock_if_list(rs);

	send_to_socket(req->sockfd, info, len);
	free(info);


}


void *pwospf_hello_thread(void *param) {

	assert(param);
	struct sr_instance *sr = (struct sr_instance *)param;
	router_state *rs = get_router_state(sr);

	while(1) {

		lock_if_list_wr(rs);
		broadcast_pwospf_hello_packet(sr);
		unlock_if_list(rs);

		sleep(rs->pwospf_hello_interval-1);
	}
}


void *pwospf_lsu_thread(void *param) {

	assert(param);
	struct sr_instance *sr = (struct sr_instance *)param;
	router_state *rs = get_router_state(sr);

	time_t now;
	int diff;

	sleep(5);
	while(1) {

		lock_mutex_pwospf_router_list(rs);
		pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
		unlock_mutex_pwospf_router_list(rs);
		time(&now);
		if (our_router) {
			diff = (int)difftime(now, our_router->last_update);

			/* send an lsu update if we haven't done so */
			if(diff > (rs->pwospf_lsu_interval)) {

				lock_mutex_pwospf_router_list(rs);
				start_lsu_bcast_flood(rs, NULL);
				unlock_mutex_pwospf_router_list(rs);

				/* signal the lsu bcast thread to send the packets */
				pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
			}
		}

		/* poll every 1 second */
		sleep(1);
	}

}

void *pwospf_lsu_timeout_thread(void *param) {

	assert(param);
	struct sr_instance *sr = (struct sr_instance *)param;
	router_state *rs = get_router_state(sr);
	time_t now;
	int diff;
	int timeout_occured = 0;

	while(1) {
		timeout_occured = 0;
		lock_mutex_pwospf_router_list(rs);

		node *rl_cur = rs->pwospf_router_list;
		node *rl_next = NULL;

		/* eliminate lsu timedout entries */
		while(rl_cur) {
			rl_next = rl_cur->next;

			pwospf_router *rl_entry = (pwospf_router *)rl_cur->data;
			/* don't time out ourself */
			if (rl_entry->router_id == rs->router_id) {
				rl_cur = rl_next;
				continue;
			}

			time(&now);
			diff = (int)difftime(now, rl_entry->last_update);

			/* if(diff > 3 * LSUINT) */
			if (diff > (rs->pwospf_lsu_interval * 3)) {
				char addr[16];
				inet_ntop(AF_INET, &(rl_entry->router_id), addr, 16);
				//printf("PWOSPF ROUTER LENGTH: %u\n", node_length(rs->pwospf_router_list));
				//printf("Timing out router with id: %s\n", addr);
				node *il_cur = rl_entry->interface_list;
				node *il_next = NULL;

				while(il_cur) {
					il_next = il_cur->next;
					node_remove(&rl_entry->interface_list, il_cur);
					il_cur = il_next;
				}

				node_remove(&rs->pwospf_router_list, rl_cur);
				timeout_occured = 1;
			}

			rl_cur = rl_next;
		}


		/* build lsu flood information for all our neighbors */
		if(timeout_occured == 1) {
			//printf("PWOSPF ROUTER LENGTH: %u\n", node_length(rs->pwospf_router_list));
			propagate_pwospf_changes(rs, NULL);
		}


		unlock_mutex_pwospf_router_list(rs);


		/* signal thread to send the lsu flood */
		if(timeout_occured == 1) {
			pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
		}


		sleep(1);
	}


}


void *pwospf_lsu_bcast_thread(void *param) {

	assert(param);
	struct sr_instance *sr = (struct sr_instance *)param;
	router_state *rs = get_router_state(sr);

	while(1) {
		lock_mutex_pwospf_lsu_bcast(rs);
		pthread_cond_wait(rs->pwospf_lsu_bcast_cond, rs->pwospf_lsu_bcast_mutex);

		/* get lsu packet queue */
		node *lsu_queue = 0;

		lock_mutex_pwospf_lsu_queue(rs);
		lsu_queue = rs->pwospf_lsu_queue;
		rs->pwospf_lsu_queue = 0;
		unlock_mutex_pwospf_lsu_queue(rs);

		lock_arp_cache_rd(rs);
		lock_arp_queue_wr(rs);
		lock_if_list_rd(rs);
		lock_rtable_rd(rs);

		/* iterate over the queue and send each packet */
		node *cur = lsu_queue;
		node *next = 0;
		while(cur) {
			next = cur->next;
			pwospf_lsu_queue_entry *lqe = (pwospf_lsu_queue_entry *)cur->data;

			//print_packet(lqe->packet, lqe->len);

			struct in_addr next_hop;
			char next_hop_iface[IF_LEN];
			bzero(next_hop_iface, IF_LEN);


			/* is there an entry in our routing table for the destination? */
			if (!get_next_hop(&next_hop, next_hop_iface, IF_LEN, rs, &((get_ip_hdr(lqe->packet, lqe->len))->ip_dst))) {
				send_ip(sr, lqe->packet, lqe->len, &next_hop, next_hop_iface);
			} else {
				char dest[16];
				inet_ntop(AF_INET, &((get_ip_hdr(lqe->packet, lqe->len))->ip_dst), dest, 16);
				//printf("FAILURE SENDING LSU PACKET Could Not Match: %s\n", dest);
			}

			free(lqe);
			free(cur);
			cur = next;
		}

		unlock_rtable(rs);
		unlock_if_list(rs);
		unlock_arp_queue(rs);
		unlock_arp_cache(rs);

		unlock_mutex_pwospf_lsu_bcast(rs);
	}

}




void cli_pwospf_send_hello(router_state *rs, cli_request *req) {

	lock_if_list_wr(rs);
	broadcast_pwospf_hello_packet(rs->sr);
	unlock_if_list(rs);

	char *usage = "Hello packet sent on each interface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}


void cli_pwospf_send_lsu(router_state *rs, cli_request *req) {

	lock_mutex_pwospf_router_list(rs);
	start_lsu_bcast_flood(rs, NULL);
	unlock_mutex_pwospf_router_list(rs);

	/* signal the lsu bcast thread to send the packets */
	pthread_cond_signal(rs->pwospf_lsu_bcast_cond);

	char *usage = "LSU packet sent on each interface (up or down)\n";
	send_to_socket(req->sockfd, usage, strlen(usage));


}


void lock_mutex_pwospf_router_list(router_state* rs) {
	assert(rs);
	if(pthread_mutex_lock(rs->pwospf_router_list_lock) != 0) {
		perror("Failure getting router list mutex lock");
	}
}


void unlock_mutex_pwospf_router_list(router_state* rs) {
	assert(rs);
	if(pthread_mutex_unlock(rs->pwospf_router_list_lock) != 0) {
		perror("Failure unlocking router list mutex");
	}
}


void lock_mutex_pwospf_lsu_queue(router_state *rs) {
	assert(rs);
	if(pthread_mutex_lock(rs->pwospf_lsu_queue_lock) != 0) {
		perror("Failure unlocking lsu queue mutex");
	}
}

void unlock_mutex_pwospf_lsu_queue(router_state *rs){
	assert(rs);
	if(pthread_mutex_unlock(rs->pwospf_lsu_queue_lock) != 0) {
		perror("Failure unlocking lsu queue mutex");
	}
}


void lock_mutex_pwospf_lsu_bcast(router_state *rs){
	assert(rs);
	if(pthread_mutex_lock(rs->pwospf_lsu_bcast_mutex) != 0) {
		perror("Failure unlocking lsu bcast mutex");
	}
}

void unlock_mutex_pwospf_lsu_bcast(router_state *rs) {
	assert(rs);
	if(pthread_mutex_unlock(rs->pwospf_lsu_bcast_mutex) != 0) {
		perror("Failure unlocking c mutex");
	}
}



