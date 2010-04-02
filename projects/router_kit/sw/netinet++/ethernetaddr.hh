//----------------------------------------------------------------------------
// File: ethernetaddr.hh
// Date: Sat Apr 27 17:30:45 PDT 2002
// Author: Martin Casado
//
// Description:
//
// Encapsulate and ethernet address so we can convert, copy.. etc.
//
//     +-----+-----+---------------------------+
//     | I/G | U/L |     46 bits address       |
//     +-----+-----+---------------------------+
//
//     I/G bit indicates whether the MAC address is of unicast or
//     of multicast.
//
//     U/L bit indicates whether the MAC address is universal or private.
//     The rest of 46 bits field is used for frame  filtering.
//
//     References:
//     http://cell-relay.indiana.edu/mhonarc/mpls/1997-Mar/msg00031.html
//     http://www.iana.org/assignments/ethernet-numbers
//
// ----------------------------------------------------------------------------
//
//    Copyright 2003. The Regents of the University of California.
//    All rights reserved.
//
//    This work was produced at the University of California, Lawrence Livermore
//    National Laboratory (UC LLNL) under contract no. W-7405-ENG-48 (Contract
//    48) between the U.S. Department of Energy (DOE) and The Regents of the
//    University of California (University) for the operation of UC LLNL.
//    Copyright is reserved to the University for purposes of controlled
//    dissemination, commercialization through formal licensing, or other
//    disposition under terms of Contract 48; DOE policies, regulations and
//    orders; and U.S. statutes. The rights of the Federal Government are
//    reserved under Contract 48 subject to the restrictions agreed upon by the
//    DOE and University as allowed under DOE Acquisition Letter 91-7.
//
//    DISCLAIMER
//    This software was prepared as an account of work sponsored by an
//    agency of the United States Government. Neither the United States
//    Government nor the University of California nor any of their employees,
//    makes any warranty, express or implied, or assumes any liability or
//    responsibility for the accuracy, completeness, or usefulness of any
//    information, apparatus, product, or process disclosed, or represents that
//    its use would not infringe protectedly-owned rights. Reference herein to any
//    specific commercial products, process, or service by trade name, trademark,
//    manufacturer, or otherwise, does not necessarily constitute or imply its
//    endorsement, recommendation, or favoring by the United States Government or
//    the University of California. The views and opinions of authors expressed
//    herein do not necessarily represent those of the United States
//    Government or the University of California, and shall not be used for
//    advertising or product endorsement purposes.
//
//
//-----------------------------------------------------------------------------


#ifndef ETHERNETADDR_HH__
#define ETHERNETADDR_HH__

#include <stdexcept>
#include <iostream>
#include <cassert>
#include <cstring>
#include <string>

extern "C"
{
#include <netinet/in.h>
#include <netinet/ether.h>
#include <stdint.h>
}


inline
unsigned long long htonll(unsigned long long n)
{
#if __BYTE_ORDER == __BIG_ENDIAN
  return n;
#else
  return (((unsigned long long)htonl(n)) << 32) + htonl(n >> 32);
#endif
}

inline
unsigned long long ntohll(unsigned long long n)
{
#if __BYTE_ORDER == __BIG_ENDIAN
  return n;
#else
  return (((unsigned long long)htonl(n)) << 32) + htonl(n >> 32);
#endif
}

//-----------------------------------------------------------------------------
//                             struct ethernetaddr
//-----------------------------------------------------------------------------

static const uint8_t ethbroadcast[] = "\xff\xff\xff\xff\xff\xff";

//-----------------------------------------------------------------------------
struct ethernetaddr
{
    //-------------------------------------------------------------------------
    //-------------------------------------------------------------------------
    static const  unsigned int   LEN =   6;


    //-------------------------------------------------------------------------
    //-------------------------------------------------------------------------
    uint8_t     octet[ethernetaddr::LEN];

    //-------------------------------------------------------------------------
    // Constructors/Detructor
    //-------------------------------------------------------------------------
    ethernetaddr();
    ethernetaddr(const  char*);
    ethernetaddr(uint64_t  id);
    ethernetaddr(const std::string&);
    ethernetaddr(const ethernetaddr&);

    // ------------------------------------------------------------------------
    // String Representation
    // ------------------------------------------------------------------------

    std::string string() const;
    const char* c_string() const;

    uint64_t    as_long() const;

    //-------------------------------------------------------------------------
    // Overloaded casting operator
    //-------------------------------------------------------------------------
    operator const bool    () const;
    operator const uint8_t*() const;
    operator const uint16_t*() const;
    operator const struct ethernetaddr*() const;

    //-------------------------------------------------------------------------
    // Overloaded assignment operator
    //-------------------------------------------------------------------------
    ethernetaddr& operator=(const ethernetaddr&  octet);
    ethernetaddr& operator=(const char*          text);
    ethernetaddr& operator=(uint64_t               id);

    // ------------------------------------------------------------------------
    // Comparison Operators
    // ------------------------------------------------------------------------

    bool operator == (const ethernetaddr&) const;
    bool operator != (const ethernetaddr&) const;
    bool operator <  (const ethernetaddr&) const;
    bool operator <= (const ethernetaddr&) const;
    bool operator >  (const ethernetaddr&) const;
    bool operator >= (const ethernetaddr&) const;

