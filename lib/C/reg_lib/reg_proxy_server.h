/***************************************************************
* $Id$
* Author: Jad Naous
* Filename: proxy.c
* Description:
* header for the server
****************************************************************/

#ifndef REG_PROXY_SERVER_H_
#define REG_PROXY_SERVER_H_

#include "reg_proxy.h"

#define NF2C "nf2c"

void open_interfaces(struct nf2device **nf2devices, int num_netfpgas);
void close_interfaces(struct nf2device **nf2devices, int num_netfpgas);
int parse_request (int socket_to_client, struct nf2device **nf2devices, int num_netfpgas);

#endif /*REG_PROXY_SERVER_H_*/
