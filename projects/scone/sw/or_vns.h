/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_VNS_H_
#define OR_VNS_H_

#include "or_data_types.h"

void cli_show_vns(router_state *rs, cli_request *req);
void cli_show_vns_help(router_state *rs, cli_request *req);

void cli_show_vns_user(router_state *rs, cli_request *req);
void cli_show_vns_user_help(router_state *rs, cli_request *req);

void cli_show_vns_server(router_state *rs, cli_request *req);
void cli_show_vns_server_help(router_state *rs, cli_request *req);

void cli_show_vns_vhost(router_state *rs, cli_request *req);
void cli_show_vns_vhost_help(router_state *rs, cli_request *req);

void cli_show_vns_lhost(router_state *rs, cli_request *req);
void cli_show_vns_lhost_help(router_state *rs, cli_request *req);

void cli_show_vns_topology(router_state *rs, cli_request *req);
void cli_show_vns_topology_help(router_state *rs, cli_request *req);

#endif /*OR_VNS_H_*/
