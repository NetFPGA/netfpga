/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_PWOSPF_H_
#define OR_PWOSPF_H_


#include "sr_base_internal.h"
#include "or_data_types.h"

void process_pwospf_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);
void process_pwospf_hello_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);
void process_pwospf_lsu_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);
void broadcast_pwospf_hello_packet(struct sr_instance *sr);
void broadcast_pwospf_lsu_packet(struct sr_instance *sr, pwospf_hdr *pwospf, struct in_addr* src_ip);

int is_pwospf_packet_valid(router_state *rs, const uint8_t *packet, unsigned int len);

uint16_t compute_pwospf_checksum(pwospf_hdr *pwospf);
pwospf_hdr *get_pwospf_hdr(const uint8_t *packet, unsigned int len);
pwospf_hello_hdr *get_pwospf_hello_hdr(const uint8_t *packet, unsigned int len);
pwospf_lsu_hdr *get_pwospf_lsu_hdr(const uint8_t *packet, unsigned int len);
uint8_t *get_pwospf_lsu_data(const uint8_t *packet, unsigned int len);

void construct_pwospf_lsu_packet(router_state *rs, uint8_t **pwospf_packet, unsigned int *pwospf_packet_len);
void construct_pwospf_lsu_adv(router_state *rs, pwospf_lsu_adv **pwospf_lsu_adv, uint32_t *pwospf_num);

int populate_pwospf_router_interface_list(pwospf_router *router, uint8_t *packet, unsigned int len);

void propagate_pwospf_changes(router_state *rs, char *except_this_interface);
void determine_active_interfaces(router_state *rs, pwospf_router *router);
int determine_timedout_interface(router_state *rs, iface_entry *iface);
void start_lsu_bcast_flood(router_state *rs, char *exclude_this_interface);

pwospf_interface *default_route_present(router_state *rs);
int is_route_present(pwospf_router *router, pwospf_interface *iface);

void add_new_router_neighbor(router_state *rs, const uint8_t *packet, unsigned int len);

void cli_pwospf_help(router_state *rs, cli_request *req);
void cli_show_pwospf_iface(router_state *rs, cli_request *req);
void cli_show_pwospf_iface_help(router_state *rs, cli_request *req);
void cli_show_pwospf_router_list(router_state *rs, cli_request *req);
void cli_show_pwospf_info(router_state *rs, cli_request *req);
void cli_pwospf_set_aid(router_state *rs, cli_request *req);
void cli_pwospf_set_aid_help(router_state *rs, cli_request *req);
void cli_pwospf_set_hello(router_state *rs, cli_request *req);
void cli_pwospf_set_lsu_broadcast(router_state *rs, cli_request *req);
void cli_pwospf_set_lsu_interval(router_state *rs, cli_request *req);
void cli_pwospf_send_hello(router_state *rs, cli_request *req);
void cli_pwospf_send_lsu(router_state *rs, cli_request *req);

void *pwospf_hello_thread(void *param);
void *pwospf_lsu_thread(void *param);
void *pwospf_lsu_timeout_thread(void *param);
void *pwospf_lsu_bcast_thread(void *param);

void lock_mutex_pwospf_router_list(router_state* rs);
void unlock_mutex_pwospf_router_list(router_state* rs);

void lock_mutex_pwospf_lsu_queue(router_state *rs);
void unlock_mutex_pwospf_lsu_queue(router_state *rs);

void lock_mutex_pwospf_lsu_bcast(router_state *rs);
void unlock_mutex_pwospf_lsu_bcast(router_state *rs);


#endif /*OR_PWOSPF_H_*/
