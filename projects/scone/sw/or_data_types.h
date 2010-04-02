/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_DATA_TYPES_H_
#define OR_DATA_TYPES_H_

#include <sys/types.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <time.h>
#include "nf2/nf2util.h"


/** ETHERNET HEADER STRUCTURE **/
#define ETH_ADDR_LEN 6
#define ETH_HDR_LEN 14
struct eth_hdr
{
    uint8_t  eth_dhost[ETH_ADDR_LEN];    /* destination ethernet address */
    uint8_t  eth_shost[ETH_ADDR_LEN];    /* source ethernet address */
    uint16_t eth_type;                     /* packet type ID */
} __attribute__ ((packed)) ;
typedef struct eth_hdr eth_hdr;

/** DEFINES FOR ETHERNET **/
#define ETH_TYPE_ARP           0x0806  /* Addr. resolution protocol */
#define ETH_TYPE_IP            0x0800  /* IP protocol */

/** ARP HEADER STRUCTURE **/
struct arp_hdr
{
	unsigned short  arp_hrd;             /* format of hardware address   */
	unsigned short  arp_pro;             /* format of protocol address   */
	unsigned char   arp_hln;             /* length of hardware address   */
	unsigned char   arp_pln;             /* length of protocol address   */
	unsigned short  arp_op;              /* ARP opcode (command)         */
	unsigned char   arp_sha[ETH_ADDR_LEN];   /* sender hardware address      */
	struct in_addr  arp_sip;             /* sender IP address            */
	unsigned char   arp_tha[ETH_ADDR_LEN];   /* target hardware address      */
	struct in_addr  arp_tip;             /* target IP address            */
} __attribute__ ((packed)) ;
typedef struct arp_hdr arp_hdr;

/** DEFINES FOR ARP **/
#define ARP_HRD_ETHERNET 	0x0001
#define ARP_PRO_IP 				0x0800
#define ARP_OP_REQUEST 1
#define ARP_OP_REPLY   2

/** IP HEADER STRUCTURE **/
struct ip_hdr
{
	unsigned int ip_hl:4;		/* header length */
	unsigned int ip_v:4;		/* version */
	uint8_t ip_tos;				/* type of service */
	uint16_t ip_len;			/* total length */
	uint16_t ip_id;				/* identification */
	uint16_t ip_off;			/* fragment offset field */
	uint8_t ip_ttl;				/* time to live */
	uint8_t ip_p;				/* protocol */
	uint16_t ip_sum;			/* checksum */
	struct in_addr ip_src, ip_dst;	/* source and dest address */
} __attribute__ ((packed)) ;
typedef struct ip_hdr ip_hdr;

/** DEFINES FOR IP **/
#define IP_PROTO_ICMP		0x0001  /* ICMP protocol */
#define IP_PROTO_TCP		0x0006  /* TCP protocol */
#define IP_PROTO_UDP		0x0011	/* UDP protocol */
#define IP_PROTO_PWOSPF		0x0059	/* PWOSPF protocol */
#define	IP_FRAG_RF 0x8000			/* reserved fragment flag */
#define	IP_FRAG_DF 0x4000			/* dont fragment flag */
#define	IP_FRAG_MF 0x2000			/* more fragments flag */
#define	IP_FRAG_OFFMASK 0x1fff		/* mask for fragmenting bits */


/** ICMP HEADER STRUCTURE **/
struct icmp_hdr
{
	uint8_t icmp_type;
	uint8_t icmp_code;
	uint16_t icmp_sum;
} __attribute__ ((packed)) ;
typedef struct icmp_hdr icmp_hdr;

/** DEFINES FOR ICMP **/
#define ICMP_TYPE_DESTINATION_UNREACHABLE		0x3
#define ICMP_CODE_NET_UNREACHABLE						0x0
#define ICMP_CODE_HOST_UNREACHABLE					0x1
#define ICMP_CODE_PROTOCOL_UNREACHABLE			0x2
#define ICMP_CODE_PORT_UNREACHABLE 					0x3
#define ICMP_CODE_NET_UNKNOWN			 					0x6

