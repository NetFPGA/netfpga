/* ****************************************************************************
 * $Id: util.h 3546 2008-04-03 00:12:27Z grg $
 *
 * Module: nf2util.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Header file for kernel driver
 *
 * Change history:
 *
 */

#ifndef _UTIL_H
#define _UTIL_H	1

#define PATHLEN		80

uint8_t *parseip(char *str);
uint8_t *parsemac(char *str);
uint16_t cksm(uint16_t length, uint32_t buf[]);

#endif
