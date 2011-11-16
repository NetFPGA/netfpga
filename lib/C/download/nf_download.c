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

/*
 * This program reads a Xilinx .bin or .bit file and downloads it to the
 * Virtex 2 Pro or Spartan on a NetFPGA board.
 *
 * Usage: ./nf_download <code filename>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
/*
#include <sys/time.h>
#include <sys/resource.h>
#include <unistd.h>
*/
#include "nf_download.h"
#include "../common/nf2.h"
#include "../common/nf2util.h"
#include "../common/reg_defines.h"
#include "../reg_lib/reg_proxy.h"

#include <net/if.h>

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;

/*
  Checks for commandline args, intializes globals, then  begins code download.
*/
int main(int argc, char **argv) {

   nf2.device_name = DEFAULT_IFACE;

   processArgs(argc, argv);

   if (check_iface(&nf2))
   {
	   exit(1);
   }
   if (openDescriptor(&nf2))
   {
      exit(1);
   }

   if (strncmp(log_file_name, "stdout",6)) {

      if ((log_file = fopen(log_file_name, "w")) == NULL) {
	 printf("Error: unable to open logfile %s for writing.\n",
		log_file_name);
	 exit(1);
      }
   }
   else
      log_file = stdout;

   InitGlobals();

   BeginCodeDownload(bin_file_name);

   if (!cpci_reprog)
      ResetDevice();

   /* reset the PHYs */
   NF2_WR32(MDIO_0_CONTROL_REG, 0x8000);
   NF2_WR32(MDIO_1_CONTROL_REG, 0x8000);
   NF2_WR32(MDIO_2_CONTROL_REG, 0x8000);
   NF2_WR32(MDIO_3_CONTROL_REG, 0x8000);

   /* wait until the resets have been completed */
   usleep(100);

   if (intr_enable)
   {
      /* PHY interrupt mask off for link status change */
      NF2_WR32(MDIO_0_INTERRUPT_MASK_REG, 0xfffd);
      NF2_WR32(MDIO_1_INTERRUPT_MASK_REG, 0xfffd);
      NF2_WR32(MDIO_2_INTERRUPT_MASK_REG, 0xfffd);
      NF2_WR32(MDIO_3_INTERRUPT_MASK_REG, 0xfffd);
   }

   VerifyDevInfo();

   fclose(log_file);

   closeDescriptor(&nf2);

   return SUCCESS;
}

/*
  Initializes the global variables this code uses.
*/
void InitGlobals() {
  bytes_sent = 0;
}


/*
  Starts the code download process.  First opens the file containing the code to
  download.  Loops to do a single iteration on the state machine.  state is tracked
  via the global variable "serverState".  This loop continues until we error and exit,
  or the end state is reached.
*/
void BeginCodeDownload(char *codefile_name) {

  FILE *codefile;
  if ((codefile = fopen(codefile_name, "r")) == NULL) {
    fprintf(log_file, "Failed to open %s.\n", codefile_name);
    FatalError(); //exit
  }

  StripHeader(codefile);
  DownloadCode(codefile);

  fclose(codefile);
}


/*
 * Strip the header off a bin file
 *
 * Does so by reading past the header
 */
void StripHeader(FILE *code_file) {
   int code_header_size;
   unsigned char * code_header;

   int header_len;

   /* Malloc memory for the header */
   code_header = (unsigned char *) malloc(sizeof(unsigned char) * READ_BUFFER_SIZE);

   /* Read the first few bytes */
   code_header_size = fread(code_header, sizeof(unsigned char), 2, code_file);

   /* Check to see if we're dealing with a header or not */
   if (code_header_size && (code_header[0] != 0xff || code_header[1] != 0xff)) {
      header_len = code_header[0] << 8 | code_header[1];

      /* Read the header and skip a field */
      code_header_size = fread(code_header, sizeof(unsigned char), header_len + 2 + 1 + 2, code_file);

      /* Read the ncd file name */
      header_len = code_header[header_len + 2 + 1] << 8 | code_header[header_len + 2 + 1 + 1];
      code_header_size = fread(code_header, sizeof(unsigned char), header_len + 1 + 2, code_file);
      printf("Bit file built from: %s\n", code_header);

      /* Read the part name */
      header_len = code_header[header_len + 1] << 8 | code_header[header_len + 1 + 1];
      code_header_size = fread(code_header, sizeof(unsigned char), header_len + 1 + 2, code_file);
      printf("Part: %s\n", code_header);

      /* Read the date */
      header_len = code_header[header_len + 1] << 8 | code_header[header_len + 1 + 1];
      code_header_size = fread(code_header, sizeof(unsigned char), header_len + 1 + 2, code_file);
      printf("Date: %s\n", code_header);

      /* Read the time */
      header_len = code_header[header_len + 1] << 8 | code_header[header_len + 1 + 1];
      code_header_size = fread(code_header, sizeof(unsigned char), header_len + 1 + 4, code_file);
      printf("Time: %s\n", code_header);
   }
   else {
      rewind(code_file);
   }

   /* Free the code_header variable */
   free(code_header);
}

