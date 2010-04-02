/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "or_dijkstra.h"
#include "or_utils.h"
#include "or_pwospf.h"
#include "or_rtable.h"
#include "or_iface.h"
#include "or_output.h"
#include <assert.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <pthread.h>
#include <errno.h>

pwospf_router* get_shortest(node* pwospf_router_list);
void update_neighbor_distance(pwospf_router* w, node* pwospf_router_list);
node* build_route_wrapper_list(uint32_t our_rid, node* pwospf_router_list);
void add_route_wrappers(uint32_t our_rid, node** head, pwospf_router* r);
node* get_route_wrapper(node* head, struct in_addr* subnet, struct in_addr* mask);
iface_entry* get_iface_by_rid(uint32_t rid, node* if_list);
iface_entry* get_iface_by_subnet_mask(struct in_addr* subnet, struct in_addr* mask, node* if_list);
void print_wrapper_list(node* route_wrapper_list);

struct route_wrapper {
	rtable_entry entry; /* entry being wrapped, lacking next hop ip */
	uint16_t distance; /* distance from source in hops */
	uint32_t next_rid; /* next router id from source */
	uint8_t directly_connected:1; /* is this route directly connected to us? */
};
typedef struct route_wrapper route_wrapper;

/*
 * NOT thread safe, lock the pwospf_router_list_lock for writes
 * on the router_state object before passing it in, also the if_list
 * lock for reads.
 *
 * Returns: a linked list representing the dynamic rtable
 *
 */

node* compute_rtable(uint32_t our_router_id, node* pwospf_router_list, node* if_list) {
	/* initialize all the entriest to their max distance, except us */
	node* cur = pwospf_router_list;
	pwospf_router* r = NULL;
	pwospf_router* r_shortest = NULL;

	while (cur) {
		r = (pwospf_router*)cur->data;
		if (r->router_id == our_router_id) {
			r->distance = 0;
			r->shortest_path_found = 1;
		} else if (r->router_id != 0) {
			r->distance = 0xFFFFFFFF;
			r->shortest_path_found = 0;
		}

		cur = cur->next;
	}

	/* Set our router as the shortest */
	r_shortest = get_router_by_rid(our_router_id, pwospf_router_list);

	while (r_shortest) {
		/* add this router to N' */
		r_shortest->shortest_path_found = 1;

		/* update the distances to our neighbors */
		update_neighbor_distance(r_shortest, pwospf_router_list);

		/* get the next router with the shortest distance */
		r_shortest = get_shortest(pwospf_router_list);
	}

	/* now have the shortest path to each router, build the temporary route table */
	node* route_wrapper_list = build_route_wrapper_list(our_router_id, pwospf_router_list);
	//print_wrapper_list(route_wrapper_list);

	/* we now have a list of wrapped proper entries, but they need specific interface info,
	 * and need to lose the wrapping
	 */
	node* route_list = NULL;

	cur = route_wrapper_list;
	while (cur) {
		route_wrapper* wrapper = (route_wrapper*)cur->data;
		rtable_entry* new_entry = (rtable_entry*)calloc(1, sizeof(rtable_entry));
		/* just blast the entry information across */
		memcpy(new_entry, &(wrapper->entry), sizeof(rtable_entry));
		/* get the new stuff */
		iface_entry* iface = get_iface_by_rid(wrapper->next_rid, if_list);
		if (!iface) {
			iface = get_iface_by_subnet_mask(&(wrapper->entry.ip), &(wrapper->entry.mask), if_list);
			if (!iface) {
				/* most likely the default entry, assume its static, so just continue */
				free(new_entry);
				cur = cur->next;
				continue;
			}
		}
		assert(iface);

		memcpy(new_entry->iface, iface->name, IF_LEN);

		if (wrapper->directly_connected) {
			new_entry->gw.s_addr = 0;
		} else {
			nbr_router* nbr = get_nbr_by_rid(iface, wrapper->next_rid);
			assert(nbr);
			new_entry->gw.s_addr = nbr->ip.s_addr;
		}

		new_entry->is_active = 1;
		new_entry->is_static = 0;

		/* grab a new node, add it to the list */
		node* temp = node_create();
		temp->data = new_entry;

		if (!route_list) {
			route_list = temp;
		} else {
			node_push_back(route_list, temp);
		}

		cur = cur->next;
	}

	/* run through and free the wrapper list */
	cur = route_wrapper_list;
	while (cur) {
		node* next = cur->next;
		node_remove(&route_wrapper_list, cur);
		cur = next;
	}

	return route_list;
}

