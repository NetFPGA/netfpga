/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_dram.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_dram.h
 * Project: NetFPGA selftest
 * Description: Dram selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_DRAM_H
#define _SELFTEST_DRAM_H	1

/* Size of DRAM in megabytes */
#define DRAM_MEMSIZE  64

void dramResetContinuous(void);
int dramShowStatusContinuous(void);
void dramStopContinuous(void);
int dramGetResult(void);

#endif
