/*
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Glen Gibb <grg@stanford.edu>
 *
 * We are making the NetFPGA tools and associated documentation (Software)
 * available for public use and benefit with the expectation that others will
 * use, modify and enhance the Software and contribute those enhancements back
 * to the community. However, since we would like to make the Software
 * available for broadest use, with as few restrictions as possible permission
 * is hereby granted, free of charge, to any person obtaining a copy of this
 * Software) to deal in the Software under the copyrights without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any derivatives
 * without specific, written prior permission.
 */

#ifndef _NF2UTIL_H
#define _NF2UTIL_H	1

#define PATHLEN		          80
#define DEVICE_STR_LEN           100
#define DEVICE_INFO_STR_LEN     1024
#define MAX_IPADDR_LEN          32

#define PROJ_UNKNOWN    "Unknown"

#define VERSION_ANY             -1

/*
 * Structure to represent an nf2 device to a user mode programs
 */
struct nf2device {
	char *device_name;
	int fd;
	int net_iface;
        char server_ip_addr[MAX_IPADDR_LEN];
        int server_port_num;
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
