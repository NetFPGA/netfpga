/*-
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Jad Naous <jnaous@stanford.edu>
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

/*
 * Filename: reg_proxy.h
 * Description:
 * common header and utilities for client and server
 */

#ifndef REG_PROXY_H_
#define REG_PROXY_H_

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include <signal.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <stdint.h>
#include "../common/nf2.h"
#include "../common/nf2util.h"

#define SERVER_IP_ADDR "192.168.0.254"
#define SERVER_PORT 8888

#define READ_REQ 1
#define WRITE_REQ 0
#define CHECK_REQ 2
#define OPEN_REQ 3
#define CLOSE_REQ 4

struct reg_request {
	uint8_t    type;
	uint8_t    device_num;
	uint32_t   address;
	uint32_t   data;
	int8_t     error;
};

#define SA struct sockaddr

//#define DEBUG

#ifdef DEBUG
#define DPRINTF(fmt, args...)                   \
        printf("(file=%s, line=%d) " fmt, __FILE__ , __LINE__ , ##args)

#define DPRINTFC(ptr, length)                  \
        {                                       \
            int i;                              \
            printf("(file=%s, line=%d) ", __FILE__ , __LINE__ );    \
            for(i=0; i<length; i++) {           \
                putchar(ptr[i]);                \
            }                                   \
        }
#else
#define DPRINTF(fmt, args...)
#define DPRINTFC(ptr, length)
#endif

void dprint_req(struct reg_request *req);
ssize_t readn(int sockfd, char *ptr, size_t len);
ssize_t writen(int sockfd, const char *ptr, size_t len);

#endif