#define ICMP_TYPE_TIME_EXCEEDED							0xB
#define ICMP_CODE_TTL_EXCEEDED							0x0

#define ICMP_TYPE_ECHO_REQUEST							0x8
#define ICMP_TYPE_ECHO_REPLY								0x0
#define ICMP_CODE_ECHO											0x0


/** PWOSPF HEADER STRUCTURE **/
struct pwospf_hdr
{
	uint8_t pwospf_ver;
	uint8_t pwospf_type;
	uint16_t pwospf_len;
	uint32_t pwospf_rid;
	uint32_t pwospf_aid;
	uint16_t pwospf_sum;
	uint16_t pwospf_atype;
	uint32_t pwospf_auth1;
	uint32_t pwospf_auth2;
} __attribute__ ((packed));
typedef struct pwospf_hdr pwospf_hdr;

#define PWOSPF_HDR_LEN 24

#define PWOSPF_VERSION					0x2
#define PWOSPF_TYPE_HELLO				0x1
#define PWOSPF_TYPE_LINK_STATE_UPDATE	0x4

#define PWOSPF_AREA_ID 0x0
#define PWOSPF_HELLO_TIP 0xe0000005

#define PWOSPF_NEIGHBOR_TIMEOUT 5
#define PWOSPF_LSUINT 30
#define PWOSPF_HELLO_PADDING 0x0

struct pwospf_hello_hdr
{
	struct in_addr pwospf_mask;
	uint16_t pwospf_hint;
	uint16_t pwospf_pad;
} __attribute__ ((packed));
typedef struct pwospf_hello_hdr pwospf_hello_hdr;


struct pwospf_lsu_hdr
{
	uint16_t pwospf_seq;
	uint16_t pwospf_ttl;
	uint32_t pwospf_num;
} __attribute__ ((packed));
typedef struct pwospf_lsu_hdr pwospf_lsu_hdr;


struct pwospf_lsu_adv
{
	struct in_addr pwospf_sub;
	struct in_addr pwospf_mask;
	uint32_t pwospf_rid;
} __attribute__ ((packed));
typedef struct pwospf_lsu_adv pwospf_lsu_adv;


struct nat_tcp_hdr
{
	uint16_t tcp_sport;
	uint16_t tcp_dport;
	uint32_t tcp_seq;
	uint32_t tcp_ack;
	uint8_t unused1[4];
	uint16_t tcp_sum;
	uint8_t unused2[2];
} __attribute__ ((packed));
typedef struct nat_tcp_hdr nat_tcp_hdr;

struct nat_udp_hdr
{
	uint16_t udp_sport;
	uint16_t udp_dport;
	uint16_t udp_len;
	uint16_t udp_sum;
} __attribute__ ((packed));
typedef struct nat_udp_hdr nat_udp_hdr;

struct nat_icmp_hdr
{
	uint8_t icmp_type;
	uint8_t icmp_code;
        uint16_t icmp_sum;
	uint16_t icmp_opt1;
	uint16_t icmp_opt2;
} __attribute__ ((packed));
typedef struct nat_icmp_hdr nat_icmp_hdr;



/** LINKED LIST STRUCT **/
struct node {
	struct node* prev;
	struct node* next;
	void* data;
};
typedef struct node node;


/** ROUTER STATE STRUCT **/
struct router_state {
	void* sr;

	/* network byte order */
	uint32_t router_id;
	uint32_t area_id;
	uint32_t lsu_update_needed:1;
	uint16_t pwospf_hello_interval;
	uint32_t pwospf_lsu_interval;
	uint32_t pwospf_lsu_broadcast;
	uint32_t dijkstra_dirty;
	uint16_t is_netfpga;
	uint32_t arp_ttl;
	uint32_t nat_timeout;

