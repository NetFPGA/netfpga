/**
 * Filename: packet-eventcap.c
 * Author:   David Underhill
 * Updated:  2008-06-08
 * Purpose:  define a Wireshark 0.99.x-1.x dissector for the NetFPGA Event Capture protocol
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <glib.h>
#include <epan/packet.h>
#include <epan/prefs.h>
#include <string.h>
#include <arpa/inet.h>
#include "eventcap.h"

#define PROTO_TAG_EVENTCAP	"EVENTCAP"

/* Wireshark ID of the EVENTCAP protocol */
static int proto_eventcap = -1;
static dissector_handle_t eventcap_handle;
static void dissect_eventcap(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree);

/* traffic will arrive with UDP port EVENTCAP_DST_UDP_PORT */
#define UDP_PORT_FILTER "udp.port"
static int global_eventcap_proto = EVENTCAP_DST_UDP_PORT;

/** names to bind to various values in the type field */
static const value_string names_type[] = {
    { TYPE_TIMESTAMP, "Timestamp" },
    { TYPE_ARRIVE,    "Arrive"    },
    { TYPE_DEPART,    "Depart"    },
    { TYPE_DROP,      "Drop"      },
    { 0,              NULL        }
};

/** names to bind to various values in the queue ID field */
static const value_string names_queue_id[] = {
    { 0, "NF2C0" },
    { 1, "CPU0"  },
    { 2, "NF2C1" },
    { 3, "CPU1"  },
    { 4, "NF2C2" },
    { 5, "CPU2"  },
    { 6, "NF2C3" },
    { 7, "CPU3"  },
    { 0, NULL    }
};
/* The hf_* variables are used to hold the IDs of our header fields; they are
 * set when we call proto_register_field_array() in proto_register_eventcap()
 */
