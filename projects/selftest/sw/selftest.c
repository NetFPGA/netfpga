/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest.c 6010 2010-03-14 08:24:50Z grg $
 *
 * Module: selftest.c
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
#include <sys/time.h>

#include <net/if.h>

#include <time.h>

#include <signal.h>

#include "../lib/C/reg_defines_selftest.h"
#include "../../cpci/lib/C/reg_defines_cpci.h"
#include "../../../lib/C/common/nf2util.h"
#include <curses.h>
#include "selftest.h"
#include "selftest_dram.h"
#include "selftest_sram.h"
#include "selftest_serial.h"
#include "selftest_phy.h"
#include "selftest_mdio.h"
#include "selftest_reg.h"
#include "selftest_clk.h"
#include "selftest_dma.h"

#define PATHLEN		80

#define DEFAULT_IFACE	"nf2c0"
#define SELFTEST_VERSION  "1.00 alpha"

#define ONE_SHOT_ITER   5

typedef enum {LOW = 0, HIGH = 1} SW_TEST_EFFORT_LEVEL;

/* Global vars */
struct nf2device nf2;
int verbose = 0;
int continuous = 0;
int shortrun = 1;
int no_sata_flg = 0;

FILE * log_file;
WINDOW *w;

/* Function declarations */
void mainContinuous(void);
void mainOneShot(void);
//void init_work(void);
void reset_tests(void);
//void show_stats (int loop_iter);
//bool show_status_serial_test(void);
//bool show_status_sram_test(void);
//bool show_status_dram_test(void);
//bool show_status_mii_test(void);
//bool show_status_phy_test(void);
//bool show_status_reg_test(void);
//void sram_sw_test(SW_TEST_EFFORT_LEVEL );
void processArgs (int, char **);
void usage (char*);
void run_continuous(void);
void reset_continuous(void);
void stop_continuous(void);
void sigint_handler(int signum);
void reset_board(void);
void title_bar(void);
void clear_line(void);

#define NUM_TESTS 8
/* Selftest module interface */
struct test_module modules[NUM_TESTS] = {
  {
    "Clock select",
    clkResetContinuous,
    clkShowStatusContinuous,
    clkStopContinuous,
    clkGetResult,
  },
  {
    "Register interface",
    regResetContinuous,
    regShowStatusContinuous,
    regStopContinuous,
    regGetResult,
  },
  {
    "MDIO interface",
    mdioResetContinuous,
    mdioShowStatusContinuous,
    mdioStopContinuous,
    mdioGetResult,
  },
  {
    "PHY interface",
    phyResetContinuous,
    phyShowStatusContinuous,
    phyStopContinuous,
    phyGetResult,
  },
  {
    "DRAM controller",
    dramResetContinuous,
    dramShowStatusContinuous,
    dramStopContinuous,
    dramGetResult,
  },
  {
    "SRAM controller",
    sramResetContinuous,
    sramShowStatusContinuous,
    sramStopContinuous,
    sramGetResult,
  },
  {
    "SATA controller",
    serialResetContinuous,
    serialShowStatusContinuous,
    serialStopContinuous,
    serialGetResult,
  },
  {
    "DMA interface",
    dmaResetContinuous,
    dmaShowStatusContinuous,
    dmaStopContinuous,
    dmaGetResult,
  },
};


/*
 * Main function
 */
int main(int argc, char *argv[])
{
  // Set the default device
  nf2.device_name = DEFAULT_IFACE;

  // Process the command line arguments
  processArgs(argc, argv);

  // Check that the interface is valid and open it if possible
  if (check_iface(&nf2))
  {
    exit(1);
  }
  if (openDescriptor(&nf2))
  {
    exit(1);
  }

  // Verify that the correct device is downloaded
  if (!checkVirtexBitfile(&nf2, DEVICE_PROJ_DIR,
			DEVICE_MAJOR, DEVICE_MINOR, VERSION_ANY,
			DEVICE_MAJOR, DEVICE_MINOR, VERSION_ANY)) {
    fprintf(stderr, "%s\n", getVirtexBitfileErr());
    exit(1);
  }
  else {
    printf(getDeviceInfoStr(&nf2));
  }

  // Add a signal handler
  signal(SIGINT, sigint_handler);

  // Measure the clock rates
  measureClocks();

  // Run the appropriate test
  if (continuous) {
    mainContinuous();
  }
  else if (shortrun) {
    mainOneShot();
  }

  // Close the network descriptor
  closeDescriptor(&nf2);

  return 0;
}

