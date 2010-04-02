/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_dram.c 5968 2010-03-06 05:45:26Z grg $
 *
 * Module: selftest_dram.c
 * Project: NetFPGA selftest
 * Description: Dram selftest module
 *
 * Change history:
 *
 */

#include "../lib/C/reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_dram.h"
#include <curses.h>
#include <time.h>

static time_t start_time;

/*
 * Reset the interface and configure it for continuous operation
 */
void dramResetContinuous(void) {
  // Ensure that all tests have finished
  writeReg(&nf2, DRAM_TEST_CTRL_REG, 0x00000000);
  usleep(100000);

  // Enable all tests
  writeReg(&nf2, DRAM_TEST_EN_REG, DRAM_TEST_ENABLE_ENABLE_MASK);

  // Record the time
  start_time = time(NULL);

  // Start the tests running in continuous mode
  writeReg(&nf2, DRAM_TEST_CTRL_REG, DRAM_TEST_CTRL_REPEAT);
} // dramResetContinuous

/*
 * Show the status of the DRAM test when running in continuous mode
 *
 * Return: boolean value indicating success
 */
int dramShowStatusContinuous(void) {
  unsigned int max_num_of_tests = 8;

  unsigned int iter;
  unsigned int good;
  unsigned int bad;

  double bw;

  time_t now;

  unsigned int val;
  unsigned char test_en;

  int i;
  unsigned int tests;

  // Read the iteration counters
  readReg(&nf2, DRAM_TEST_ITER_NUM_REG, &iter);
  readReg(&nf2, DRAM_TEST_BAD_RUNS_REG, &bad);
  readReg(&nf2, DRAM_TEST_GOOD_RUNS_REG, &good);

  // Get the current time
  now = time(NULL);

  // Evaluate which tests are enabled
  readReg(&nf2, DRAM_TEST_EN_REG, &val);
  test_en = val & 0xFF;

  // Count the number of tests
  tests = 0;
  for (i = 0; i < 8; i++) {
    if (test_en & (1 << i))
      tests++;
  }

  // Calculate the bandwidth
  bw = DRAM_MEMSIZE * (iter - 1);
  bw *= tests * 2;
  bw /= (now - start_time);
  bw *= 1.024 * 1.024 / 1000 * 8;

  printw("DRAM test: Iteration: %d   Good: %d   Bad: %d   B/W: %3.2f Gbps\n", iter, good, bad, bw);

  // Have we seen any failures
  return good != 0 && bad == 0;
} // dramShowStatusContinuous

/*
 * Stop the interface
 */
void dramStopContinuous(void) {
  // Ensure that all tests have finished
  writeReg(&nf2, DRAM_TEST_CTRL_REG, 0x00000000);
} // dramStopContinuous

/*
 * Get the status of the DRAM test
 *
 * Return: boolean value indicating success
 */
int dramGetResult(void) {
  unsigned int good;
  unsigned int bad;

  // Read the iteration counters
  readReg(&nf2, DRAM_TEST_BAD_RUNS_REG, &bad);
  readReg(&nf2, DRAM_TEST_GOOD_RUNS_REG, &good);

  // Have we seen any failures
  return good != 0 && bad == 0;
} // dramGetResult

