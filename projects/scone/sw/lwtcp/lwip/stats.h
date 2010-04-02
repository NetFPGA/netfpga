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
 * $Id: stats.h 2430 2007-04-06 22:29:40Z paun $
 */
#ifndef __LWIP_STATS_H__
#define __LWIP_STATS_H__

#include "lwip/opt.h"
#include "lwip/cc.h"

#include "lwip/memp.h"

#ifdef STATS

struct stats_proto {
  uint16_t xmit;    /* Transmitted packets. */
  uint16_t rexmit;  /* Retransmitted packets. */
  uint16_t recv;    /* Received packets. */
  uint16_t fw;      /* Forwarded packets. */
  uint16_t drop;    /* Dropped packets. */
  uint16_t chkerr;  /* Checksum error. */
  uint16_t lenerr;  /* Invalid length error. */
  uint16_t memerr;  /* Out of memory error. */
  uint16_t rterr;   /* Routing error. */
  uint16_t proterr; /* Protocol error. */
  uint16_t opterr;  /* Error in options. */
  uint16_t err;     /* Misc error. */
  uint16_t cachehit;
};

struct stats_mem {
  uint16_t avail;
  uint16_t used;
  uint16_t max;
  uint16_t err;
  uint16_t reclaimed;
};

struct stats_pbuf {
  uint16_t avail;
  uint16_t used;
  uint16_t max;
  uint16_t err;
  uint16_t reclaimed;

  uint16_t alloc_locked;
  uint16_t refresh_locked;
};

struct stats_syselem {
  uint16_t used;
  uint16_t max;
  uint16_t err;
};

struct stats_sys {
  struct stats_syselem sem;
  struct stats_syselem mbox;
};

struct stats_ {
  struct stats_proto link;
  struct stats_proto ip;
  struct stats_proto icmp;
  struct stats_proto udp;
  struct stats_proto tcp;
  struct stats_pbuf pbuf;
  struct stats_mem mem;
  struct stats_mem memp[MEMP_MAX];
  struct stats_sys sys;
};

extern struct stats_ stats;

#endif /* STATS */

void stats_init(void);
#endif /* __LWIP_STATS_H__ */




