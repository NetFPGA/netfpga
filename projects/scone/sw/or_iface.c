/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <pthread.h>
#include <stdio.h>
#include "assert.h"
#include <stdlib.h>
#include "string.h"


#include "or_iface.h"
#include "or_main.h"
#include "or_output.h"
#include "or_utils.h"
#include "or_rtable.h"
#include "or_dijkstra.h"
#include "or_pwospf.h"
#include "reg_defines.h"
#include "or_netfpga.h"

int iface_match_ip(router_state* rs, uint32_t ip) {

	node* cur = rs->if_list;
	int retval = 0;
	while (cur != NULL) {
		iface_entry* entry = (iface_entry*)cur->data;
		if ((entry->is_active) && (entry->ip == ip)) {
			retval = 1;
		}

		cur = cur->next;
	}

	return retval;
}



iface_entry *get_iface(router_state* rs, const char *interface)
{
	assert(rs);
	assert(interface);

	node* cur = rs->if_list;
	iface_entry* sr_if = 0;

	while(cur != NULL) {

		sr_if = (iface_entry*)cur->data;

		if(!strncmp(interface, sr_if->name, SR_NAMELEN))
	       	{ break; }

		sr_if = 0;
		cur = cur->next;
	}

	return sr_if;
}

/* NOT THREAD SAFE: lock rtable for writes
 * Updates the rtable entry matching interface, with the new ip and mask
 * Returns: 1 if the entry was updated, 0 otherwise
 */
int iface_update(router_state* rs, char* interface, struct in_addr* ip, struct in_addr* mask) {
	iface_entry* iface = get_iface(rs, interface);
	if (!iface) {
		return 0;
	}

	iface->ip = ip->s_addr;
	iface->mask = mask->s_addr;
	return 1;
}



void lock_if_list_rd(router_state *rs) {

	assert(rs);

	if(pthread_rwlock_rdlock(rs->if_list_lock) != 0) {
		perror("Failure getting iface list read lock");
	}
}

void lock_if_list_wr(router_state *rs) {

	assert(rs);

	if(pthread_rwlock_wrlock(rs->if_list_lock) != 0) {
		perror("Failure getting iface list write lock");
	}
}

void unlock_if_list(router_state *rs) {

	assert(rs);

	if(pthread_rwlock_unlock(rs->if_list_lock) != 0) {
		perror("Failure unlocking iface list lock");
	}
}

void cli_show_ip_iface(router_state* rs, cli_request* req) {

	char *if_list_info;
	int len;

	lock_if_list_rd(rs);
	sprint_if_list(rs, &if_list_info, &len);
	unlock_if_list(rs);

	send_to_socket(req->sockfd, if_list_info, len);
	free(if_list_info);
}

