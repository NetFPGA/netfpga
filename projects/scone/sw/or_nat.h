/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef _OR_NAT_H_
#define _OR_NAT_H_

#include "or_data_types.h"

void process_nat_ext_packet(router_state *rs, const uint8_t *packet, unsigned int len);
void process_nat_int_packet(router_state *rs, const uint8_t *packet, unsigned int len, uint32_t ext_ip);


nat_entry *get_nat_table_entry(router_state *rs, const uint8_t *packet, unsigned int len, int nat_type);
void get_nat_ip_port_pair(nat_ip_port_pair *pair, const uint8_t *packet, unsigned int len, int nat_type);
void get_nat_port_from_icmp(nat_ip_port_pair *pair, const uint8_t *packet, unsigned int len, int nat_type);


nat_entry *create_nat_table_entry(router_state *rs, const uint8_t *packet, unsigned int len, uint32_t ext_ip);
uint16_t get_src_port_number(const uint8_t *packet, unsigned int len, uint8_t ip_protocol);
uint16_t get_src_port_number_from_icmp(const uint8_t *packet, unsigned int len);


int found_nat_table_match(nat_entry *ne, nat_ip_port_pair *nipp, int nat_type);
int is_unique_nat_ext_port(router_state *rs, uint16_t port);


nat_tcp_hdr *get_nat_tcp_hdr(const uint8_t *packet, unsigned int len);
nat_udp_hdr *get_nat_udp_hdr(const uint8_t *packet, unsigned int len);
nat_icmp_hdr *get_nat_icmp_hdr(const uint8_t *packet, unsigned int len);
ip_hdr *get_ip_hdr_from_icmp_data(const uint8_t *packet, unsigned int len);
nat_icmp_hdr *get_icmp_hdr_from_icmp_data(const uint8_t *packet, unsigned int len);
uint16_t *get_nat_port_list_from_icmp_data(const uint8_t *packet, unsigned int len);
uint16_t get_nat_echo_id_from_icmp_data(const uint8_t *packet, unsigned int len);

void compute_nat_checksums(nat_ip_port_pair *pair);
uint16_t nat_checksum(uint16_t old, uint16_t pos, uint16_t neg);

void* nat_maintenance_thread(void* arg);
void write_nat_table_entry_to_hw(router_state *rs, nat_entry *ne, uint8_t row);
void write_nat_table_zero_to_hw(router_state *rs, uint8_t row);
uint32_t get_hw_hits(router_state *rs, uint8_t row);


void cli_nat_help(router_state *rs, cli_request *req);
void cli_show_nat_table(router_state *rs, cli_request *req);
void cli_show_hw_nat_table(router_state *rs, cli_request *req);
void cli_nat_set(router_state *rs, cli_request *req);
void cli_nat_reset(router_state *rs, cli_request *req);
void cli_nat_add(router_state *rs, cli_request *req);
void cli_nat_del(router_state *rs, cli_request *req);

void lock_nat_table(router_state *rs);
void unlock_nat_table(router_state *rs);

#endif
