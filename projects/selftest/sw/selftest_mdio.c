/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest_mdio.c 5985 2010-03-07 04:37:38Z grg $
 *
 * Module: selftest_mdio.c
 * Project: NetFPGA selftest
 * Description: MDIO selftest module
 *
 * Change history:
 *
 */

#include "../lib/C/reg_defines_selftest.h"
#include "selftest.h"
#include "selftest_mdio.h"
#include <curses.h>
#include <time.h>

int readMDIOReg(int phy, int addr);
void writeMDIOReg(int phy, int addr, int val);

/*
 * Reset the interface and configure it for continuous operation
 */
void mdioResetContinuous(void) {
  // No action needed for reset

  // FIXME: Set the extended control register to turn on/off the LEDs
} // mdioResetContinuous

/*
 * Show the status of the MDIO test when running in continuous mode
 *
 * Return -- boolean value indicating success
 */
int mdioShowStatusContinuous(void) {
  unsigned int max_num_of_tests = 8;
  bool all_tests_done;
  int i;

  unsigned int val;
  unsigned char test_en, test_done, test_fail;

  unsigned int fail_cnt;
  unsigned int fail_addr;
  unsigned long long fail_exp;
  unsigned long long fail_rd;

  int retry;

  int phy;

  int phyid_hi;
  int phyid_lo;
  int phyid;

  int auxstatus;

  int x, y;

  int good = 1;

  // Store the current screen position
  getyx(stdscr, y, x);

  // Move down a line
  move(y + 1, x);

  // Process the phys
  for (phy = 0; phy < MAX_PHY_PORTS; phy++) {
    // Read the PHY ID register
    phyid_hi = readMDIOReg(phy, MDIO_PHY_0_PHY_ID_HI_REG);
    phyid_lo = readMDIOReg(phy, MDIO_PHY_0_PHY_ID_LO_REG);

    phyid = (phyid_hi << 16) | phyid_lo;

    // Read the auxillary status
    auxstatus = readMDIOReg(phy, MDIO_PHY_0_AUX_STATUS_REG);

    // Work out whether the phy seems okay
    printw("     Phy %d:", phy + 1);
    if (phyid_hi < 0 || phyid_lo < 0) {
      printw(" Invalid PHY Id (Read failed)");
      good = 0;
    }
    else if ((phyid & 0xfffffff0) != 0x002060B0) { //Invalid PHY Id: 0x007f60b1   up, 1000Base-TX full
      printw(" Invalid PHY Id: 0x%08x", phyid);
      good = 0;
    }
    else {
      printw(" rev %d", phyid & 0xf);
    }

    // Display the Aux status
    if (auxstatus < 0) {
      printw("   Status: read fail");
    }
    else {
      printw("  ");
      printw(" %s", (auxstatus & 0x4) ? "up" : "down");
      switch ((auxstatus & 0x0700) >> 8) {
        case 0 : printw(", autoneg"); break;
        case 1 : printw(", 10Base-T half"); break;
        case 2 : printw(", 10Base-T full"); break;
        case 3 : printw(", 100Base-TX half"); break;
        case 4 : printw(", 100Base-T4"); break;
        case 5 : printw(", 100Base-TX full"); break;
        case 6 : printw(", 1000Base-TX half"); break;
        case 7 : printw(", 1000Base-TX full"); break;
      }
    }

    printw("\n");
  }

  // Print overall success/failure
  move(y, x);
  printw("MDIO test: %s", good ? "pass" : "fail");
  move(y + 1 + MAX_PHY_PORTS, x);

  return good;
} // mdioShowStatusContinuous

/*
 * Read an MDIO register.
 *
 * Return:  < 0 : read failed
 *         >= 0 : read result
 */
int readMDIOReg(int phy, int addr) {
  unsigned int val;
  int retry;

  // Perform the read
  retry = MDIO_READ_RETRIES;
  do {
    readReg(&nf2, phy * MDIO_PHY_GROUP_INST_OFFSET + addr, &val);
    retry--;
    usleep(1000);
  } while (retry > 0 && (val & 0x80000000));

  // Return the result -- either -1 on failure or the low 16 bits of the result
  if (val & 0x80000000)
    return -1;
  else
    return val & 0xffff;
} // readMDIOReg

/*
 * Write to an MDIO register
 */
void writeMDIOReg(int phy, int addr, int val) {
  writeReg(&nf2, phy * MDIO_PHY_GROUP_INST_OFFSET + addr, val & 0xffff);
}

/*
 * Stop the interface
 */
void mdioStopContinuous(void) {
  // No action needed for stop
} // mdioStopContinuous

/*
 * Get the success status of the test
 *
 * Return -- boolean value indicating success
 */
int mdioGetResult(void) {
  int phy;

  int phyid_hi;
  int phyid_lo;
  int phyid;

  int auxstatus;

  int good = 1;

  // Process the phys
  for (phy = 0; phy < MAX_PHY_PORTS; phy++) {
    // Read the PHY ID register
    phyid_hi = readMDIOReg(phy, MDIO_PHY_0_PHY_ID_HI_REG);
    phyid_lo = readMDIOReg(phy, MDIO_PHY_0_PHY_ID_LO_REG);

    phyid = (phyid_hi << 16) | phyid_lo;

    // Read the auxillary status
    auxstatus = readMDIOReg(phy, MDIO_PHY_0_AUX_STATUS_REG);

    // Work out whether the phy seems okay
    if (phyid_hi < 0 || phyid_lo < 0) {
      good = 0;
    }
    else if ((phyid & 0xfffffff0) != 0x002060B0) {
      good = 0;
    }
  }

  return good;
} // mdioGetResult

