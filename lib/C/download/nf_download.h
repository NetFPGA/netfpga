/*-
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
