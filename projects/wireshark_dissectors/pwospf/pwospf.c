/**
 * Filename: pwospf.c
 * Purpose: define the PWOSPF header and methods to compute its checksum
 */

/** PWOSPF Header */
typedef struct pwospf_hdr_t {
    byte version;
    byte type;
    guint16 len;
    guint32 router_id;
    guint32 area_id;
    guint16 checksum;
    guint16 auth_type;
    uint64_t auth;
} __attribute__ ((packed)) pwospf_hdr_t;

/*
 * The implementation of this function is based on code in the following book:
 *  W. Richard Stevens, Bill Fenner, and Andrew M. Rudoff. UNIX Network
 *  Programming. Addison-Wesley. Volume 1, Edition 3, 2007. 753.
 */
guint16 checksum( guint16* buf, unsigned len ) {
    guint16 answer;
    guint32 sum;

    /* add all 16 bit pairs into the total */
    answer = sum = 0;
    while( len > 1 ) {
        sum += *buf++;
        len -= 2;
    }

    /* take care of the last lone byte, if present */
    if( len == 1 ) {
        *(unsigned char *)(&answer) = *(unsigned char *)buf;
        sum += answer;
    }

    /* fold any carries back into the lower 16 bits */
    sum = (sum >> 16) + (sum & 0xFFFF);    /* add hi 16 to low 16 */
    sum += (sum >> 16);                    /* add carry           */
    answer = ~sum;                         /* truncate to 16 bits */

    return answer;
}

/**
 * Recompute the checksum field in the header and then return that new value.
 * The header will also be updated with this new value.
 */
guint16 checksum_pwospf( pwospf_hdr_t* hdr ) {
    hdr->checksum = 0;
    hdr->checksum = checksum( (guint16*)hdr, ntohs(hdr->len) );
    return hdr->checksum;
}
