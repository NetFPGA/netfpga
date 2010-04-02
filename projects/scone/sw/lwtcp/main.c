/*-----------------------------------------------------------------------------
 * file:
 * date:
 * Author:
 *
 * Description:
 *
 *---------------------------------------------------------------------------*/

#include "lwip/tcp.h"

struct netif *ip_route(struct ip_addr *dest)
{
}

err_t sr_ip_output(struct pbuf *p, struct ip_addr *src, struct ip_addr *dest,
		uint8_t ttl, uint8_t proto)
{
}

err_t sr_ip_output_if(struct pbuf *p, struct ip_addr *src, struct ip_addr *dest,
		   uint8_t ttl, uint8_t proto,
		   struct netif *netif)
{
}

static void
main_thread(void *arg)
{
    tcp_init();

    while(1)
    {
        tcp_input
    }
}

int main(int argc,char **argv)
{
    sys_init();
    mem_init();
    memp_init();
    pbuf_init();


    sys_thread_new((void *)(main_thread), NULL);
    pause();

    return 0;
}
