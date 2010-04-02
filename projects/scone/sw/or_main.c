/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <string.h>
#include <libnet.h>
#include <pcap.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>

#include "or_main.h"
#include "or_utils.h"
#include "or_arp.h"
#include "or_ip.h"
#include "sr_base_internal.h"
#include "or_rtable.h"
#include "or_iface.h"
#include "or_output.h"
#include "or_cli.h"
#include "or_vns.h"
#include "or_sping.h"
#include "or_pwospf.h"
#include "or_dijkstra.h"
#include "or_netfpga.h"
#include "or_nat.h"
#include "nf2/nf2util.h"
#include "nf2/nf2.h"
#include "reg_defines.h"
#include "or_www.h"
#include "or_nat.h"

inline router_state* get_router_state(struct sr_instance* sr) {
	return (router_state*)sr->interface_subsystem;
}

void init(struct sr_instance* sr)
{
		unsigned int iseed = (unsigned int)time(NULL);
		srand(iseed+1);

    router_state* rs = (router_state*)malloc(sizeof(router_state));
    assert(rs);
    bzero(rs, sizeof(router_state));
    rs->sr = sr;

	#ifdef _CPUMODE_
    init_rawsockets(rs);
	#endif


    /** INITIALIZE LOCKS **/
    rs->write_lock = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->write_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->arp_cache_lock = (pthread_rwlock_t*)malloc(sizeof(pthread_rwlock_t));
    if (pthread_rwlock_init(rs->arp_cache_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->arp_queue_lock = (pthread_rwlock_t*)malloc(sizeof(pthread_rwlock_t));
    if (pthread_rwlock_init(rs->arp_queue_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->if_list_lock = (pthread_rwlock_t*)malloc(sizeof(pthread_rwlock_t));
    if (pthread_rwlock_init(rs->if_list_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->rtable_lock = (pthread_rwlock_t*)malloc(sizeof(pthread_rwlock_t));
    if (pthread_rwlock_init(rs->rtable_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->cli_commands_lock = (pthread_rwlock_t*)malloc(sizeof(pthread_rwlock_t));
    if (pthread_rwlock_init(rs->cli_commands_lock, NULL) != 0) {
    	perror("Lock init error");
    	exit(1);
    }

    rs->nat_table_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->nat_table_mutex, NULL) != 0) {
    	perror("Mutex init error");
    	exit(1);
    }

    rs->nat_table_cond = (pthread_cond_t*)malloc(sizeof(pthread_cond_t));
    if (pthread_cond_init(rs->nat_table_cond, NULL) != 0) {
			perror("Nat Table cond init error");
			exit(1);
    }

    rs->local_ip_filter_list_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->local_ip_filter_list_mutex, NULL) != 0) {
			perror("Local IP Filter Mutex init error");
			exit(1);
    }

    rs->log_dumper_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->log_dumper_mutex, NULL) != 0) {
			perror("Log dumper mutex init error");
			exit(1);
    }

    rs->sr = sr;
		rs->area_id = PWOSPF_AREA_ID;
		rs->pwospf_hello_interval = PWOSPF_NEIGHBOR_TIMEOUT;
		rs->pwospf_lsu_interval = PWOSPF_LSUINT;
		rs->pwospf_lsu_broadcast = 1;
		rs->arp_ttl = INITIAL_ARP_TIMEOUT;
		rs->nat_timeout = 120;

		/* clear stats */
		int i, j;
		for (i = 0; i < 8; ++i) {
			for (j = 0; j < 4; ++j) {
				rs->stats_last[i][j] = 0;
			}
			for (j = 0; j < 2; ++j) {
				rs->stats_avg[i][j] = 0.0;
			}
		}
		rs->stats_last_time.tv_sec = 0;
		rs->stats_last_time.tv_usec = 0;

		#ifdef _CPUMODE_
			rs->is_netfpga = 1;
			char* name = (char*)calloc(1, 32);
			strncpy(name, sr->interface, 32);
			rs->netfpga.device_name = name;
			rs->netfpga.fd = 0;
			rs->netfpga.net_iface = 0;

			if (check_iface(&(rs->netfpga))) {
				printf("Failure connecting to NETFPGA\n");
				exit(1);
			}

			if (openDescriptor(&(rs->netfpga))) {
				printf("Failure connecting to NETFPGA\n");
				exit(1);
			}

			/* initialize the hardware */
			init_hardware(rs);

		#else
			rs->is_netfpga = 0;
		#endif

		if (rs->is_netfpga) {
			/* Add 224.0.0.5 as a local IP Filter */
			struct in_addr ip;
			inet_pton(AF_INET, "224.0.0.5", &ip);
			add_local_ip_filter(rs, &ip, "pwospf");
		}


    /* Initialize SPING data */
    rs->sping_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->sping_mutex, NULL) != 0) {
	perror("Sping mutex init error");
    	exit(1);
    }

    rs->sping_cond = (pthread_cond_t*)malloc(sizeof(pthread_cond_t));
    if (pthread_cond_init(rs->sping_cond, NULL) != 0) {
			perror("Sping cond init error");
			exit(1);
    }

    /* Initialize LSU data */
    rs->pwospf_router_list_lock = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->pwospf_router_list_lock, NULL) != 0) {
			perror("Routing list mutex init error");
    	exit(1);
    }

    rs->pwospf_lsu_bcast_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->pwospf_lsu_bcast_mutex, NULL) != 0) {
			perror("LSU bcast mutex init error");
    	exit(1);
    }

    rs->pwospf_lsu_bcast_cond = (pthread_cond_t*)malloc(sizeof(pthread_cond_t));
    if (pthread_cond_init(rs->pwospf_lsu_bcast_cond, NULL) != 0) {
			perror("LSU bcast cond init error");
			exit(1);
    }

    rs->pwospf_lsu_queue_lock = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->pwospf_lsu_queue_lock, NULL) != 0) {
			perror("Lsu queue mutex init error");
    	exit(1);
    }


    /* Initialize PWOSPF Dijkstra Thread Mutex/Cond Var */
    rs->dijkstra_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->dijkstra_mutex, NULL) != 0) {
			perror("Dijkstra mutex init error");
    	exit(1);
    }

    rs->dijkstra_cond = (pthread_cond_t*)malloc(sizeof(pthread_cond_t));
    if (pthread_cond_init(rs->dijkstra_cond, NULL) != 0) {
			perror("Dijkstra cond init error");
			exit(1);
    }

    /* Initialize WWW Mutex/Cond Var */
    rs->www_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->www_mutex, NULL) != 0) {
			perror("WWW mutex init error");
    	exit(1);
    }

    rs->www_cond = (pthread_cond_t*)malloc(sizeof(pthread_cond_t));
    if (pthread_cond_init(rs->www_cond, NULL) != 0) {
			perror("WWW cond init error");
			exit(1);
    }

    /* Initialize Stats Mutex */
    rs->stats_mutex = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (pthread_mutex_init(rs->stats_mutex, NULL) != 0) {
			perror("Stats mutex init error");
    	exit(1);
    }


    sr_set_subsystem(sr, (void*)rs);

    /** SPAWN THE ARP QUEUE THREAD **/
    rs->arp_thread = (pthread_t*)malloc(sizeof(pthread_t));

    if(pthread_create(rs->arp_thread, NULL, arp_thread, (void *)sr) != 0) {
	    perror("Thread create error");
    }


    /** SPAWN THE PWOSPF HELLO BROADCAST THREAD **/
    rs->pwospf_hello_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->pwospf_hello_thread, NULL, pwospf_hello_thread, (void *)sr) != 0) {
		perror("Thread create error");
    }


    /** SPAWN THE PWOSPF LSU BROADCAST THREAD **/
    rs->pwospf_lsu_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->pwospf_lsu_thread, NULL, pwospf_lsu_thread, (void *)sr) != 0) {
	    perror("Thread create error");
    }


    /** SPAWN THE PWOSPF LSU BCAST TIMEOUT THREAD **/
    rs->pwospf_lsu_timeout_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->pwospf_lsu_timeout_thread, NULL, pwospf_lsu_timeout_thread, (void*)sr) != 0) {
	    perror("Thread create error");
    }

    /** SPAWN THE DIJKSTRA THREAD **/
    rs->pwospf_dijkstra_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->pwospf_dijkstra_thread, NULL, dijkstra_thread, (void*)get_router_state(sr)) != 0) {
	    perror("Thread create error");
    }


    /** SPAWN THE PWOSPF LSU BCAST THREAD **/
    rs->pwospf_lsu_bcast_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->pwospf_lsu_bcast_thread, NULL, pwospf_lsu_bcast_thread, (void*)sr) != 0) {
	    perror("Thread create error");
    }

    /** Spawn the NAT Maintenance Thread **/
    /*
    rs->nat_maintenance_thread = (pthread_t*)malloc(sizeof(pthread_t));
    if(pthread_create(rs->nat_maintenance_thread, NULL, nat_maintenance_thread, (void*)rs) != 0) {
	    perror("Thread create error");
    }
    */

    /* if we are on the NETFPGA spawn the stats thread */
		if (rs->is_netfpga) {
	    rs->stats_thread = (pthread_t*)malloc(sizeof(pthread_t));
	    if(pthread_create(rs->stats_thread, NULL, netfpga_stats, (void*)rs) != 0) {
		    perror("Thread create error");
	    }
		}
}

