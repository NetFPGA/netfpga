/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_clk.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_clk.h
 * Project: NetFPGA selftest
 * Description: Clock selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_CLK_H
#define _SELFTEST_CLK_H	1

void measureClocks(void);

void clkResetContinuous(void);
int clkShowStatusContinuous(void);
void clkStopContinuous(void);
int clkGetResult(void);

#endif
