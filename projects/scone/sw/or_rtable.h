/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_RTABLE_H_
#define OR_RTABLE_H_

#include "or_data_types.h"
#include "sr_base_internal.h"

int get_next_hop(struct in_addr* next_hop, char* next_hop_iface, int len, router_state* rs, struct in_addr* destination);
int add_route(router_state* rs, struct in_addr* dest, struct in_addr* gateway, struct in_addr* mask, char* interface);
int del_route(router_state* rs, struct in_addr* dest, struct in_addr* mask);

int deactivate_routes(router_state* rs, char* interface);
int activate_routes(router_state* rs, char* interface);

void trigger_rtable_modified(router_state* rs);
void write_rtable_to_hw(router_state* rs);

void lock_rtable_rd(router_state *rs);
void lock_rtable_wr(router_state *rs);
void unlock_rtable(router_state *rs);

void cli_show_ip_rtable(router_state *rs, cli_request *req);
void cli_show_ip_rtable_help(router_state *rs, cli_request *req);

void cli_ip_route_add(router_state *rs, cli_request *req);
void cli_ip_route_del(router_state *rs, cli_request *req);

void cli_ip_route_help(router_state *rs, cli_request *req);
void cli_ip_route_add_help(router_state *rs, cli_request *req);
void cli_ip_route_del_help(router_state *rs, cli_request *req);

void cli_show_hw_rtable(router_state *rs, cli_request *req);

#endif /*OR_RTABLE_H_*/
