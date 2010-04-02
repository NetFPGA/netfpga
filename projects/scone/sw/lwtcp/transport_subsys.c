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
 * $Id: transport_subsys.c 2430 2007-04-06 22:29:40Z paun $
 */

#include "lwip/debug.h"

#include "lwip/opt.h"

#include "lwip/sys.h"

#include "lwip/memp.h"
#include "lwip/pbuf.h"

#include "lwip/transport_subsys.h"

#include "lwip/tcp.h"

#include <assert.h>

static void (* transport_init_done)(void *arg) = NULL;
static void *transport_init_done_arg;
static sys_mbox_t mbox;

/*-----------------------------------------------------------------------------------*/
static void
transport_tcp_timer(void *arg)
{
  tcp_tmr();
  sys_timeout(TCP_TMR_INTERVAL, (sys_timeout_handler)transport_tcp_timer, NULL);
}
/*-----------------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------------*/
static void
transport_thread(void *arg)
{
  struct transport_msg *msg;

  udp_init();
  tcp_init();

  sys_timeout(TCP_TMR_INTERVAL, (sys_timeout_handler)transport_tcp_timer, NULL);

  if(transport_init_done != NULL) {
    transport_init_done(transport_init_done_arg);
  }

  while(1) {                          /* MAIN Loop */
    sys_mbox_fetch(mbox, (void *)&msg);
    switch(msg->type) {
    case TCP_MSG_API:
      DEBUGF(TCP_DEBUG, ("transport_thread: API message %p\n", msg));
      api_msg_input(msg->msg.apimsg);
      break;
    case TCP_MSG_INPUT:
      DEBUGF(TCP_DEBUG, ("transport_thread: TCP input packet %p\n", msg));
      tcp_input(msg->msg.inp.p, msg->msg.inp.netif);
      break;
    default:
      break;
    }
    memp_freep(MEMP_TCP_MSG, msg);
  }
}
/*-----------------------------------------------------------------------------------*/

err_t
udp_msg_input(struct pbuf *p, struct netif *inp)
{
    assert(0);
    return 1;
}

/*-----------------------------------------------------------------------------------*/
err_t
tcp_msg_input(struct pbuf *p, struct netif *inp)
{
  struct transport_msg *msg;

  msg = memp_mallocp(MEMP_TCP_MSG);
  if(msg == NULL) {
    pbuf_free(p);
    return ERR_MEM;
  }

  msg->type = TCP_MSG_INPUT;
  msg->msg.inp.p = p;
  msg->msg.inp.netif = inp;
  sys_mbox_post(mbox, msg);
  return ERR_OK;
}

/*-----------------------------------------------------------------------------------*/
err_t
transport_subsys_input(struct pbuf *p, struct netif *inp)
{
  struct transport_msg *msg;

  msg = memp_mallocp(MEMP_TCP_MSG);
  if(msg == NULL) {
    pbuf_free(p);
    return ERR_MEM;
  }

  msg->type = TCP_MSG_INPUT;
  msg->msg.inp.p = p;
  msg->msg.inp.netif = inp;
  sys_mbox_post(mbox, msg);
  return ERR_OK;
}


/*-----------------------------------------------------------------------------------*/
void
transport_apimsg(struct api_msg *apimsg)
{
  struct transport_msg *msg;
  msg = memp_mallocp(MEMP_TCP_MSG);
  if(msg == NULL) {
    memp_free(MEMP_TCP_MSG, apimsg);
    return;
  }
  msg->type = TCP_MSG_API;
  msg->msg.apimsg = apimsg;
  sys_mbox_post(mbox, msg);
}
/*-----------------------------------------------------------------------------------*/
void
transport_subsys_init(void (* initfunc)(void *), void *arg)
{
  transport_init_done = initfunc;
  transport_init_done_arg = arg;
  mbox = sys_mbox_new();
  sys_thread_new((void *)transport_thread, NULL);
}
/*-----------------------------------------------------------------------------------*/



