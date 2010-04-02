/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_phy.c 5971 2010-03-06 06:44:56Z grg $
 *
 * Module: selftest_phy.c
 * Project: NetFPGA selftest
 * Description: SATA selftest module
 *
 * Change history:
 *
 */

#include "../lib/C/reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_phy.h"
#include <curses.h>
#include <time.h>

#define NUM_PORTS 4

static int prev_good_pkts[NUM_PORTS];
static int prev_bad_pkts[NUM_PORTS];

/*
 * Reset the interface and configure it for continuous operation
 */
void phyResetContinuous(void) {
  int i;

  for (i = 0; i < NUM_PORTS; i++) {
    prev_good_pkts[i] = 0;
    prev_bad_pkts[i] = 0;
  }

  // Stop the test (and wait for the test to stop)
  writeReg(&nf2, PHY_TEST_CTRL_REG, 0x0);
  sleep(1);

  writeReg(&nf2, PHY_TEST_PATTERN_REG, PHY_TEST_PATTERN_ENABLE_MASK);

  // Start the test
  writeReg(&nf2, PHY_TEST_CTRL_REG, PHY_TEST_CTRL_REPEAT);
} // phyResetContinuous

/*
 * Show the status of the SATA test when running in continuous mode
 *
 * Return -- boolean indicating success
 */
int phyShowStatusContinuous(void) {
  unsigned int val;
  unsigned int port_status;
  unsigned int good_pkts;
  unsigned int bad_pkts;

  int i;

  int x, y;

  int good = 1;

  // Store the current screen position
  getyx(stdscr, y, x);

  // Move down a line
  move(y + 1, x);

  // Read the individual port registers
  for (i = 0; i < NUM_PORTS; i++) {
    printw("   Port %d:", i + 1);

    // Start with the status register
    readReg(&nf2, PHY_TEST_PHY_0_RX_STATUS_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &port_status);
    if (port_status & 0x100) {
      printw(" link w/ %d", (port_status & 0xf0000) >> 16);
    }
    else {
      printw(" no link");
      good = 0;
    }

    // Read the number of good/bad packets
    readReg(&nf2, PHY_TEST_PHY_0_RX_GOOD_PKT_CNT_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &good_pkts);
    readReg(&nf2, PHY_TEST_PHY_0_RX_ERR_PKT_CNT_REG  + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &bad_pkts);
    printw(" Good: %d   Bad: %d", good_pkts, bad_pkts);

    printw("\n");

    // Verify if we should reset the counters
    /*if ((port_status & 0x1100) == 0x1100) {
      // Only reset if the number of good packets has incremented but the bad
      // packets have remained the same
      if (bad_pkts == prev_bad_pkts[i] && good_pkts != prev_good_pkts[i]) {
        writeReg(&nf2, PHY_TEST_PHY_0_RX_CTRL_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, 0x3);
      }

      // Update the counters
      prev_bad_pkts[i] = bad_pkts;
      prev_good_pkts[i] = good_pkts;
    }*/

    // Update the good flag
    if (bad_pkts != 0)
      good = 0;
  }

  // Print overall success/failure
  move(y, x);
  printw("PHY test: %s", good ? "pass" : "fail");
  move(y + 1 + NUM_PORTS, x);

  return good;
} // phyShowStatusContinuous

/*
 * Stop the interface
 */
void phyStopContinuous(void) {
  // Stop the test (and wait for the test to stop)
  writeReg(&nf2, PHY_TEST_CTRL_REG, 0x00000000);
} // phyStopContinuous

/*
 * Get the result of the test
 *
 * Return -- boolean indicating success
 */
int phyGetResult(void) {
  unsigned int val;
  unsigned int port_status;
  unsigned int good_pkts;
  unsigned int bad_pkts;

  int i;

  int good = 1;

  // Read the individual port registers
  for (i = 0; i < NUM_PORTS; i++) {
    // Start with the status register
    readReg(&nf2, PHY_TEST_PHY_0_RX_STATUS_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &port_status);
    if ((port_status & 0x100) == 0) {
      good = 0;
    }

    // Read the number of good/bad packets
    readReg(&nf2, PHY_TEST_PHY_0_RX_GOOD_PKT_CNT_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &good_pkts);
    readReg(&nf2, PHY_TEST_PHY_0_RX_ERR_PKT_CNT_REG + i * PHY_TEST_PHY_GROUP_INST_OFFSET, &bad_pkts);

    // Update the good flag
    if (bad_pkts != 0) {
      good = 0;
    }
  }

  return good;
} // phyGetResult