void init_add_interface(struct sr_instance* sr, struct sr_vns_if* vns_if) {
	/* do not add any of the cpu interfaces */
	if (strstr(vns_if->name, "cpu")) {
		return;
	}

	router_state* rs = (router_state*)sr->interface_subsystem;
	node* n = node_create();

	iface_entry* ie = (iface_entry*)malloc(sizeof(iface_entry));
	bzero(ie, sizeof(iface_entry));
	ie->is_active = 1;
	ie->ip = vns_if->ip;
	ie->mask = vns_if->mask;
	ie->speed = vns_if->speed;
	ie->is_wan = 0;
	memcpy(ie->addr, vns_if->addr, ETH_ADDR_LEN);
	memcpy(ie->name, vns_if->name, IF_LEN);
//	ie->hello_interval = PWOSPF_NEIGHBOR_TIMEOUT;


	/* router id is the same as the ip of the 0th iface */
	if(strncmp(ie->name, "eth0", IF_LEN) == 0) {
		rs->router_id = ie->ip;
	}

	n->data = ie;

	if (rs->if_list == NULL) {
		rs->if_list = n;
	} else {
		node_push_back(rs->if_list, n);
	}

	if (rs->is_netfpga) {
		/* set this on hardware */
		unsigned int mac_hi = 0;
		mac_hi |= ((unsigned int)vns_if->addr[0]) << 8;
		mac_hi |= ((unsigned int)vns_if->addr[1]);
		unsigned int mac_lo = 0;
		mac_lo |= ((unsigned int)vns_if->addr[2]) << 24;
		mac_lo |= ((unsigned int)vns_if->addr[3]) << 16;
		mac_lo |= ((unsigned int)vns_if->addr[4]) << 8;
		mac_lo |= ((unsigned int)vns_if->addr[5]);

		switch (getPortNumber(vns_if->name)) {
			case 0:
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_HI_REG, mac_hi);
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_0_LO_REG, mac_lo);
				break;
			case 1:
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_HI_REG, mac_hi);
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_1_LO_REG, mac_lo);
				break;
			case 2:
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_HI_REG, mac_hi);
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_2_LO_REG, mac_lo);
				break;
			case 3:
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_HI_REG, mac_hi);
				writeReg(&rs->netfpga, ROUTER_OP_LUT_MAC_3_LO_REG, mac_lo);
				break;
		}
	}

	/* add a local ip filter as well */
	struct in_addr ip;
	ip.s_addr = vns_if->ip;
	add_local_ip_filter(rs, &ip, vns_if->name);
}

