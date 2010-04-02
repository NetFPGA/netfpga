/*-----------------------------------------------------------------------------
 * File: sr_base.c
 * Date: Spring 2002
 * Author: Martin Casado <casado@stanford.edu>
 *
 * Entry module to the low level networking subsystem of the router.
 *
 * Caveats:
 *
 *  - sys_thread_init(..) in sr_lwip_transport_startup(..) MUST be called from
 *    the main thread before other threads have been started.
 *
 *  - lwip requires that only one instance of the IP stack exist, therefore
 *    at the moment we don't support multiple instances of sr.  However
 *    support for this (given a cooperative tcp stack) would be simple,
 *    simple allow sr_init_low_level_subystem(..) to create new sr_instances
 *    each time they are called and return an identifier.  This identifier
 *    must be passed into sr_global_instance(..) to return the correct
 *    instance.
 *
 *  - lwip needs to keep track of all the threads so we use its
 *    sys_thread_new(), this is essentially a wrapper around
 *    pthread_create(..) that saves the thread's ID.  In the future, if
 *    we move away from lwip we should simply use pthread_create(..)
 *
 *
 *---------------------------------------------------------------------------*/

#ifdef _SOLARIS_
#define __EXTENSIONS__
#endif /* _SOLARIS_ */

/* get unistd.h to declare gethostname on linux */
#define __USE_BSD 1

#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>

#ifdef _LINUX_
#include <getopt.h>
#endif /* _LINUX_ */

#include "lwip/tcp.h"
#include "lwip/memp.h"
#include "lwip/transport_subsys.h"

#include "sr_vns.h"
#include "sr_base_internal.h"

#ifdef _CPUMODE_
#include "sr_cpu_extension_nf2.h"
#endif


extern char* optarg;

static void usage(char* );
static int  sr_lwip_transport_startup(void);
static void sr_set_user(struct sr_instance* sr);
static void sr_init_instance(struct sr_instance* sr);
static void sr_low_level_network_subsystem(void *arg);
static void sr_destroy_instance(struct sr_instance* sr);

/*----------------------------------------------------------------------------
 * sr_init_low_level_subystem
 *
 * Entry method to the sr low level network subsystem. Responsible for
 * managing, connecting to the server, reserving the topology, reading
 * the hardware information and starting the packet recv(..) loop in a
 * seperate thread.
 *
 * Caveats :
 *  - this method can only be called once!
 *
 *---------------------------------------------------------------------------*/

void* sr_init_low_level_subystem(int argc, char **argv)
{
    /* -- VNS default parameters -- */
    char  *host   = "vrhost";
    char  *rtable = "rtable";
    char  *server = "171.67.71.18";
    char  *cpuhw  = CPU_HW_FILENAME;
    uint16_t port =  12345;
    uint16_t topo =  0;

    char  *client = 0;
    char  *logfile = 0;


    char  *interface = "nf2c0"; /* Default NetFPGA interface for card 0 */

    /* -- singleton instance of router, passed to sr_get_global_instance
          to become globally accessible                                  -- */
    static struct sr_instance* sr = 0;

    int c;

    if ( sr )
    {
        fprintf(stderr,  "Warning: because of limitations in lwip, ");
        fprintf(stderr,  " sr supports 1 router instance per process. \n ");
        return 0;
    }

    sr = (struct sr_instance*) malloc(sizeof(struct sr_instance));

    while ((c = getopt(argc, argv, "hs:v:p:c:t:r:l:i:m:")) != EOF)
    {
        switch (c)
        {
            case 'h':
                usage(argv[0]);
                exit(0);
                break;
            case 'p':
                port = atoi((char *) optarg);
                break;
            case 't':
                topo = atoi((char *) optarg);
                break;
            case 'v':
                host = optarg;
                break;
            case 'r':
                rtable = optarg;
                break;
            case 'c':
                client = optarg;
                break;
            case 's':
                server = optarg;
                break;
            case 'l':
                logfile = optarg;
                break;
            case 'm':
                cpuhw = optarg;
                break;
            case 'i':
                interface = optarg;
                if (strncmp(interface, "nf2c", 4) != 0) {
                        usage(argv[0]);
                        exit(1);
                }
                break;
        } /* switch */
    } /* -- while -- */

        /* Set the NetFPGA interface name */
    strncpy(sr->interface, interface, 31);
    sr->interface[31] = '\0';

#ifdef _CPUMODE_
    Debug(" \n ");
    Debug(" < -- Starting sr in cpu mode -- >\n");
    Debug(" \n ");
#else
    Debug(" < -- Starting sr in router mode  -- >\n");
    Debug(" \n ");
#endif /* _CPUMODE_ */

    /* -- required by lwip, must be called from the main thread -- */
    sys_thread_init();

    /* -- zero out sr instance and set default configurations -- */
    sr_init_instance(sr);

#ifdef _CPUMODE_
    sr->topo_id = 0;
    strncpy(sr->vhost,  "cpu",    SR_NAMELEN);
    strncpy(sr->rtable, rtable, SR_NAMELEN);

    if ( sr_cpu_init_hardware(sr, cpuhw) )
    { exit(1); }
    sr_integ_hw_setup(sr);
#else
    sr->topo_id = topo;
    strncpy(sr->vhost,  host,    SR_NAMELEN);
    strncpy(sr->rtable, rtable, SR_NAMELEN);
#endif /* _CPUMODE_ */

    if(! client )
    { sr_set_user(sr); }
    else
    { strncpy(sr->user, client,  SR_NAMELEN); }

    if ( gethostname(sr->lhost,  SR_NAMELEN) == -1 )
    {
        perror("gethostname(..)");
        return 0;
    }

    /* -- log all packets sent/received to logfile (if non-null) -- */
    sr_vns_init_log(sr, logfile);

    sr_lwip_transport_startup();


#ifndef _CPUMODE_
    Debug("Client %s connecting to Server %s:%d\n",
            sr->user, server, port);
    Debug("Requesting topology %d\n", topo);

    /* -- connect to VNS and reserve host -- */
    if(sr_vns_connect_to_server(sr,port,server) == -1)
    { return 0; }

    /* read from server until the hardware is setup */
    while (! sr->hw_init )
    {
        if(sr_vns_read_from_server(sr) == -1 )
        {
            fprintf(stderr, "Error: could not get hardware information ");
            fprintf(stderr, "from the server");
            sr_destroy_instance(sr);
            return 0;
        }
    }
#endif

    /* -- start low-level network thread, dissown sr -- */
    sys_thread_new(sr_low_level_network_subsystem, (void*)sr /* dissown */);

    return sr->interface_subsystem;
}/* -- main -- */

