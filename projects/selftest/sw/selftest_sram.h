/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_sram.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_sram.h
 * Project: NetFPGA selftest
 * Description: Dram selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_SRAM_H
#define _SELFTEST_SRAM_H	1

/* Size of SRAM in megabytes (per bank) */
#define SRAM_MEMSIZE  2

void sramResetContinuous(void);
int sramShowStatusContinuous(void);
void sramStopContinuous(void);
int sramGetResult(void);

#endif
