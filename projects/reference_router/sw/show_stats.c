/* ****************************************************************************
 * $Id: show_stats.c 5456 2009-05-05 18:22:05Z g9coving $
 *
 * Module: show_stats.c
 * Project: NetFPGA 2. Yashar's buffer sizing project
 * Description: Display current stats
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

#include "../lib/C/reg_defines_reference_router.h"
#include "../../../lib/C/common/nf2util.h"
#include <curses.h>

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"

/* Global vars */
static struct nf2device nf2;
static int verbose = 0;
static int force_cnet = 0;

/* Function declarations */
void show_stats (void);

WINDOW *w;

static unsigned int lost[8],stored[8], removed[8];

int main(int argc, char *argv[])
{
	unsigned val;

        for (val=0;val<8;val++) { lost[val] = 0; stored[val]=0; removed[val]=0; }

	nf2.device_name = DEFAULT_IFACE;

	if (check_iface(&nf2))
	{
		exit(1);
	}
	if (openDescriptor(&nf2))
	{
		exit(1);
	}

        w = initscr(); cbreak(); noecho();

	show_stats();

	closeDescriptor(&nf2);

	endwin();

	return 0;
}

void show_stats(void) {
   unsigned val;
   unsigned lo_addr[8], hi_addr[8];
   unsigned i;

   while (1) {

      move(5,0);

      readReg(&nf2, MAC_GRP_0_CONTROL_REG, &val);
      printw("MAC 0 Control: 0x%08x ", val);
      if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
         printw("TX disabled, ");
      }
      else {
         printw("TX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
         printw("RX disabled, ");
      }
      else {
         printw("RX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
         printw("reset on,    ");
      }
      else {
         printw("reset off,   ");
      }
      printw("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

      readReg(&nf2, MAC_GRP_1_CONTROL_REG, &val);
      printw("MAC 1 Control: 0x%08x ", val);
      if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
         printw("TX disabled, ");
      }
      else {
         printw("TX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
         printw("RX disabled, ");
      }
      else {
         printw("RX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
         printw("reset on,    ");
      }
      else {
         printw("reset off,   ");
      }
      printw("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

      readReg(&nf2, MAC_GRP_2_CONTROL_REG, &val);
      printw("MAC 2 Control: 0x%08x ", val);
      if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
         printw("TX disabled, ");
      }
      else {
         printw("TX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
         printw("RX disabled, ");
      }
      else {
         printw("RX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
         printw("reset on,    ");
      }
      else {
         printw("reset off,   ");
      }
      printw("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

      readReg(&nf2, MAC_GRP_3_CONTROL_REG, &val);
      printw("MAC 3 Control: 0x%08x ", val);
      if(val&(1<<MAC_GRP_TX_QUEUE_DISABLE_BIT_NUM)) {
         printw("TX disabled, ");
      }
      else {
         printw("TX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RX_QUEUE_DISABLE_BIT_NUM)) {
         printw("RX disabled, ");
      }
      else {
         printw("RX enabled,  ");
      }
      if(val&(1<<MAC_GRP_RESET_MAC_BIT_NUM)) {
         printw("reset on,    ");
      }
      else {
         printw("reset off,   ");
      }
      printw("mac config 0x%02x\n", val>>MAC_GRP_MAC_DISABLE_TX_BIT_NUM);

      move (12,0);
      printw("                   Port 0    CPU 0   Port 1    CPU 1   Port 2    CPU 2   Port 3    CPU 3\n");
      printw("OQ Packets Lost:\n");
      printw("OQ Packets Stored:\n");
      printw("OQ Packets Removed:\n");
      printw("OQ Bytes Stored:\n");
      printw("OQ Bytes Removed:\n");
      printw("OQ Low address:\n");
      printw("OQ High address:\n");
      printw("OQ Write address:\n");
      printw("OQ Read address:\n");
      printw("Rx Q # bytes pushed:\n");
      printw("Tx Q # bytes pushed:\n");

      move (13,17);
      readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_DROPPED_REG, &val); lost[0] = val;
      printw("%8i", lost[0]);
      readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_DROPPED_REG, &val);lost[1] = val;
      printw(" %8i", lost[1]);
      readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_DROPPED_REG, &val);lost[2] = val;
      printw(" %8i", lost[2]);
      readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_DROPPED_REG, &val);lost[3] = val;
      printw(" %8i", lost[3]);
      readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_DROPPED_REG, &val);lost[4] = val;
      printw(" %8i", lost[4]);
      readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_DROPPED_REG, &val);lost[5] = val;
      printw(" %8i", lost[5]);
      readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_DROPPED_REG, &val);lost[6] = val;
      printw(" %8i", lost[6]);
      readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_DROPPED_REG, &val);lost[7] = val;
      printw(" %8i", lost[7]);

      move (14,17);
      readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_STORED_REG, &val);stored[0] = val;
      printw("%8i", stored[0]);
      readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_STORED_REG, &val);stored[1] = val;
      printw(" %8i", stored[1]);
      readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_STORED_REG, &val);stored[2] = val;
      printw(" %8i", stored[2]);
      readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_STORED_REG, &val);stored[3] = val;
      printw(" %8i", stored[3]);
      readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_STORED_REG, &val);stored[4] = val;
      printw(" %8i", stored[4]);
      readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_STORED_REG, &val);stored[5] = val;
      printw(" %8i", stored[5]);
      readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_STORED_REG, &val);stored[6] = val;
      printw(" %8i", stored[6]);
      readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_STORED_REG, &val);stored[7] = val;
      printw(" %8i", stored[7]);

      move (15,17);
      readReg(&nf2, OQ_QUEUE_0_NUM_PKTS_REMOVED_REG, &val);removed[0] = val;
      printw("%8i", removed[0]);
      readReg(&nf2, OQ_QUEUE_1_NUM_PKTS_REMOVED_REG, &val);removed[1] = val;
      printw(" %8i", removed[1]);
      readReg(&nf2, OQ_QUEUE_2_NUM_PKTS_REMOVED_REG, &val);removed[2] = val;
      printw(" %8i", removed[2]);
      readReg(&nf2, OQ_QUEUE_3_NUM_PKTS_REMOVED_REG, &val);removed[3] = val;
      printw(" %8i", removed[3]);
      readReg(&nf2, OQ_QUEUE_4_NUM_PKTS_REMOVED_REG, &val);removed[4] = val;
      printw(" %8i", removed[4]);
      readReg(&nf2, OQ_QUEUE_5_NUM_PKTS_REMOVED_REG, &val);removed[5] = val;
      printw(" %8i", removed[5]);
      readReg(&nf2, OQ_QUEUE_6_NUM_PKTS_REMOVED_REG, &val);removed[6] = val;
      printw(" %8i", removed[6]);
      readReg(&nf2, OQ_QUEUE_7_NUM_PKTS_REMOVED_REG, &val);removed[7] = val;
      printw(" %8i", removed[7]);

      move (16,17);
      readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG, &val);
      printw("%8i", val);
      readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_4_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_5_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_6_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_7_NUM_PKT_BYTES_STORED_REG, &val);
      printw(" %8i", val);

      move (17,17);
      readReg(&nf2, OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw("%8i", val);
      readReg(&nf2, OQ_QUEUE_1_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_3_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_4_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_5_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_6_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, OQ_QUEUE_7_NUM_PKT_BYTES_REMOVED_REG, &val);
      printw(" %8i", val);

      move (18,17);
      readReg(&nf2, OQ_QUEUE_0_ADDR_LO_REG, &val);lo_addr[0] = val;
      printw("%8x", lo_addr[0]<<3);
      readReg(&nf2, OQ_QUEUE_1_ADDR_LO_REG, &val);lo_addr[1] = val;
      printw(" %8x", lo_addr[1]<<3);
      readReg(&nf2, OQ_QUEUE_2_ADDR_LO_REG, &val);lo_addr[2] = val;
      printw(" %8x", lo_addr[2]<<3);
      readReg(&nf2, OQ_QUEUE_3_ADDR_LO_REG, &val);lo_addr[3] = val;
      printw(" %8x", lo_addr[3]<<3);
      readReg(&nf2, OQ_QUEUE_4_ADDR_LO_REG, &val);lo_addr[4] = val;
      printw(" %8x", lo_addr[4]<<3);
      readReg(&nf2, OQ_QUEUE_5_ADDR_LO_REG, &val);lo_addr[5] = val;
      printw(" %8x", lo_addr[5]<<3);
      readReg(&nf2, OQ_QUEUE_6_ADDR_LO_REG, &val);lo_addr[6] = val;
      printw(" %8x", lo_addr[6]<<3);
      readReg(&nf2, OQ_QUEUE_7_ADDR_LO_REG, &val);lo_addr[7] = val;
      printw(" %8x", lo_addr[7]<<3);

      move (19,17);
      readReg(&nf2, OQ_QUEUE_0_ADDR_HI_REG, &val);hi_addr[0] = val;
      printw("%8x", hi_addr[0]<<3);
      readReg(&nf2, OQ_QUEUE_1_ADDR_HI_REG, &val);hi_addr[1] = val;
      printw(" %8x", hi_addr[1]<<3);
      readReg(&nf2, OQ_QUEUE_2_ADDR_HI_REG, &val);hi_addr[2] = val;
      printw(" %8x", hi_addr[2]<<3);
      readReg(&nf2, OQ_QUEUE_3_ADDR_HI_REG, &val);hi_addr[3] = val;
      printw(" %8x", hi_addr[3]<<3);
      readReg(&nf2, OQ_QUEUE_4_ADDR_HI_REG, &val);hi_addr[4] = val;
      printw(" %8x", hi_addr[4]<<3);
      readReg(&nf2, OQ_QUEUE_5_ADDR_HI_REG, &val);hi_addr[5] = val;
      printw(" %8x", hi_addr[5]<<3);
      readReg(&nf2, OQ_QUEUE_6_ADDR_HI_REG, &val);hi_addr[6] = val;
      printw(" %8x", hi_addr[6]<<3);
      readReg(&nf2, OQ_QUEUE_7_ADDR_HI_REG, &val);hi_addr[7] = val;
      printw(" %8x", hi_addr[7]<<3);

      move (20,17);
      readReg(&nf2, OQ_QUEUE_0_WR_ADDR_REG, &val);
      printw("%8x", val<<3);
      readReg(&nf2, OQ_QUEUE_1_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_2_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_3_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_4_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_5_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_6_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_7_WR_ADDR_REG, &val);
      printw(" %8x", val<<3);

      move (21,17);
      readReg(&nf2, OQ_QUEUE_0_RD_ADDR_REG, &val);
      printw("%8x", val<<3);
      readReg(&nf2, OQ_QUEUE_1_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_2_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_3_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_4_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_5_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_6_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);
      readReg(&nf2, OQ_QUEUE_7_RD_ADDR_REG, &val);
      printw(" %8x", val<<3);

      move (22,17);
      readReg(&nf2, MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw("%8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_0_RX_NUM_BYTES_RCVD_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_1_RX_NUM_BYTES_RCVD_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_2_RX_NUM_BYTES_RCVD_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2,CPU_REG_Q_3_RX_NUM_BYTES_RCVD_REG , &val);
      printw(" %8i", val);

      move (23,17);
      readReg(&nf2, MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw("%8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_0_TX_NUM_BYTES_SENT_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_1_TX_NUM_BYTES_SENT_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2, CPU_REG_Q_2_TX_NUM_BYTES_SENT_REG, &val);
      printw(" %8i", val);
      readReg(&nf2, MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG, &val);
      printw(" %8i", val);
      val = -1;//readReg(&nf2,CPU_REG_Q_3_TX_NUM_BYTES_SENT_REG , &val);
      printw(" %8i", val);

      move (24,0);
      printw("Size:");
      move (24,16);
      for (i=0;i<8;i++) {
	 printw(" %6iKB", ((hi_addr[i]-lo_addr[i])/128));
      }


      refresh();

      sleep(1);

   }

}
