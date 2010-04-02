/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "or_dijkstra.h"
#include "or_utils.h"
#include "or_output.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>


void print_pwospf_router_list(node* head);

int main(int argc, char** argv)
{
	int our_rid = atoi(argv[1]);

	FILE* file = fopen(argv[2], "r");
  if (file == NULL) {
  	perror("Failure opening file");
   	exit(1);
  }

  char* buf = (char*)malloc(1024);
  bzero(buf, 1024);

  node* iface_list = NULL;
  node* router_list = NULL;
  unsigned char is_iface_line = 1;
	unsigned char is_router_line = 0;
	unsigned char is_interface_line = 0;
	pwospf_router* cur_router = NULL;

  while (fgets(buf, 1024, file) != NULL) {
  	if (buf[0] == '#') {
  		continue;
  	}

		if (is_iface_line) {
			iface_entry* iface = (iface_entry*)calloc(1, sizeof(iface_entry));
			char* ip_str = NULL;
			//char* nbr_ip_str = NULL;
			char* mask_str = NULL;

			/* FIXME
			if (sscanf(buf, "%15s %as %as %as %u", iface->name, &ip_str, &nbr_ip_str, &mask_str, &(iface->nbr_router_id)) != 5) {
				free(iface);
				cur_router = NULL;
				is_iface_line = 0;
				is_router_line = 1;
				continue;
	  	}
			*/

	  	if (inet_pton(AF_INET, ip_str, &(iface->ip)) == 0) {
	  		perror("Failure reading ip");
	  	}

			/* FIXME
	  	if (inet_pton(AF_INET, nbr_ip_str, &(iface->nbr_ip)) == 0) {
	  		perror("Failure reading nbr_ip");
	  	}
	  	*/

	  	if (inet_pton(AF_INET, mask_str, &(iface->mask)) == 0) {
	  		perror("Failure reading mask");
	  	}

			iface->is_active = 1;

			node* n = node_create();
			n->data = iface;
			if (!(iface_list)) {
				iface_list = n;
			} else {
				node_push_back(iface_list, n);
			}
		} else if (is_router_line) {
			cur_router = (pwospf_router*)calloc(1, sizeof(pwospf_router));
			unsigned int seq_temp;
	  	if (sscanf(buf, "%u %u %u", &(cur_router->router_id), &(cur_router->area_id), &(seq_temp)) != 3) {
	  		printf("Failure reading from rtable file\n");
	  	}
	  	cur_router->seq = seq_temp;

			/* add it to the list */
			node* n = node_create();
			n->data = cur_router;
			if (!router_list) {
				router_list = n;
			} else {
				node_push_back(router_list, n);
			}

			is_router_line = 0;
			is_interface_line = 1;
		} else if (is_interface_line) {
			pwospf_interface* iface = (pwospf_interface*)calloc(1, sizeof(pwospf_interface));
			char* subnet_str = NULL;
			char* mask_str = NULL;

			if (sscanf(buf, "%as %as %u", &subnet_str, &mask_str, &(iface->router_id)) != 3) {
				free(iface);
				cur_router = NULL;
				is_interface_line = 0;
				is_router_line = 1;
				continue;
	  	}

			iface->is_active = 1;

	  	if (inet_pton(AF_INET, subnet_str, &(iface->subnet)) == 0) {
	  		perror("Failure reading subnet");
	  	}
	  	if (inet_pton(AF_INET, mask_str, &(iface->mask)) == 0) {
	  		perror("Failure reading mask");
	  	}

			node* n = node_create();
			n->data = iface;
			/* add it to the current router */
			if (!(cur_router->interface_list)) {
				cur_router->interface_list = n;
			} else {
				node_push_back(cur_router->interface_list, n);
			}
		}

  }

	if (fclose(file) != 0) {
		perror("Failure closing file");
	}

	print_pwospf_router_list(router_list);

	node* rtable = compute_rtable(our_rid, router_list, iface_list);

	router_state rs;
	rs.rtable = rtable;
	char* rtable_printout;
	int len;
	sprint_rtable(&rs, &rtable_printout, &len);
	printf("%s\n", rtable_printout);
  return 0;
}

void print_pwospf_router_list(node* head) {
	node* cur_node_r = head;
	while (cur_node_r) {
		pwospf_router* router = (pwospf_router*)cur_node_r->data;

		printf("%u %u %u\n", router->router_id, router->area_id, router->seq);

		node* cur_node_i = router->interface_list;
		while (cur_node_i) {
			pwospf_interface* iface = (pwospf_interface*)cur_node_i->data;
			char subnet_str[16];
			char mask_str[16];
			inet_ntop(AF_INET, &(iface->subnet), subnet_str, 16);
			inet_ntop(AF_INET, &(iface->mask), mask_str, 16);

			printf("%s %s %u\n", subnet_str, mask_str, iface->router_id);

			cur_node_i = cur_node_i->next;
		}

		printf("\n");

		cur_node_r = cur_node_r->next;
	}
}