/**
 * This function is NOT thread safe!
 *
 */
iface_entry* get_interface(struct sr_instance* sr, const char* name) {

	node* if_walker = 0;
	iface_entry* vns_if = 0;
	router_state* rs = (router_state*)sr->interface_subsystem;


	/* given an interface name return the interface record
	 * return 0 if interface record doesn't exist
	 */
	if_walker = rs->if_list;
	while(if_walker)
	{
		vns_if = (iface_entry*) if_walker->data;
		if(!strncmp(vns_if->name, name, SR_NAMELEN))
		{ break; }

		vns_if = 0;
		if_walker = if_walker->next;
	}

	return vns_if;
}

void init_router_list(struct sr_instance* sr){

	assert(sr);
	router_state *rs = get_router_state(sr);

	/* build an entry for our router */
	pwospf_router *our_router = (pwospf_router *)calloc(1, sizeof(pwospf_router));
	our_router->router_id = rs->router_id;
	our_router->area_id = rs->area_id;
	our_router->seq = 0;
	our_router->distance = 0;
	our_router->shortest_path_found = 0;
	time(&our_router->last_update);


	/* insert our_router in the pwospf router list */
	assert(rs->pwospf_router_list == NULL);
	node *n = node_create();
	n->data = (void *)our_router;
	rs->pwospf_router_list = n;


	/* advertise what's directly connected to us */
	node *il_walker = rs->if_list;
	while(il_walker) {
		iface_entry *ie = (iface_entry *)il_walker->data;

		pwospf_interface *pi = (pwospf_interface *)calloc(1, sizeof(pwospf_interface));
		pi->subnet.s_addr = (ie->ip & ie->mask);
		pi->mask.s_addr = ie->mask;
		pi->router_id = 0;
		pi->is_active = 0;

		node *rl_entry = node_create();
		rl_entry->data = (void *)pi;
		if(our_router->interface_list == NULL) {
			our_router->interface_list = rl_entry;
		}
		else {
			node_push_back(our_router->interface_list, rl_entry);
		}

		il_walker = il_walker->next;
	}


	//char *str; int len;
	//sprint_pwospf_router_list(rs, &str, &len);
	//printf("\nINITIAL ROUTER LIST:\n\n%s\n\n", str);
}



