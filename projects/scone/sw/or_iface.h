/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_IFACE_H_
#define OR_IFACE_H_

#include "or_data_types.h"
#include <netinet/in.h>

int iface_match_ip(router_state* rs, uint32_t ip);
iface_entry *get_iface(router_state* rs, const char *interface);
int iface_update(router_state* rs, char* interface, struct in_addr* ip, struct in_addr* mask);
int iface_is_active(router_state* rs, char* interface);
int iface_up(router_state* rs, char* interface);
int iface_down(router_state* rs, char* interface);
nbr_router* get_nbr_by_rid(iface_entry* iface, uint32_t rid);

void read_hw_iface_mac(router_state *rs, unsigned int port, unsigned int *mac_hi, unsigned int *mac_lo);
void write_hw_iface_mac(router_state *rs, unsigned int port, unsigned int mac_hi, unsigned int mac_lo);
void set_hw_iface(router_state *rs, unsigned int queue, unsigned int command);

void lock_if_list_rd(router_state *rs);
void lock_if_list_wr(router_state *rs);
void unlock_if_list(router_state *rs);

void cli_show_ip_iface(router_state* rs, cli_request* req);
void cli_show_ip_iface_help(router_state* rs, cli_request* req);

void cli_ip_interface_help(router_state *rs, cli_request *req);
void cli_ip_interface(router_state* rs, cli_request* req);

void cli_show_hw_interface(router_state* rs, cli_request* req);
void cli_hw_interface_add(router_state* rs, cli_request* req);
void cli_hw_interface_del(router_state* rs, cli_request* req);
void cli_hw_interface_set(router_state* rs, cli_request* req);


#endif /*OR_IFACE_H_*/