/*-----------------------------------------------------------------------------
 * Method: sr_set_subsystem(..)
 * Scope: Global
 *
 * Set the router core in sr_instance
 *
 *---------------------------------------------------------------------------*/

void sr_set_subsystem(struct sr_instance* sr, void* core)
{
    sr->interface_subsystem = core;
} /* -- sr_set_subsystem -- */


/*-----------------------------------------------------------------------------
 * Method: sr_get_subsystem(..)
 * Scope: Global
 *
 * Return the sr router core
 *
 *---------------------------------------------------------------------------*/

void* sr_get_subsystem(struct sr_instance* sr)
{
    return sr->interface_subsystem;
} /* -- sr_get_subsystem -- */

/*-----------------------------------------------------------------------------
 * Method: sr_get_global_instance(..)
 * Scope: Global
 *
 * Provide the world with access to sr_instance(..)
 *
 *---------------------------------------------------------------------------*/

struct sr_instance* sr_get_global_instance(struct sr_instance* sr)
{
    static struct sr_instance* sr_global_instance = 0;

    if ( sr )
    { sr_global_instance = sr; }

    return sr_global_instance;
} /* -- sr_get_global_instance -- */

/*-----------------------------------------------------------------------------
 * Method: sr_low_level_network_subsystem(..)
 * Scope: local
 *---------------------------------------------------------------------------*/

static void sr_low_level_network_subsystem(void *arg)
{
    struct sr_instance* sr = (struct sr_instance*)arg;

    /* -- set argument as global singleton -- */
    sr_get_global_instance(sr);


#ifdef _CPUMODE_
    /* -- whizbang main loop ;-) */
    while( sr_cpu_input(sr) == 1);
#else
    /* -- whizbang main loop ;-) */
    while( sr_vns_read_from_server(sr) == 1);
#endif

   /* -- this is the end ... my only friend .. the end -- */
    sr_destroy_instance(sr);
} /* --  sr_low_level_network_subsystem -- */

/*-----------------------------------------------------------------------------
 * Method: sr_lwip_transport_startup(..)
 * Scope: local
 *---------------------------------------------------------------------------*/

static int sr_lwip_transport_startup(void)
{
    sys_init();
    mem_init();
    memp_init();
    pbuf_init();

    transport_subsys_init(0, 0);

    return 0;
} /* -- sr_lwip_transport_startup -- */


/*-----------------------------------------------------------------------------
 * Method: sr_set_user(..)
 * Scope: local
 *---------------------------------------------------------------------------*/

static void sr_set_user(struct sr_instance* sr)
{
    uid_t uid = getuid();
    struct passwd* pw = 0;

    /* REQUIRES */
    assert(sr);

    if(( pw = getpwuid(uid) ) == 0)
    {
        fprintf (stderr, "Error getting username, using something silly\n");
        strncpy(sr->user, "something_silly",  SR_NAMELEN);
    }
    else
    { strncpy(sr->user, pw->pw_name,  SR_NAMELEN); }

} /* -- sr_set_user -- */

/*-----------------------------------------------------------------------------
 * Method: sr_init_instance(..)
 * Scope:  Local
 *
 *----------------------------------------------------------------------------*/

static
void sr_init_instance(struct sr_instance* sr)
{
    /* REQUIRES */
    assert(sr);

    sr->sockfd   = -1;
    sr->user[0]  = 0;
    sr->vhost[0] = 0;
    sr->topo_id  = 0;
    sr->logfile  = 0;
    sr->hw_init  = 0;

    sr->interface_subsystem = 0;

    pthread_mutex_init(&(sr->send_lock), 0);

    sr_integ_init(sr);
} /* -- sr_init_instance -- */

/*-----------------------------------------------------------------------------
 * Method: sr_destroy_instance(..)
 * Scope:  local
 *
 *----------------------------------------------------------------------------*/

static void sr_destroy_instance(struct sr_instance* sr)
{
    /* REQUIRES */
    assert(sr);

    sr_integ_destroy(sr);
} /* -- sr_destroy_instance -- */

/*-----------------------------------------------------------------------------
 * Method: usage(..)
 * Scope: local
 *---------------------------------------------------------------------------*/

static void usage(char* argv0)
{
    printf("Router SCONE (Software Component of NETFPGA)\n");
    printf("Format : %s [OPTIONS]\n", argv0);
    printf("Options: \n");
    printf("     -r rtable.file\n");
    printf("     -l log.file\n");
    printf("     -i nf2cX (X being the first port of the NetFPGA card desired)\n");
    printf("     -u cpuhw.file\n");
} /* -- usage -- */