void cli_show_ip_iface_help(router_state* rs, cli_request* req) {
	char *usage = "usage: show ip interface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}



void cli_ip_interface_help(router_state *rs, cli_request* req) {
	char *usage0 = "usage: ip iterface <args>\n";
	send_to_socket(req->sockfd, usage0, strlen(usage0));

	char *usage1 = "ip interface name ip mask\n";
	send_to_socket(req->sockfd, usage1, strlen(usage1));

	char *usage2 = "ip interface name up\n";
	send_to_socket(req->sockfd, usage2, strlen(usage2));

	char *usage3 = "ip interface name down\n";
	send_to_socket(req->sockfd, usage3, strlen(usage3));
}

void cli_ip_interface(router_state* rs, cli_request* req) {
	char* name = NULL;
	char* ip_str = NULL;
	char* mask_str = NULL;

	/* figure out which command they are actually requesting here */
	int args;
	args = sscanf(req->command, "ip interface %as %as %as", &name, &ip_str, &mask_str);
	if ((args < 2) || (args > 3)) {
		char* message = "Syntax error.\n";
		send_to_socket(req->sockfd, message, strlen(message));
		return;
	}

	int retval = 0;

	if (strncmp("up", ip_str, 2) == 0) {
		/* bringing up an interface */

		lock_if_list_wr(rs);
		lock_rtable_wr(rs);

		retval = iface_up(rs, name);

		unlock_rtable(rs);
		unlock_if_list(rs);

		char* message = malloc(128);
		if (!retval) {
			snprintf(message, 128, "Successfully brought up %s.\n", name);
		} else {
			snprintf(message, 128, "No interface %s found.\n", name);
		}

		send_to_socket(req->sockfd, message, strlen(message));
		free(message);
	} else if (strncmp("down", ip_str, 4) == 0) {
		/* downing an interface */

		lock_if_list_wr(rs);
		lock_rtable_wr(rs);

		retval = iface_down(rs, name);

		unlock_rtable(rs);
		unlock_if_list(rs);

		char* message = malloc(128);
		if (!retval) {
			snprintf(message, 128, "Successfully brought down %s.\n", name);
		} else {
			snprintf(message, 128, "No interface %s found.\n", name);
		}

		send_to_socket(req->sockfd, message, strlen(message));
		free(message);
	} else {
		struct in_addr ip, mask;
		if (inet_pton(AF_INET, ip_str, &ip) != 1) {
			char* message = "Failure reading ip.\n";
			send_to_socket(req->sockfd, message, strlen(message));
			return;
		}

		if (inet_pton(AF_INET, mask_str, &mask) != 1) {
			char* message = "Failure reading mask.\n";
			send_to_socket(req->sockfd, message, strlen(message));
			return;
		}

		lock_if_list_wr(rs);
		retval = iface_update(rs, name, &ip, &mask);
		unlock_if_list(rs);

		char* message = malloc(128);
		if (retval) {
			snprintf(message, 128, "Succesfully updated %s.\n", name);
		} else {
			snprintf(message, 128, "No interface updated.\n");
		}

		send_to_socket(req->sockfd, message, strlen(message));
		free(message);

	}

	if (name) {
		free(name);
	}

	if (ip_str) {
		free(ip_str);
	}

	if (mask_str) {
		free(mask_str);
	}
}

/*
 * THREAD SAFE
 * Returns: 1 if interface is active, 0 if disabled
 */
int iface_is_active(router_state* rs, char* interface) {
	int retval = 0;

	lock_if_list_rd(rs);

	iface_entry* entry = get_iface(rs, interface);
	if (entry && (entry->is_active == 1)) {
		retval = 1;
	}
	unlock_if_list(rs);

	return retval;
}

/*
 * NOT THREAD SAFE: lock interface list write, rtable write
 * Returns: 0 if interface was brought up, 1 otherwise
 */
int iface_up(router_state* rs, char* interface) {
	int retval = 1;

	/* get and bring up the interface */
	iface_entry* iface = get_iface(rs, interface);
	if (iface) {

		if(iface->is_active == 1) {
			return 0;
		}

		iface->is_active = 1;

		/* activate any static routes pertaining to this interface */
		activate_routes(rs, interface);


		/* clear our hello related information */
		if (iface->nbr_routers) {
			node* cur = iface->nbr_routers;
			while (cur) {
				node_remove(&iface->nbr_routers, cur);
			}
		}

		/* append this interface to our router's pwospf interfaces */

		/* add the route if it's not present */
		pwospf_interface *pi = calloc(1, sizeof(pwospf_interface));
		pi->subnet.s_addr = iface->ip & iface->mask;
		pi->mask.s_addr = iface->mask;
		pi->router_id = 0;

		/* add the above interface adv if not already present */
		pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
		if(is_route_present(our_router, pi) == 0) {

			node *n = node_create();
			n->data = (void *)pi;

			if(our_router->interface_list == NULL) {
				our_router->interface_list = n;
			}
			else {
				node_push_back(our_router->interface_list, n);
			}
		}
		else {
			/* router already present, free allocated memory */
			free(pi);
		}

		/* build the information for the lsu flood targetting ALL our neighbors */
		lock_mutex_pwospf_router_list(rs);
		propagate_pwospf_changes(rs, NULL);
		unlock_mutex_pwospf_router_list(rs);

		/* signal the lsu bcast thread to send the packets */
		pthread_cond_signal(rs->pwospf_lsu_bcast_cond);


		retval = 0;
	}


	return retval;
}

/*
 * NOT THREAD SAFE: lock interface list write, rtable write
 * Returns: 0 if interface was brought up, 1 otherwise
 */
int iface_down(router_state* rs, char* interface) {
	int retval = 1;
	int iface_removed = 0;

	/* get and down the interface */
	iface_entry* iface = get_iface(rs, interface);
	if (iface) {


		if(iface->is_active == 0) {
			return 0;
		}


		iface->is_active = 0;

		/* deactivate and or delete routes pertaining to this interface */
		deactivate_routes(rs, interface);


		/* clear our hello related information */
		if (iface->nbr_routers) {
			node* cur = iface->nbr_routers;
			while (cur) {
				node_remove(&iface->nbr_routers, cur);
			}
		}

		/* remove interface entries from our router entry in the router list */
		pwospf_router *our_router = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
		node *rl_cur = our_router->interface_list;
		node *rl_next = 0;

		while(rl_cur) {
			rl_next = rl_cur->next;

			pwospf_interface *pi = (pwospf_interface *)rl_cur->data;
			if(pi->subnet.s_addr == (iface->ip & iface->mask)) {
				node_remove(&our_router->interface_list, rl_cur);
				iface_removed = 1;
			}

			rl_cur = rl_next;
		}

		/* recompute fwd table */
		if(iface_removed == 1) {
			/* build lsu flood for our neighbors not connected to this interface*/
			lock_mutex_pwospf_router_list(rs);
			propagate_pwospf_changes(rs, interface);
			unlock_mutex_pwospf_router_list(rs);

			/* signal the lsu bcast thread to send the packets */
			pthread_cond_signal(rs->pwospf_lsu_bcast_cond);
		}


		retval = 0;
	}

	return retval;
}

nbr_router* get_nbr_by_rid(iface_entry* iface, uint32_t rid) {
	node* cur = iface->nbr_routers;
	while (cur) {
		nbr_router* nbr = (nbr_router*)cur->data;
		if (nbr->router_id == rid) {
			return nbr;
		}
		cur = cur->next;
	}

	return NULL;
}

void cli_show_hw_interface(router_state* rs, cli_request* req) {

	if(rs->is_netfpga) {
		char *iface_info = 0;
		unsigned int len;

		sprint_hw_iface(rs, &iface_info, &len);
		send_to_socket(req->sockfd, iface_info, len);
		free(iface_info);
	}
}



void read_hw_iface_mac(router_state *rs, unsigned int port, unsigned int *mac_hi, unsigned int *mac_lo) {

	switch(port) {

		case 0:
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_HI_REG, mac_hi);
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_LO_REG, mac_lo);
			break;

		case 1:
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_HI_REG, mac_hi);
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_LO_REG, mac_lo);
			break;

		case 2:
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_HI_REG, mac_hi);
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_LO_REG, mac_lo);
			break;
		case 3:
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_HI_REG, mac_hi);
			readReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_LO_REG, mac_lo);
			break;
		default:
			printf("Unknwon port, Failed to read the hardware registers\n");
			*mac_hi = 0;
			*mac_lo = 0;
			break;
	}
}



