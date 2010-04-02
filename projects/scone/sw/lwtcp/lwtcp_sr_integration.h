/*-----------------------------------------------------------------------------
 * file:
 * date:
 * Author:
 *
 * Description:
 *
 *---------------------------------------------------------------------------*/

#ifndef LWTCP_SR_INTEGRATION_H
#define LWTCP_SR_INTEGRATION_H

#include "lwip/ip_addr.h"
#include "lwip/ip.h"
#include "lwip/netif.h"
#include "lwip/pbuf.h"
#include "lwip/transport_subsys.h"

uint32_t /*nbo*/ ip_route(struct ip_addr *dest);
err_t sr_lwip_output(struct pbuf *p,struct ip_addr *src, struct ip_addr *dst, uint8_t proto );

#endif  /* LWTCP_SR_INTEGRATION_H */
