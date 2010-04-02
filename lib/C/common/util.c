/* ****************************************************************************
 * $Id: util.c 3546 2008-04-03 00:12:27Z grg $
 *
 * Module: nf2util.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for user mode programs
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <inttypes.h>
#include <string.h>

uint8_t * parseip(char *str) {
        uint8_t *ret = (uint8_t *)malloc(4 * sizeof(uint8_t));
        char *num = (char *)strtok(str, ".");
	int index = 0;
        while (num != NULL) {
                ret[index++] = atoi(num);
                num = (char *)strtok(NULL, ".");
        }
        return ret;
}

uint8_t * parsemac(char *str) {
        uint8_t *ret = (uint8_t *)malloc(6 * sizeof(char));
        char *num = (char *)strtok(str, ":");
	int index = 0;
        while (num != NULL) {
		int i;
		sscanf(num, "%x", &i);
		ret[index++] = i;
                num = (char *)strtok(NULL, ":");
        }
        return ret;
}

uint16_t cksm(int length, uint32_t buf[]) {
	uint32_t sum = 0;
	int ind = 14;

	int max = ind + (buf[4] >> 16);

	while (ind < max) {
		int i = ind / 4;
		int shift = !(ind % 4);
		uint32_t val = buf[i];
		if (shift) val >>= 16;
		val &= 0xffff;
		sum += val;
		ind += 2;
	}

	while (sum >> 16)
		sum = (sum & 0xffff) + (sum >> 16);

	sum = ~sum;

	return ((uint16_t)sum);
}
