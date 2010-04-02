#ifndef OR_DATA_TYPES_H_
#define OR_DATA_TYPES_H_

#include <sys/types.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <time.h>

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
#define ICMP_TYPE_DESTINATION_UNREACHABLE	0x3
#define ICMP_CODE_NET_UNREACHABLE	     	0x0
#define ICMP_CODE_HOST_UNREACHABLE		0x1
#define ICMP_CODE_PROTOCOL_UNREACHABLE		0x2
#define ICMP_CODE_PORT_UNREACHABLE 		0x3
#define ICMP_CODE_NET_UNKNOWN			0x6

#define ICMP_TYPE_TIME_EXCEEDED			0xB
#define ICMP_CODE_TTL_EXCEEDED			0x0

#define ICMP_TYPE_ECHO_REQUEST			0x8
#define ICMP_TYPE_ECHO_REPLY			0x0
#define ICMP_CODE_ECHO				0x0


#endif /*OR_DATA_TYPES_H_*/
