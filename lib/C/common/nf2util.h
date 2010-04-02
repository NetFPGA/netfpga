/* ****************************************************************************
 * $Id: nf2util.h 6008 2010-03-14 08:17:15Z grg $
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

#define PATHLEN		          80
#define DEVICE_STR_LEN           100
#define DEVICE_INFO_STR_LEN     1024

#define PROJ_UNKNOWN    "Unknown"

#define VERSION_ANY             -1

/*
 * Structure to represent an nf2 device to a user mode programs
 */
struct nf2device {
	char *device_name;
	int fd;
	int net_iface;
};

/* Function declarations */

int readReg(struct nf2device *nf2, unsigned reg, unsigned *val);
int writeReg(struct nf2device *nf2, unsigned reg, unsigned val);
int check_iface(struct nf2device *nf2);
int openDescriptor(struct nf2device *nf2);
int closeDescriptor(struct nf2device *nf2);
void nf2_read_info(struct nf2device *nf2);
void printHello (struct nf2device *nf2, int *val);
unsigned getCPCIVersion(struct nf2device *nf2);
unsigned getCPCIRevsion(struct nf2device *nf2);
unsigned getDeviceCPCIVersion(struct nf2device *nf2);
unsigned getDeviceCPCIRevsion(struct nf2device *nf2);
unsigned getDeviceID(struct nf2device *nf2);
unsigned getDeviceMajor(struct nf2device *nf2);
unsigned getDeviceMinor(struct nf2device *nf2);
unsigned getDeviceRevision(struct nf2device *nf2);
unsigned getDeviceIDModuleVersion(struct nf2device *nf2);
const char* getProjDir(struct nf2device *nf2);
const char* getProjName(struct nf2device *nf2);
const char* getProjDesc(struct nf2device *nf2);
const char* getDeviceInfoStr(struct nf2device *nf2);
int isVirtexProgrammed(struct nf2device *nf2);
int checkVirtexBitfile(struct nf2device *nf2, char *projDir,
    int minVerMajor, int minVerMinor, int minVerRev,
    int maxVerMajor, int maxVerMinor, int maxVerRev);
const char *getVirtexBitfileErr();

#endif
