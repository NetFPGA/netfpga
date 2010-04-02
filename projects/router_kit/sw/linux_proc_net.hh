//-----------------------------------------------------------------------------
// File:  linux_proc_net.hh
// Date:  Sun Apr 29 18:08:22 PDT 2007
// Author: Martin Casado
//
// Description:
//
//-----------------------------------------------------------------------------

#ifndef LINUX_PROC_NET_HH__
#define LINUX_PROC_NET_HH__

#include "rtable.hh"
#include "arptable.hh"

namespace rk
{

static const char PROC_ROUTE_FILE[] = "/proc/net/route";
static const char PROC_ARP_FILE[]   = "/proc/net/arp";
static const char PROC_DEV_FILE[]   = "/proc/net/dev";

void
linux_proc_net_load_rtable(rtable& rt);

void
linux_proc_net_load_arptable(arptable& rt);

} // -- namespace rk


#endif // -- LINUX_PROC_NET_HH__
