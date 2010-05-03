/* ****************************************************************************
 * $Id: nf2util.c 6008 2010-03-14 08:17:15Z grg $
 *
 * Module: nf2util.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for user mode programs
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#include <net/if.h>

#include <arpa/inet.h>

#include "nf2.h"
#include "nf2util.h"

#include "reg_defines.h"

#define MD5_LEN		4
#define MAX_STR_LEN	1024
#define MAX_DEV_LEN	16
#define MAX_VER_LEN     32

/* Function declarations */
static int readRegNet(struct nf2device *nf2, unsigned reg, unsigned *val);
static int readRegFile(struct nf2device *nf2, unsigned reg, unsigned *val);
static int writeRegNet(struct nf2device *nf2, unsigned reg, unsigned val);
static int writeRegFile(struct nf2device *nf2, unsigned reg, unsigned val);
static void readStr(struct nf2device *nf2, unsigned regStart, unsigned len, char *dst);
void prepDeviceInfo(struct nf2device *nf2);

/* Local variables */
unsigned cpci_version = -1;
unsigned cpci_revision = -1;
unsigned nf2_dev_id_module_version = -1;
unsigned nf2device_id = -1;
unsigned nf2_version = -1;
unsigned nf2_cpci_version = -1;
unsigned nf2_cpci_revision = -1;
char have_version_info = 0;
char virtex_programmed = 0;
char nf2_proj_name_v1[DEV_ID_PROJ_NAME_BYTE_LEN_V1] = "";
char nf2_proj_dir[DEV_ID_PROJ_DIR_BYTE_LEN] = "";
char nf2_proj_name[DEV_ID_PROJ_NAME_BYTE_LEN] = "";
char nf2_proj_desc[DEV_ID_PROJ_DESC_BYTE_LEN] = "";

char nf2device_info[DEVICE_INFO_STR_LEN] = "";
char nf2_version_err[DEVICE_INFO_STR_LEN] = "";

struct nf2device prev_dev;

/*
 * readReg - read a register
 */
int readReg(struct nf2device *nf2, unsigned reg, unsigned *val)
{
	if (nf2->net_iface)
	{
		return readRegNet(nf2, reg, val);
	}
	else
	{
		return readRegFile(nf2, reg, val);
	}
}

/*
 * readRegNet - read a register, using a network socket
 */
static int readRegNet(struct nf2device *nf2, unsigned reg, unsigned *val)
{
        struct ifreq ifreq;
	struct nf2reg nf2reg;
	int ret;

	nf2reg.reg = reg;

	/* Set up the ifreq structure */
	ifreq.ifr_data = (char *)&nf2reg;
        strncpy(ifreq.ifr_ifrn.ifrn_name, nf2->device_name, IFNAMSIZ);
        /*if (setsockopt(nf2->fd, SOL_SOCKET, SO_BINDTODEVICE,
                       (char *)&ifreq, sizeof(ifreq)) < 0) {
                perror("sendpacket: setting SO_BINDTODEVICE");
                return -1;
        } */

	/* Call the ioctl */
	if ((ret = ioctl(nf2->fd, SIOCREGREAD, &ifreq)) == 0)
	{
		*val = nf2reg.val;
		return 0;
	}
	else
	{
                perror("sendpacket: ioctl failed");
                return -1;
	}
}

/*
 * readRegFile - read a register, using a file descriptor
 */
static int readRegFile(struct nf2device *nf2, unsigned reg, unsigned *val)
{
        struct ifreq ifreq;
	struct nf2reg nf2reg;
	int ret;

	nf2reg.reg = reg;

	/* Call the ioctl */
	if ((ret = ioctl(nf2->fd, SIOCREGREAD, &nf2reg)) == 0)
	{
		*val = nf2reg.val;
		return 0;
	}
	else
	{
                perror("sendpacket: ioctl failed");
                return -1;
	}
}


/*
 * writeReg - write a register
 */
int writeReg(struct nf2device *nf2, unsigned reg, unsigned val)
{
	if (nf2->net_iface)
	{
		return writeRegNet(nf2, reg, val);
	}
	else
	{
		return writeRegFile(nf2, reg, val);
	}
}