/*
   Download the codefile by writing it to the programming register in CPCI.
*/
void DownloadCode(FILE *code_file) {

   u_int result;
   u_int version;
   int code_data_size;
   unsigned char * code_data;
   u_int retries;
   int bytes_expected;

   /*
    * Identify what version of the board we are running
    */
   version = NF2_RD32(CPCI_ID);
   version &= 0xffffff;

   if (!cpci_reprog) {
      /*
         First, make sure the download interface is reset.
         This flushes buffers, resets state machines etc.
      */

      NF2_WR32(CPCI_PROGRAMMING_CONTROL, 1);

      /* Clear the error registers */
      NF2_WR32(CPCI_ERROR, 0);

      /* Wait a while for the PROG_B cycle to finish. */
      usleep(100);

      /*
         Read programming status:
         Check that DONE bit (bit 8) is zero and FIFO (bit 1) is empty (1).
      */

      result = NF2_RD32(CPCI_PROGRAMMING_STATUS);

      if ((result & 0x102) != 0x2) {
         fprintf(log_file, "After resetting Programming interface, expected status to be 1 (FIFO empty).\n");
         fprintf(log_file, "However status & 0x102 is 0x%0x\n", (result & 0x102));
         FatalError();
      }

      /* Check the error register */
      fprintf(log_file, "Error Registers: %x\n", NF2_RD32(CPCI_ERROR));

      fprintf(log_file, "Good, after resetting programming interface the FIFO is empty\n");

      /* Sleep for a while to allow the INIT pin to be reset */
      usleep(10000);
      retries = 3;

      while (NF2_RD32(CPCI_PROGRAMMING_STATUS) & 0x10002)
      {
         if ((NF2_RD32(CPCI_PROGRAMMING_STATUS) & 0x10000))
             usleep(10000);
         else {
            break;
         }
         retries--;

         if (retries <= 0)
         {
            printf("CPCI's INIT signal did not clear in time, exiting\n");
            printf ("CPCI_PROGRAMMING_STATUS: 0x%08x\n", NF2_RD32(CPCI_PROGRAMMING_STATUS));
            exit(1);
         }
      }
   } // if (!cpci_reprog)


   /* Read the code file, and write it to the card.  */

   code_data = (unsigned char *) malloc(sizeof(unsigned char) * READ_BUFFER_SIZE);

   /* check num bytes read */
   while (code_data_size = fread(code_data, sizeof(unsigned char), READ_BUFFER_SIZE, code_file))
      {
         if (cpci_reprog)
	    DownloadCPCICodeBlock(code_data, code_data_size);
         else
	    DownloadVirtexCodeBlock(code_data, code_data_size);
	 bytes_sent += code_data_size;
      }

   /* Free the code_data variable */
   free(code_data);

   /* Work out how large the download should have been */
   if (cpci_reprog) {
      bytes_expected = CPCI_BIN_SIZE;
   }
   else {
      switch (version) {
         case 1: bytes_expected = VIRTEX_BIN_SIZE_V2_0; break;
         case 2:
         case 3:
         case 4: bytes_expected = VIRTEX_BIN_SIZE_V2_1; break;
         default : bytes_expected = -1;
      }
      if (version < CPCI_MIN_VER || version > CPCI_MAX_VER)
         fprintf(log_file, "\n"
               "WARNING: Unkown CPCI version (%d).\n"
               "         Known versions are between %d and %d inclusive.\n"
               "         Expected number of bytes will be displayed as -1.\n\n",
               version, CPCI_MIN_VER, CPCI_MAX_VER);
   }

   fprintf(log_file, "Download completed -  %d bytes. (expected %d).\n", bytes_sent, bytes_expected);

   /*
    * Kick off the programming process or wait for the process to complete
    */
   if (cpci_reprog) {
      NF2_WR32(VIRTEX_PROGRAM_CTRL_ADDR, DISABLE_RESET | START_PROGRAMMING);
      fprintf(log_file, "Instructed CPCI reprogramming to start. Please reload PCI BARs.\n");
   }
   else {
      /*
      Now wait to see that DONE goes high (bit 8) and INIT (16) is low
      */
      for (retries=0; retries<3; retries++) {
         sleep(1);
         result = NF2_RD32(CPCI_PROGRAMMING_STATUS);
         if  ((result & 0x100) == 0x100 ) {
            fprintf(log_file, "DONE went high - chip has been successfully programmed.\n");
            return;
         }
         if  ((result & 0x10000) == 0x10000 ) {
            fprintf(log_file, "INIT went high - appears to be a programming error.\n");
            FatalError();
         }
         if (retries == 2) {
            fprintf(log_file, "DONE has not gone high - looks like an error\n");
            FatalError();
         }
      }
   }
}