void init_rtable(struct sr_instance* sr) {
	/* get the rtable lock */
	lock_rtable_wr(get_router_state(sr));

	/* the sr_instance only holds 32 chars of the path to the rtable file so we have
	 * to pass it in as a relative path to the working directory, which requires
	 * us to get the working directory, do some string manipulation, and append
	 * the relative path to the end of the working directory */
	char path[256];
	bzero(path, 256);
	getcwd(path, 256);
	int len = strlen(path);
	path[len] = '/';
	strcpy(path+len+1, sr->rtable);
	FILE* file = fopen(path, "r");
  if (file == NULL) {
  	perror("Failure opening file");
   	exit(1);
  }

  char buf[1024];
  bzero(buf, 1024);

  router_state* rs = (router_state*)sr->interface_subsystem;

  /* walk through the file one line at a time adding its contents to the rtable */
  while (fgets(buf, 1024, file) != NULL) {
  	char* ip = NULL;
  	char* gw = NULL;
  	char* mask = NULL;
  	char* iface = NULL;
  	if (sscanf(buf, "%as %as %as %as", &ip, &gw, &mask, &iface) != 4) {
  		printf("Failure reading from rtable file\n");
  	}

  	rtable_entry* entry = (rtable_entry*)malloc(sizeof(rtable_entry));
  	bzero(entry, sizeof(rtable_entry));

  	if (inet_pton(AF_INET, ip, &(entry->ip)) == 0) {
  		perror("Failure reading rtable");
  	}
  	if (inet_pton(AF_INET, gw, &(entry->gw)) == 0) {
  		perror("Failure reading rtable");
  	}
  	if (inet_pton(AF_INET, mask, &(entry->mask)) == 0) {
  		perror("Failure reading rtable");
  	}
  	strncpy(entry->iface, iface, 32);

  	entry->is_active = 1;
  	entry->is_static = 1;
  	/* create a node, set data pointer to the new entry */
  	node* n = node_create();
  	n->data = entry;

  	if (rs->rtable == NULL) {
  		rs->rtable = n;
  	} else {
  		node_push_back(rs->rtable, n);
  	}

  	char ip_array[INET_ADDRSTRLEN];
  	char gw_array[INET_ADDRSTRLEN];
  	char mask_array[INET_ADDRSTRLEN];

  	printf("Read: %s ", inet_ntop(AF_INET, &(entry->ip), ip_array, INET_ADDRSTRLEN));
  	printf("%s ", inet_ntop(AF_INET, &(entry->gw), gw_array, INET_ADDRSTRLEN));
  	printf("%s ", inet_ntop(AF_INET, &(entry->mask), mask_array, INET_ADDRSTRLEN));
  	printf("%s\n", entry->iface);
  }


	if (fclose(file) != 0) {
		perror("Failure closing file");
	}

	/* check if we have a default route entry, if so we need to add it to our pwospf router */
	pwospf_interface* default_route = default_route_present(rs);

	/* release the rtable lock */
	unlock_rtable(get_router_state(sr));

	if (default_route) {
		lock_mutex_pwospf_router_list(rs);

		pwospf_router* r = get_router_by_rid(rs->router_id, rs->pwospf_router_list);
		node* n = node_create();
		n->data = default_route;

		if (r->interface_list) {
			node_push_back(r->interface_list, n);
		} else {
			r->interface_list = n;
		}

		unlock_mutex_pwospf_router_list(rs);
	}
	/* tell our dijkstra algorithm to run */
	dijkstra_trigger(rs);
}

void init_hardware(router_state* rs) {
	/* reset the router */
	writeReg(&rs->netfpga, CPCI_REG_CTRL, 0x00010100);
	usleep(2000);

	/* enable DMA */
	//writeReg(&rs->netfpga, DMA_ENABLE_REG, 0x1);

	/* write 0's out to the rtable and arp table */
	write_arp_cache_to_hw(rs);
	write_rtable_to_hw(rs);
}

