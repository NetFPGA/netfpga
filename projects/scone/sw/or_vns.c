/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <string.h>
#include <stdlib.h>
#include "or_vns.h"
#include "or_utils.h"
#include "sr_base_internal.h"

void cli_show_vns_help(router_state *rs, cli_request* req) {
	char *usage = "usage: show vns [user server vhost lhost topology]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));
}

/*
 * CLI show vns functions
 */
void cli_show_vns(router_state *rs, cli_request *req) {
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	char *show_vns;

	show_vns = "VNS Values:";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));

	show_vns = "\n\tUser:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->user, strlen(sr->user));

	show_vns = "\n\tServer:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	char *server = calloc(80, sizeof(char));
	char addr[INET_ADDRSTRLEN];
	sprintf(server, "AF_INET\t\tPort: %d\tIP: %s", htons(sr->sr_addr.sin_port), inet_ntop(AF_INET, &(sr->sr_addr.sin_addr), addr, INET_ADDRSTRLEN));
	send_to_socket(req->sockfd, server, strlen(server));
	free(server);


	show_vns = "\n\tVhost:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->vhost, strlen(sr->vhost));

	show_vns = "\n\tLhost:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->lhost, strlen(sr->lhost));

	char *top_id = calloc(80, sizeof(char));
	sprintf(top_id, "\n\tTopology: \t%d\n", sr->topo_id);
	send_to_socket(req->sockfd, top_id, strlen(top_id));
	free(top_id);
}

void cli_show_vns_user(router_state *rs, cli_request *req){
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	char *show_vns;

	show_vns = "User:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->user, strlen(sr->user));
	send_to_socket(req->sockfd, "\n", 1);
}
void cli_show_vns_user_help(router_state *rs, cli_request *req){
	char *show_vns = "Usage: show vns user\n";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
}


void cli_show_vns_server(router_state *rs, cli_request *req){
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	char *show_vns;

	show_vns = "Server:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	char *server = calloc(80, sizeof(char));
	char addr[INET_ADDRSTRLEN];
	sprintf(server, "AF_INET\t\tPort: %d\tIP: %s\n", htons(sr->sr_addr.sin_port), inet_ntop(AF_INET, &(sr->sr_addr.sin_addr), addr, INET_ADDRSTRLEN));
	send_to_socket(req->sockfd, server, strlen(server));
	free(server);

}
void cli_show_vns_server_help(router_state *rs, cli_request *req){
	char *show_vns = "Usage: show vns server\n";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
}


void cli_show_vns_vhost(router_state *rs, cli_request *req){
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	char *show_vns;

	show_vns = "Vhost:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->vhost, strlen(sr->vhost));
	send_to_socket(req->sockfd, "\n", 1);
}
void cli_show_vns_vhost_help(router_state *rs, cli_request *req){
	char *show_vns = "Usage: show vns vhost\n";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));

}

void cli_show_vns_lhost(router_state *rs, cli_request *req){
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	char *show_vns;

	show_vns = "Lhost:\t\t";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
	send_to_socket(req->sockfd, sr->lhost, strlen(sr->lhost));
	send_to_socket(req->sockfd, "\n", 1);
}
void cli_show_vns_lhost_help(router_state *rs, cli_request *req){
	char *show_vns = "Usage: show vns lhost\n";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));
}


void cli_show_vns_topology(router_state *rs, cli_request *req){
	struct sr_instance* sr = (struct sr_instance*)rs->sr;

	char *top_id = calloc(80, sizeof(char));
	sprintf(top_id, "Topology: \t%d\n", sr->topo_id);
	send_to_socket(req->sockfd, top_id, strlen(top_id));
	free(top_id);
}
void cli_show_vns_topology_help(router_state *rs, cli_request *req){
	char *show_vns = "Usage: show vns topology\n";
	send_to_socket(req->sockfd, show_vns, strlen(show_vns));

}


