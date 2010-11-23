/**
 * Filename: eventcap.h
 * Purpose:  Specify the NetFPGA Event Capture packet.
 */

#ifndef EVENTCAP_H
#define EVENTCAP_H

/** shorthand for a byte */
typedef guint8 byte;
typedef guint64 bitfield;

/** encapsulates information about queue size */
typedef struct {
    guint32 words;                 /* size in 64-bit words */
    guint32 packets;               /* size in packets */
} __attribute__ ((packed)) queue_size_t;

/** encapsulates information about a timestamp event */
typedef struct {
#ifdef _LITTLE_ENDIAN_
    bitfield type:2;               /* type should be TYPE_TIMESTAMP */
    bitfield time_top:30;          /* timestamp (MSB) with units of 8ns */
#   define MASK_TYPE     0xC0000000
#   define MASK_TIME_TOP 0x3FFFFFFF
#else
    bitfield time_top:30;          /* timestamp (MSB) with units of 8ns */
    bitfield type:2;
#   define MASK_TIME_TOP 0xFFFFFFFC
#   define MASK_TYPE     0x00000003
#endif
    uint32_t time_btm;             /* timestamp (LSB) with units of 8ns */
} __attribute__ ((packed)) event_timestamp_t;

/** encapsulates information about a arrive / depart / drop event */
typedef struct {
#ifdef _LITTLE_ENDIAN_
    bitfield type:2;               /* type (arrive, depart, or drop) */
    bitfield queue_id:3;           /* which queue the event is for */
    bitfield packet_len:8;         /* length of the packet involved */
    bitfield time_lsb:19;          /* partial timestamp in units of 8ns */
#define MASK_QUEUE_ID   0x38000000
#define MASK_PACKET_LEN 0x07F80000
#define MASK_TIME_LSB   0x0007FFFF
#else
    bitfield time_lsb:19;
    bitfield packet_len:8;
    bitfield queue_id:3;
    bitfield type:2;
#define MASK_TIME_LSB   0xFFFFE000
#define MASK_PACKET_LEN 0x00001FE0
#define MASK_QUEUE_ID   0x0000001C
#endif
} __attribute__ ((packed)) event_short_t;

/** define the NetFPGA Event Capture header */
typedef struct {
#ifdef _LITTLE_ENDIAN_
    bitfield pad:4;                /* padding; should be zero */
    bitfield version:4;            /* version */
#   define MASK_PAD     0xF0
#   define MASK_VERSION 0x0F
#else
    bitfield version:4;
    bitfield pad:4;
#   define MASK_VERSION 0xF0
#   define MASK_PAD     0x0F
#endif
    byte     num_events;           /* # of events at the end of the packet */
    guint32  seq;                  /* sequence number */
    queue_size_t queue_size[8];    /* size of each queue in words and packets */
    event_timestamp_t timestamp;   /* timestamp of the queue size info */
} __attribute__ ((packed)) eventcap_hdr_t;

#define TYPE_TIMESTAMP 0
#define TYPE_ARRIVE    1
#define TYPE_DEPART    2
#define TYPE_DROP      3

/** maximum size after removing Ethernet, IP, and UDP headers from 1500B */
#define MAX_EC_SIZE 1446

/**
 * Converts a 64-bit timestamp from its upper and lower 32 bits into a
 * human-readable timestamp broken down into years, days, hours, minutes,
 * seconds, milliseconds, microseconds, and finally nanoseconds.  The units of
 * the timestamp is assumed to be 8ns, e.g. 1 = 8ns, 2 = 16ns, etc.  The
 * returned string is in a statically allocated buffer.
 */