/*
 * writeRegNet - write a register, using a network socket
 */
static int writeRegNet(struct nf2device *nf2, unsigned reg, unsigned val)
{
        struct ifreq ifreq;
	struct nf2reg nf2reg;
	int ret;

	nf2reg.reg = reg;
	nf2reg.val = val;

	/* Set up the ifreq structure */
	ifreq.ifr_data = (char *)&nf2reg;
        strncpy(ifreq.ifr_ifrn.ifrn_name, nf2->device_name, IFNAMSIZ);
        /*if (setsockopt(nf2->fd, SOL_SOCKET, SO_BINDTODEVICE,
                       (char *)&ifreq, sizeof(ifreq)) < 0) {
                perror("sendpacket: setting SO_BINDTODEVICE");
                return -1;
        } */

	/* Call the ioctl */
	if ((ret = ioctl(nf2->fd, SIOCREGWRITE, &ifreq)) == 0)
	{
		return 0;
	}
	else
	{
                perror("sendpacket: ioctl failed");
                return -1;
	}
}


/*
 * writeRegFile - write a register, using a file descriptor
 */
static int writeRegFile(struct nf2device *nf2, unsigned reg, unsigned val)
{
        struct ifreq ifreq;
	struct nf2reg nf2reg;
	int ret;

	nf2reg.reg = reg;
	nf2reg.val = val;

	/* Call the ioctl */
	if ((ret = ioctl(nf2->fd, SIOCREGWRITE, &nf2reg)) == 0)
	{
		return 0;
	}
	else
	{
                perror("sendpacket: ioctl failed");
                return -1;
	}
}

/*
 * Check the iface name to make sure we can find the interface
 */
int check_iface(struct nf2device *nf2)
{
	struct stat buf;
	char filename[PATHLEN];

	/* See if we can find the interface name as a network device */

	/* Test the length first of all */
	if (strlen(nf2->device_name) > IFNAMSIZ)
	{
		fprintf(stderr, "Interface name is too long: %s\n", nf2->device_name);
		return -1;
	}

	/* Check for /sys/class/net/iface_name */
	strcpy(filename, "/sys/class/net/");
	strcat(filename, nf2->device_name);
	if (stat(filename, &buf) == 0)
	{
		fprintf(stderr, "Found net device: %s\n", nf2->device_name);
		nf2->net_iface = 1;
		return 0;
	}

	/* Check for /dev/iface_name */
	strcpy(filename, "/dev/");
	strcat(filename, nf2->device_name);
	if (stat(filename, &buf) == 0)
	{
		fprintf(stderr, "Found dev device: %s\n", nf2->device_name);
		nf2->net_iface = 0;
		return 0;
	}

	fprintf(stderr, "Can't find device: %s\n", nf2->device_name);
	return -1;
}

/*
 * Open the descriptor associated with the device name
 */
int openDescriptor(struct nf2device *nf2)
{
        struct ifreq ifreq;
	char filename[PATHLEN];
	struct sockaddr_in address;
	int i;
	struct sockaddr_in *sin = (struct sockaddr_in *) &ifreq.ifr_addr;
	int found = 0;

	if (nf2->net_iface)
	{
		/* Open a network socket */
		nf2->fd = socket(AF_INET, SOCK_DGRAM, 0);
		if (nf2->fd == -1)
		{
                	perror("socket: creating socket");
                	return -1;
		}
		else
		{
			/* Root can bind to a network interface.
			   Non-root has to bind to a network address. */
			if (geteuid() == 0)
			{
				strncpy(ifreq.ifr_ifrn.ifrn_name, nf2->device_name, IFNAMSIZ);
				if (setsockopt(nf2->fd, SOL_SOCKET, SO_BINDTODEVICE,
					(char *)&ifreq, sizeof(ifreq)) < 0) {
					perror("setsockopt: setting SO_BINDTODEVICE");
					return -1;
				}

			}
		}
	}
	else
	{
		strcpy(filename, "/dev/");
		strcat(filename, nf2->device_name);
		nf2->fd = fileno(fopen(filename, "w+"));
		if (nf2->fd == -1)
		{
                	perror("fileno: creating descriptor");
                	return -1;
		}
	}

	return 0;
}

