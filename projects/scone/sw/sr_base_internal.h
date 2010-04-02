/*-----------------------------------------------------------------------------
 * file:  sr_base_internal.h
 * date:  Tue Feb 03 11:18:32 PST 2004
 * Author: Martin Casado
 *
 * Description:
 *
 * House all the definitions for the basic core router definitions.  This
 * should not be included by any "user level" files such as main or
 * network applications that run on the router.  Any low level code
 * (which would normally be kernel level) will require these definitions).
 *
 * Low level network code should use the functios:
 *
 * sr_get_global_instance(..) - to gain a pointer to the global sr context
 *
 *  and
 *
 * sr_get_subsystem(..)       - to get the router subsystem from the context
 *
 *---------------------------------------------------------------------------*/

#ifndef SR_BASE_INTERNAL_H
#define SR_BASE_INTERNAL_H

#ifdef _LINUX_
#include <stdint.h>
#endif /* _LINUX_ */

#ifdef _DARWIN_
#include <inttypes.h>
#endif /* _DARWIN_ */

#include <unistd.h>
#include <stdio.h>
#include <sys/time.h>
#include <netinet/in.h>

#define SR_NAMELEN 32

#define CPU_HW_FILENAME "cpuhw"

/* -- gcc specific vararg macro support ... but its so nice! -- */
#ifdef _DEBUG_
#define Debug(x, args...) printf(x, ## args)
#define DebugIP(x) \
  do { struct in_addr addr; addr.s_addr = x; printf("%s",inet_ntoa(addr));\
     } while(0)
#define DebugMAC(x) \
  do { int ivyl; for(ivyl=0; ivyl<5; ivyl++) printf("%02x:", \
  (unsigned char)(x[ivyl])); printf("%02x",(unsigned char)(x[5])); } while (0)
#else
#define Debug(x, args...) do{}while(0)
#define DebugMAC(x) do{}while(0)
#endif

/* ----------------------------------------------------------------------------
 * struct sr_vns_if
 *
 * Abstraction for a VNS virtual host interface
 *
 * -------------------------------------------------------------------------- */

struct sr_vns_if
{
    char name[SR_NAMELEN];
    unsigned char addr[6];
    uint32_t ip;
    uint32_t mask;
    uint32_t speed;
};

/* ----------------------------------------------------------------------------
 * struct sr_instance
 *
 * Encapsulation of the state for a single virtual router.
 *
 * -------------------------------------------------------------------------- */

struct sr_instance
{
    /* VNS specific */
    int  sockfd;    /* socket to server */
    char user[32];  /* user name */
    char vhost[32]; /* host name */
    char lhost[32]; /* host name of machine running client */
    char rtable[32];/* filename for routing table          */
    unsigned short topo_id; /* topology id */
    struct sockaddr_in sr_addr; /* address to server */
    FILE* logfile; /* file to log all received/sent packets to */
    volatile uint8_t  hw_init; /* bool : hardware has been initialized */
    pthread_mutex_t   send_lock; /* experimental */

	/* NetFPGA specific */
	char interface[32];

    void* interface_subsystem; /* subsystem to send/recv packets from */
};

/* ----------------------------------------------------------------------------
 * See method definitions in sr_base.c for detailed explanation of the
 * following two methods.
 * -------------------------------------------------------------------------*/

void* sr_get_subsystem(struct sr_instance* sr);
void  sr_set_subsystem(struct sr_instance* sr, void* core);
struct sr_instance* sr_get_global_instance(struct sr_instance* sr);


/* ----------------------------------------------------------------------------
 * Integration methods for calling subsystem (e.g. the router).  These
 * may be replaced by callback functions that get registered with
 * sr_instance.
 * -------------------------------------------------------------------------*/

void sr_integ_init(struct sr_instance* );
void sr_integ_hw_setup(struct sr_instance* ); /* called after hwinfo */
void sr_integ_destroy(struct sr_instance* );
void sr_integ_close(struct sr_instance* sr);
void sr_integ_input(struct sr_instance* sr,
                   const uint8_t * packet/* borrowed */,
                   unsigned int len,
                   const char* interface/* borrowed */);
void sr_integ_add_interface(struct sr_instance*,
                            struct sr_vns_if* /* borrowed */);

int sr_integ_output(struct sr_instance* sr /* borrowed */,
                    uint8_t* buf /* borrowed */ ,
                    unsigned int len,
                    const char* iface /* borrowed */);

uint32_t sr_findsrcip(uint32_t dest /* nbo */);
uint32_t sr_integ_ip_output(uint8_t* payload /* given */,
                            uint8_t  proto,
                            uint32_t src, /* nbo */
                            uint32_t dest, /* nbo */
                            int len);
int sr_integ_low_level_output(struct sr_instance* sr /* borrowed */,
                             uint8_t* buf /* borrowed */ ,
                             unsigned int len,
                             const char* iface /* borrowed */);
uint32_t sr_integ_findsrcip(uint32_t dest /* nbo */);


#endif  /* -- SR_BASE_INTERNAL_H -- */