    //-------------------------------------------------------------------------
    // Non-Const Member Methods
    //-------------------------------------------------------------------------

    void set_octet(const uint8_t* oct);

    //-------------------------------------------------------------------------
    // Method: private(..)
    //
    // Check whether the private bit is set
    //-------------------------------------------------------------------------
    bool is_private() const;

    bool is_init() const;

    //-------------------------------------------------------------------------
    // Method: is_multicast(..)
    //
    // Check whether the multicast bit is set
    //-------------------------------------------------------------------------
    bool is_multicast() const;

    bool is_broadcast() const;

    bool is_zero() const;

}__attribute__ ((__packed__));
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::ethernetaddr()
{
    memset(octet,0,LEN);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::ethernetaddr(const ethernetaddr& addr_in)
{
    ::memcpy(octet,addr_in.octet,LEN);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::ethernetaddr(uint64_t id)
{
    if( (id & 0xff000000000000ULL) != 0)
    {
        std::cerr << " ethernetaddr::operator=(uint64_t) warning, value "
            << "larger then 48 bits, truncating" << std::endl;
    }

    id = htonll(id);

#if __BYTE_ORDER == __BIG_ENDIAN
    ::memcpy(octet, &id, LEN);
#else
    ::memcpy(octet, ((uint8_t*)&id) + 2, LEN);
#endif
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::ethernetaddr(const char* text)
{
    // -- REQUIRES
    assert(octet != 0);

    struct ether_addr* e_addr;
    e_addr = ::ether_aton(text);
    if(e_addr == 0)
    { ::memset(octet, 0, LEN);; }
    else
    { ::memcpy(octet, e_addr, LEN); }
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::ethernetaddr(const std::string& text)
{
    // -- REQUIRES
    assert(octet != 0);

    struct ether_addr* e_addr;
    e_addr = ::ether_aton(text.c_str());
    if(e_addr == 0)
    { ::memset(octet, 0, LEN);; }
    ::memcpy(octet, e_addr, LEN);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr&
ethernetaddr::operator=(const ethernetaddr& addr_in)
{
    ::memcpy(octet,addr_in.octet,LEN);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr&
ethernetaddr::operator=(uint64_t               id)
{
    if( (id & 0xff0000000000ULL) != 0)
    {
        std::cerr << " ethernetaddr::operator=(uint64_t) warning, value "
                  << "larger then 48 bits, truncating" << std::endl;
    }
    ::memcpy(octet, &id, LEN);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::is_init() const
{
    return
        (*((uint32_t*)octet) != 0) &&
        (*(((uint16_t*)octet)+2) != 0) ;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr&
ethernetaddr::operator=(const char* addr_in)
{
    ::memcpy(octet,::ether_aton(addr_in),LEN);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator==(const ethernetaddr& addr_in) const
{
    for(unsigned int i=0 ; i < LEN ; i++) {
        if(octet[i] != addr_in.octet[i])
        { return false; }
    }
    return true;
}
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator!=(const ethernetaddr& addr_in) const
{
    for(unsigned int i=0;i<LEN;i++)
        if(octet[i] != addr_in.octet[i])
            return true;
    return false;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator <  (const ethernetaddr& in) const
{
    return ::memcmp(in.octet, octet, LEN) < 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator <=  (const ethernetaddr& in) const
{
    return ::memcmp(in.octet, octet, LEN) <= 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator >  (const ethernetaddr& in) const
{
    return ::memcmp(in.octet, octet, LEN) > 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::operator >=  (const ethernetaddr& in) const
{
    return ::memcmp(in.octet, octet, LEN) >= 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
ethernetaddr::set_octet(const uint8_t* oct)
{
    ::memcpy(octet,oct,LEN);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::operator const bool    () const
{
    static const uint64_t zero = 0;
    return ::memcmp(octet, &zero, LEN) != 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::operator const struct ethernetaddr*() const
{
    return reinterpret_cast<const ethernetaddr*>(octet);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::operator const uint8_t*() const
{
    return reinterpret_cast<const uint8_t*>(octet);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ethernetaddr::operator const uint16_t*() const
{
    return reinterpret_cast<const uint16_t*>(octet);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::string
ethernetaddr::string() const
{
    return std::string(::ether_ntoa(reinterpret_cast<const ether_addr*>(octet)));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
uint64_t
ethernetaddr::as_long() const
{
    uint64_t id = *((uint64_t*)octet);
    return (ntohll(id)) >> 16;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
const char*
ethernetaddr::c_string() const
{
    return ::ether_ntoa(reinterpret_cast<const ether_addr*>(octet));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool ethernetaddr::is_private() const
{
    return((0x40&octet[0]) != 0);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool ethernetaddr::is_multicast() const
{
    return((0x80&octet[0]) != 0);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool ethernetaddr::is_broadcast() const
{
    // yeah ... close enough :)
    return( *((uint32_t*)octet) == 0xffffffff);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ethernetaddr::is_zero() const
{
    return ((*(uint32_t*)octet) == 0) && ((*(uint16_t*)(octet+4)) == 0);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os,const ethernetaddr& addr_in)
{
    os << addr_in.c_string();
    return os;
}
//-----------------------------------------------------------------------------

#endif   // __ETHERNETADDR_HH__
