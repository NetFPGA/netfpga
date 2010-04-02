/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_IP_H_
#define OR_IP_H_

#include "or_data_types.h"
#include "sr_base_internal.h"

void process_ip_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);
uint32_t send_ip_packet(struct sr_instance* sr, uint8_t proto, uint32_t src, uint32_t dest, uint8_t *payload, int len);


int is_packet_valid(const uint8_t * packet, unsigned int len);
ip_hdr* get_ip_hdr(const uint8_t* packet, unsigned int len);
uint16_t compute_ip_checksum(ip_hdr* iphdr);
int verify_checksum(uint8_t *data, unsigned int len);

void cli_show_ip_help(router_state *rs, cli_request *req);
void cli_ip_help(router_state *rs, cli_request *req);

#endif /*OR_IP_H_*/