/*
 * Close the descriptor associated with the device name
 */
int closeDescriptor(struct nf2device *nf2)
{
        struct ifreq ifreq;
	char filename[PATHLEN];

	if (nf2->net_iface)
	{
		close(nf2->fd);
	}
	else
	{
		close(nf2->fd);
	}

	return 0;
}


/*
 *  Read the version info from the Virtex and CPCI
 */
void nf2_read_info(struct nf2device *nf2)
{
        int i;
	int md5_good_v1 = 1;
	int md5_good_v2 = 1;
	unsigned md5[MD5_LEN];
	unsigned cpci_id;
	unsigned nf2_cpci_id;

        // Copy the device info
        prev_dev = *nf2;

	// Read the CPCI version/revision
	readReg(nf2, CPCI_ID_REG, &cpci_id);
	cpci_version = cpci_id & 0xffffff;
	cpci_revision = cpci_id >> 24;
        have_version_info = 1;

        // Check if the Virtex is programmed
        virtex_programmed = isVirtexProgrammed(nf2);

        // Clear the Virtex-related variables
        nf2_dev_id_module_version = -1;
        nf2device_id = -1;
        nf2_version = -1;
        nf2_cpci_version = -1;
        nf2_cpci_revision = -1;
        nf2_proj_name_v1[0] = '\0';
        nf2_proj_dir[0] = '\0';
        nf2_proj_name[0] = '\0';
        nf2_proj_desc[0] = '\0';

	// Verify the MD5 checksum of the device ID block
	for  (i = 0; i < MD5_LEN; i++) {
		readReg(nf2, DEV_ID_MD5_0_REG + i * 4, &md5[i]);
	}

	md5_good_v1 &= md5[0] == DEV_ID_MD5_VALUE_V1_0;
	md5_good_v1 &= md5[1] == DEV_ID_MD5_VALUE_V1_1;
	md5_good_v1 &= md5[2] == DEV_ID_MD5_VALUE_V1_2;
	md5_good_v1 &= md5[3] == DEV_ID_MD5_VALUE_V1_3;

	md5_good_v2 &= md5[0] == DEV_ID_MD5_VALUE_V2_0;
	md5_good_v2 &= md5[1] == DEV_ID_MD5_VALUE_V2_1;
	md5_good_v2 &= md5[2] == DEV_ID_MD5_VALUE_V2_2;
	md5_good_v2 &= md5[3] == DEV_ID_MD5_VALUE_V2_3;

	// Process only if the MD5 sum is good
	if (md5_good_v1 || md5_good_v2) {
		// Read the version and revision
		readReg(nf2, DEV_ID_DEVICE_ID_REG, &nf2device_id);
		readReg(nf2, DEV_ID_VERSION_REG, &nf2_version);
		readReg(nf2, DEV_ID_CPCI_ID_REG, &nf2_cpci_id);
		nf2_cpci_version = nf2_cpci_id & 0xffffff;
		nf2_cpci_revision = nf2_cpci_id >> 24;
        }

	if (md5_good_v1) {
                nf2_dev_id_module_version = 1;
                readStr(nf2, DEV_ID_PROJ_DIR_0_REG, DEV_ID_PROJ_NAME_BYTE_LEN_V1, nf2_proj_name_v1);
	}

        if (md5_good_v2) {
                nf2_dev_id_module_version = 2;
                readStr(nf2, DEV_ID_PROJ_DIR_0_REG, DEV_ID_PROJ_DIR_BYTE_LEN, nf2_proj_dir);
                readStr(nf2, DEV_ID_PROJ_NAME_0_REG, DEV_ID_PROJ_NAME_BYTE_LEN, nf2_proj_name);
                readStr(nf2, DEV_ID_PROJ_DESC_0_REG, DEV_ID_PROJ_DESC_BYTE_LEN, nf2_proj_desc);
        }
}

