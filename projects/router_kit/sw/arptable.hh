//-----------------------------------------------------------------------------
// File: arptable.hh
// Date: Sun Apr 29 16:50:18 PDT 2007
// Author: Martin Casado
//
// Description:
//
// ARP table
//
//-----------------------------------------------------------------------------

#ifndef ARPTABLE_HH
#define ARPTABLE_HH

#include "netinet++/ipaddr.hh"
#include "netinet++/ethernetaddr.hh"


#include <iostream>
#include <string>
#include <vector>

namespace rk
{

//-----------------------------------------------------------------------------
struct arp_entry
{
    ipaddr ip;
    ethernetaddr etha;
    std::string  dev;

    arp_entry(const ipaddr& ip_, const ethernetaddr& etha_,
              const std::string& str);
    arp_entry(const arp_entry&);

    bool operator == (const arp_entry&) const;
};
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
class arptable
{
    std::vector<arp_entry> table;

    public:
    arptable();

    void   add(const arp_entry&);
    size_t size() const;
    bool   contains(const arp_entry&);
    void   clear();

    const arp_entry& operator[](int i) const;

    arptable& operator = (const  arptable&);
    bool      operator == (const arptable&) const;
    bool      operator != (const arptable&) const;
};
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
arptable::arptable()
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
arptable::add(const arp_entry& entry)
{
    table.push_back(entry);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
arptable::clear()
{
    table.clear();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
size_t
arptable::size() const
{
    return table.size();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
arptable::contains(const arp_entry& entry)
{
    for(size_t i = 0; i < table.size(); ++i){
        if(table[i] == entry){
            return true;
        }
    }
    return false;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
arptable&
arptable::operator = (const arptable& rt)
{
    table.clear();
    table = rt.table;
    return (*this);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
arptable::operator == (const arptable& rt) const
{
    return (table == rt.table);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
arptable::operator != (const arptable& rt) const
{
    return (table != rt.table);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
arp_entry::arp_entry(const ipaddr& ip_, const ethernetaddr& etha_,
                     const std::string& dev_ ):
    ip(ip_), etha(etha_), dev(dev_)
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
arp_entry::arp_entry(const arp_entry& in):
    ip(in.ip), etha(in.etha), dev(in.dev)
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
arp_entry::operator == (const arp_entry& in) const
{
    return ((ip   == in.ip)   &&
            (etha == in.etha) &&
            (dev  == in.dev));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
const arp_entry&
arptable::operator[](int i) const
{
    return table[i];
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os, const arp_entry& entry)
{
    os << entry.ip << " : " << entry.etha <<  " : " << entry.dev;

    return os;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os, arptable& at)
{
    for ( size_t i = 0; i < at.size(); ++i){
        os <<  (at[i]) << std::endl;
    }
    return os;
}
//-----------------------------------------------------------------------------

} // -- namespace rk

#endif  // -- ARPTABLE_HH