static gint hf_nf2ec                     = -1;
static gint hf_nf2ec_header              = -1;
static gint hf_nf2ec_pad                 = -1;
static gint hf_nf2ec_version             = -1;
static gint hf_nf2ec_num_events          = -1;
static gint hf_nf2ec_seq                 = -1;
static gint hf_nf2ec_queue_size_words[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
static gint hf_nf2ec_queue_size_pkts[8]  = {-1,-1,-1,-1,-1,-1,-1,-1};

static gint hf_nf2ec_event               = -1;
static gint hf_nf2ec_type                = -1;
static gint hf_nf2ec_time_full           = -1;
static gint hf_nf2ec_time_top            = -1;
static gint hf_nf2ec_time_btm            = -1;

static gint hf_nf2ec_short_event         = -1;
static gint hf_nf2ec_queue_id            = -1;
static gint hf_nf2ec_packet_len          = -1;
static gint hf_nf2ec_time_lsb            = -1;

/* These are the ids of the subtrees that we may be creating */
static gint ett_nf2ec                     = -1;
static gint ett_nf2ec_header              = -1;
static gint ett_nf2ec_pad                 = -1;
static gint ett_nf2ec_version             = -1;
static gint ett_nf2ec_num_events          = -1;
static gint ett_nf2ec_seq                 = -1;
static gint ett_nf2ec_queue_size_words[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
static gint ett_nf2ec_queue_size_pkts[8]  = {-1,-1,-1,-1,-1,-1,-1,-1};

static gint ett_nf2ec_event               = -1;
static gint ett_nf2ec_type                = -1;
static gint ett_nf2ec_time_full           = -1;
static gint ett_nf2ec_time_top            = -1;
static gint ett_nf2ec_time_btm            = -1;

static gint ett_nf2ec_short_event         = -1;
static gint ett_nf2ec_queue_id            = -1;
static gint ett_nf2ec_packet_len          = -1;
static gint ett_nf2ec_time_lsb            = -1;

void proto_reg_handoff_eventcap()
{
    eventcap_handle = create_dissector_handle(dissect_eventcap, proto_eventcap);
    dissector_add(UDP_PORT_FILTER, global_eventcap_proto, eventcap_handle);
}

#define NO_STRINGS NULL
#define NO_MASK 0x0

void proto_register_eventcap()
{
    /* A header field is something you can search/filter on.
    *
    * We create a structure to register our fields. It consists of an
    * array of hf_register_info structures, each of which are of the format
    * {&(field id), {name, abbrev, type, display, strings, bitmask, blurb, HFILL}}.
    */
    static hf_register_info hf[] = {
        /* header fields */
        { &hf_nf2ec,
          { "Data", "nf2ec.data",                FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK,      "NetFPGA-1G Event Capture PDU",          HFILL }},

        { &hf_nf2ec_header,
          { "Header", "nf2ec.header",            FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK,      "NetFPGA-1G Event Capture Header",       HFILL }},

        { &hf_nf2ec_pad,
          { "Padding", "nf2ec.pad",              FT_UINT8,  BASE_DEC,  NO_STRINGS,       MASK_PAD,     "Padding",                        HFILL }},

        { &hf_nf2ec_version,
          { "Version", "nf2ec.ver",              FT_UINT8,  BASE_DEC,  NO_STRINGS,       MASK_VERSION, "Version",                        HFILL }},

        { &hf_nf2ec_num_events,
          { "# of Events", "nf2ec.num_events",   FT_UINT8,  BASE_DEC,  NO_STRINGS,       NO_MASK,      "# of Events",                    HFILL }},

        { &hf_nf2ec_seq,
          { "Seq #", "nf2ec.seq",                FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "Sequence #",                     HFILL }},

        { &hf_nf2ec_queue_size_words[0],
          { "CPU0  Words  ", "nf2ec.cpu0w",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU0 Size in 64-bit Words",      HFILL }},

        { &hf_nf2ec_queue_size_pkts[0],
          { "CPU0  Packets", "nf2ec.cpu0p",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU0 Size in Packets",           HFILL }},

        { &hf_nf2ec_queue_size_words[1],
          { "NF2C0 Words  ", "nf2ec.nf2c0w",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C0 Size in 64-bit Words",     HFILL }},

        { &hf_nf2ec_queue_size_pkts[1],
          { "NF2C0 Packets", "nf2ec.nf2c0p",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C0 Size in Packets",          HFILL }},

        { &hf_nf2ec_queue_size_words[2],
          { "CPU1  Words  ", "nf2ec.cpu1w",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU1 Size in 64-bit Words",      HFILL }},

        { &hf_nf2ec_queue_size_pkts[2],
          { "CPU1  Packets", "nf2ec.cpu1p",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU1 Size in Packets",           HFILL }},

        { &hf_nf2ec_queue_size_words[3],
          { "NF2C1 Words  ", "nf2ec.nf2c1w",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C1 Size in 64-bit Words",     HFILL }},

        { &hf_nf2ec_queue_size_pkts[3],
          { "NF2C1 Packets", "nf2ec.nf2c1p",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C1 Size in Packets",          HFILL }},

        { &hf_nf2ec_queue_size_words[4],
          { "CPU2  Words  ", "nf2ec.cpu2w",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU2 Size in 64-bit Words",      HFILL }},

        { &hf_nf2ec_queue_size_pkts[4],
          { "CPU2  Packets", "nf2ec.cpu2p",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU2 Size in Packets",           HFILL }},

        { &hf_nf2ec_queue_size_words[5],
          { "NF2C2 Words  ", "nf2ec.nf2c2w",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C2 Size in 64-bit Words",     HFILL }},

        { &hf_nf2ec_queue_size_pkts[5],
          { "NF2C2 Packets", "nf2ec.nf2c2p",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C2 Size in Packets",          HFILL }},

        { &hf_nf2ec_queue_size_words[6],
          { "CPU3  Words  ", "nf2ec.cpu3w",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU3 Size in 64-bit Words",      HFILL }},

        { &hf_nf2ec_queue_size_pkts[6],
          { "CPU3  Packets", "nf2ec.cpu3p",      FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "CPU3 Size in Packets",           HFILL }},

        { &hf_nf2ec_queue_size_words[7],
          { "NF2C3 Words  ", "nf2ec.nf2c3w",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C3 Size in 64-bit Words",     HFILL }},

        { &hf_nf2ec_queue_size_pkts[7],
          { "NF2C3 Packets", "nf2ec.nf2c3p",     FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,      "NF2C3 Size in Packets",          HFILL }},


        /* event type fields */
        { &hf_nf2ec_event,
          { "Event", "nf2ec.event",              FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK,      "Event",                          HFILL }},

        { &hf_nf2ec_type,
          { "Type", "nf2ec.type",                FT_UINT32, BASE_DEC,  VALS(names_type), MASK_TYPE,    "Event Type",                     HFILL }},

        /* note: this takes advantage that the type is 0, therefore the upper
           two bits in the timestamp will be 0 and can be safely included as part
           of the timestamp */
        { &hf_nf2ec_time_full,
          { "Timestamp", "nf2ec.ts",             FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK,      "Timestamp in units of 8ns",      HFILL }},

        { &hf_nf2ec_time_top,
          { "Timestamp Upper", "nf2ec.ts_top",   FT_UINT32, BASE_DEC,  NO_STRINGS,       MASK_TIME_TOP, "Upper Timestamp in units of 8ns", HFILL }},

        { &hf_nf2ec_time_btm,
          { "Timestamp Lower", "nf2ec.ts_btm",   FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK,       "Lower Timestamp in units of 8ns", HFILL }},

        { &hf_nf2ec_short_event,
          { "Event", "nf2ec.ev",                FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK,      "Short Event",                      HFILL }},

        { &hf_nf2ec_queue_id,
          { "Queue", "nf2ec.q",                  FT_UINT32, BASE_DEC,  VALS(names_queue_id), MASK_QUEUE_ID,  "Queue",                      HFILL }},

        { &hf_nf2ec_packet_len,
          { "Packet Length", "nf2ec.len",        FT_UINT32, BASE_DEC,  NO_STRINGS,       MASK_PACKET_LEN, "Packet Length (B)",           HFILL }},

        { &hf_nf2ec_time_lsb,
          { "Timestamp (LSB)", "nf2ec.ts_lsb",   FT_UINT32, BASE_DEC,  NO_STRINGS,       MASK_TIME_LSB,  "Timestamp (LSB) in untis of 8ns", HFILL }}
    };

    static gint *ett[] = {
        &ett_nf2ec,
        &ett_nf2ec_header,
        &ett_nf2ec_pad,
        &ett_nf2ec_version,
        &ett_nf2ec_num_events,
        &ett_nf2ec_seq,
        &ett_nf2ec_queue_size_words[0],
        &ett_nf2ec_queue_size_pkts[0],
        &ett_nf2ec_queue_size_words[1],
        &ett_nf2ec_queue_size_pkts[1],
        &ett_nf2ec_queue_size_words[2],
        &ett_nf2ec_queue_size_pkts[2],
        &ett_nf2ec_queue_size_words[3],
        &ett_nf2ec_queue_size_pkts[3],
        &ett_nf2ec_queue_size_words[4],
        &ett_nf2ec_queue_size_pkts[4],
        &ett_nf2ec_queue_size_words[5],
        &ett_nf2ec_queue_size_pkts[5],
        &ett_nf2ec_queue_size_words[6],
        &ett_nf2ec_queue_size_pkts[6],
        &ett_nf2ec_queue_size_words[7],
        &ett_nf2ec_queue_size_pkts[7],

        &ett_nf2ec_event,
        &ett_nf2ec_type,
        &ett_nf2ec_time_full,
        &ett_nf2ec_time_top,
        &ett_nf2ec_time_btm,

        &ett_nf2ec_short_event,
        &ett_nf2ec_queue_id,
        &ett_nf2ec_packet_len,
        &ett_nf2ec_time_lsb
    };

    proto_eventcap = proto_register_protocol( "NetFPGA Event Capture Protocol",
                                              "EVENTCAP",
                                              "nf2ec" ); /* abbreviation for filters */

    proto_register_field_array (proto_eventcap, hf, array_length (hf));
    proto_register_subtree_array (ett, array_length (ett));
    register_dissector("eventcap", dissect_eventcap, proto_eventcap);
}

/**
 * Adds "hf" to "tree" starting at "offset" into "tvb" and using "length"
 * bytes.  offset is incremented by length.
 */
static void add_child( proto_item* tree, gint hf, tvbuff_t *tvb, guint32* offset, guint32 len ) {
    proto_tree_add_item( tree, hf, tvb, *offset, len, FALSE );
    *offset += len;
}

/**
 * Adds "hf" to "tree" starting at "offset" into "tvb" and using "length" bytes.
 */
static void add_child_const( proto_item* tree, gint hf, tvbuff_t *tvb, guint32 offset, guint32 len ) {
    proto_tree_add_item( tree, hf, tvb, offset, len, FALSE );
}

static void
dissect_eventcap(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree)
{
    /* display our protocol text if the protocol column is visible */
    if (check_col(pinfo->cinfo, COL_PROTOCOL))
        col_set_str(pinfo->cinfo, COL_PROTOCOL, PROTO_TAG_EVENTCAP);

    /* Clear out stuff in the info column */
    if(check_col(pinfo->cinfo,COL_INFO)){
        col_clear(pinfo->cinfo,COL_INFO);
    }

    /* get some of the header fields' values for later use */
    guint8  ver = tvb_get_guint8( tvb, 0 ) & MASK_VERSION;
    guint32 seq = tvb_get_ntohl( tvb, 2 );
    guint32 ts_top = tvb_get_ntohl( tvb, 70 );
    guint32 ts_btm = tvb_get_ntohl( tvb, 74 );
    char*   str_ts = timestamp8ns_to_string( ts_top, ts_btm);

    /* clarify protocol name display with version, sequence number, and timestamp */
    if (check_col(pinfo->cinfo, COL_INFO)) {
        col_add_fstr( pinfo->cinfo, COL_INFO, "NetFPGA-1G Update v%u (seq=%u, time=%s)", ver, seq, str_ts );
    }

    if (tree) { /* we are being asked for details */
        proto_item *item        = NULL;
        proto_item *sub_item    = NULL;
        proto_tree *nf2ec_tree     = NULL;
        proto_tree *header_tree = NULL;
        guint32 offset = 0;

        /* consume the entire tvb for the eventcap packet, and add it to the tree */
        item = proto_tree_add_item(tree, proto_eventcap, tvb, 0, -1, FALSE);
        nf2ec_tree = proto_item_add_subtree(item, ett_nf2ec);
        header_tree = proto_item_add_subtree(item, ett_nf2ec);

        /* put the header in its own node as a child of the eventcap node */
        sub_item = proto_tree_add_item( nf2ec_tree, hf_nf2ec_header, tvb, offset, -1, FALSE );
        header_tree = proto_item_add_subtree(sub_item, ett_nf2ec_header);

        /* add the headers field as children of the header node */
        add_child_const( header_tree, hf_nf2ec_pad,     tvb, offset, 1 );
        add_child_const( header_tree, hf_nf2ec_version, tvb, offset, 1 );
        offset += 1;
        add_child( header_tree, hf_nf2ec_num_events,    tvb, &offset, 1 );
        add_child( header_tree, hf_nf2ec_seq,           tvb, &offset, 4 );
        guint8 i;
        for( i=0; i<8; i++ ) {
            add_child( header_tree, hf_nf2ec_queue_size_words[i], tvb, &offset, 4 );
            add_child( header_tree, hf_nf2ec_queue_size_pkts[i],  tvb, &offset, 4 );
        }

        /* add the timestamp (computed the string representation earlier) */
        proto_tree_add_string( header_tree, hf_nf2ec_time_full, tvb, offset, 8, str_ts );
        offset += 8;

        /** handle events (loop until out of bytes) */
        while( offset <= MAX_EC_SIZE - 4 ) {
            /* get the 2-bit type field */
            guint8 type = (tvb_get_guint8( tvb, offset ) & 0xC0) >> 6;

            if( type == TYPE_TIMESTAMP ) {
                if( offset > MAX_EC_SIZE - 8 )
                    break;

                ts_top = tvb_get_ntohl( tvb, offset );
                ts_btm = tvb_get_ntohl( tvb, offset+4 );
                str_ts = timestamp8ns_to_string( ts_top, ts_btm );
                proto_tree_add_string( nf2ec_tree, hf_nf2ec_short_event, tvb, offset, 8, event_to_string(0, 0, 0, str_ts) );
                offset += 8;
            }
            else {
                guint32 event_val = tvb_get_ntohl( tvb, offset );
                guint32 queue_id = (event_val & MASK_QUEUE_ID) >> 27;
                guint32 plen = (event_val & MASK_PACKET_LEN) >> 19;
                guint32 ts_btm_me = (ts_btm & ~MASK_TIME_LSB) | (event_val & MASK_TIME_LSB);
                str_ts = timestamp8ns_to_string( ts_top, ts_btm_me );
                proto_tree_add_string( nf2ec_tree, hf_nf2ec_short_event, tvb, offset, 8, event_to_string(type, queue_id, plen, str_ts) );
                offset += 4;
            }
        }
    }
}
