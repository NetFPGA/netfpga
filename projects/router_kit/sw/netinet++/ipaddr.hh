//-----------------------------------------------------------------------------
// File:  ipaddr.hh
// Date:  Tue Dec 10 22:54:28 PST 2002
// Authors: Martin Casado, Norman Franke
//
// Description:
//
// Yet another ip address class
//
//-----------------------------------------------------------------------------

#ifndef ipaddr_HH
#define ipaddr_HH

#include <string>
#include <cstdio>
#include <cassert>
#include <cstring>
#include <iostream>
#include <stdexcept>

extern "C"
{
#include <netdb.h>
#include <inttypes.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
}


struct ipaddr
{
    uint32_t addr;

    // ------------------------------------------------------------------------
    // Constructors
    // ------------------------------------------------------------------------

    ipaddr();
    ipaddr(uint32_t);
    ipaddr(const ipaddr&);
    ipaddr(const char*);
    ipaddr(const in_addr&);
    ipaddr(const uint8_t*);
    ipaddr(const sockaddr&);
    ipaddr(const std::string&);

    // ------------------------------------------------------------------------
    //  Byte Ordering
    // ------------------------------------------------------------------------

    void change_byte_ordering();

    // ------------------------------------------------------------------------
    // String Representation
    // ------------------------------------------------------------------------

    void        fill_string(char* in) const;
    void        fill_string(std::string& in) const;
    std::string string() const;
    const char* c_string() const;
    const char* c_str   () const;

    // ------------------------------------------------------------------------
    // Casting Operators
    // ------------------------------------------------------------------------

    operator bool        () const;
    operator const char* () const;
    operator uint32_t    () const;
    operator std::string () const;

    // ------------------------------------------------------------------------
    // Binary Operators
    // ------------------------------------------------------------------------

    bool    operator !  () const;
    ipaddr  operator ~  () const;
    ipaddr  operator &  (const ipaddr&) const;
    ipaddr  operator &  (uint32_t) const;
    ipaddr& operator &= (const ipaddr&);
    ipaddr& operator &= (uint32_t);
    ipaddr  operator |  (const ipaddr&) const;
    ipaddr  operator |  (uint32_t) const;
    ipaddr& operator |= (const ipaddr&);
    ipaddr& operator |= (uint32_t);

    // ------------------------------------------------------------------------
    // Mathematical operators
    // ------------------------------------------------------------------------

    ipaddr operator ++ ();
    ipaddr operator ++ (int);
    ipaddr operator -- ();
    ipaddr operator += (int);
    ipaddr operator +  (int) const;

    int    operator -  (const ipaddr &) const;
    ipaddr operator -  (int) const;

    // ------------------------------------------------------------------------
    // Assignment
    // ------------------------------------------------------------------------

    ipaddr& operator = (const ipaddr&);
    ipaddr& operator = (const std::string &);
    ipaddr& operator = (uint32_t);

    // ------------------------------------------------------------------------
    // Comparison Operators
    // ------------------------------------------------------------------------

