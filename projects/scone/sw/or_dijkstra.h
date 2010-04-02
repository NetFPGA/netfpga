/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_DIJKSTRA_H_
#define OR_DIJKSTRA_H_

#include "or_data_types.h"

node* compute_rtable(uint32_t our_router_id, node* pwospf_router_list, node* if_list);
pwospf_router* get_router_by_rid(uint32_t rid, node* pwospf_router_list);
void* dijkstra_thread(void* arg);
void dijkstra_trigger(router_state* rs);

#endif /*OR_DIJKSTRA_H_*/
