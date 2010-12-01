#ifndef _NF2_DOWNLOAD_H
#define _NF2_DOWNLOAD_H

int bytes_sent;
char *log_file_name;
FILE *log_file;
char *bin_file_name;
FILE *bin_file;
u_int verbose;
u_int cpci_reprog;
u_int prog_addr;
u_int ignore_dev_info;
u_int intr_enable;

#define READ_BUFFER_SIZE 4096
#define SUCCESS 0
#define FAILURE 1

#define CPCI_PROGRAMMING_DATA    0x100
#define CPCI_PROGRAMMING_STATUS  0x104
#define CPCI_PROGRAMMING_CONTROL 0x108
#define CPCI_ERROR               0x010
#define CPCI_ID	                 0x000
#define CPCI_CTRL                0x008


#define START_PROGRAMMING        0x00000001
#define DISABLE_RESET            0x00000100

#define VIRTEX_PROGRAM_CTRL_ADDR        0x0440000
#define VIRTEX_PROGRAM_RAM_BASE_ADDR    0x0480000

#define CPCI_BIN_SIZE            166980

#define VIRTEX_BIN_SIZE_V2_0     1448740
#define VIRTEX_BIN_SIZE_V2_1     2377668

// Minimum and maximum known versions of the CPCI
#define CPCI_MIN_VER             1
#define CPCI_MAX_VER             4


void BeginCodeDownload(char *codefile_name);
void InitGlobals();
void FatalError();
void StripHeader(FILE *code_file);
void DownloadCode(FILE *code_file);
void DownloadVirtexCodeBlock (u_char *code_data, int code_data_size);
void DownloadCPCICodeBlock (u_char *code_data, int code_data_size);
void ResetDevice(void);
void VerifyDevInfo(void);
void NF2_WR32(u_int addr, u_int data);
u_int NF2_RD32(u_int addr);
void processArgs (int argc, char **argv );
void usage ();


#endif