void write_hw_iface_mac(router_state *rs, unsigned int port, unsigned int mac_hi, unsigned int mac_lo) {

	switch(port) {

		case 0:
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_HI_REG, mac_hi);
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_LO_REG, mac_lo);
			break;

		case 1:
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_HI_REG, mac_hi);
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_LO_REG, mac_lo);
			break;

		case 2:
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_HI_REG, mac_hi);
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_LO_REG, mac_lo);
			break;
		case 3:
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_HI_REG, mac_hi);
			writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_LO_REG, mac_lo);
			break;
		default:
			printf("Unknown port, Failed to write hardware registers\n");
			break;
	}
}





void cli_hw_interface_add(router_state* rs, cli_request* req) {

	if(rs->is_netfpga) {
		char *iface;
		unsigned char mac[ETH_ADDR_LEN];
		unsigned int mac_int[ETH_ADDR_LEN];
		unsigned int mac_hi = 0;
		unsigned int mac_lo = 0;

		if(sscanf(req->command, "hw iface add %as %2X:%2X:%2X:%2X:%2X:%2X", &iface,
			mac_int, (mac_int+1), (mac_int+2), (mac_int+3), (mac_int+4), (mac_int+5)) != 7) {
			send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));

			return;
		}

		int port;
		if(strncmp(ETH0, iface, strlen(ETH0)) == 0) { port = 0; }
		else if(strncmp(ETH1, iface, strlen(ETH1)) == 0) { port = 1; }
		else if(strncmp(ETH2, iface, strlen(ETH2)) == 0) { port = 2; }
		else if(strncmp(ETH3, iface, strlen(ETH3)) == 0) { port = 3; }
		else {
			send_to_socket(req->sockfd, "Failure reading the interface name.\n", strlen("Failure reading the interface name.\n"));
			return;
		}

		int i;
		for(i=0; i<6; i++) {
			mac[i] = (unsigned char)mac_int[i];
		}

		mac_hi |= ((unsigned int)mac[0]) << 8;
		mac_hi |= ((unsigned int)mac[1]);

		mac_lo |= ((unsigned int)mac[2]) << 24;
		mac_lo |= ((unsigned int)mac[3]) << 16;
		mac_lo |= ((unsigned int)mac[4]) << 8;
		mac_lo |= ((unsigned int)mac[5]);

		write_hw_iface_mac(rs, port, mac_hi, mac_lo);
		send_to_socket(req->sockfd, "Interface added\n", strlen("Interface added\n"));
	}
}