/*
 * "Main" function for continuous mode
 */
void mainContinuous(void)
{
  // Set up curses
  w = initscr();
  cbreak();
  halfdelay(1);
  noecho();

  //init_work(); //initialization. one time effort

  // Run the test in continuous mode
  run_continuous();
  stop_continuous();

  // End the curses
  endwin();
}

/*
 * "Main" function for one-shot mode
 */
void mainOneShot(void)
{
  int i;
  int failed = 0;

  // Reset the board and initialize the tests
  reset_board();
  reset_continuous();

  // Run the test in one-shot mode mode
  printf("NetFPGA selftest %s\n", SELFTEST_VERSION);
  printf("Running");
  fflush(stdout);
  for (i = 0; i < ONE_SHOT_ITER; i++) {
    sleep(1);
    printf(".");
    fflush(stdout);
  }
  printf(" ");

  // Verify the results
  for (i = 0; i < NUM_TESTS; i++) {
    if (!modules[i].get_result()) {
      if (!failed)
        printf("FAILED. Failing tests: ");
      else
        printf(", ");
      printf(modules[i].name);

      // Record that the tests have failed
      failed = 1;
    }
  }

  // Terminat the tests
  stop_continuous();

  // Check if the tests failed
  if (!failed)
    printf("PASSED\n");
  else
    printf("\n");
}

/*
 * Display a title bar
 */
void title_bar(void) {
  move(0,0);
  attron(A_REVERSE);
  clear_line();
  move(0,4);
  printw("NetFPGA selftest v%s", SELFTEST_VERSION);
  attroff(A_REVERSE);
}

/*
 * Clear a line
 */
void clear_line(void) {
  int n;

  n = COLS;
  for (; n > 0; n--)
      addch(' ');
}

/*
 * Run the program in continuous mode
 */
void run_continuous(void) {
  int ch = ERR;
  int count;
  int prev_lines;
  int prev_cols;
  int i;

  // Reset the board and initialize the tests
  reset_board();
  reset_continuous();


  // Run the tests continuously and wait
  while (1) {
    // Remember the screen dimensions
    prev_lines = LINES;
    prev_cols = COLS;

    // Clear the screen and move to the top corner
    erase();
    move(0,0);

    // Display a title bar
    title_bar();

    // Display the output of the tests
    move(2,0);

    for (i = 0; i < NUM_TESTS; i++) {
      modules[i].show_status_continuous();
    }

    // Display a footer bar
    move(LINES - 1, 0);
    clear_line();
    move(LINES - 1, 0);
    attron(A_REVERSE);
    printw("Q");
    attroff(A_REVERSE);
    printw(" Quit");
    move(LINES - 2,0);

    // Draw the screen
    refresh();

    // Sleep for a while, looking for key presses
    count = 0;
    ch = ERR;
    while (count < 10 && ch != 'q' && ch != 'Q' && prev_lines == LINES && prev_cols == COLS) {
      ch = getch();
      count++;
    }
    if (ch == 'q' || ch == 'Q') {
      return;
    }
  }
}

/*
 * Reset the board
 */
void reset_board(void) {
   u_int val;

   /* Read the current value of the control register so that we can modify
    * it to do a reset */
   readReg(&nf2, CPCI_CTRL_REG, &val);

   /* Write to the control register to reset it */
   writeReg(&nf2, CPCI_CTRL_REG, val | CPCI_CTRL_CNET_RESET);
}

/*
 * Handle SIGINT gracefully
 */
void sigint_handler(int signum) {
  if (signum == SIGINT) {
    endwin();

    if (continuous)
      stop_continuous();

    printf("Caught SIGINT. Exiting...\n");
    exit(0);
  }
}