/*
 * Read a string from the NetFPGA
 *
 * Ensure that the string is null-terminated
 *
 * Note: the length *must* be an integral number of words or the
 * final bytes will be truncated.
 */
static void readStr(struct nf2device *nf2, unsigned regStart, unsigned len, char *dst)
{
	int i;

        // Read the string
        for (i = 0; i < len / 4; i++)
        {
                readReg(nf2, regStart + i * 4, (unsigned *)(dst + i * 4));

                // Perform byte swapping if necessary
                *(unsigned *)(dst + i * 4) = ntohl(*(unsigned *)(dst + i * 4));
        }

        // Ensure that the string is null-terminated
        dst[(len / 4) * 4 - 1] = '\0';
        //dst[len - 1] = '\0';
}

/*
 * Get the CPCI version number
 */
unsigned getCPCIVersion(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return cpci_version;
}

/*
 * Get the CPCI revision number
 */
unsigned getCPCIRevision(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return cpci_revision;
}

/*
 * Get the device ID
 */
unsigned getDeviceID(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return nf2device_id;
}

/*
 * Get the device CPCI version
 */
unsigned getDeviceCPCIVersion(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return nf2_cpci_version;
}

/*
 * Get the device CPCI revision
 */
unsigned getDeviceCPCIRevision(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return nf2_cpci_revision;
}

/*
 * Get the device major version
 */
unsigned getDeviceMajor(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version > 1)
        return (nf2_version >> 16) & 0xff;
    else
        return nf2_version;
}

/*
 * Get the device minor version
 */
unsigned getDeviceMinor(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version > 1)
        return (nf2_version >> 8) & 0xff;
    else
        return 0;
}

/*
 * Get the device revision
 */
unsigned getDeviceRevision(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version > 1)
        return (nf2_version >> 0) & 0xff;
    else
        return 0;
}

/*
 * Get the device ID module version
 */
unsigned getDeviceIDModuleVersion(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    return nf2_dev_id_module_version;
}

/*
 * Get the project dir
 */
const char* getProjDir(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version == 2)
        return nf2_proj_dir;
    else
        return PROJ_UNKNOWN;
}

/*
 * Get the project name
 */
const char* getProjName(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version == 2)
        return nf2_proj_name;
    else if (nf2_dev_id_module_version == 1)
        return nf2_proj_name_v1;
    else
        return PROJ_UNKNOWN;
}

/*
 * Get the project description
 */
const char* getProjDesc(struct nf2device *nf2) {
    prepDeviceInfo(nf2);

    if (nf2_dev_id_module_version == 2)
        return nf2_proj_desc;
    else
        return PROJ_UNKNOWN;
}

/*
 * Print out a test string
 */
void printHello (struct nf2device *nf2, int *val)
{
  printf ("Hello world. Name=%s val=%d\n", nf2->device_name, *val);
  *val = 10;
}

/*
 * Get a textual string of the Device Information
 */
