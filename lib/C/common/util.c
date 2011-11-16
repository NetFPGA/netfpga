/*
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Glen Gibb <grg@stanford.edu>
 *
 * We are making the NetFPGA tools and associated documentation (Software)
 * available for public use and benefit with the expectation that others will
 * use, modify and enhance the Software and contribute those enhancements back
 * to the community. However, since we would like to make the Software
 * available for broadest use, with as few restrictions as possible permission
 * is hereby granted, free of charge, to any person obtaining a copy of this
 * Software) to deal in the Software under the copyrights without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any derivatives
 * without specific, written prior permission.
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