static inline char* timestamp8ns_to_string( guint32 upper, guint32 lower ) {
    static char str_ts[64];
    guint32 yr=0, day=0, hr=0, min=0, sec=0, msec=0, usec=0, nsec=0;
    guint64 nsec8_left = 0;

#define USEC_DIV_8NS 125
#define MSEC_DIV_8NS 125000
#define SEC_DIV_8NS  125000000
#define MIN_DIV_8NS  7500000000ULL
#define HR_DIV_8NS   450000000000ULL
#define DAY_DIV_8NS  (24ULL*HR_DIV_8NS)
#define YR_DIV_8NS   (365ULL*DAY_DIV_8NS)

    nsec8_left = (((guint64)upper) << 32) + lower;
    while( nsec8_left >= YR_DIV_8NS ) {
        nsec8_left -= YR_DIV_8NS;
        yr += 1;
    }
    while( nsec8_left >= DAY_DIV_8NS ) {
        nsec8_left -= DAY_DIV_8NS;
        day += 1;
    }
    while( nsec8_left >= HR_DIV_8NS ) {
        nsec8_left -= HR_DIV_8NS;
        hr += 1;
    }
    while( nsec8_left >= MIN_DIV_8NS ) {
        nsec8_left -= MIN_DIV_8NS;
        min += 1;
    }
    while( nsec8_left >= SEC_DIV_8NS ) {
        nsec8_left -= SEC_DIV_8NS;
        sec += 1;
    }
    while( nsec8_left >= MSEC_DIV_8NS ) {
        nsec8_left -= MSEC_DIV_8NS;
        msec += 1;
    }
    while( nsec8_left >= USEC_DIV_8NS ) {
        nsec8_left -= USEC_DIV_8NS;
        usec += 1;
    }
    nsec = nsec8_left * 8;

    if( yr > 0 )
        snprintf( str_ts, 64, "%uyr, %u day, %02uh:%02um:%02us:%03ums:%03uus:%03uns", yr, day, hr, min, sec, msec, usec, nsec );
    else if( day > 0 )
        snprintf( str_ts, 64, "%u day, %02uh:%02um:%02us:%03ums:%03uus:%03uns", day, hr, min, sec, msec, usec, nsec );
    else if( hr > 0 )
        snprintf( str_ts, 64, "%02uh:%02um:%02us:%03ums:%03uus:%03uns", hr, min, sec, msec, usec, nsec );
    else if( min > 0 )
        snprintf( str_ts, 64, "%02um:%02us:%03ums:%03uus:%03uns", min, sec, msec, usec, nsec );
    else
        snprintf( str_ts, 64, "%02us:%03ums:%03uus:%03uns", sec, msec, usec, nsec );

    return str_ts;
}

/**
 * Converts an event to a string.  For short events, display the timestamp
 * followed by the queue it applies to and the length of the packet in bytes
 * (NOT including the extra 8B word used internally by the NetFPGA).  The
 * returned string is in a statically allocated buffer.
 */
static inline char* event_to_string( guint32 type,
                                     guint32 queue_id,
                                     guint32 packet_len_8Bwords,
                                     char* str_timestamp ) {
    static char str_event[128];
    char* str_type;
    char* str_queue;

    switch( type ) {
    case TYPE_TIMESTAMP:
        snprintf( str_event, 128, "   at %s: Timestamp", str_timestamp );
        return str_event;

    case TYPE_ARRIVE:    str_type = "Arrival   of";    break;
    case TYPE_DEPART:    str_type = "Departure of";    break;
    case TYPE_DROP:      str_type = "Dropped     ";      break;
    default:             str_type = "Unknown Type";
    }

    switch( queue_id ) {
    case 0: str_queue = "NF2C0"; break;
    case 1: str_queue = " CPU0"; break;
    case 2: str_queue = "NF2C1"; break;
    case 3: str_queue = " CPU1"; break;
    case 4: str_queue = "NF2C2"; break;
    case 5: str_queue = " CPU2"; break;
    case 6: str_queue = "NF2C3"; break;
    case 7: str_queue = " CPU3"; break;
    default:str_queue = "Unknown Queue";
    }

    snprintf( str_event, 128, "   at %s: %s %s %uB",
              str_timestamp, str_queue, str_type, (packet_len_8Bwords-1)*8 );

    return str_event;
}

#endif /* EVENTCAP_H */
