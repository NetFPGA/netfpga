/* ****************************************************************************
 * $Id: nf2util.h 2719 2007-08-10 21:40:24Z derickso $
 *
 * Module: nf2util.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Header file for kernel driver
 *
 * Change history:
 *
 */

#ifndef _NF2UTIL_H
#define _NF2UTIL_H	1

#define PATHLEN		80
#define DEVICE_STR_LEN 120


/*
 * Structure to represent an nf2 device to a user mode programs
 */
struct nf2device {
	char *device_name;
	int fd;
	int net_iface;
};
typedef struct nf2device nf2device;

/* Function declarations */

int readReg(struct nf2device *nf2, unsigned reg, unsigned *val);
int writeReg(struct nf2device *nf2, unsigned reg, unsigned val);
int check_iface(struct nf2device *nf2);
int openDescriptor(struct nf2device *nf2);
int closeDescriptor(struct nf2device *nf2);
void read_info(struct nf2device *nf2);

extern unsigned nf2_device_id;
extern unsigned nf2_revision;
extern char nf2_device_str[DEVICE_STR_LEN];

#endif
