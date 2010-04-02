//-----------------------------------------------------------------------------
// File:  linux_proc_net.cc
// Date:  Sun Apr 29 18:14:04 PDT 2007
// Author: Martin Casado
//
// Description:
//
// Load routing and arp table from linux proc system
//
//-----------------------------------------------------------------------------

#include <cstdio>

#include "linux_proc_net.hh"
#include "netinet++/ipaddr.hh"
#include "netinet++/ethernetaddr.hh"

#include <cstring>

extern "C"
{
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
}

using namespace std;

namespace rk
{

void
linux_proc_net_load_rtable(rtable& rt)
{
    char     buf[BUFSIZ], dev[16];
    uint32_t dest, gw, mask;
    ipaddr   idest, igw, imask;
    int toss;

	FILE* fd = ::fopen(PROC_ROUTE_FILE, "r");

	rt.clear();

	// -- throw away first line
	::fgets(buf, BUFSIZ, fd);
	while( ::fgets(buf, BUFSIZ, fd))
	{
		// yummy
		::sscanf(buf,"%s%x%x%d%d%d%d%x%d%d%d",  dev, &dest, &gw,
				&toss,&toss,&toss,&toss,&mask,&toss,&toss,&toss);
		idest = dest; igw = gw; imask = mask;

		rt.add(ipv4_entry(idest, igw, imask, dev));
	}
	::fclose(fd);
}

void
linux_proc_net_load_arptable(arptable& at)
{
    char buf[BUFSIZ], dev[16];
	FILE* fd = ::fopen(PROC_ARP_FILE, "r");
	char ip[32], mac[32], toss[32];

	at.clear();

	// -- throw away first line
	::fgets(buf, BUFSIZ, fd);
	while( ::fgets(buf, BUFSIZ, fd)){
		::sscanf(buf,"%s%s%s%s%s%s",  ip, toss, toss, mac, toss,dev);

		if(ethernetaddr(mac)){
			at.add(arp_entry(ip, mac, dev));
		}
	}
	::fclose(fd);
}

}