void init_cli(struct sr_instance* sr) {
	router_state* rs = get_router_state(sr);

	if(pthread_rwlock_wrlock(rs->cli_commands_lock) != 0) {
		perror("Failure getting CLI commands write lock");
	}


	/* CLI: help ... */
	register_cli_command(&(rs->cli_commands), "help", &cli_help);
	register_cli_command(&(rs->cli_commands), "?", &cli_help);


	/* CLI: show ... */
	register_cli_command(&(rs->cli_commands), "show ?", &cli_show_help);

	/* CLI: show vns ... */
	register_cli_command(&(rs->cli_commands), "show vns ?", &cli_show_vns_help);
	register_cli_command(&(rs->cli_commands), "show vns", &cli_show_vns);
	register_cli_command(&(rs->cli_commands), "show vns user", &cli_show_vns_user);
	register_cli_command(&(rs->cli_commands), "show vns user ?", &cli_show_vns_user_help);
	register_cli_command(&(rs->cli_commands), "show vns lhost", &cli_show_vns_lhost);
	register_cli_command(&(rs->cli_commands), "show vns lhost ?", &cli_show_vns_lhost_help);
	register_cli_command(&(rs->cli_commands), "show vns vhost", &cli_show_vns_vhost);
	register_cli_command(&(rs->cli_commands), "show vns vhost ?", &cli_show_vns_vhost_help);
	register_cli_command(&(rs->cli_commands), "show vns server", &cli_show_vns_server);
	register_cli_command(&(rs->cli_commands), "show vns server ?", &cli_show_vns_server_help);
	register_cli_command(&(rs->cli_commands), "show vns topology", &cli_show_vns_topology);
	register_cli_command(&(rs->cli_commands), "show vns topology ?", &cli_show_vns_topology_help);


	/* CLI: show ip ... */
	register_cli_command(&(rs->cli_commands), "show ip", &cli_show_ip_help);
	register_cli_command(&(rs->cli_commands), "show ip ?", &cli_show_ip_help);
	register_cli_command(&(rs->cli_commands), "show ip arp", &cli_show_ip_arp);
	register_cli_command(&(rs->cli_commands), "show ip arp ?", &cli_show_ip_arp_help);
	register_cli_command(&(rs->cli_commands), "show ip interface", &cli_show_ip_iface);
	register_cli_command(&(rs->cli_commands), "show ip interface ?", &cli_show_ip_iface_help);
	register_cli_command(&(rs->cli_commands), "show ip route", &cli_show_ip_rtable);
	register_cli_command(&(rs->cli_commands), "show ip route ?", &cli_show_ip_rtable_help);


	/* CLI: ip ... */
	register_cli_command(&(rs->cli_commands), "ip ?", &cli_ip_help);


	/* CLI: ip route ... */
	register_cli_command(&(rs->cli_commands), "ip route ?", &cli_ip_route_help);
	register_cli_command(&(rs->cli_commands), "ip route add", &cli_ip_route_add);
	register_cli_command(&(rs->cli_commands), "ip route add ?", &cli_ip_route_add_help);
	register_cli_command(&(rs->cli_commands), "ip route del", &cli_ip_route_del);
	register_cli_command(&(rs->cli_commands), "ip route del ?", &cli_ip_route_del_help);

	/* CLI: ip interface ... */
	register_cli_command(&(rs->cli_commands), "ip interface ?", &cli_ip_interface_help);
	register_cli_command(&(rs->cli_commands), "ip interface", &cli_ip_interface);


	/* CLI: ip arp ... */
	register_cli_command(&(rs->cli_commands), "ip arp ?", &cli_ip_arp_help);
	register_cli_command(&(rs->cli_commands), "ip arp add", &cli_ip_arp_add);
	register_cli_command(&(rs->cli_commands), "ip arp add ?", &cli_ip_arp_add_help);
	register_cli_command(&(rs->cli_commands), "ip arp del", &cli_ip_arp_del);
	register_cli_command(&(rs->cli_commands), "ip arp del ?", &cli_ip_arp_del_help);
	register_cli_command(&(rs->cli_commands), "ip arp set ttl", &cli_ip_arp_set_ttl);


	/* CLI: sping ... */
	register_cli_command(&(rs->cli_commands), "sping", &cli_sping);
	register_cli_command(&(rs->cli_commands), "sping ?", &cli_sping_help);


	/* CLI: pwospf ... */
	register_cli_command(&(rs->cli_commands), "pwospf ?", &cli_pwospf_help);
	register_cli_command(&(rs->cli_commands), "show pwospf iface", &cli_show_pwospf_iface);
	register_cli_command(&(rs->cli_commands), "show pwospf iface ?", &cli_show_pwospf_iface_help);
	register_cli_command(&(rs->cli_commands), "show pwospf router", &cli_show_pwospf_router_list);
	register_cli_command(&(rs->cli_commands), "show pwospf info", &cli_show_pwospf_info);
	register_cli_command(&(rs->cli_commands), "set aid", &cli_pwospf_set_aid);
	register_cli_command(&(rs->cli_commands), "set aid ?", &cli_pwospf_set_aid_help);
	register_cli_command(&(rs->cli_commands), "set hello interval", &cli_pwospf_set_hello);
	register_cli_command(&(rs->cli_commands), "set lsu broadcast", &cli_pwospf_set_lsu_broadcast);
	register_cli_command(&(rs->cli_commands), "set lsu interval", &cli_pwospf_set_lsu_interval);
	register_cli_command(&(rs->cli_commands), "send hello", &cli_pwospf_send_hello);
	register_cli_command(&(rs->cli_commands), "send lsu", &cli_pwospf_send_lsu);


	/* CLI: hw ... */
	register_cli_command(&(rs->cli_commands), "hw info", &cli_hw_info);
	register_cli_command(&(rs->cli_commands), "hw ?", &cli_hw_help);
	register_cli_command(&(rs->cli_commands), "show hw rtable", &cli_show_hw_rtable);
	register_cli_command(&(rs->cli_commands), "show hw arp", &cli_show_hw_arp_cache);
	register_cli_command(&(rs->cli_commands), "nuke arp", &cli_nuke_arp_cache);
	register_cli_command(&(rs->cli_commands), "nuke hw arp", &cli_nuke_hw_arp_cache_entry);
	register_cli_command(&(rs->cli_commands), "show hw iface", &cli_show_hw_interface);
	register_cli_command(&(rs->cli_commands), "hw iface add", &cli_hw_interface_add);
	register_cli_command(&(rs->cli_commands), "hw iface del", &cli_hw_interface_del);
	register_cli_command(&(rs->cli_commands), "hw iface", &cli_hw_interface_set);
	register_cli_command(&(rs->cli_commands), "hw arp miss", &cli_hw_arp_cache_misses);
	register_cli_command(&(rs->cli_commands), "hw pckts fwd", &cli_hw_num_pckts_fwd);

	/* CLI: nat ... */
	/*
	register_cli_command(&(rs->cli_commands), "nat ?", &cli_nat_help);
	register_cli_command(&(rs->cli_commands), "show nat table", &cli_show_nat_table);
	register_cli_command(&(rs->cli_commands), "nat set", &cli_nat_set);
	register_cli_command(&(rs->cli_commands), "nat reset", &cli_nat_reset);
	register_cli_command(&(rs->cli_commands), "nat test", &cli_nat_test);
	register_cli_command(&(rs->cli_commands), "nat add", &cli_nat_add);
	register_cli_command(&(rs->cli_commands), "nat del", &cli_nat_del);
	register_cli_command(&(rs->cli_commands), "show hw nat table", &cli_show_hw_nat_table);
	*/

	/* bubble sort command list */
	int swapped = 0;
	do {
		swapped = 0;
		node* cur = rs->cli_commands;
		while (cur && cur->next) {
			cli_entry* a = (cli_entry*)cur->data;
			cli_entry* b = (cli_entry*)cur->next->data;
			if (strcmp(a->command, b->command) == 1) {
				cur->data = b;
				cur->next->data = a;
				swapped = 1;
			}

			cur = cur->next;
		}
	} while (swapped);



	if(pthread_rwlock_unlock(rs->cli_commands_lock) != 0) {
		perror("Failure unlocking CLI commands lock");
	}
}