    bool operator == (const ipaddr&) const;
    bool operator == (uint32_t) const;
    bool operator != (const ipaddr&) const;
    bool operator != (uint32_t) const;
    bool operator <  (uint32_t) const;
    bool operator <  (const ipaddr&) const;
    bool operator <= (uint32_t) const;
    bool operator <= (const ipaddr&) const;
    bool operator >  (uint32_t) const;
    bool operator >  (const ipaddr&) const;
    bool operator >= (uint32_t) const;
    bool operator >= (const ipaddr&) const;

}__attribute__ ((__packed__)); // -- struct ipaddr

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr()
{
    addr = 0;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const char* addr_in)
{
    struct hostent* hp = 0;

    // -- REQUIRES
    assert(addr_in);

    if ((hp = ::gethostbyname(addr_in)) == 0)
    {
        // -- Quick hack b/c I don't know how to get swig and C++
        //    exceptions to cooperate
        addr = 0;
        return;
        // throw std::runtime_error("could not convert string to address");
    }

    // -- CHECK
    assert(hp->h_length == 4);

    memcpy(&addr,hp->h_addr,hp->h_length);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const ipaddr& in)
{
    addr = in.addr;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const std::string& addr_in)
{
    struct hostent* hp = 0;

    if ((hp = ::gethostbyname(addr_in.c_str())) == 0)
    {
        perror("gethostbyname");
        throw std::runtime_error("could not convert string to address");
    }

    // -- CHECK
    assert(hp->h_length == 4);

    memcpy(&addr,hp->h_addr,hp->h_length);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const sockaddr& addr_in)
{
    addr = *((uint32_t*)&addr_in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const in_addr& addr_in)
{
    addr = *((uint32_t*)&addr_in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(const uint8_t* addr_in)
{
    // -- REQUIRES
    assert(addr_in);

    addr = *((uint32_t*)&addr_in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::ipaddr(uint32_t addr_in)
{
    addr = htonl(addr_in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
ipaddr::change_byte_ordering()
{
    addr = htonl(addr);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
ipaddr::fill_string(std::string& in) const
{
    in = this->string();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
ipaddr::fill_string(char* in) const
{
    // -- REQUIRES
    assert(in);

    std::string ret;
    ret = this->string();

    ::strncpy(in, ret.c_str(), INET_ADDRSTRLEN);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::string
ipaddr::string() const
{
    char  buf[INET_ADDRSTRLEN];

    if(! ::inet_ntop(AF_INET, ((struct in_addr*)&addr), buf, INET_ADDRSTRLEN ))
    { throw std::runtime_error("unable to convert ipaddr to string"); }

    return std::string(buf);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
const
char*
ipaddr::c_string() const
{
    static char ip_buf[16];
    const char* tmp = 0;

    if((tmp = ::inet_ntoa(*((struct in_addr*)&addr))) == 0)
    {
        perror("inet_ntoa");
        throw std::runtime_error("could not convert address to string");
    }

    ::strncpy(ip_buf,tmp,16);
    return ip_buf;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
const
char*
ipaddr::c_str() const
{
    char  buf[INET_ADDRSTRLEN];

    if(! ::inet_ntop(AF_INET, ((struct in_addr*)&addr), buf, INET_ADDRSTRLEN ))
    { throw std::runtime_error("unable to convert ipaddr to string"); }

    return std::string(buf).c_str();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::operator std::string() const
{
    char* tmp = 0;

    if((tmp = ::inet_ntoa(*((struct in_addr*)&addr))) == 0)
    {
        perror("inet_ntoa");
        throw std::runtime_error("could not convert address to string");
    }

    return std::string(tmp);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::operator bool () const
{
    return !(addr == 0);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::operator const char* () const
{
    return (const char*)c_string();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr::operator uint32_t () const
{
    return addr;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator ~ () const
{
    return ipaddr(htonl(~addr));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator & (const ipaddr& in) const
{
    return ipaddr(htonl(addr&in.addr));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator & (uint32_t in) const
{
    return ipaddr(ntohl(addr) & in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator &= (const ipaddr& in)
{
    addr &= in.addr;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator &= (uint32_t in)
{
    addr &= in;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator | (const ipaddr& in) const
{
    return ipaddr(htonl(addr|in.addr));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator | (uint32_t in) const
{
    return ipaddr(htonl(addr | in));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator |= (const ipaddr& in)
{
    addr |= in.addr;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator |= (uint32_t in)
{
    addr |= in;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator = (const std::string& in)
{
    struct hostent* hp = 0;

    if ((hp = ::gethostbyname(in.c_str())) == 0)
    {
        perror("gethostbyname");
        throw std::runtime_error("could not convert string to address");
    }

    // -- CHECK
    assert(hp->h_length == 4);

    memcpy(&addr,hp->h_addr,hp->h_length);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator = (const ipaddr& in)
{
    addr = in.addr;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr&
ipaddr::operator = (uint32_t in)
{
    addr = in;
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator == (const ipaddr& in) const
{
    return addr == in.addr;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator == (uint32_t in) const
{
    return addr == in;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator != (const ipaddr& in) const
{
    return addr != in.addr;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator != (uint32_t in) const
{
    return addr != in;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator ++ ()
{
    addr = htonl(htonl(addr) + 1);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator ++ (int)
{
    ipaddr ret = *this;
    ++(*this);
    return ret;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator -- ()
{
    addr = htonl(htonl(addr) - 1);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator += (int in)
{
    addr = htonl(htonl(addr) + in);
    return *this;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator + (int in) const
{
    return ipaddr(htonl(addr) + in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
int
ipaddr::operator - (const ipaddr &in) const
{
    return htonl(addr) - htonl(in.addr);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipaddr
ipaddr::operator - (int in) const
{
    return ipaddr(htonl(addr) - in);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator < (uint32_t in) const
{
    return htonl(addr) < in;
}

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator < (const ipaddr& in) const
{
    return htonl(addr) < htonl(in.addr);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator <= (uint32_t in) const
{
    return htonl(addr) <= in;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator <= (const ipaddr& in) const
{
    return htonl(addr) <= htonl(in.addr);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator >  (uint32_t in) const
{
    return htonl(addr) > in;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator >  (const ipaddr& in) const
{
    return htonl(addr) > htonl(in.addr);
}
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator >= (uint32_t in) const
{
    return htonl(addr) >= in;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator ! () const
{
    return addr == 0x00000000;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipaddr::operator >= (const ipaddr& in) const
{
    return htonl(addr) >= htonl(in.addr);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os,const ipaddr& addr)
{
    os << addr.string();
    return os;
}
//-----------------------------------------------------------------------------

#endif  // -- ipaddr_HH