const char* getDeviceInfoStr(struct nf2device *nf2)
{
    char cpciVersionStr[MAX_STR_LEN];
    char deviceVersionStr[MAX_STR_LEN];

    prepDeviceInfo(nf2);

    snprintf(cpciVersionStr, MAX_STR_LEN,
            "CPCI Information\n"
            "----------------\n"
            "Version: %d (rev %d)\n",
            getCPCIVersion(nf2), getCPCIRevision(nf2));

    if (virtex_programmed) {
        if (getDeviceIDModuleVersion(nf2) != -1) {
            if (getDeviceIDModuleVersion(nf2) == 2) {
                snprintf(deviceVersionStr, MAX_STR_LEN,
                        "Device (Virtex) Information\n"
                        "---------------------------\n"
                        "Project directory: %s\n"
                        "Project name: %s\n"
                        "Project description: %s\n"
                        "\n"
                        "Device ID: %d\n"
                        "Version: %d.%d.%d\n"
                        "Built against CPCI version: %d (rev %d)\n",
                        getProjDir(nf2),
                        getProjName(nf2),
                        getProjDesc(nf2),
                        getDeviceID(nf2),
                        getDeviceMajor(nf2), getDeviceMinor(nf2), getDeviceRevision(nf2),
                        getDeviceCPCIVersion(nf2), getDeviceCPCIRevision(nf2)
                        );
            }
            else if (getDeviceIDModuleVersion(nf2) == 1) {
                snprintf(deviceVersionStr, MAX_STR_LEN,
                        "Device (Virtex) Information\n"
                        "---------------------------\n"
                        "Project name: %s\n"
                        "\n"
                        "Device ID: %d\n"
                        "Version: %d\n"
                        "Built against CPCI version: %d (rev %d)\n",
                        getProjName(nf2),
                        getDeviceID(nf2),
                        getDeviceMajor(nf2),
                        getDeviceCPCIVersion(nf2), getDeviceCPCIRevision(nf2)
                        );
            }
            else {
                snprintf(deviceVersionStr, MAX_STR_LEN,
                        "Uknown Device ID Module verions: %d\n",
                        getDeviceIDModuleVersion(nf2));
            }
        }
        else {
            snprintf(deviceVersionStr, MAX_STR_LEN,
                        "Device (Virtex) Information\n"
                        "---------------------------\n"
                        "Device info not found\n");
        }
    }
    else {
        snprintf(deviceVersionStr, MAX_STR_LEN,
                    "Device (Virtex) Information\n"
                    "---------------------------\n"
                    "Device not programmed\n");
    }

    snprintf(nf2device_info, DEVICE_INFO_STR_LEN, "%s\n%s\n",
        cpciVersionStr,
        deviceVersionStr);

    return nf2device_info;
}

/*
 * Check if the Virtex is programmed
 */
int isVirtexProgrammed(struct nf2device *nf2)
{
    unsigned progStatus;

    readReg(nf2, CPCI_REPROG_STATUS_REG, &progStatus);
    return (progStatus & 0x100) != 0;
}

/*
 * Check if a particular bitfile is downloaded and whether it's the correct version.
 */
