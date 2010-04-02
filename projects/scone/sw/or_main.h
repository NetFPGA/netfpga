/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_MAIN_H_
#define OR_MAIN_H_

#include "sr_base_internal.h"
#include "or_data_types.h"

/* Default setting for ARP */
#define INITIAL_ARP_TIMEOUT 300

void init(struct sr_instance* sr);
void init_add_interface(struct sr_instance* sr, struct sr_vns_if* vns_if);
iface_entry* get_interface(struct sr_instance* sr, const char* name);
void init_router_list(struct sr_instance* sr);
void init_rtable(struct sr_instance* sr);
void init_cli(struct sr_instance* sr);
void init_hardware(router_state* rs);
void init_rawsockets(router_state* rs);
void init_libnet(router_state* rs);
void init_pcap(router_state* rs);
void process_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);

int send_ip(struct sr_instance* sr, uint8_t* packet, unsigned int len, struct in_addr* next_hop, const char* out_iface);
int send_packet(struct sr_instance* sr, uint8_t* packet, unsigned int len, const char* iface);

uint32_t find_srcip(uint32_t dest);
uint32_t integ_ip_output(uint8_t *payload, uint8_t proto, uint32_t src, uint32_t dst, int len);

void destroy(struct sr_instance* sr);
router_state* get_router_state(struct sr_instance* sr);

#endif /*OR_MAIN_H_*/
