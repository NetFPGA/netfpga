/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_UTILS_H_
#define OR_UTILS_H_

#include "or_data_types.h"

node* node_create(void);
void node_push_back(node* head, node* n);
void node_remove(node** head, node* n);
int node_length(node* head);

void populate_eth_hdr(eth_hdr* ether_hdr, uint8_t* dhost, uint8_t *shost, uint16_t type);
void populate_arp_hdr(arp_hdr* arp_header, uint8_t* arp_tha, uint32_t arp_tip, uint8_t* arp_sha, uint32_t arp_sip, uint16_t op);
void populate_ip(ip_hdr* ip, uint16_t payload_size, uint8_t protocol, uint32_t source_ip, uint32_t dest_ip);
void populate_icmp(icmp_hdr* icmp, 	uint8_t icmp_type, uint8_t icmp_code, uint8_t* payload, int payload_len);
void populate_pwospf(pwospf_hdr*pwospf, uint8_t type, uint16_t len, uint32_t rid, uint32_t aid);
void populate_pwospf_hello(pwospf_hello_hdr* hello, uint32_t mask, uint16_t helloint);
void populate_pwospf_lsu(pwospf_lsu_hdr* lsu, uint16_t seq, uint32_t num);
void populate_padding(uint8_t *start, unsigned int len);

void populate_nat_packet(ip_hdr *ip, const uint8_t *packet, unsigned int len,  nat_entry *ne, int nat_type);

char* mallocCopy(const char* c);
void register_cli_command(node** head, char* command, cli_command_handler handler);
void cleanCRLFs(char* c);
void send_to_socket(int sockfd, char *buf, int len);
char* my_strncat(char* left, char* right, int* left_alloc_size);
char* urlencode(char* str);
char* urldecode(char* str);
int getMax(int* int_array, int len);
#endif /*OR_UTILS_H_*/
