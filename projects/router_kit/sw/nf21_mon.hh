//-----------------------------------------------------------------------------
// File:   nf21_mon.hh
// Date:   Sun Apr 29 19:36:57 PDT 2007
// Author: Martin Casado
//
// Description:
//
// Monitor NetFPGA2.1 board, update timers and syncronize routing and arp
// table.
//
//-----------------------------------------------------------------------------

#ifndef NF21_MON_HH__
#define NF21_MON_HH__

#include "rtable.hh"
#include "iflist.hh"
#include "arptable.hh"

#include <map>

extern "C"
{
#include "reg_defines.h"
#include "common/nf2util.h"
#include "common/util.h"
}


namespace rk
{

static const char NF21_DEV_PREFIX[]  = "nf2c";
static const char NF21_DEFAULT_DEV[] = "nf2c0";

class nf21_mon
{
    public:

        static const unsigned int FIXME_RT_MAX         = 32;
        static const unsigned int FIXME_ARP_MAX        = 32;
        static const unsigned int FIXME_DST_FILTER_MAX = 32;

	protected:
		// base NF2 interface name
		char interface[32];

        struct nf2device nf2;

        std::map<std::string,int> devtoport;
        std::map<int,std::string> porttodev;

		// SW copies of hardware routing and forwarding table
		rtable   rt;
		arptable at;

        // SW copy of interfacelist ... we're only interested
        // in keeping track of nf2 interfaces
        iflist   ifl;


        // Utility
        void update_interface_table(const iflist&);
        void update_routing_table  (const rtable&);
        void update_arp_table      (const arptable&);
        void nf2_set_mac(const uint8_t* addr, int index);

        void clear_dst_filter_rtable();
        void clear_hw_rtable();
        void clear_hw_arptable();

        void sync_routing_table();

	public:

		nf21_mon(char* interface);

        // --
        // Events
        // --
		void rtable_update   (const rtable& rt);
		void arptable_update (const arptable& at);
		void interface_update(const iflist& at);

};


} // -- namespace rk

#endif  // -- NF21_MON_HH__
