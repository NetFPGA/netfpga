/*-----------------------------------------------------------------------------
 * file:  sr_cpu_extension_nf2.h
 * date:  Mon Feb 09 16:40:49 PST 2004
 * Author: Martin Casado <casado@stanford.edu>
 *
 * Description:
 *
 * Extensions to sr to operate with the NetFPGA in "cpu" mode.  That is,
 * provides the more complicated routing functionality such as ARP and
 * ICMP for a router built using the NetFPGA.
 *
 *---------------------------------------------------------------------------*/

#ifndef SR_CPU_EXTENSIONS_H
#define SR_CPU_EXTENSIONS_H

#include "sr_base_internal.h"

static const uint16_t CPU_CONTROL_READ  = 0x8804;
static const uint16_t CPU_CONTROL_WRITE = 0x8805;
#define               CPU_CONTROL_ADDR    "0:20:ce:10:03"

int  sr_cpu_init_hardware(struct sr_instance*, const char* hwfile);

int sr_cpu_input(struct sr_instance* sr);
int sr_cpu_output(struct sr_instance* sr /* borrowed */,
                       uint8_t* buf /* borrowed */ ,
                       unsigned int len,
                       const char* iface /* borrowed */);

#endif  /* --  SR_CPU_EXTENSIONS_H -- */