void cli_hw_interface_del(router_state* rs, cli_request* req) {

	if(rs->is_netfpga) {
		char *iface;
		if(sscanf(req->command, "hw iface del %as", &iface) != 1) {
			send_to_socket(req->sockfd, "Failure reading arguments.\n", strlen("Failure reading arguments.\n"));
			return;
		}

		int port;
		if(strncmp(ETH0, iface, strlen(ETH0)) == 0) { port = 0; }
		else if(strncmp(ETH1, iface, strlen(ETH1)) == 0) { port = 1; }
		else if(strncmp(ETH2, iface, strlen(ETH2)) == 0) { port = 2; }
		else if(strncmp(ETH3, iface, strlen(ETH3)) == 0) { port = 3; }
		else {
			send_to_socket(req->sockfd, "Failure reading the interface name.\n", strlen("Failure reading the interface name.\n"));
			return;
		}


		unsigned int mac_hi = 0;
		unsigned int mac_lo = 0;
		write_hw_iface_mac(rs, port, mac_hi, mac_lo);
		send_to_socket(req->sockfd, "Interface deleted\n", strlen("Interface deleted\n"));
	}
}


void cli_hw_interface_set(router_state* rs, cli_request* req) {

	if(rs->is_netfpga) {
		char *cmd = NULL;
		char *name = NULL;
		char *msg = NULL;
		unsigned int queue = 0;

		if(sscanf(req->command, "hw iface %as %as", &name, &cmd) != 2) {
			msg = "Syntax error.\n";
			send_to_socket(req->sockfd, msg, strlen(msg));
			return;
		}

		if(strncmp(ETH0, name, strlen(ETH0)) == 0) {
			queue = 0;
		}
		else if(strncmp(ETH1, name, strlen(ETH1)) == 0) {
			queue = 1;
		}
		else if(strncmp(ETH2, name, strlen(ETH2)) == 0) {
			queue = 2;
		}
		else if(strncmp(ETH3, name, strlen(ETH3)) == 0) {
			queue = 3;
		}
		else {
			msg = "Invalid interface name\n";
			send_to_socket(req->sockfd, msg, strlen(msg));
			return;
		}


		if(strncmp("up", cmd, 2) == 0) {
			set_hw_iface(rs, queue, 0x0);

			msg = calloc(80, sizeof(uint8_t));
			snprintf(msg, 80, "HW interface %s was brought up\n", name);
			send_to_socket(req->sockfd, msg, strlen(msg));
			free(msg);
		}
		else if(strncmp("down", cmd, 4) == 0) {
			set_hw_iface(rs, queue, 0x3);

			msg = calloc(80, sizeof(uint8_t));
			snprintf(msg, 80, "HW interface %s was brought down\n", name);
			send_to_socket(req->sockfd, msg, strlen(msg));
			free(msg);
		}
		else {
			msg = "Invalid command name\n";
			send_to_socket(req->sockfd, msg, strlen(msg));
			return;
		}
	}
}

void set_hw_iface(router_state *rs, unsigned int queue, unsigned int command) {

	switch(queue) {
		case 0:
			writeReg(&(rs->netfpga), MAC_GRP_0_CONTROL_REG, command);
			break;
		case 1:
			writeReg(&(rs->netfpga), MAC_GRP_1_CONTROL_REG, command);
			break;
		case 2:
			writeReg(&(rs->netfpga), MAC_GRP_2_CONTROL_REG, command);
			break;
		case 3:
			writeReg(&(rs->netfpga), MAC_GRP_3_CONTROL_REG, command);
			break;
		default:
			printf("Unknown queue, Failed to write hardware registers\n");
			break;
	}
}
