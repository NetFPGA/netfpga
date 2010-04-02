#include <netinet/in.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>

#include "or_utils.h"
#include "or_ip.h"
#include "or_data_types.h"

/*
 * Returns the host order checksum for the given packet
 */
uint16_t compute_ip_checksum(ip_hdr* iphdr) {
	iphdr->ip_sum = 0;
	unsigned long sum = 0;
	uint16_t s_sum = 0;
	int numShorts = iphdr->ip_hl * 2;
	int i = 0;
	uint16_t* s_ptr = (uint16_t*)iphdr;

	for (i = 0; i < numShorts; ++i) {
		/* sum all except checksum field */
		if (i != 5) {
			sum += ntohs(*s_ptr);
		}
		++s_ptr;
	}

	/* sum carries */
	sum = (sum >> 16) + (sum & 0xFFFF);
	sum += (sum >> 16);

	/* ones compliment */
	s_sum = sum & 0xFFFF;
	s_sum = (~s_sum);

	return s_sum;
}