/*
  Given a block of bytes to write, and a bytecount, create 32 bit words from these
  bytes and write them to the Programming FIFO.
  After each 8 words stop and check that the FIFO is empty.
*/
void DownloadVirtexCodeBlock (u_char *code_data, int code_data_size) {

   u_int result;
   u_int data_word;
   int bytes_left;
   u_int count = 0;

   bytes_left = code_data_size;

   while (bytes_left)
      {
	 data_word = (u_int) (*code_data++); bytes_left--;
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))<<8 ; bytes_left--;}
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))<<16 ; bytes_left--;}
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))<<24 ; bytes_left--;}

	 NF2_WR32(CPCI_PROGRAMMING_DATA, data_word);

	 /* Every 8 words we need to check the FIFO - should always be empty!
	  * (or the done flag should be asserted)
	  */
	 if (++count == 8) {
	    count = 0;
	    while (((result = NF2_RD32(CPCI_PROGRAMMING_STATUS)) & 0x10002) != 2 && (result & 0x100) != 0x100) {
	       if (result & 0x10000) {
	          fprintf(log_file, "INIT went active during programming - there was an error!\n");
                  exit(1);
	       }
	       fprintf(log_file, "Strange. FIFO wasnt empty... trying again.\n");
	       usleep(100);
	       result = NF2_RD32(CPCI_PROGRAMMING_STATUS);
	       if ((result & 0x10002) != 2) {
	          fprintf(log_file, "Retrying ... FIFO still not empty. Giving up.\n");
	          fprintf(log_file, "Last status word read was 0x%0x\n", result);
   	       }
	    }
	 }
      }
}


/*
  Given a block of bytes to write, and a bytecount, create 32 bit words from these
  bytes and write them to the programming RAM in the Virtex
*/
void DownloadCPCICodeBlock (u_char *code_data, int code_data_size) {

   u_int result;
   u_int data_word;
   int bytes_left;
   u_int count = 0;

   bytes_left = code_data_size;

   while (bytes_left)
      {
	 data_word = ((u_int) (*code_data++)) << 24; bytes_left--;
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))<<16 ; bytes_left--;}
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))<<8  ; bytes_left--;}
	 if (bytes_left) { data_word |= ((u_int) (*code_data++))     ; bytes_left--;}

	 NF2_WR32(prog_addr, data_word);
         prog_addr += 4;
      }
}

/*
 * Reset the device
 */
void ResetDevice(void) {
   u_int val;

   /* Read the current value of the control register so that we can modify
    * it to do a reset */
   val = NF2_RD32(CPCI_CTRL);

   /* Write to the control register to reset it */
   NF2_WR32(CPCI_CTRL, val | 0x100);

   /* Sleep for a while to let the reset complete */
   sleep(2);
}


/*
 * Verify the device info
 */
