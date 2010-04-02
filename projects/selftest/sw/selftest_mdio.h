/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_mdio.h 5974 2010-03-06 07:12:53Z grg $
 *
 * Module: selftest_mdio.h
 * Project: NetFPGA selftest
 * Description: MDIO selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_MDIO_H
#define _SELFTEST_MDIO_H	1

#define MDIO_READ_RETRIES 20

void mdioResetContinuous(void);
int mdioShowStatusContinuous(void);
void mdioStopContinuous(void);
int mdioGetResult(void);

#endif
