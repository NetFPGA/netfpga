/* ****************************************************************************
 *
 * Module: nf2_export.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Header file with exported functions for kernel driver
 *
 * Change history:
 *
 */

#ifndef _NF2_EXPORT_H
#define _NF2_EXPORT_H	1

#ifdef __KERNEL__

#include <linux/sockios.h>

/*
 * Functions
 */

int nf2k_reg_read(struct net_device *dev, unsigned int addr, void* data);
int nf2k_reg_write(struct net_device *dev, unsigned int addr, void* data);

#endif	/* __KERNEL__ */

#endif	/* _NF2_EXPORT_H */