void VerifyDevInfo(void) {
   if (!ignore_dev_info && !cpci_reprog) {
      /* Read the device info from the board */
      nf2_read_info(&nf2);

      /* Print the device information */
      printf(getDeviceInfoStr(&nf2));

      /* Check the CPCI version info */
      if (getDeviceID(&nf2) == -1) {
         fprintf(log_file, "WARNING: NetFPGA device info not found. Cannot verify that the CPCI version matches.\n");
      }
      else {
         if (getCPCIVersion(&nf2) != getDeviceCPCIVersion(&nf2)) {// ||
            // Commented out so the script will not give an error on revision number changes.  Revisions should be small changes that do not need users to upgrade the CPCI.  The users should only be forced to change the CPCI on a major release.
            // cpci_revision != nf2_cpci_revision) {
            fprintf(stderr, "Error: Virtex design compiled against a different CPCI version\n");
            fprintf(stderr, "  Active CPCI version : %d (rev %d)\n", getCPCIVersion(&nf2), getCPCIRevision(&nf2));
            fprintf(stderr, "  Device built against: %d (rev %d)\n", getDeviceCPCIVersion(&nf2), getDeviceCPCIRevision(&nf2));
            exit(1);
         }
         else {
            fprintf(stderr,"Virtex design compiled against active CPCI version\n");
         }
      }
   }
}


/*
   Called once we have encountered a fatal error.
   Leave message in log file and terminate.
*/
void FatalError() {
  fprintf(log_file, "\nFatal Error, exiting...\n");
  fclose(log_file);
  exit(FAILURE);
}

/*
 * readReg - read a register
 */
u_int NF2_RD32(u_int addr)
{
   u_int val;

   if (readReg(&nf2, addr, &val))
   {
      fprintf(stderr, "Error reading register %x\n", addr);
      exit(1);
   }

   return val;
}

void NF2_WR32(u_int addr, u_int data)
{
   if (writeReg(&nf2, addr, data))
   {
      fprintf(stderr, "Error writing register %x\n", addr);
      exit(1);
   }
}

/*
   Process the arguments.
*/

void processArgs (int argc, char **argv ) {

   char c;

   /* set defaults */
   verbose = 0;
   cpci_reprog = 0;
   ignore_dev_info = 0;
   prog_addr = VIRTEX_PROGRAM_RAM_BASE_ADDR;
   log_file_name = "stdout";
   intr_enable = 1;

   /* don't want getopt to moan - I can do that just fine thanks! */
   opterr = 0;

   while ((c = getopt (argc, argv, "rvcnl:i:a:p:")) != -1)
      switch (c)
	 {
	 case 'v':
	    verbose = 1;
	    break;
	 case 'c':
	    cpci_reprog = 1;
	    break;
	 case 'n':
	    ignore_dev_info = 1;
	    break;
	 case 'l':   /* log file */
	    log_file_name = optarg;
	    break;
         case 'r':
            intr_enable = 0;
            break;
	 case 'i':   /* interface name */
	    nf2.device_name = optarg;
	    break;
         case 'p':
            nf2.server_port_num = strtol(optarg, NULL, 0);
            break;
         case 'a':
            strncpy(nf2.server_ip_addr, optarg, strlen(optarg));
            break;

	 case '?':
	    if (isprint (optopt))
               fprintf (stderr, "Unknown option `-%c'.\n", optopt);
	    else
               fprintf (stderr,
                        "Unknown option character `\\x%x'.\n",
                        optopt);
	 default:
	    usage();
	    exit(1);
	 }



   /* optind starts at first non-option argument (filename of bin file) */

   if (argv[optind] == NULL) {
      usage(); exit(1);
   }

   /* filename MUST end in .bin or .bit */
   if (strstr(argv[optind],".bin") == NULL && strstr(argv[optind],".bit") == NULL) {
      fprintf(stderr,"Error: the filename must end in .bin or .bit (filename: %s)\n", argv[optind]);
      exit(1);
   }

   bin_file_name = argv[optind];

   if (verbose) {
      printf ("logfile = %s.   bin file = %s\n", log_file_name, bin_file_name);
   }

}


/*
   Describe usage of this program.
*/
void usage () {
   printf("Usage: ./nf_download <options>  [filename.bin | filename.bit]\n");
   printf("\nOptions: -l <logfile> (default is stdout).\n");
   printf("         -i <iface> : interface name.\n");
   printf("         -a <IP-Addr> : IP Address of socket listen.\n");
   printf("         -p <Port-num> : Port Number of socket listen.\n");
   printf("         -c : reprogram CPCI.\n");
   printf("         -n : don't verify Spartan/Virtex build compatibility.\n");
   printf("         -v : be verbose.\n");
   printf("         -r : Disable PHY interrupt for its link status changing.\n");
}

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
