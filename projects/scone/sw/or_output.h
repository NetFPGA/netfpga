/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_OUTPUT_H_
#define OR_OUTPUT_H_

#include "sr_base_internal.h"
#include "or_data_types.h"

void sprint_arp_cache(router_state *rs, char **buf, int *len);
void sprint_if_list(router_state *rs, char **buf, int *len);
void sprint_pwospf_if_list(router_state *rs, char **buf, int *len);
void sprint_pwospf_router_list(router_state *rs, char **buf, int *len);
void sprint_rtable(router_state *rs, char **buf, int *len);
void print_arp_queue(struct sr_instance* sr);
void print_sping_queue(struct sr_instance* sr);
void sprint_nat_table(router_state *rs, char **buf, unsigned int *len);

void sprint_hw_rtable(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_arp_cache(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_iface(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_nat_table(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_stats(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_drops(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_oq_drops(router_state *rs, char **buf, unsigned int *len);
void sprint_hw_local_ip_filter(router_state *rs, char **buf, unsigned int *len);

void print_packet(const uint8_t *packet, unsigned int len);
void print_eth_hdr(const uint8_t *packet, unsigned int len);
void print_arp_hdr(const uint8_t *packet, unsigned int len);
void print_ip_hdr(const uint8_t *packet, unsigned int len);
void print_icmp_load(const uint8_t *packet, unsigned int len);
void print_tcp_load(const uint8_t *packet, unsigned int len);
void print_pwospf_load(const uint8_t *packet, unsigned int len);
void print_pwospf(pwospf_hdr *pwospf);

void print_ip(ip_hdr *ip);
#endif
