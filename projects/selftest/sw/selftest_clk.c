/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_clk.c 5990 2010-03-10 22:14:12Z grg $
 *
 * Module: selftest_clk.c
 * Project: NetFPGA selftest
 * Description: Clock selftest module
 *
 * Change history:
 *
 */

#include "../lib/C/reg_defines_selftest.h"
#include "../../cpci/lib/C/reg_defines_cpci.h"
#include "selftest.h"
#include "selftest_clk.h"
#include <curses.h>
#include <time.h>
#include <sys/time.h>

#define CLOCK_125     1
#define CLOCK_62_5    0

#define RESET_PERIOD    500000
#define MEASURE_PERIOD  500000

// How many MHz are the rates allowed to differ from their expected values
#define ALLOWED_RATE_DELTA   2.0

double estimateRate(int freq);

static int clock_125_good = 0;
static int clock_62_5_good = 0;

static double rate_125 = 0;
static double rate_62_5 = 0;

/*
 * Reset the interface and configure it for continuous operation
 */
void clkResetContinuous(void) {
  // No action needed for reset continuous
} // clkResetContinuous

/*
 * Show the status of the MII test when running in continuous mode
 *
 * Return -- boolean value indicating success
 */
int clkShowStatusContinuous(void) {
  if (clock_125_good && clock_62_5_good)
    printw("Clock test: pass\n");
  else
    printw("Clock test: fail   (62.5MHz: %1.3fMHz   125MHz: %1.3fMHz)\n", rate_62_5, rate_125);

  return clock_125_good && clock_62_5_good;
} // clkShowStatusContinuous

/*
 * Stop the interface
 */
void clkStopContinuous(void) {
  // No action needed for stop
} // clkStopContinuous

/*
 * Get the success status of the test
 *
 * Return -- boolean value indicating success
 */
int clkGetResult(void) {
  return clock_125_good && clock_62_5_good;
} // clkGetResult


/*
 * Measure the clock rates at both 125 and 62.5 MHz
 */
void measureClocks(void) {
  /*
   * NOTE: It is assumed that the 125 MHz rate measurement resets the card
   * to a 125 MHz clock.
   */

  // Measure the two clock frequencies
  rate_62_5 = estimateRate(CLOCK_62_5);
  rate_125 = estimateRate(CLOCK_125);

  // Work out if the clocks are good (within a couple of MHz is good)
  clock_125_good = rate_125 > 125 - ALLOWED_RATE_DELTA &&
                   rate_125 < 125 + ALLOWED_RATE_DELTA;
  clock_62_5_good = rate_62_5 > 62.5 - ALLOWED_RATE_DELTA &&
                    rate_62_5 < 62.5 + ALLOWED_RATE_DELTA;
}


/*
 * Estimate the clock rate
 */
double estimateRate(int freq) {
  unsigned int ticks;
  unsigned int ctrl;

  struct timeval start_time;
  struct timeval end_time;
  struct timeval delta;

  double rate;

  // Read the current value of the control register so that we can modify
  // it to do a reset
  readReg(&nf2, CPCI_CTRL_REG, &ctrl);


  // Set the clock to the desired frequency
  writeReg(&nf2, CPCI_CNET_CLK_SEL_REG, freq);

  // Write to the control register to reset it
  writeReg(&nf2, CPCI_CTRL_REG, ctrl | 0x100);

  // Wait a while for the reset to complete
  usleep(RESET_PERIOD);

  // Read the clock counter register
  //
  // This should reset it
  readReg(&nf2, CLOCK_TEST_TICKS_REG, &ticks);

  // Record the time
  gettimeofday(&start_time, NULL);

  // Sleep for the measurement period
  usleep(MEASURE_PERIOD);

  // Read the clock counter register
  //
  // This should reset it
  readReg(&nf2, CLOCK_TEST_TICKS_REG, &ticks);

  // Record the time
  gettimeofday(&end_time, NULL);

  // Calculate the approximate clock rate
  timersub(&end_time, &start_time, &delta);
  rate = (ticks / 1000000.0) / (delta.tv_sec + delta.tv_usec / 1000000.0);

  return rate;
}



