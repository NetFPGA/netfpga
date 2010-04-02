/*
 * Copyright (c) 2001, Swedish Institute of Computer Science.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the Institute nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE INSTITUTE AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE INSTITUTE OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * This file is part of the lwIP TCP/IP stack.
 *
 * Author: Adam Dunkels <adam@sics.se>
 *
 * $Id: ip_addr.h 2430 2007-04-06 22:29:40Z paun $
 */
#ifndef __LWIP_IP_ADDR_H__
#define __LWIP_IP_ADDR_H__

#include "lwip/cc.h"
#include "lwip/arch.h"

#define IP_ADDR_ANY 0

#define IP_ADDR_BROADCAST (&ip_addr_broadcast)

PACK_STRUCT_BEGIN
struct ip_addr {
  PACK_STRUCT_FIELD(uint32_t addr);
} PACK_STRUCT_STRUCT;
PACK_STRUCT_END

extern struct ip_addr ip_addr_broadcast;

#define IP4_ADDR(ipaddr, a,b,c,d) (ipaddr)->addr = htonl(((uint32_t)(a & 0xff) << 24) | ((uint32_t)(b & 0xff) << 16) | \
                                                         ((uint32_t)(c & 0xff) << 8) | (uint32_t)(d & 0xff))

#define ip_addr_set(dest, src) (dest)->addr = \
                               ((src) == IP_ADDR_ANY? IP_ADDR_ANY:\
				((struct ip_addr *)src)->addr)
#define ip_addr_maskcmp(addr1, addr2, mask) (((addr1)->addr & \
                                              (mask)->addr) == \
                                             ((addr2)->addr & \
                                              (mask)->addr))
#define ip_addr_cmp(addr1, addr2) ((addr1)->addr == (addr2)->addr)

#define ip_addr_isany(addr1) ((addr1) == NULL || (addr1)->addr == 0)

#define ip_addr_isbroadcast(addr1, mask) (((((addr1)->addr) & ~((mask)->addr)) == \
					 (0xffffffff & ~((mask)->addr))) || \
                                         ((addr1)->addr == 0xffffffff) || \
                                         ((addr1)->addr == 0x00000000))


#define ip_addr_ismulticast(addr1) (((addr1)->addr & ntohl(0xf0000000)) == ntohl(0xe0000000))


#define ip_addr_debug_print(ipaddr) DEBUGF(LWIP_DEBUG, ("%d.%d.%d.%d", \
		    (uint8_t)(ntohl((ipaddr)->addr) >> 24) & 0xff, \
		    (uint8_t)(ntohl((ipaddr)->addr) >> 16) & 0xff, \
		    (uint8_t)(ntohl((ipaddr)->addr) >> 8) & 0xff, \
		    (uint8_t)ntohl((ipaddr)->addr) & 0xff))


#define ip4_addr1(ipaddr) ((uint8_t)(ntohl((ipaddr)->addr) >> 24) & 0xff)
#define ip4_addr2(ipaddr) ((uint8_t)(ntohl((ipaddr)->addr) >> 16) & 0xff)
#define ip4_addr3(ipaddr) ((uint8_t)(ntohl((ipaddr)->addr) >> 8) & 0xff)
#define ip4_addr4(ipaddr) ((uint8_t)(ntohl((ipaddr)->addr)) & 0xff)
#endif /* __LWIP_IP_ADDR_H__ */