/*
 * Invoke the reset functions for continuous mode
 */
void reset_continuous(void) {
  int i;

  for (i = 0; i < NUM_TESTS; i++) {
    modules[i].reset_continuous();
  }
}

/*
 * Invoke the stop functions for continuous mode
 */
void stop_continuous(void) {
  int i;

  for (i = 0; i < NUM_TESTS; i++) {
    modules[i].stop_continuous();
  }
}

//initialize. this is one time effort
/*void init_work() {
  struct timeval tv;
  struct timezone tz;

  gettimeofday(&tv, &tz);

  long int sram_tst_seed = tv.tv_sec;
  srand48(sram_tst_seed);

  log_file = fopen("selftest.log", "a");
  fprintf(log_file, "sram h/w random test seed = %ld\n", sram_tst_seed);
}*/

// Reset the status of all tests
void reset_tests(void) {
  unsigned int val;
  int i;

  unsigned int data1, data2;
  move(10,0);

  // program h/w random test with a different test seed for each iteration
  data1 = lrand48();
  data2 = lrand48();
  writeReg(&nf2, SRAM_TEST_RAND_SEED_HI_REG, data1 & 0xf);
  writeReg(&nf2, SRAM_TEST_RAND_SEED_LO_REG, data2);

  writeReg(&nf2, SRAM_TEST_EN_REG,
      SRAM_TEST_ENABLE_TEST_EN_MASK |
      SRAM_TEST_ENABLE_SRAM_EN_MASK);
  writeReg(&nf2, DRAM_TEST_EN_REG, DRAM_TEST_ENABLE_ENABLE_MASK);
  writeReg(&nf2, DRAM_TEST_CTRL_REG, 0x0);
  usleep(100000);
  writeReg(&nf2, DRAM_TEST_CTRL_REG, DRAM_TEST_CTRL_REPEAT);

  writeReg(&nf2, SERIAL_TEST_CTRL_REG, SERIAL_TEST_GLBL_CTRL_RESTART);
  //writeReg(&nf2, SERIAL_TEST_CTRL_REG, SERIAL_TEST_GLBL_CTRL_NONSTOP);
  writeReg(&nf2, SERIAL_TEST_CTRL_REG, 0);
  writeReg(&nf2, SERIAL_TEST_CTRL_0_REG, 0);
  writeReg(&nf2, SERIAL_TEST_CTRL_1_REG, 0);
}


/*
 * Process the arguments.
 */
void processArgs (int argc, char **argv ) {

   char c;

   /* set defaults */
   verbose = 0;

   /* don't want getopt to moan - I can do that just fine thanks! */
   opterr = 0;
   while ((c = getopt (argc, argv, "csi:n")) != -1)
      switch (c)
	 {
	 case 'c':
	    continuous = 1;
	    shortrun = 0;
	    break;
	 case 's':
	    shortrun = 1;
	    continuous = 0;
	    break;
//	 case 'v':
//	    verbose = 1;
//	    break;
//	 case 'l':   /* log file */
//	    log_file_name = optarg;
//	    break;
	 case 'i':   /* interface name */
	    nf2.device_name = optarg;
	    break;
   case 'n': /* without SATA test */
      no_sata_flg = 1;
      break;
	 case '?':
	    if (isprint (optopt))
               fprintf (stderr, "Unknown option `-%c'.\n", optopt);
	    else
               fprintf (stderr,
                        "Unknown option character `\\x%x'.\n",
                        optopt);
	 default:
	    usage(argv[0]);
	    exit(1);
	 }

//   if (verbose) {
//      printf ("logfile = %s.   bin file = %s\n", log_file_name, bin_file_name);
//   }

}

/*
 * Describe usage of this program.
 */
void usage (char *prog) {
   printf("Usage: %s <options>  [filename.bin | filename.bit]\n", prog);
   printf("\nOptions: -l <logfile> (default is stdout).\n");
   printf("         -i <iface> : interface name.\n");
   printf("         -v : be verbose.\n");
   printf("         -c : run continuously\n");
   printf("         -s : short test mode\n");
   printf("         -n : disable SATA testing\n");
}


