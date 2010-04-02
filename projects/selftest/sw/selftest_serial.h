/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_serial.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest_serial.h
 * Project: NetFPGA selftest
 * Description: SATA selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_SERIAL_H
#define _SELFTEST_SERIAL_H	1

void serialResetContinuous(void);
int serialShowStatusContinuous(void);
void serialStopContinuous(void);
int serialGetResult(void);

#endif
