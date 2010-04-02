/**
 * This header file defines data structures for logging packets in tcpdump
 * format as well as a set of operations for logging.
 */


#ifdef _LINUX_
#include <stdint.h>
#endif /* _LINUX_ */

#ifdef _DARWIN_
#include <inttypes.h>
#endif /* _DARWIN_ */

#include <sys/time.h>
#include <pcap.h>

#define PCAP_VERSION_MAJOR 2
#define PCAP_VERSION_MINOR 4
#define PCAP_ETHA_LEN 6
#define PCAP_PROTO_LEN 2

#define TCPDUMP_MAGIC 0xa1b2c3d4

#define LINKTYPE_ETHERNET 1

#define min(a,b) ( (a) < (b) ? (a) : (b) )

#define SR_PACKET_DUMP_SIZE 1514


/*
 * This is a timeval as stored in disk in a dumpfile.
 * It has to use the same types everywhere, independent of the actual
 * `struct timeval'
 */
struct pcap_timeval {
    int tv_sec;           /* seconds */
    int tv_usec;          /* microseconds */
};


/*
 * How a `pcap_pkthdr' is actually stored in the dumpfile.
 */
struct pcap_sf_pkthdr {
    struct pcap_timeval ts;     /* time stamp */
    uint32_t caplen;         /* length of portion present */
    uint32_t len;            /* length this packet (off wire) */
};

/* Given sr instance, log packet to logfile */
struct sr_instance; /* forward declare */
void sr_log_packet(struct sr_instance* sr, uint8_t* buf, int len );

/**
 * Open a dump file and initialize the file.
 */
FILE* sr_dump_open(const char *fname, int thiszone, int snaplen);

/**
 * Write data into the log file
 */
void sr_dump(FILE *fp, const struct pcap_pkthdr *h, const unsigned char *sp);

/**
 * Close the file
 */
void sr_dump_close(FILE *fp);