	/* NETFPGA specific */
	nf2device netfpga;
	void* libnet_context[4];
	char* libnet_errbuf[4];
	void* pcap_context[4];
	char* pcap_errbuf[4];
	pthread_t* input_threads[4];
	int raw_sockets[4];

	pthread_mutex_t* write_lock;

	node* rtable;
	pthread_rwlock_t* rtable_lock;

	node* arp_cache;
	pthread_rwlock_t* arp_cache_lock;

	node* if_list;
	pthread_rwlock_t* if_list_lock;

	node* arp_queue;
	pthread_rwlock_t* arp_queue_lock;

	node* cli_commands;
	pthread_rwlock_t* cli_commands_lock;

	node* sping_queue;
	pthread_mutex_t* sping_mutex;
	pthread_cond_t* sping_cond;

	node* pwospf_router_list;
	pthread_mutex_t* pwospf_router_list_lock;

	node* pwospf_lsu_queue;
	pthread_mutex_t* pwospf_lsu_queue_lock;

	node* nat_table;
	pthread_t* nat_maintenance_thread;
	pthread_mutex_t* nat_table_mutex;
	pthread_cond_t* nat_table_cond;

	pthread_t* arp_thread;
	pthread_t *pwospf_hello_thread;
	pthread_t *pwospf_lsu_thread;
	pthread_t *pwospf_lsu_timeout_thread;

	pthread_t* pwospf_dijkstra_thread;
	pthread_mutex_t* dijkstra_mutex;
	pthread_cond_t* dijkstra_cond;

	pthread_t* pwospf_lsu_bcast_thread;
	pthread_mutex_t* pwospf_lsu_bcast_mutex;
	pthread_cond_t* pwospf_lsu_bcast_cond;

	/* webserver related */
	pthread_t* www_thread;
	node* www_request_queue;
	pthread_mutex_t* www_mutex;
	pthread_cond_t* www_cond;

	/* stats related */
	pthread_t* stats_thread;
	pthread_mutex_t* stats_mutex;
	struct timeval stats_last_time;
	uint32_t stats_last[8][4];
	double stats_avg[8][2];

	pthread_mutex_t* local_ip_filter_list_mutex;
	node* local_ip_filter_list;

	pthread_mutex_t* log_dumper_mutex;
};
typedef struct router_state router_state;

/** RTABLE STRUCT **/
struct rtable_entry {
  	struct in_addr ip;
  	struct in_addr gw;
  	struct in_addr mask;
  	char iface[32];
  	unsigned int is_static:1;
  	unsigned int is_active:1;
};
typedef struct rtable_entry rtable_entry;


/** ARP CACHE STRUCT **/
#define IF_LEN 32

struct arp_cache_entry {
	struct in_addr ip;			/* target IP address */
	unsigned char arp_ha[ETH_ADDR_LEN];	/* target hardware address */
	time_t TTL;				/* time expiration of entry */
	int is_static;
};
typedef struct arp_cache_entry arp_cache_entry;


/** ARP QUEUE STRUCT **/
struct arp_queue_entry {
	char out_iface_name[IF_LEN];
	struct in_addr next_hop;
	int requests;
	time_t last_req_time;
	node* head;
};
typedef struct arp_queue_entry arp_queue_entry;

struct arp_queue_packet_entry {
	uint8_t* packet;
	unsigned int len;
};
typedef struct arp_queue_packet_entry arp_queue_packet_entry;


/** SPING QUEUE STRUCT **/
struct sping_queue_entry {
	uint8_t *packet;
	unsigned int len;
	time_t arrival_time;
};
typedef struct sping_queue_entry sping_queue_entry;


/** STRUCT CONTAINING INFO FOR THREAD SPAWED TO SATISFY A CLIENTS CLI COMMAND **/
struct cli_client_thread_info {
	int sockfd;
	router_state *rs;
};
typedef struct cli_client_thread_info cli_client_thread_info;


