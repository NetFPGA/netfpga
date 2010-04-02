/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_ICMP_H_
#define OR_ICMP_H_

#include "or_data_types.h"
#include "sr_base_internal.h"

void process_icmp_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface);

int send_icmp_packet(struct sr_instance* sr, const uint8_t* src_packet, unsigned int len, uint8_t icmp_type, uint8_t icmp_code);
uint16_t compute_icmp_checksum(icmp_hdr* icmp, int payload_len);
icmp_hdr* get_icmp_hdr(const uint8_t* packet, unsigned int len);

int send_icmp_echo_request_packet(struct sr_instance* sr, struct in_addr dest, unsigned short id);
int process_icmp_echo_reply_packet(struct sr_instance* sr, const uint8_t* packet, unsigned int len);

#endif /*OR_ICMP_H_*/