int checkVirtexBitfile(struct nf2device *nf2, char *projDir,
    int minVerMajor, int minVerMinor, int minVerRev,
    int maxVerMajor, int maxVerMinor, int maxVerRev) {

    int minVer, maxVer, virtexVer;

    // Ensure that we've read the device info
    prepDeviceInfo(nf2);

    // Check if the Virtex is programmed
    if (!virtex_programmed) {
        sprintf(nf2_version_err, "Error: Virtex is not programmed");
        return 0;
    }

    // Calculate the version numbers as necessary
    minVer = 0;
    if (minVerMajor != VERSION_ANY) {
        minVer += minVerMajor;
    }
    minVer <<= 8;
    if (minVerMinor != VERSION_ANY) {
        minVer += minVerMinor;
    }
    minVer <<= 8;
    if (minVerRev != VERSION_ANY) {
        minVer += minVerRev;
    }

    maxVer = 0;
    maxVer += (maxVerMajor != VERSION_ANY) ? maxVerMajor : 255;
    maxVer <<= 8;
    maxVer += (maxVerMinor != VERSION_ANY) ? maxVerMinor : 255;
    maxVer <<= 8;
    maxVer += (maxVerRev != VERSION_ANY) ? maxVerRev : 255;

    virtexVer = (getDeviceMajor(nf2) << 16) |
                 (getDeviceMinor(nf2) << 8) |
                 getDeviceRevision(nf2);

    // Check the device name
    const char *virtexProjDir;
    const char *virtexProjName;
    if (nf2_dev_id_module_version >= 2) {
        virtexProjDir = getProjDir(nf2);
        virtexProjName = getProjName(nf2);
    }
    else {
        virtexProjDir = getProjName(nf2);
        virtexProjName = PROJ_UNKNOWN;
    }

    if (strcmp(virtexProjDir, projDir) != 0) {
        sprintf(nf2_version_err, "Error: Incorrect bitfile loaded. Found '%s' (%s), expecting: '%s'",
                virtexProjDir, virtexProjName, projDir);
        return 0;
    }

    // Check the version number
    if (virtexVer < minVer || virtexVer > maxVer) {
        // Work out equality etc
        int hasMin = (minVerMajor != VERSION_ANY) ||
                     (minVerMinor != VERSION_ANY) ||
                     (minVerRev != VERSION_ANY);
        int hasMax = (maxVerMajor != VERSION_ANY) ||
                     (maxVerMinor != VERSION_ANY) ||
                     (maxVerRev != VERSION_ANY);
        int verMajorEqual = ((minVerMajor != VERSION_ANY) ? minVerMajor : -1) ==
                            ((maxVerMajor != VERSION_ANY) ? maxVerMajor : -1);
        int verMinorEqual = ((minVerMinor != VERSION_ANY) ? minVerMinor : -1) ==
                            ((maxVerMinor != VERSION_ANY) ? maxVerMinor : -1);
        int verRevEqual = ((minVerRev != VERSION_ANY) ? minVerRev : -1) ==
                          ((maxVerRev != VERSION_ANY) ? maxVerRev : -1);
        int minMaxEqual = verMajorEqual && verMinorEqual && verRevEqual;

        // Generate strings for min and max
        char minStr[MAX_VER_LEN];
        if (minVerRev != VERSION_ANY)
            sprintf(minStr, "%d.%d.%d", minVerMajor, minVerMinor, minVerRev);
        else if (minVerMinor != VERSION_ANY)
            sprintf(minStr, "%d.%d.x", minVerMajor, minVerMinor);
        else if (minVerMajor != VERSION_ANY)
            sprintf(minStr, "%d.x.x", minVerMajor);
        else
            sprintf(minStr, "x.x.x");

        char maxStr[MAX_VER_LEN];
        if (maxVerRev != VERSION_ANY)
            sprintf(maxStr, "%d.%d.%d", maxVerMajor, maxVerMinor, maxVerRev);
        else if (maxVerMinor != VERSION_ANY)
            sprintf(maxStr, "%d.%d.x", maxVerMajor, maxVerMinor);
        else if (maxVerMajor != VERSION_ANY)
            sprintf(maxStr, "%d.x.x", maxVerMajor);
        else
            sprintf(maxStr, "x.x.x");

        char virtexVerStr[MAX_VER_LEN];
        sprintf(virtexVerStr, "%d.%d.%d",
                getDeviceMajor(nf2),
                getDeviceMinor(nf2),
                getDeviceRevision(nf2));

        if (minMaxEqual)
            sprintf(nf2_version_err,
                    "Error: Incorrect version for bitfile: '%s' (%s).  Expecting: %s   Active: %s",
                    projDir, virtexProjName, minStr, virtexVerStr);
        else if (hasMin && hasMax)
            sprintf(nf2_version_err,
                    "Error: Incorrect version for bitfile: '%s' (%s).  Expecting: %s -- %s   Active: %s",
                    projDir, virtexProjName, minStr, maxStr, virtexVerStr);
        else if (hasMin)
            sprintf(nf2_version_err,
                    "Error: Incorrect version for bitfile: '%s' (%s).  Expecting: > %s   Active: %s",
                    projDir, virtexProjName, minStr, virtexVerStr);
        else
            sprintf(nf2_version_err,
                    "Error: Incorrect version for bitfile: '%s' (%s).  Expecting: < %s   Active: %s",
                    projDir, virtexProjName, maxStr, virtexVerStr);
        return 0;
    }

    sprintf(nf2_version_err, "GOOD");
    return 1;
}

/*
 * Get the error string corresponding to the most recent call to
 * checkVirtexBitfile
 */
const char *getVirtexBitfileErr() {
    return nf2_version_err;
}

/*
 * Ensure that the device info has been read
 */
void prepDeviceInfo(struct nf2device *nf2) {
    if (!have_version_info || prev_dev.fd != nf2->fd) {
        nf2_read_info(nf2);
    }
}
