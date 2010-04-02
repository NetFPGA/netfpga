/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_phy.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_phy.h
 * Project: NetFPGA selftest
 * Description: PHY selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_PHY_H
#define _SELFTEST_PHY_H	1

void phyResetContinuous(void);
int phyShowStatusContinuous(void);
void phyStopContinuous(void);
int phyGetResult(void);

#endif
