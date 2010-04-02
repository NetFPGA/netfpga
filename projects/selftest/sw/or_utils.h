#ifndef OR_UTILS_H_
#define OR_UTILS_H_

#include "or_data_types.h"

void populate_eth_hdr(eth_hdr* ether_hdr, uint8_t* dhost, uint8_t *shost, uint16_t type);
void populate_ip(ip_hdr* ip, uint16_t payload_size, uint8_t protocol, uint32_t source_ip, uint32_t dest_ip);

#endif /*OR_UTILS_H_*/