pwospf_router* get_router_by_rid(uint32_t rid, node* pwospf_router_list) {
	node* cur = pwospf_router_list;
	while (cur) {
		pwospf_router* r = (pwospf_router*)cur->data;
		if (r->router_id == rid) {
			return r;
		}
		cur = cur->next;
	}

	return NULL;
}

pwospf_router* get_shortest(node* pwospf_router_list) {
	pwospf_router* shortest_router = NULL;
	uint32_t shortest_distance = 0xFFFFFFFF;

	node* cur = pwospf_router_list;
	while (cur) {
		pwospf_router* r = (pwospf_router*)cur->data;
		if ((!r->shortest_path_found) && (r->distance < shortest_distance)) {
			shortest_router = r;
			shortest_distance = r->distance;
		}
		cur = cur->next;
	}

	return shortest_router;
}

/*
 * Helper function to update distances of routers attached to w's interfaces
 */
void update_neighbor_distance(pwospf_router* w, node* pwospf_router_list) {
	node* cur = w->interface_list;
	/* iterate through each interface of this router */
	while (cur) {
		pwospf_interface* i = (pwospf_interface*)cur->data;
		if ((i->router_id != 0) && i->is_active) {
			pwospf_router* v = get_router_by_rid(i->router_id, pwospf_router_list);

			/* if the distance to v is shorter through w, update it */
			/* ADDED: ensure V exists in our router list as well,
			 * it is possible that someone is reporting a router that is
			 * a neighbor that we have not received an LSU for yet */
			if ((v) && (!v->shortest_path_found) && ((w->distance+1) < v->distance)) {
				v->distance = w->distance + 1;
				v->prev_router = w;
			}
		}

		cur = cur->next;
	}
}

node* build_route_wrapper_list(uint32_t our_rid, node* pwospf_router_list) {
	node* head = NULL;

	/* iterate through the routers, adding their interfaces to the route list */
	node* cur = pwospf_router_list;
	while (cur) {
		pwospf_router* r = (pwospf_router*)cur->data;
		add_route_wrappers(our_rid, &head, r);
		cur = cur->next;
	}

	return head;
}

void add_route_wrappers(uint32_t our_rid, node** head, pwospf_router* r) {
	node* cur = r->interface_list;
	while (cur) {
		pwospf_interface* i = (pwospf_interface*)cur->data;

		/* check if we have an existing route matching this subnet and mask */
		node* temp_node = get_route_wrapper(*head, &(i->subnet), &(i->mask));
		if (temp_node) {
			/* if our distance is longer, just continue to the next interface */
			route_wrapper* wrapper = (route_wrapper*)temp_node->data;
			if (r->distance >= wrapper->distance) {
				cur = cur->next;
				continue;
			} else {
				/* replace the existing entries data with ours */
				wrapper->distance = r->distance;
				/* walk down until the next router is the source */
				pwospf_router* cur_router = r;
				if (!cur_router->prev_router) {
					wrapper->next_rid = i->router_id;
				} else {
					while (cur_router->prev_router->distance != 0) {
						cur_router = cur_router->prev_router;
					}

					wrapper->next_rid = cur_router->router_id;
				}

				/* set that this is directly connected to us */
				if (our_rid == r->router_id) {
					wrapper->directly_connected = 1;
				}
			}
		} else {
			node* new_node = node_create();

			/* no existing route wrapper, create a new one for this route */
			route_wrapper* new_route = (route_wrapper*)calloc(1, sizeof(route_wrapper));
			new_route->entry.ip.s_addr = i->subnet.s_addr & i->mask.s_addr;
			new_route->entry.mask.s_addr = i->mask.s_addr;
			new_route->distance = r->distance;

			/* walk down until the next router is the source */
			pwospf_router* cur_router = r;
			if (!cur_router->prev_router) {
				new_route->next_rid = i->router_id;
			} else {
				while (cur_router->prev_router->distance != 0) {
					cur_router = cur_router->prev_router;
				}
				new_route->next_rid = cur_router->router_id;
			}

			/* set that this is directly connected to us */
			if (our_rid == r->router_id) {
				new_route->directly_connected = 1;
			}

			/* point the node's data at our route wrapper */
			new_node->data = new_route;

			if (!(*head)) {
				(*head) = new_node;
			} else {
				node_push_back(*head, new_node);
			}
		}

		cur = cur->next;
	}
}

node* get_route_wrapper(node* head, struct in_addr* subnet, struct in_addr* mask) {
	/* walk the route wrapper list looking for an entry matching this subnet and mask */
	node* cur = head;
	while (cur) {
		route_wrapper* wrapper = (route_wrapper*)cur->data;
		if ((wrapper->entry.ip.s_addr == (subnet->s_addr & mask->s_addr)) && (wrapper->entry.mask.s_addr == mask->s_addr)) {
			return cur;
		}

		cur = cur->next;
	}

	return NULL;
}

