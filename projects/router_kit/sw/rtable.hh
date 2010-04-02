//-----------------------------------------------------------------------------
// File:  rtable.hh
// Date:  Sun Apr 29 16:38:20 PDT 2007
// Author: Martin Casado
//
// Description:
//
// Encapsulate routing table
//
//-----------------------------------------------------------------------------

#ifndef RTABLE_HH
#define RTABLE_HH

#include "netinet++/ipaddr.hh"

#include <iostream>
#include <string>
#include <vector>

namespace rk
{

//-----------------------------------------------------------------------------
struct ipv4_entry
{
    ipaddr      dest;
    ipaddr      gw;
    ipaddr      mask;

    std::string dev;

    ipv4_entry(const ipaddr&, const ipaddr&, const ipaddr&, const
            std::string&);
    ipv4_entry(const ipv4_entry&);

    bool operator == (const ipv4_entry&) const;
};
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
class rtable
{
    std::vector<ipv4_entry> table;

    public:
    rtable();

    void   add(const ipv4_entry&);
    size_t size() const ;
    bool   contains(const ipv4_entry&);
    void   clear();

    const ipv4_entry& operator[](int i) const;

    rtable& operator = (const rtable&);
    bool    operator == (const rtable&) const;
    bool    operator != (const rtable&) const;
};
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
inline
rtable::rtable()
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
rtable::add(const ipv4_entry& entry)
{
    table.push_back(entry);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
void
rtable::clear()
{
    table.clear();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
size_t
rtable::size() const
{
    return table.size();
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
rtable::contains(const ipv4_entry& entry)
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
rtable&
rtable::operator = (const rtable& rt)
{
    table.clear();
    table = rt.table;
    return (*this);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
rtable::operator == (const rtable& rt) const
{
    return (table == rt.table);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
rtable::operator != (const rtable& rt) const
{
    return (table != rt.table);
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipv4_entry::ipv4_entry(const ipaddr& dest_, const ipaddr& gw_, const ipaddr&
        mask_, const std::string& dev_ ):
    dest(dest_), gw(gw_), mask(mask_), dev(dev_)
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
ipv4_entry::ipv4_entry(const ipv4_entry& in):
    dest(in.dest), gw(in.gw), mask(in.mask), dev(in.dev)
{
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
bool
ipv4_entry::operator == (const ipv4_entry& in) const
{
    return ((dest == in.dest) &&
            (gw   == in.gw)  &&
            (mask == in.mask) &&
            (dev  == in.dev));
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
const ipv4_entry&
rtable::operator[](int i) const
{
    return table[i];
}
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os, const ipv4_entry& entry)
{
    os << entry.dest << " : " << entry.gw <<  " : " << entry.mask << " : "
       << entry.dev;

    return os;
}
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
inline
std::ostream&
operator <<(std::ostream& os,rtable& rt)
{
    for ( size_t i = 0; i < rt.size(); ++i){
        os <<  (rt[i]) << std::endl;
    }
    return os;
}
//-----------------------------------------------------------------------------

} // -- namespace rk

#endif // -- RTABLE_HH
