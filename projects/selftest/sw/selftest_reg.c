/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_reg.c 5976 2010-03-06 07:20:44Z grg $
 *
 * Module: selftest_reg.c
 * Project: NetFPGA selftest
 * Description: Register selftest module
 *
 * Change history:
 *
 */

#include "../lib/C/reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_reg.h"
#include <curses.h>
#include <time.h>

/*
 * Reset the interface and configure it for continuous operation
 */
void regResetContinuous(void) {
} // regResetContinuous

/*
 * Show the status of the SATA test when running in continuous mode
 *
 * Return -- boolean indicating success
 */
int regShowStatusContinuous(void) {
  unsigned int val;
  int i;
  int vals[REG_TEST_SIZE];
  int ok = 1;

  // Generate random values and write them to the test registers
  for (i = 0; i < REG_TEST_SIZE; i++) {
    vals[i] = rand();
    writeReg(&nf2, REG_FILE_BASE_ADDR + i * 4, vals[i]);
  }

  // Read the values back to check for errors
  for (i = 0; i < REG_TEST_SIZE; i++) {
    readReg(&nf2, REG_FILE_BASE_ADDR + i * 4, &val);
    if (val != vals[i]) {
      ok = 0;
    }
  }

  printw("Reg test: %s\n", ok ? "pass" : "fail");

  return ok;
} // regShowStatusContinuous

/*
 * Stop the interface
 */
void regStopContinuous(void) {
} // regStopContinuous

/*
 * Get the test result
 *
 * Return -- boolean indicating success
 */
int regGetResult(void) {
  unsigned int val;
  int i;
  int vals[REG_TEST_SIZE];
  int ok = 1;

  // Generate random values and write them to the test registers
  for (i = 0; i < REG_TEST_SIZE; i++) {
    vals[i] = rand();
    writeReg(&nf2, REG_FILE_BASE_ADDR + i * 4, vals[i]);
  }

  // Read the values back to check for errors
  for (i = 0; i < REG_TEST_SIZE; i++) {
    readReg(&nf2, REG_FILE_BASE_ADDR + i * 4, &val);
    if (val != vals[i]) {
      ok = 0;
    }
  }

  return ok;
} // regGetResult