void process_packet(struct sr_instance* sr, const uint8_t * packet, unsigned int len, const char* interface) {

	/*
	printf("\n--- Received Packet on iface: %s ---\n", interface);
	print_packet((uint8_t*)packet, len);
	printf("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&\n");
	*/

	if (iface_is_active(get_router_state(sr), (char*)interface) == 0) {
		/* drop the packet */
		return;
	}

	/* REQUIRES */
	assert(sr);
	assert(packet);
	assert(interface);

	eth_hdr *ether_hdr = (eth_hdr *) packet;
	switch(ntohs(ether_hdr->eth_type)) {

		case ETH_TYPE_IP:
			printf(" ** -> Received IP packet of length %d\n", len);
			process_ip_packet(sr, packet, len, interface);
			break;

		case ETH_TYPE_ARP:
			printf(" ** -> Received ARP packet of length %d\n", len);
			process_arp_packet(sr, packet, len, interface);
			break;

		default: break;
	}

}

/*
 * This function takes responsibility for finding the target MAC address, and freeing packet.
 */
int send_ip(struct sr_instance* sr, uint8_t* packet, unsigned int len, struct in_addr* next_hop, const char* out_iface) {

	eth_hdr* eth = (eth_hdr*)packet;

	/*print_arp_cache(sr);*/
	arp_cache_entry* ace = get_from_arp_cache(sr, next_hop);
	if (ace) {
		memcpy(eth->eth_dhost, ace->arp_ha, ETH_ADDR_LEN);

		if (send_packet(sr, packet, len, out_iface) != 0) {
			printf("Failure sending IP packet\n");
			free(packet);
			return 1;
		}

		free(packet);
	} else {
		/* arp queue add adds the packet to the queue, will free later */
		arp_queue_add(sr, packet, len, out_iface, next_hop);
	}

	return 0;
}

