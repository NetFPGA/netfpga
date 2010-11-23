/**
 * Filename: packet-pwospf.c
 * Author:   David Underhill
 * Updated:  2008-05-19
 * Purpose:  define a Wireshark 0.99.x-1.x dissector for the PWOSPF protocol
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

#define PROTO_TAG_PWOSPF	"PWOSPF"

/* Wireshark ID of the PWOSPF protocol */
static int proto_pwospf = -1;
static dissector_handle_t pwospf_handle;
static void dissect_pwospf(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree);

/* traffic will arrive with IP protocol 89 */
#define IP_PROTO_FILTER "ip.proto"
static int global_pwospf_proto = 89;

#define TYPE_HELLO  1
#define TYPE_UPDATE 4

/** names to bind to various values in the type field */
static const value_string names_type[] = {
    { TYPE_HELLO,  "HELLO" },
    { TYPE_UPDATE, "LS UPDATE" },
    { 0, NULL }
};

/* The hf_* variables are used to hold the IDs of our header fields; they are
 * set when we call proto_register_field_array() in proto_register_pwospf()
 */
static gint hf_pw                  = -1;
static gint hf_pw_header           = -1;
static gint hf_pw_version          = -1;
static gint hf_pw_type             = -1;
static gint hf_pw_plen             = -1;
static gint hf_pw_my_rtr_id        = -1;
static gint hf_pw_my_rtr_id_str    = -1;
static gint hf_pw_area_id          = -1;
static gint hf_pw_checksum         = -1;
static gint hf_pw_checksum_str     = -1;
static gint hf_pw_auth_type        = -1;
static gint hf_pw_auth             = -1;

static gint hf_pw_hello            = -1;
static gint hf_pw_mask             = -1;
static gint hf_pw_hello_interval   = -1;
static gint hf_pw_pad              = -1;

static gint hf_pw_update           = -1;
static gint hf_pw_seq              = -1;
static gint hf_pw_ttl              = -1;
static gint hf_pw_num_adverts      = -1;

static gint hf_pw_advert           = -1;
static gint hf_pw_subnet           = -1;
/* mask already covered above */
static gint hf_pw_rtr_id           = -1;
static gint hf_pw_rtr_id_str       = -1;
static gint hf_pw_subnet_and_mask  = -1;

/* These are the ids of the subtrees that we may be creating */
static gint ett_pw                 = -1;
static gint ett_pw_header          = -1;
static gint ett_pw_version         = -1;
static gint ett_pw_type            = -1;
static gint ett_pw_plen            = -1;
static gint ett_pw_my_rtr_id       = -1;
static gint ett_pw_my_rtr_id_str   = -1;
static gint ett_pw_area_id         = -1;
static gint ett_pw_checksum        = -1;
static gint ett_pw_checksum_str    = -1;
static gint ett_pw_auth_type       = -1;
static gint ett_pw_auth            = -1;

static gint ett_pw_hello           = -1;
static gint ett_pw_mask            = -1;
static gint ett_pw_hello_interval  = -1;
static gint ett_pw_pad             = -1;

static gint ett_pw_update          = -1;
static gint ett_pw_seq             = -1;
static gint ett_pw_ttl             = -1;
static gint ett_pw_num_adverts     = -1;

static gint ett_pw_advert          = -1;
static gint ett_pw_subnet          = -1;
static gint ett_pw_rtr_id          = -1;
static gint ett_pw_rtr_id_str      = -1;
static gint ett_pw_subnet_and_mask = -1;

void proto_reg_handoff_pwospf()
{
    pwospf_handle = create_dissector_handle(dissect_pwospf, proto_pwospf);
    dissector_add(IP_PROTO_FILTER, global_pwospf_proto, pwospf_handle);
}

#define NO_STRINGS NULL
#define NO_MASK 0x0

