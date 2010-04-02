#include <sys/time.h>
#include <sys/types.h>

#include <stdio.h>
#include <assert.h>

#include "sr_dumper.h"

#include "sr_base_internal.h"


/*-----------------------------------------------------------------------------
 * Method: sr_log_packet()
 * Scope:  Global
 *
 *---------------------------------------------------------------------------*/

void sr_log_packet(struct sr_instance* sr, uint8_t* buf, int len )
{
    struct pcap_pkthdr h;
    int size;

    /* REQUIRES */
    assert(sr);

    if(!sr->logfile)
    {return; }

    size = min(SR_PACKET_DUMP_SIZE, len);

    gettimeofday(&h.ts, 0);
    h.caplen = size;
    h.len = (size < SR_PACKET_DUMP_SIZE) ? size : SR_PACKET_DUMP_SIZE;

    sr_dump(sr->logfile, &h, buf);
    fflush(sr->logfile);
} /* -- sr_log_packet -- */

static void
sf_write_header(FILE *fp, int linktype, int thiszone, int snaplen)
{
        struct pcap_file_header hdr;

        hdr.magic = TCPDUMP_MAGIC;
        hdr.version_major = PCAP_VERSION_MAJOR;
        hdr.version_minor = PCAP_VERSION_MINOR;

        hdr.thiszone = thiszone;
        hdr.snaplen = snaplen;
        hdr.sigfigs = 0;
        hdr.linktype = linktype;

        if (fwrite((char *)&hdr, sizeof(hdr), 1, fp) != 1)
                fprintf(stderr, "sf_write_header: can't write header\n");
}

/*
 * Initialize so that sf_write_header() will output to the file named 'fname'.
 */
FILE *
sr_dump_open(const char *fname, int thiszone, int snaplen)
{
  FILE *fp;

        if (fname[0] == '-' && fname[1] == '\0')
                fp = stdout;
        else {
                fp = fopen(fname, "w");
                if (fp == NULL) {
                        fprintf(stderr, "sr_dump_open: can't open %s",
                            fname);
                        return (NULL);
                }
        }

        sf_write_header(fp, LINKTYPE_ETHERNET, thiszone, snaplen);

        return fp;
}

/*
 * Output a packet to the initialized dump file.
 */
void
sr_dump(FILE *fp, const struct pcap_pkthdr *h, const unsigned char *sp)
{
        struct pcap_sf_pkthdr sf_hdr;

        sf_hdr.ts.tv_sec  = h->ts.tv_sec;
        sf_hdr.ts.tv_usec = h->ts.tv_usec;
        sf_hdr.caplen     = h->caplen;
        sf_hdr.len        = h->len;
        /* XXX we should check the return status */
        (void)fwrite(&sf_hdr, sizeof(sf_hdr), 1, fp);
        (void)fwrite((char *)sp, h->caplen, 1, fp);
}

void
sr_dump_close(FILE *fp)
{
  fclose(fp);
}

