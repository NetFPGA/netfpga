/*-----------------------------------------------------------------------------
 * file:   sr_vns.h
 * date:   Fri Nov 21 13:06:27 PST 2003
 * Author: Martin Casado
 *
 * Description:
 *
 * Header file for interface to VNS.  Able to connect, reserve host,
 * receive/parse hardware information, receive/send packets from/to VNS.
 *
 * See method definitions in sr_vns.c for detailed comments.
 *
 *---------------------------------------------------------------------------*/

#ifndef SR_VNS_H
#define SR_VNS_H

#ifdef _LINUX_
#include <stdint.h>
#endif /* _LINUX_ */

#ifdef _DARWIN_
#include <inttypes.h>
#endif /* _DARWIN_ */

#ifdef _SOLARIS_
#include <inttypes.h>
#endif /* _SOLARIS_ */

struct sr_instance* sr; /* -- forward declare -- */

int  sr_vns_read_from_server(struct sr_instance* );

int  sr_vns_connected_to_server(struct sr_instance* );

void sr_vns_init_log(struct sr_instance* sr, char* logfile);

int  sr_vns_connect_to_server(struct sr_instance* ,unsigned short , char* );

int  sr_vns_send_packet(struct sr_instance* ,uint8_t* , unsigned int , const char*);


#endif  /* -- SR_VNS_H -- */
