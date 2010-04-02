/*-----------------------------------------------------------------------------
 * File: sr_vns.c
 * Start Date: Sometime in Spring 2002
 * Authors: Guido Apanzeller, Vikram Vijayaraghaven, Martin Casado
 * Contact: casado@stanford.edu
 *
 * Provides core functionality for communicating with the VNS.
 *
 *---------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <netdb.h>
#include <pthread.h>
#include <sys/types.h>
#include <errno.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

#include "sr_vns.h"
#include "sr_dumper.h"

#include "sr_base_internal.h"

#include "vnscommand.h"


/*-----------------------------------------------------------------------------
 * Method: sr_vns_init_log(..)
 * Scope: Global
 *---------------------------------------------------------------------------*/

void sr_vns_init_log(struct sr_instance* sr, char* logfile)
{
    if (!logfile)
    { return; }

    sr->logfile = sr_dump_open(logfile, 0, SR_PACKET_DUMP_SIZE);
    if(!sr->logfile)
    {
        fprintf(stderr,"Error opening up dump file %s\n",
                logfile);
        exit(1);
    }
} /* -- sr_init_log -- */

/*-----------------------------------------------------------------------------
 * Method: sr_close_instance(..)
 * Scope: Global
 *
 *----------------------------------------------------------------------------*/
void sr_close_instance(struct sr_instance* sr)
{
    close(sr->sockfd);

    if(sr->logfile)
    { sr_dump_close(sr->logfile); }

    sr->hw_init = 0;
} /* -- sr_close_instance -- */

/*-----------------------------------------------------------------------------
 * Method: sr_vns_connected_to_server()
 * Scope: Global
 *
 * Test whether we are already connected to a server
 * ---------------------------------------------------------------------------*/

int sr_vns_connected_to_server(struct sr_instance* sr)
{
    int slen = sizeof(struct sockaddr);
    struct sockaddr dummyaddr;

    /* simple test to see if we are already connected */
    if ( getpeername(sr->sockfd, &dummyaddr, (socklen_t*)&slen) != -1)
    {   return -1; }

    return 0;
} /* -- sr_connected_to_server -- */

/*-----------------------------------------------------------------------------
 * Method: sr_connect_to_server()
 * Scope: Global
 *
 * Connect to the virtual server
 *
 * RETURN VALUES:
 *
 *  0 on success
 *  something other than zero on error
 *
 *---------------------------------------------------------------------------*/

