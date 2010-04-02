/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */
#ifndef OR_ARP_H_
#define OR_ARP_H_

#include "sr_base_internal.h"
#include "or_data_types.h"

void process_arp_packet(struct sr_instance* sr, const uint8_t* packet, unsigned int len, const char* interface);
void process_arp_request( struct sr_instance* sr, const uint8_t* packet, unsigned int len, const char* interface);
void process_arp_reply( struct sr_instance* sr, const uint8_t* packet, unsigned int len, const char* interface);
void send_arp_reply(struct sr_instance* sr, const uint8_t* packet, unsigned int len, iface_entry* iface);
void send_arp_request(struct sr_instance* sr, uint32_t ip, const char* interface);
arp_hdr* get_arp_hdr(const uint8_t* packet, unsigned int len);


int update_arp_cache(struct sr_instance* sr, struct in_addr* remote_ip, char* remote_mac, int is_static);
int del_arp_cache(struct sr_instance* sr, struct in_addr* ip);
arp_cache_entry* get_from_arp_cache(struct sr_instance* sr, struct in_addr* next_hop);
void lock_arp_cache_rd(router_state *rs);
void lock_arp_cache_wr(router_state *rs);
void unlock_arp_cache(router_state *rs);


void arp_queue_add(struct sr_instance* sr, uint8_t* packet, unsigned int len, const char* out_iface_name, struct in_addr *next_hop);
arp_queue_entry* get_from_arp_queue(struct sr_instance* sr, struct in_addr* next_hop);
void update_arp_queue(struct sr_instance* sr, arp_hdr* arp_header, const char* interface);
void send_queued_packets(struct sr_instance* sr, struct in_addr* dest_ip, char* dest_mac);

void trigger_arp_cache_modified(router_state *rs);
void write_arp_cache_to_hw(router_state* rs);
void write_arp_cache_entry_to_hw(router_state* rs, arp_cache_entry *entry, int row);

void lock_arp_queue_rd(router_state *rs);
void lock_arp_queue_wr(router_state *rs);
void unlock_arp_queue(router_state *rs);

void cli_show_ip_arp(router_state* rs, cli_request* req);
void cli_show_ip_arp_help(router_state* rs, cli_request* req);

void cli_ip_arp_help(router_state *rs, cli_request *req);
void cli_ip_arp_add(router_state *rs, cli_request *req);
void cli_ip_arp_add_help(router_state *rs, cli_request *req);
void cli_ip_arp_del(router_state *rs, cli_request *req);
void cli_ip_arp_del_help(router_state *rs, cli_request *req);
void cli_ip_arp_set_ttl(router_state *rs, cli_request *req);

void cli_show_hw_arp_cache(router_state *rs, cli_request *req);
void cli_nuke_arp_cache(router_state *rs, cli_request *req);
void cli_nuke_hw_arp_cache_entry(router_state *rs, cli_request *req);
void cli_hw_arp_cache_misses(router_state *rs, cli_request *req);
void cli_hw_num_pckts_fwd(router_state *rs, cli_request *req);



void* arp_thread(void *param);

#endif /*OR_ARP_H_*/
