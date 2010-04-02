/***************************************************************
* $Id$
* Author: Jad Naous
* Filename: reg_proxy.h
* Description:
* common header and utilities for client and server
****************************************************************/

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