/*
 * Find and return the iface_entry structure that has a neighbor
 * with the given router id.
 *
 * Params
 * rid: neighbor router id
 * if_list: interface list
 *
 * Returns
 * the associated iface_entry with rid as the neighboring router
 */
iface_entry* get_iface_by_rid(uint32_t rid, node* if_list) {
	if (!rid) {
		return NULL;
	}

	node* cur = if_list;
	while (cur) {
		iface_entry* i = (iface_entry*)cur->data;
		node* nbr_walker = i->nbr_routers;

		while (nbr_walker) {
			nbr_router* nbr = nbr_walker->data;

			if (nbr->router_id == rid) {
				return i;
			}

			nbr_walker = nbr_walker->next;
		}

		cur = cur->next;
	}
	return NULL;
}

iface_entry* get_iface_by_subnet_mask(struct in_addr* subnet, struct in_addr* mask, node* if_list) {
	node* cur = if_list;
	while (cur) {
		iface_entry* i = (iface_entry*)cur->data;
		if (((i->ip & i->mask) == subnet->s_addr) && (i->mask == mask->s_addr)) {
			return i;
		}

		cur = cur->next;
	}
	return NULL;
}

void print_wrapper_list(node* route_wrapper_list) {
	node* cur = route_wrapper_list;
	while (cur) {
		route_wrapper* wrapper = (route_wrapper*)cur->data;
		char subnet_str[16];
		char mask_str[16];
		inet_ntop(AF_INET, &(wrapper->entry.ip), subnet_str, 16);
		inet_ntop(AF_INET, &(wrapper->entry.mask), mask_str, 16);

		printf("%u %u %s %s\n", wrapper->distance, wrapper->next_rid, subnet_str, mask_str);

		cur = cur->next;
	}
}

void* dijkstra_thread(void* arg) {
	router_state* rs = (router_state*)arg;

	struct timespec wake_up_time;
	struct timeval now;
	int result = 0;

	pthread_mutex_lock(rs->dijkstra_mutex);
	while (1) {
		/* Determine the time when to wake up next */
		gettimeofday(&now, NULL);
		wake_up_time.tv_sec = now.tv_sec + 1;
		wake_up_time.tv_nsec = now.tv_usec + 1000;

		result = pthread_cond_timedwait(rs->dijkstra_cond, rs->dijkstra_mutex, &wake_up_time);
		/* if we timed out, and the data is not dirty, go back to sleep */
		if (result == ETIMEDOUT) {
			if (!rs->dijkstra_dirty) {
				continue;
			}
		}
		rs->dijkstra_dirty = 0;

		lock_if_list_rd(rs);
		lock_rtable_wr(rs);
		lock_mutex_pwospf_router_list(rs);

		/* nuke all the non static entries */
		//printf("---RTABLE BEFORE DIJKSTRA---\n");
		//char* rtable_printout;
		//int len;
		//sprint_rtable(rs, &rtable_printout, &len);
		//printf("%s\n", rtable_printout);
		//free(rtable_printout);

		node* cur = rs->rtable;
		node* next = NULL;
		while (cur) {
			next = cur->next;
			rtable_entry* entry = (rtable_entry*)cur->data;
			if (!entry->is_static) {
				node_remove(&(rs->rtable), cur);
			}

			cur = next;
		}

		/* run dijkstra */
		node* dijkstra_rtable = compute_rtable(rs->router_id, rs->pwospf_router_list, rs->if_list);

		/* patch our list on to the end of the rtable */
		if (!(rs->rtable)) {
			rs->rtable = dijkstra_rtable;
		} else {
			cur = rs->rtable;
			/* run to the end of the rtable */
			while (cur->next) {
				cur = cur->next;
			}
			cur->next = dijkstra_rtable;
			if (dijkstra_rtable) {
				dijkstra_rtable->prev = cur;
			}
		}

		/* write new rtable out to hardware */
		trigger_rtable_modified(rs);
		char* rtable_printout;
		int len;
		printf("---RTABLE AFTER DIJKSTRA---\n");
		sprint_rtable(rs, &rtable_printout, &len);
		printf("%s\n", rtable_printout);
		free(rtable_printout);

		/* unlock everything */
		unlock_mutex_pwospf_router_list(rs);
		unlock_rtable(rs);
		unlock_if_list(rs);

	}
	pthread_mutex_unlock(rs->dijkstra_mutex);

	return NULL;
}

void dijkstra_trigger(router_state* rs) {
	/* no lock on this object, worst case it takes an extra second to run */
	rs->dijkstra_dirty = 1;
	pthread_cond_signal(rs->dijkstra_cond);
}
