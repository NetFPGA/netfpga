/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_serial.c 5964 2010-03-06 05:11:23Z grg $
 *
 * Module: selftest_serial.c
 * Project: NetFPGA selftest
 * Description: SATA selftest module
 *
 * Change history:
 *
 */

#include <sys/types.h>
#include <curses.h>
#include <time.h>
#include "../lib/C/reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_serial.h"


//external global variable for flags
extern no_sata_flg;

/*
 * Reset the interface and configure it for continuous operation
 */
void serialResetContinuous(void) {
  writeReg(&nf2, SERIAL_TEST_CTRL_REG, SERIAL_TEST_GLBL_CTRL_RESTART);
  writeReg(&nf2, SERIAL_TEST_CTRL_REG, 0);

  writeReg(&nf2, SERIAL_TEST_CTRL_0_REG, 0);
  writeReg(&nf2, SERIAL_TEST_CTRL_1_REG, 0);
} // serialResetContinuous

/*
 * Show the status of the SATA test when running in continuous mode
 *
 * Return -- boolean indicatin success
 */
int serialShowStatusContinuous(void) {
  unsigned int val;
  unsigned int val2;
  unsigned int val3;
  int64_t val_long1;
  int64_t val_long2;

  if (no_sata_flg == 1)
  {
    printw("SATA Test Disabled\n");
    return 0;
  }
  else
  {
  writeReg(&nf2, SERIAL_TEST_CTRL_REG, SERIAL_TEST_GLBL_CTRL_NONSTOP);

  readReg(&nf2, SERIAL_TEST_STATUS_0_REG, &val2);
  readReg(&nf2, SERIAL_TEST_STATUS_1_REG, &val3);

  // Read the status register
  readReg(&nf2, SERIAL_TEST_STATUS_REG, &val);
  printw("SATA test: %s   (Success: %d    Running: %d)\n",
      (val & SERIAL_TEST_GLBL_STATUS_SUCCESSFUL) &&
      (val & SERIAL_TEST_GLBL_STATUS_RUNNING) ? "pass" : "fail",
      (val2 & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      (val2 & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP) &&
      (val3 & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      (val3 & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP) &&
      (val & SERIAL_TEST_GLBL_STATUS_SUCCESSFUL),
      !!(val & SERIAL_TEST_GLBL_STATUS_RUNNING));

  readReg(&nf2, SERIAL_TEST_STATUS_0_REG, &val);
  printw("Serial module 0 status:       lane up    : %d,   channel_up  : %d,   hard_error  : %d",
	 !!(val & SERIAL_TEST_IFACE_STATUS_LANE_UP),
         !!(val & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP),
         !!(val & SERIAL_TEST_IFACE_STATUS_HARD_ERROR));

  if (!(val & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      !(val & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP))
  {
    printw("  (ERROR: Check the SATA Cable connection)\n");
  }
  else
  {
    printw("\n");
  }

  printw("                              soft_error : %d,   frame_error : %d,   error_count : %d\n",
	 !!(val & SERIAL_TEST_IFACE_STATUS_SOFT_ERROR),
         !!(val & SERIAL_TEST_IFACE_STATUS_FRAME_ERROR),
         (val & SERIAL_TEST_IFACE_STATUS_ERROR_COUNT_MASK) >> SERIAL_TEST_IFACE_STATUS_ERROR_COUNT_POS_LO);

  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_SENT_0_HI_REG, &val);
  val_long1 = val;
  val_long1 <<= 32;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_SENT_0_LO_REG, &val);
  val_long1 += val;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_RCVD_0_HI_REG, &val);
  val_long2 = val;
  val_long2 <<= 32;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_RCVD_0_LO_REG, &val);
  val_long2 += val;
  printw("Serial module 0 stats :       num frames sent:   %d, num frames rcvd:   ", val_long1);
  printw("%d \n", val_long2);

  readReg(&nf2, SERIAL_TEST_STATUS_1_REG, &val);
  printw("Serial module 1 status:       lane up    : %d,   channel_up  : %d,   hard_error  : %d",
	 !!(val & SERIAL_TEST_IFACE_STATUS_LANE_UP),
         !!(val & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP),
         !!(val & SERIAL_TEST_IFACE_STATUS_HARD_ERROR));

  if (!(val & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      !(val & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP))
  {
    printw("  (ERROR: Check the SATA Cable connection)\n");
  }
  else
  {
    printw("\n");
  }

  printw("                              soft_error : %d,   frame_error : %d,   error_count : %d\n",
	 !!(val & SERIAL_TEST_IFACE_STATUS_SOFT_ERROR),
         !!(val & SERIAL_TEST_IFACE_STATUS_FRAME_ERROR),
         (val & SERIAL_TEST_IFACE_STATUS_ERROR_COUNT_MASK) >> SERIAL_TEST_IFACE_STATUS_ERROR_COUNT_POS_LO);

  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_SENT_1_HI_REG, &val);
  val_long1 = val;
  val_long1 <<= 32;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_SENT_1_LO_REG, &val);
  val_long1 += val;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_RCVD_1_HI_REG, &val);
  val_long2 = val;
  val_long2 <<= 32;
  readReg(&nf2, SERIAL_TEST_NUM_FRAMES_RCVD_1_LO_REG, &val);
  val_long2 += val;
  printw("Serial module 1 stats :       num frames sent:   %d, num frames rcvd:   ", val_long1);
  printw("%d \n", val_long2);

  return (val & SERIAL_TEST_GLBL_STATUS_SUCCESSFUL) && (val & SERIAL_TEST_GLBL_STATUS_RUNNING);
  }
} // serialShowStatusContinuous

/*
 * Stop the interface
 */
void serialStopContinuous(void) {
  writeReg(&nf2, SERIAL_TEST_CTRL_REG, 0);
} // serialStopContinuous

/*
 * Get the test result
 *
 * Return -- boolean indicatin success
 */
int serialGetResult(void) {
  unsigned int val;
  unsigned int val2;
  unsigned int val3;

  /*   readReg(&nf2, SERIAL_TEST_CTRL_REG, &val); */
  /*   printf("nonstop: %d\n",!!(val & SERIAL_TEST_GLBL_CTRL_NONSTOP)) ; */
  if (no_sata_flg != 1)
  {
    // Read the status register
    readReg(&nf2, SERIAL_TEST_STATUS_REG, &val);
    readReg(&nf2, SERIAL_TEST_STATUS_0_REG, &val2);
    readReg(&nf2, SERIAL_TEST_STATUS_1_REG, &val3);

    /*   printf("success: %d, done: %d, count: %x\n",
    *   (val & SERIAL_TEST_GLBL_STATUS_SUCCESSFUL),
    *   (val & SERIAL_TEST_GLBL_STATUS_DONE),
    *   (val & SERIAL_TEST_GLBL_STATUS_COUNT_MASK) >> SERIAL_TEST_GLBL_STATUS_COUNT_POS_LO);
    */

    return (val2 & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      (val2 & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP) &&
      (val3 & SERIAL_TEST_IFACE_STATUS_LANE_UP) &&
      (val3 & SERIAL_TEST_IFACE_STATUS_CHANNEL_UP) &&
      (val & SERIAL_TEST_GLBL_STATUS_SUCCESSFUL) &&
      (val & SERIAL_TEST_GLBL_STATUS_DONE);
  }
  else
  {
    return 1;
  }
} // serialGetResult

