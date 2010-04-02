/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_sram.c 5983 2010-03-07 03:30:11Z grg $
 *
 * Module: selftest_sram.c
 * Project: NetFPGA selftest
 * Description: SRAM selftest module
 *
 * Change history:
 *
 */

#include "../lib/C//reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_sram.h"
#include <curses.h>
#include <time.h>

static time_t start_time;

/*
 * Reset the interface and configure it for continuous operation
 */
void sramResetContinuous(void) {
  // program h/w random test with a different test seed for each iteration
  //data1 = lrand48();
  //data2 = lrand48();
  //writeReg(&nf2, SRAM_TEST_RAND_SEED_1_REG, data1 & 0xf);
  //writeReg(&nf2, SRAM_TEST_RAND_SEED_2_REG, data2);

  // Ensure that all tests have finished
  writeReg(&nf2, SRAM_TEST_CTRL_REG, 0x0);
  usleep(100000);

  // Enable all tests
  writeReg(&nf2, SRAM_TEST_EN_REG,
      SRAM_TEST_ENABLE_TEST_EN_MASK |
      SRAM_TEST_ENABLE_SRAM_EN_MASK);

  // Record the time
  start_time = time(NULL);

  // Start the tests running in continuous mode
  writeReg(&nf2, SRAM_TEST_CTRL_REG, SRAM_TEST_CTRL_REPEAT);
} // sramResetContinuous

/*
 * Show the status of the DRAM test when running in continuous mode
 *
 * Return -- boolean indicatin success
 */
int sramShowStatusContinuous(void) {
  unsigned int max_num_of_tests = 8;

  unsigned int iter;
  unsigned int good;
  unsigned int bad;

  double bw;

  time_t now;

  unsigned int val;
  unsigned char test_en;
  unsigned char sram_en;

  int i;
  unsigned int tests;
  unsigned int srams;

  // Read the iteration counters
  readReg(&nf2, SRAM_TEST_ITER_NUM_REG, &iter);
  readReg(&nf2, SRAM_TEST_BAD_RUNS_REG, &bad);
  readReg(&nf2, SRAM_TEST_GOOD_RUNS_REG, &good);

  // Get the current time
  now = time(NULL);

  // Evaluate which tests are enabled
  readReg(&nf2, SRAM_TEST_EN_REG, &val);
  sram_en = (val >> 16) & 0x3;
  test_en = val & 0xFF;

  // Count the number of tests
  tests = 0;
  for (i = 0; i < 8; i++) {
    if (test_en & (1 << i))
      tests++;
  }

  // Count how many SRAMS are enabled
  switch (sram_en) {
    case 1 : srams = 1; break;
    case 2 : srams = 1; break;
    case 3 : srams = 2; break;
    default: srams = 0;
  }

  // Calculate the bandwidth
  bw = SRAM_MEMSIZE * (iter - 1);
  bw *= srams * tests * 2;
  bw /= (now - start_time);
  bw *= 1.024 * 1.024 / 1000 * 8;

  printw("SRAM test: Iteration: %d   Good: %d   Bad: %d   B/W: %3.2f Gbps\n", iter, good, bad, bw);

  // Good only if we've done an iteration and there are no bad iterations
  return good != 0 && bad == 0;
} // sramShowStatusContinuous

/*
 * Stop the interface
 */
void sramStopContinuous(void) {
  // Ensure that all tests have finished
  writeReg(&nf2, SRAM_TEST_CTRL_REG, 0x0);
} // sramStopContinuous

/*
 * Get the test result
 *
 * Return -- boolean indicatin success
 */
int sramGetResult(void) {
  unsigned int good;
  unsigned int bad;

  // Read the iteration counters
  readReg(&nf2, SRAM_TEST_BAD_RUNS_REG, &bad);
  readReg(&nf2, SRAM_TEST_GOOD_RUNS_REG, &good);

  // Good only if we've done an iteration and there are no bad iterations
  return good != 0 && bad == 0;
} // sramGetResult
