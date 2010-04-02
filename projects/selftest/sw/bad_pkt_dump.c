/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: bad_pkt_dump.c 5979 2010-03-06 07:32:24Z grg $
 *
 * Module: phy_read.c
 * Project: NetFPGA 2.1
 * Description: Interface with the self-test modules on the NetFPGA
 * to help diagnose problems.
 *
 * Change history:
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>

#include <net/if.h>

#include <time.h>

#include "../lib/C/reg_defines_selftest.h"
#include "../../../lib/C/common/nf2util.h"
#include <curses.h>

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;


int main(int argc, char *argv[])
{
   unsigned val, log_depth;
   int i;

   nf2.device_name = DEFAULT_IFACE;

   if (check_iface(&nf2))
   {
   	exit(1);
   }
   if (openDescriptor(&nf2))
   {
   	exit(1);
   }


   // Read the status register
   readReg(&nf2, PHY_TEST_PHY_0_RX_LOG_STATUS_REG, &val);

   if (!(val & 0x1))
     printf("No data in the log\n");
   else {
     log_depth = (val & 0xffffff00) >> 8;

     // Read the expected data register
     printf("Expected data:\n");
     for (i = 0; i < log_depth; i++) {
       readReg(&nf2, PHY_TEST_PHY_0_RX_LOG_EXP_DATA_REG, &val);
       if (i % 4 == 0)
         printf("%08x:", i * 4);
       printf(" %02x %02x %02x %02x",
                (val >> 24) & 0xff,
                (val >> 16) & 0xff,
                (val >> 8) & 0xff,
                (val) & 0xff);
       if (i % 4 == 3)
         printf("\n");
     }
     printf("\n");
     printf("\n");

     // Read the rx data register
     printf("Received data:\n");
     for (i = 0; i < log_depth; i++) {
       readReg(&nf2, PHY_TEST_PHY_0_RX_LOG_RX_DATA_REG, &val);
       if (i % 4 == 0)
         printf("%08x:", i * 4);
       printf(" %02x %02x %02x %02x",
                (val >> 24) & 0xff,
                (val >> 16) & 0xff,
                (val >> 8) & 0xff,
                (val) & 0xff);
       if (i % 4 == 3)
         printf("\n");
     }
     printf("\n");
     printf("\n");

     // Clear the log
     writeReg(&nf2, PHY_TEST_PHY_0_RX_LOG_CTRL_REG, 1);
   }

   /*for (j = 0; j < 250; j++) {
      readReg(&nf2, NF2_REG_TEST_BASE + j * 4, &val);
      printf("Read value %x in address %d\n", val, j*4);
   }*/


}