void proto_register_pwospf()
{
    /* A header field is something you can search/filter on.
    *
    * We create a structure to register our fields. It consists of an
    * array of hf_register_info structures, each of which are of the format
    * {&(field id), {name, abbrev, type, display, strings, bitmask, blurb, HFILL}}.
    */
    static hf_register_info hf[] = {
        /* header fields */
        { &hf_pw,
          { "Data", "pw.data",                FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK, "PWOSPF PDU",          HFILL }},

        { &hf_pw_header,
          { "Header", "pw.header",            FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK, "PWOSPF Header",       HFILL }},

        { &hf_pw_version,
          { "Version", "pw.ver",              FT_UINT8,  BASE_DEC,  NO_STRINGS,       NO_MASK, "PWOSPF Version",      HFILL }},

        { &hf_pw_type,
          { "Type", "pw.type",                FT_UINT8,  BASE_DEC,  VALS(names_type), NO_MASK, "Type",                HFILL }},

        { &hf_pw_plen,
          { "Length", "pw.plen",              FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Packet Length",       HFILL }},

        { &hf_pw_my_rtr_id,
          { "Router ID", "pw.src_rtr_id",     FT_IPv4,   BASE_NONE, NO_STRINGS,       NO_MASK, "Source Router ID",    HFILL }},

        { &hf_pw_my_rtr_id_str,
          { "Router ID", "pw.src_rtr",        FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK, "Source Router ID",    HFILL }},

        { &hf_pw_area_id,
          { "Area ID", "pw.area",             FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK, "Area ID",             HFILL }},

        { &hf_pw_checksum,
          { "Checksum", "pw.checksum_val",    FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Checksum",            HFILL }},

        { &hf_pw_checksum_str,
          { "Checksum", "pw.checksum",        FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK, "Checksum",            HFILL }},

        { &hf_pw_auth_type,
          { "Auth Type", "pw.auth_type",      FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Authorization Type",  HFILL }},

        { &hf_pw_auth,
          { "Authentication", "pw.auth",      FT_UINT64, BASE_DEC,  NO_STRINGS,       NO_MASK, "Authentication",      HFILL }},


        /* hello fields */
        { &hf_pw_hello,
          { "Hello", "pw.hello",              FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK, "Hello Packet",        HFILL }},

        { &hf_pw_mask,
          { "Mask", "pw.mask",                FT_IPv4,   BASE_NONE, NO_STRINGS,       NO_MASK, "Network Mask",        HFILL }},

        { &hf_pw_hello_interval,
          { "Interval", "pw.hint",            FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Hello Interval (s)",  HFILL }},

        { &hf_pw_pad,
          { "Padding", "pw.pad",              FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Padding",             HFILL }},


        /* update fields */
        { &hf_pw_update,
          { "LS Update", "pw.update",         FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK, "Link-State Update",   HFILL }},

        { &hf_pw_seq,
          { "Sequence #", "pw.seq",           FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Sequence #",          HFILL }},

        { &hf_pw_ttl,
          { "TTL", "pw.ttl",                  FT_UINT16, BASE_DEC,  NO_STRINGS,       NO_MASK, "Time to Live",        HFILL }},

        { &hf_pw_num_adverts,
          { "# of Adverts", "pw.num_adverts", FT_UINT32, BASE_DEC,  NO_STRINGS,       NO_MASK, "# of Advertisements", HFILL }},


        /* advertisement fields */
        { &hf_pw_advert,
          { "Advert", "pw.advert",            FT_NONE,   BASE_NONE, NO_STRINGS,       NO_MASK, "Advertisement",       HFILL }},

        { &hf_pw_subnet,
          { "Subnet", "pw.subnet",            FT_IPv4,   BASE_NONE, NO_STRINGS,       NO_MASK, "Subnet",              HFILL }},

        { &hf_pw_rtr_id,
          { "Router ID", "pw.rtr_id",         FT_IPv4,   BASE_NONE, NO_STRINGS,       NO_MASK, "Neighbor Router ID",  HFILL }},

        { &hf_pw_rtr_id_str,
          { "Router ID", "pw.rtr",            FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK, "Neighbor Router ID",  HFILL }},

        { &hf_pw_subnet_and_mask,
          { "Subnet/Mask", "mw.sm",           FT_STRING, BASE_NONE, NO_STRINGS,       NO_MASK, "Advert Subnet/Mask",  HFILL }}
    };

    static gint *ett[] = {
        &ett_pw,
        &ett_pw_header,
        &ett_pw_version,
        &ett_pw_type,
        &ett_pw_plen,
        &ett_pw_my_rtr_id,
        &ett_pw_my_rtr_id_str,
        &ett_pw_area_id,
        &ett_pw_checksum,
        &ett_pw_checksum_str,
        &ett_pw_auth_type,
        &ett_pw_auth,

        &ett_pw_hello,
        &ett_pw_mask,
        &ett_pw_hello_interval,
        &ett_pw_pad,

        &ett_pw_update,
        &ett_pw_seq,
        &ett_pw_ttl,
        &ett_pw_num_adverts,

        &ett_pw_advert,
        &ett_pw_subnet,
        &ett_pw_rtr_id,
        &ett_pw_rtr_id_str,
        &ett_pw_subnet_and_mask
    };

    proto_pwospf = proto_register_protocol( "PWOSPF Protocol",
                                             "PWOSPF",
                                             "pw" ); /* abbreviation for filters */

    proto_register_field_array (proto_pwospf, hf, array_length (hf));
    proto_register_subtree_array (ett, array_length (ett));
    register_dissector("pwospf", dissect_pwospf, proto_pwospf);
}

/**
 * Adds "hf" to "tree" starting at "offset" into "tvb" and using "length"
 * bytes.  offset is incremented by length.
 */
static void add_child( proto_item* tree, gint hf, tvbuff_t *tvb, guint32* offset, guint32 len ) {
    proto_tree_add_item( tree, hf, tvb, *offset, len, FALSE );
    *offset += len;
}

/** IP address type */
typedef guint32 addr_ip_t;
typedef guint8  byte;

/* helper methods for computing the PWOSPF checksum */
#include "pwospf.c"

/* helper methods for converting IPs and Subnet/Mask pairs into strings */
#include "to_string.c"

static void
dissect_pwospf(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree)
{
    /* display our protocol text if the protocol column is visible */
    if (check_col(pinfo->cinfo, COL_PROTOCOL))
        col_set_str(pinfo->cinfo, COL_PROTOCOL, PROTO_TAG_PWOSPF);

    /* Clear out stuff in the info column */
    if(check_col(pinfo->cinfo,COL_INFO)){
        col_clear(pinfo->cinfo,COL_INFO);
    }

    /* get some of the header fields' values for later use */
    guint8 type = tvb_get_guint8( tvb, 1 );
    guint16 plen = tvb_get_ntohs( tvb, 2 );
    guint32 src_rtr_id = tvb_get_ntohl( tvb, 4 );
    guint32 area_id = tvb_get_ntohl( tvb, 8 );

    /* check the checksum */
    pwospf_hdr_t* hdr = (pwospf_hdr_t*)tvb_get_ptr( tvb, 0, plen );
    guint16 checksum = hdr->checksum;
    guint8 checksum_ok = ( checksum == checksum_pwospf( hdr ) );

    /* clarify protocol name display with type */
    if (check_col(pinfo->cinfo, COL_INFO)) {
        char str_ip[STRLEN_IP];
        ip_to_string( str_ip, src_rtr_id );

        col_add_fstr( pinfo->cinfo, COL_INFO, "%s <- %s (Area=%u)",
                      val_to_str(type, names_type, "Unknown Type:0x%02x"), str_ip, area_id );
    }

    if (tree) { /* we are being asked for details */
        proto_item *item        = NULL;
        proto_item *sub_item    = NULL;
        proto_tree *pw_tree     = NULL;
        proto_tree *header_tree = NULL;
        proto_tree *hello_tree  = NULL;
        proto_tree *update_tree = NULL;
        proto_tree *advert_tree = NULL;
        guint32 offset = 0;
        guint32 num_adverts;

        /* consume the entire tvb for the pwospf packet, and add it to the tree */
        item = proto_tree_add_item(tree, proto_pwospf, tvb, 0, -1, FALSE);
        pw_tree = proto_item_add_subtree(item, ett_pw);
        header_tree = proto_item_add_subtree(item, ett_pw);

        /* put the header in its own node as a child of the pwospf node */
        sub_item = proto_tree_add_item( pw_tree, hf_pw_header, tvb, offset, -1, FALSE );
        header_tree = proto_item_add_subtree(sub_item, ett_pw_header);

        /* add the headers field as children of the header node */
        add_child( header_tree, hf_pw_version,   tvb, &offset, 1 );
        add_child( header_tree, hf_pw_type,      tvb, &offset, 1 );
        add_child( header_tree, hf_pw_plen,      tvb, &offset, 2 );


        /* add source router ip */
        char str_ip[STRLEN_IP];
        ip_to_string( str_ip, tvb_get_ntohl( tvb, offset ) );
        proto_tree_add_string( header_tree, hf_pw_my_rtr_id_str, tvb, offset, 4, str_ip );
        offset += 4;

        add_child( header_tree, hf_pw_area_id,   tvb, &offset, 4 );

#if 1
        char str_checksum[32];
        if( checksum_ok )
            snprintf( str_checksum, 32, "%0X (correct)", checksum );
        else
            snprintf( str_checksum, 32, "%0X (incorrect, expected %0X)",
                      checksum, hdr->checksum );

        proto_tree_add_string( header_tree, hf_pw_checksum_str, tvb, offset, 2, str_checksum );
        offset += 2;
#else
        add_child( header_tree, hf_pw_checksum,  tvb, &offset, 2 );
#endif

        add_child( header_tree, hf_pw_auth_type, tvb, &offset, 2 );
        add_child( header_tree, hf_pw_auth,      tvb, &offset, 8 );

        /** handle the type-specific fields for hellos */
        if( type == TYPE_HELLO ) {
            /* put the hello header in its own node as a child of the pwospf node */
            sub_item = proto_tree_add_item( pw_tree, hf_pw_hello, tvb, offset, -1, FALSE );
            hello_tree = proto_item_add_subtree(sub_item, ett_pw_hello);

            add_child( hello_tree, hf_pw_mask,           tvb, &offset, 4 );
            add_child( hello_tree, hf_pw_hello_interval, tvb, &offset, 2 );
            add_child( hello_tree, hf_pw_pad,            tvb, &offset, 2 );
        }
        else if( type == TYPE_UPDATE ) {
            /* put the update header in its own node as a child of the pwospf node */
            sub_item = proto_tree_add_item( pw_tree, hf_pw_update, tvb, offset, -1, FALSE );
            update_tree = proto_item_add_subtree(sub_item, ett_pw_update);

            add_child( update_tree, hf_pw_seq,         tvb, &offset, 2 );
            add_child( update_tree, hf_pw_ttl,         tvb, &offset, 2 );
            add_child( update_tree, hf_pw_num_adverts, tvb, &offset, 4 );

            /* handle any adverts */
            num_adverts = tvb_get_ntohl( tvb, 28 );
            while( num_adverts > 0 ) {
                num_adverts -= 1;

                /* put each advert header in its own node as a child of the update node */
                sub_item = proto_tree_add_item( update_tree, hf_pw_advert, tvb, offset, -1, FALSE );
                advert_tree = proto_item_add_subtree(sub_item, ett_pw_advert);

                /* add subnet + mask as one field */
                guint32 subnet = tvb_get_ntohl( tvb, offset );
                guint32 mask   = tvb_get_ntohl( tvb, offset+4 );
                char str_subnet[STRLEN_SUBNET];
                subnet_to_string( str_subnet, subnet, mask );
                proto_tree_add_string( advert_tree, hf_pw_subnet_and_mask, tvb, offset, 4, str_subnet );

                /* add neighbor router ip */
                ip_to_string( str_ip, tvb_get_ntohl( tvb, offset+8 ) );
                proto_tree_add_string( advert_tree, hf_pw_rtr_id_str, tvb, offset+8, 4, str_ip );
                offset += 12;
            }
        }
    }
}
