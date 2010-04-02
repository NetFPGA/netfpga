/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_reg.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_reg.h
 * Project: NetFPGA selftest
 * Description: Register selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_REG_H
#define _SELFTEST_REG_H	1

#define REG_TEST_SIZE    8

void regResetContinuous(void);
int regShowStatusContinuous(void);
void regStopContinuous(void);
int regGetResult(void);

#endif