int sr_vns_connect_to_server(struct sr_instance* sr,unsigned short port,
                             char* server)
{
    struct hostent *hp;
    c_open command;

    /* REQUIRES */
    assert(sr);
    assert(server);

    if ( sr_vns_connected_to_server(sr) )
    { return -1; }

    /* purify UMR be gone ! */
    memset((void*)&command,0,sizeof(c_open));

    /* zero out server address struct */
    memset(&(sr->sr_addr),0,sizeof(struct sockaddr_in));

    sr->sr_addr.sin_family = AF_INET;
    sr->sr_addr.sin_port = htons(port);

    /* grab hosts address from domain name */
    if ((hp = gethostbyname(server))==0)
    {
        perror("gethostbyname:sr_client.c::sr_connect_to_server(..)");
        return -1;
    }

    /* set server address */
    memcpy(&(sr->sr_addr.sin_addr),hp->h_addr,hp->h_length);

    /* create socket */
    if ((sr->sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        perror("socket(..):sr_client.c::sr_connect_to_server(..)");
        return -1;
    }

    /* attempt to connect to the server */
    if (connect(sr->sockfd, (struct sockaddr *)&(sr->sr_addr),
                sizeof(sr->sr_addr)) < 0)
    {
        perror("connect(..):sr_vns.c::sr_connect_to_server(..)");
        close(sr->sockfd);
        return -1;
    }

    /* send sr_OPEN message to server */
    command.mLen   = htonl(sizeof(c_open));
    command.mType  = htonl(VNSOPEN);
    command.topoID = htons(sr->topo_id);
    strncpy( command.mVirtualHostID, sr->vhost,  IDSIZE);
    strncpy( command.mUID, sr->user, IDSIZE);

    if (send(sr->sockfd, (void *)&command, sizeof(c_open), 0) != sizeof(c_open))
    {
        perror("send(..):sr_client.c::sr_connect_to_server()");
        return -1;
    }

    return 0;
} /* -- sr_connect_to_server -- */

/*-----------------------------------------------------------------------------
 * Method: sr_handle_hwinfo(..)
 * scope: global
 *
 *
 * Read, from the server, the hardware information for the reserved host.
 *
 *---------------------------------------------------------------------------*/

int sr_handle_hwinfo(struct sr_instance* sr, c_hwinfo* hwinfo)
{
    int num_entries;
    int i = 0;
    struct sr_vns_if vns_if;

    /* REQUIRES */
    assert(sr);
    assert(hwinfo);

    num_entries = (ntohl(hwinfo->mLen) - (2*sizeof(uint32_t)))/sizeof(c_hw_entry);
    Debug("Received Hardware Info with %d entries\n",num_entries);

    vns_if.name[0] = 0;

    for ( i=0; i<num_entries; i++ )
    {
        switch( ntohl(hwinfo->mHWInfo[i].mKey))
        {
            case HWFIXEDIP:
                Debug("Fixed IP: %s\n",inet_ntoa(
                            *((struct in_addr*)(hwinfo->mHWInfo[i].value))));
                break;
            case HWINTERFACE:
                Debug("Interface: %s\n",hwinfo->mHWInfo[i].value);
                if (vns_if.name[0])
                { sr_integ_add_interface(sr, &vns_if); vns_if.name[0] = 0; }
                strncpy(vns_if.name, hwinfo->mHWInfo[i].value, SR_NAMELEN);
                break;
            case HWSPEED:
                Debug("Speed: %d\n",
                        ntohl(*((unsigned int*)hwinfo->mHWInfo[i].value)));
                vns_if.speed =
                    ntohl(*((unsigned int*)hwinfo->mHWInfo[i].value));
                break;
            case HWSUBNET:
                Debug("Subnet: %s\n",inet_ntoa(
                            *((struct in_addr*)(hwinfo->mHWInfo[i].value))));
                break;
            case HWMASK:
                Debug("Mask: %s\n",inet_ntoa(
                            *((struct in_addr*)(hwinfo->mHWInfo[i].value))));
                vns_if.mask = *((uint32_t*)hwinfo->mHWInfo[i].value);
                break;
            case HWETHIP:
                Debug("Ethernet IP: %s\n",inet_ntoa(
                            *((struct in_addr*)(hwinfo->mHWInfo[i].value))));
                vns_if.ip = *((uint32_t*)hwinfo->mHWInfo[i].value);
                break;
            case HWETHER:
                Debug("Hardware Address: ");
                DebugMAC(hwinfo->mHWInfo[i].value);
                Debug("\n");
                memcpy(vns_if.addr,
                        (unsigned char*)hwinfo->mHWInfo[i].value, 6);
                break;
            default:
                printf (" %d \n",ntohl(hwinfo->mHWInfo[i].mKey));
        } /* -- switch -- */
    } /* -- for -- */

    if (vns_if.name[0])
    { sr_integ_add_interface(sr, &vns_if); vns_if.name[0] = 0; }

    /* flag that hardware has been initialized */
    sr->hw_init = 1;

    /* let subsystem know all the hardware has been set up */
    sr_integ_hw_setup(sr);

    return num_entries;
} /* -- sr_handle_hwinfo -- */

/*-----------------------------------------------------------------------------
 * Method: sr_vns_read_from_server(..)
 * Scope: global
 *
 * Houses main while loop for communicating with the virtual router server.
 *
 *---------------------------------------------------------------------------*/

int sr_vns_read_from_server(struct sr_instance* sr /* borrowed */)
{
    int command, len;
    unsigned char *buf = 0;
    c_packet_ethernet_header* sr_pkt = 0;
    int ret = 0, bytes_read = 0;

    /* REQUIRES */
    assert(sr);

    /*---------------------------------------------------------------------------
      Read a command from the server
      -------------------------------------------------------------------------*/

    bytes_read = 0;

    /* attempt to read the size of the incoming packet */
    while( bytes_read < 4)
    {
        do
        { /* -- just in case SIGALRM breaks recv -- */
            errno = 0; /* -- hacky glibc workaround -- */
            if((ret = recv(sr->sockfd,((uint8_t*)&len) + bytes_read,
                            4 - bytes_read, 0)) == -1)
            {
                if ( errno == EINTR )
                { continue; }

                perror("recv(..):sr_client.c::sr_vns_read_from_server");
                return -1;
            }
            bytes_read += ret;
        } while ( errno == EINTR); /* be mindful of signals */
    }

    len = ntohl(len);

    if ( len > 10000 || len < 0 )
    {
        fprintf(stderr,"Error: command length to large %d\n",len);
        close(sr->sockfd);
        return -1;
    }

    if((buf = (unsigned char*)malloc(len)) == 0)
    {
        fprintf(stderr,"Error: out of memory (sr_vns_read_from_server)\n");
        return -1;
    }

    /* set first field of command since we've already read it */
    *((int *)buf) = htonl(len);

    bytes_read = 0;

    /* read the rest of the command */
    while ( bytes_read < len - 4)
    {
        do
        {/* -- just in case SIGALRM breaks recv -- */
            errno = 0; /* -- hacky glibc workaround -- */
            if ((ret = read(sr->sockfd, buf+4+bytes_read, len - 4 - bytes_read)) ==
                    -1)
            {
                if ( errno == EINTR )
                { continue; }
                fprintf(stderr,"Error: failed reading command body %d\n",ret);
                close(sr->sockfd);
                return -1;
            }
            bytes_read += ret;
        } while (errno == EINTR); /* be mindful of signals */
    }

    /* My entry for most unreadable line of code - guido */
    /* ... you win - mc                                  */
    command = *(((int *)buf)+1) = ntohl(*(((int *)buf)+1));

    switch (command)
    {
        /* -------------        VNSPACKET     -------------------- */

        case VNSPACKET:
            sr_pkt = (c_packet_ethernet_header *)buf;

            /* -- log packet -- */
            sr_log_packet(sr, buf + sizeof(c_packet_header),
                    ntohl(sr_pkt->mLen) - sizeof(c_packet_header));

            /* -- pass to router, student's code should take over here -- */
            sr_integ_input(sr,
                    (buf+sizeof(c_packet_header)), /* lent */
                    len - sizeof(c_packet_header),
                    (const char*)buf + sizeof(c_base)); /* lent */

            break;

            /* -------------        VNSCLOSE      -------------------- */

        case VNSCLOSE:
            fprintf(stderr,"vns server closed session.\n");
            fprintf(stderr,"Reason: %s\n",((c_close*)buf)->mErrorMessage);
            sr_close_instance(sr);
            sr_integ_close(sr);
            if(buf)
            { free(buf); }
            return 0;
            break;

            /* -------------     VNSHWINFO     -------------------- */

        case VNSHWINFO:
            sr_handle_hwinfo(sr,(c_hwinfo*)buf);
            break;

        default:
            Debug("unknown command: %d\n", command);
            break;
    }

    if(buf)
    { free(buf); }
    return 1;
}/* -- sr_vns_read_from_server -- */

/*-----------------------------------------------------------------------------
 * Method: sr_send_packet(..)
 * Scope: Global
 *
 * Send a packet (ethernet header included!) of length 'len' to the server
 * to be injected onto the wire.
 *
 * Note: buf is expected to be an IP packet!!
 *
 *---------------------------------------------------------------------------*/

int sr_vns_send_packet(struct sr_instance* sr /* borrowed */,
                       uint8_t* buf /* borrowed */ ,
                       unsigned int len,
                       const char* iface /* borrowed */)
{
    c_packet_header *sr_pkt;
    unsigned int total_len =  len + (sizeof(c_packet_header));

    /* REQUIRES */
    assert(sr);
    assert(buf);
    assert(iface);

    /* don't waste my time ... */
    if ( len < 14 /* sizeof ethernet header */ )
    {
        fprintf(stderr , "** Error: packet is wayy to short \n");
        return -1;
    }

    /* Create packet */
    sr_pkt = (c_packet_header *)malloc(total_len);

    assert(sr_pkt);
    sr_pkt->mLen  = htonl(total_len);
    sr_pkt->mType = htonl(VNSPACKET);
    strncpy(sr_pkt->mInterfaceName,iface,16);
    memcpy(((uint8_t*)sr_pkt) + sizeof(c_packet_header),
            buf,len);

    /* -- log packet -- */
    sr_log_packet(sr,buf,len);

    if ( pthread_mutex_lock(&(sr->send_lock)) )
    { assert (0); }
    if( write(sr->sockfd, sr_pkt, total_len) < (signed int)total_len )
    {
        fprintf(stderr, "Error writing packet\n");
        free(sr_pkt);
        if ( pthread_mutex_unlock(&(sr->send_lock)) )
        { assert (0); }
        return -1;
    }
    if ( pthread_mutex_unlock(&(sr->send_lock)) )
    { assert (0); }

    free(sr_pkt);

    return 0;
} /* -- sr_send_packet -- */

