/**
 * Filename: to_string.c
 * Purpose: define methods which convert non-string data to strings
 */

#define STRLEN_IP 20
/** convert an 32-bit IPv4 address in host-byte order to a string */
void ip_to_string( char* buf, addr_ip_t ip ) {
    byte* bytes;

    if( ip == 0xE0000005 /* 224.0.0.5 */ ) {
        snprintf( buf, STRLEN_IP, "ROUTER-OSPF-IP" );
        return;
    }

    if( ip == 0 ) {
        snprintf( buf, STRLEN_IP, "No Connected Router" );
        return;
    }

    bytes = (byte*)&ip;

    snprintf( buf, STRLEN_IP, "%u.%u.%u.%u",
              bytes[3],
              bytes[2],
              bytes[1],
              bytes[0] );
}

/**
 * counts the number of bits in x with the value 1.
 * Based on Hacker's Delight (2003) by Henry S. Warren, Jr.
 */
uint32_t ones( register guint32 x ) {
  x -= ((x >> 1) & 0x55555555);
  x = (((x >> 2) & 0x33333333) + (x & 0x33333333));
  x = (((x >> 4) + x) & 0x0f0f0f0f);
  x += (x >> 8);
  x += (x >> 16);

  return( x & 0x0000003f );
}

#define STRLEN_SUBNET 19
/**
 * convert 32-bit IPv4 subnet and mask address into a succint subnet/mask
 * string representation
 */
void subnet_to_string( char* buf, addr_ip_t subnet, addr_ip_t mask ) {
    guint32 num_ones;
    byte* bytes;

    num_ones = ones(mask);
    bytes = (byte*)&subnet;

    if( num_ones == 0 && subnet == 0 )
        snprintf( buf, STRLEN_SUBNET, "<catch-all>" );
    else if( num_ones <= 8 )
        snprintf( buf, STRLEN_SUBNET, "%u/%u",
                  bytes[3], num_ones );
    else if( num_ones <= 16 )
        snprintf( buf, STRLEN_SUBNET, "%u.%u/%u",
                  bytes[3], bytes[2], num_ones );
    else if( num_ones <= 24 )
        snprintf( buf, STRLEN_SUBNET, "%u.%u.%u/%u",
                  bytes[3], bytes[2], bytes[1], num_ones );
    else
        snprintf( buf, STRLEN_SUBNET, "%u.%u.%u.%u/%u",
                  bytes[3], bytes[2], bytes[1], bytes[0], num_ones );
}