/** STRUCT CONTAINING A COMMAND FROM A CLIENT ON OUR CLI **/
struct cli_request {
	int sockfd;
	char* command;
};
typedef struct cli_request cli_request;

/** TYPEDEF FOR OUR FUNCTION POINTER HANDLING CLI COMMANDS **/
typedef void (*cli_command_handler)(router_state*, cli_request*);

/** STRUCT MAPPING A COMMAND TO A FUNCTION TO HANDLE IT **/
struct cli_entry {
	char* command;
	cli_command_handler handler;
};
typedef struct cli_entry cli_entry;

/*
 * Structure for holding information about an interface
 *
 */
struct iface_entry {
    char name[IF_LEN];
    unsigned char addr[6];
    uint32_t ip;
    uint32_t mask;
    uint32_t speed;
    unsigned int is_active:1;
    time_t last_sent_hello;
    node* nbr_routers;
    uint8_t is_wan;
};
typedef struct iface_entry iface_entry;

struct nbr_router {
	uint32_t router_id;	/* net byte order */
	struct in_addr ip;	/* net byte order */
	time_t last_rcvd_hello;
};
typedef struct nbr_router nbr_router;

/*
 * Definitions for Dijkstra's Algorithm
 */
 struct pwospf_interface {
 	struct in_addr subnet;
 	struct in_addr mask;
 	uint32_t router_id;
 	uint32_t is_active:1;
 };

 typedef struct pwospf_interface pwospf_interface;

 struct pwospf_router {
 	uint32_t router_id;
 	uint32_t area_id;
// 	uint16_t lsu_int;
 	uint16_t seq;
	time_t last_update;
	uint32_t distance;
	unsigned int shortest_path_found:1;
	node* interface_list;
	struct pwospf_router* prev_router;
 };

 typedef struct pwospf_router pwospf_router;



struct pwospf_lsu_queue_entry {
	struct in_addr ip;
	char iface[IF_LEN];
	uint8_t *packet;
	unsigned int len;
};

typedef struct pwospf_lsu_queue_entry pwospf_lsu_queue_entry;



#define NAT_EXTERNAL 0
#define NAT_INTERNAL 1

struct nat_ip_port_pair {
	struct in_addr ip;  	/* NETWORK BYTE ORDER */
	uint16_t port;		/* NETWORK BYTE ORDER */
	uint16_t checksum;	/* NETWORK BYTE ORDER */
	uint16_t checksum_ip;   /* NETWORK BYTE ORDER */
	uint16_t checksum_port;   /* NETWORK BYTE ORDER */
};
typedef struct nat_ip_port_pair nat_ip_port_pair;


struct nat_entry {
	nat_ip_port_pair nat_ext;
	nat_ip_port_pair nat_int;
	uint32_t last_hits;
	time_t last_hits_time;
	uint32_t hits;
	double avg_hits_per_second;
	uint8_t hw_row;
	uint8_t is_static;
};

typedef struct nat_entry nat_entry;

/* STRUCT CONTAINING INFO FOR THREAD SPAWED TO SATISFY A CLIENTS WWW REQUEST **/
struct www_client_thread_info {
	int sockfd;
	router_state *rs;
};
typedef struct www_client_thread_info www_client_thread_info;

/* Struct for LOCAL IP FILTER used by NETFPGA */
#define LOCAL_IP_FILTER_ENTRY_NAME_LEN 32

struct local_ip_filter_entry {
	struct in_addr ip;
	char name[LOCAL_IP_FILTER_ENTRY_NAME_LEN];
};
typedef struct local_ip_filter_entry local_ip_filter_entry;

struct netfpga_input_arg {
	router_state* rs;
	int interface_num;
};
typedef struct netfpga_input_arg netfpga_input_arg;

#endif /*OR_DATA_TYPES_H_*/