int send_packet(struct sr_instance* sr, uint8_t* packet, unsigned int len, const char* iface) {
	router_state* rs = get_router_state(sr);
	if (pthread_mutex_lock(rs->write_lock) != 0) {
		perror("Failure locking write lock\n");
		exit(1);
	}

	int result;

	if (len < 60) {
		int pad_len = 60 - len;
		uint8_t* pad_packet = (uint8_t*)malloc (len + pad_len);
		if (!pad_packet) {
		  perror("Failed to malloc in send_packet().\n");
		  exit(1);
		}

		bzero(pad_packet, len+pad_len);
		memmove(pad_packet, packet, len);

		printf(" ** <- Sending packet of size %u out iface: %s\n", len+pad_len, iface);

		result=sr_integ_low_level_output(sr, pad_packet, len+pad_len, iface);

		free(pad_packet);
	} else {
		printf(" ** <- Sending packet of size %u out iface: %s\n", len, iface);
		result = sr_integ_low_level_output(sr, packet, len, iface);
	}

	/*
	print_packet(packet, len);
	*/

	if (pthread_mutex_unlock(rs->write_lock) != 0) {
		perror("Failure unlocking write lock\n");
		exit(1);
	}

	return result;
}


void destroy(struct sr_instance* sr) {
    router_state* rs = sr->interface_subsystem;

    /** DESTROY LOCKS **/
    if (pthread_mutex_destroy(rs->write_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->write_lock);

    if (pthread_rwlock_destroy(rs->arp_cache_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->arp_cache_lock);

    if (pthread_rwlock_destroy(rs->arp_queue_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->arp_queue_lock);

    if (pthread_rwlock_destroy(rs->if_list_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->if_list_lock);

    if (pthread_rwlock_destroy(rs->rtable_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->rtable_lock);

    if (pthread_rwlock_destroy(rs->cli_commands_lock) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->cli_commands_lock);

    if (pthread_mutex_destroy(rs->nat_table_mutex) != 0) {
    	perror("Lock destroy error");
    }
    free(rs->nat_table_mutex);

    if (pthread_cond_destroy(rs->nat_table_cond) != 0) {
    	perror("Cond destroy error");
    }
    free(rs->nat_table_cond);

    /* destroy dijkstra stuff */
    if (pthread_mutex_destroy(rs->dijkstra_mutex) != 0) {
    	perror("Mutex destroy error");
    }
    free(rs->dijkstra_mutex);

    if (pthread_cond_destroy(rs->dijkstra_cond) != 0) {
    	perror("Cond destroy error");
    }
    free(rs->dijkstra_cond);

    /* destroy www stuff */
    if (pthread_mutex_destroy(rs->www_mutex) != 0) {
    	perror("Mutex destroy error");
    }
    free(rs->www_mutex);

    if (pthread_cond_destroy(rs->www_cond) != 0) {
    	perror("Cond destroy error");
    }
    free(rs->www_cond);
    #ifdef _CPUMODE_
    closeDescriptor(&(rs->netfpga));
    #endif

    if (pthread_mutex_destroy(rs->local_ip_filter_list_mutex) != 0) {
    	perror("Mutex destroy error");
    } else {
    	free(rs->local_ip_filter_list_mutex);
    }

    /** TODO: Free the lists **/
}

/* Given a destination ip address:
 *  - find interface the packet would be shipped through
 *  - return this interface's ip address as the src ip address
 */
uint32_t find_srcip(uint32_t dest) {

        struct sr_instance* sr = sr_get_global_instance(0);
        router_state* rs = (router_state*)sr->interface_subsystem;
        iface_entry* iface_struct;

        char *iface = 0;
        struct in_addr dst;
        struct in_addr src;
        uint32_t srcip;

    	iface = calloc(32, sizeof(char));
        dst.s_addr = dest;
        src.s_addr = 0;


        lock_if_list_rd(rs);
        lock_rtable_rd(rs);

        if(get_next_hop(&src, iface, 32, rs, &dst)) {
                srcip = 0;
	}
	else {
		iface_struct = get_iface(rs, iface);
		assert(iface_struct);
		srcip = iface_struct->ip;
	}

        unlock_rtable(rs);
        unlock_if_list(rs);

	return srcip;
}

void init_rawsockets(router_state* rs) {
	struct sr_instance* sr = (struct sr_instance*)rs->sr;
	int base = atoi(&(sr->interface[4]));

	char iface_name[32] = "nf2c";
	int i;
	for (i = 0; i < 4; ++i) {
		sprintf(&(iface_name[4]), "%i", base+i);
		int s = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL));

		struct ifreq ifr;
		bzero(&ifr, sizeof(struct ifreq));
		strncpy(ifr.ifr_ifrn.ifrn_name, iface_name, IFNAMSIZ);
		if (ioctl(s, SIOCGIFINDEX, &ifr) < 0) {
			perror("ioctl SIOCGIFINDEX");
			exit(1);
		}

		struct sockaddr_ll saddr;
		bzero(&saddr, sizeof(struct sockaddr_ll));
		saddr.sll_family = AF_PACKET;
		saddr.sll_protocol = htons(ETH_P_ALL);
		saddr.sll_ifindex = ifr.ifr_ifru.ifru_ivalue;

		if (bind(s, (struct sockaddr*)(&saddr), sizeof(saddr)) < 0) {
			perror("bind error");
			exit(1);
		}

		rs->raw_sockets[i] = s;
	}
}

/* very un-elegant initialization routine */
void init_libnet(router_state* rs) {
	char* iface_names[4] = {"nf2c0", "nf2c1", "nf2c2", "nf2c3"};
	int i;

	for (i = 0; i < 4; ++i) {
		rs->libnet_errbuf[i] = calloc(1, LIBNET_ERRBUF_SIZE);
		if ((rs->libnet_context[i] = (void*)libnet_init(LIBNET_LINK_ADV, iface_names[i], rs->libnet_errbuf[i])) == NULL) {
			printf("Failure initializing libnet\n");
			exit(1);
		}
	}
}

void init_pcap(router_state* rs) {
	char* iface_names[4] = {"nf2c0", "nf2c1", "nf2c2", "nf2c3"};
	struct bpf_program fp;

	lock_if_list_rd(rs);

	int i = 0;
	node* cur = rs->if_list;
	while (cur) {
		iface_entry* iface = (iface_entry*)cur->data;
		if (i < 4) {
			rs->pcap_context[i] = (void*)pcap_open_live(iface_names[i], 65536, 1, 0, rs->pcap_errbuf[i]);
			if (rs->pcap_context[i] == NULL) {
				fprintf(stderr, "pcap_open_live(): %s\n", rs->pcap_errbuf[i]);
				fprintf(stderr, "This error may be caused by a non-root user running this file. Make sure this binary is SETUID.");
			}


			char filter_expr[31];
			bzero(filter_expr, 31);
			snprintf(filter_expr, 31, "!(ether src %02X:%02X:%02X:%02X:%02X:%02X)",
			iface->addr[0], iface->addr[1], iface->addr[2], iface->addr[3], iface->addr[4], iface->addr[5]);

			if (pcap_compile(rs->pcap_context[i], &fp, filter_expr, 1, 0) == -1) {
				printf("error compiling: %s\n", pcap_geterr(rs->pcap_context[i]));
				exit(1);
			}

			if (pcap_setfilter(rs->pcap_context[i], &fp) == -1) {
				printf("error setting filter: %s\n", pcap_geterr(rs->pcap_context[i]));
				exit(1);
			}

			++i;
		}


		cur = cur->next;
	}

	unlock_if_list(rs);
}

uint32_t integ_ip_output(uint8_t *payload, uint8_t proto, uint32_t src, uint32_t dest, int len) {

       assert(payload);

       struct sr_instance* sr = sr_get_global_instance(0);
       int retval = send_ip_packet(sr, proto, src, dest, payload, len);
       free(payload);
       return retval;

}

