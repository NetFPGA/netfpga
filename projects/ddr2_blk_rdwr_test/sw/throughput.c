
#include <stdlib.h>
#include <signal.h>
#include <curses.h>
#include <time.h>
#include <sys/types.h>
#include <stdio.h>
#include "../../../lib/C/common/nf2util.h"

#define DEFAULT_IFACE	                "nf2c0"
#define CPCI_CNET_CLK_SEL_REG           0x0000050
#define CPCI_CONTROL_REG                0x0000008
#define DDR2_SUCCESS_REG                0x0400000
#define DDR2_FAILURE_REG                0x0400004

static time_t start_time;
static int clk_rate_sel;
static int pkt_data_width_bits;

struct nf2device nf2;
WINDOW *w;

/*
 * Print Usage.
 */

void print_usage( char **argv ) {

  printf("Usage: %s <system clk frequency select> <pkt_data_width_bits>\n\n", argv[0]);
  printf("   <system clk frequency select> = [0 | 1].\n");
  printf("   use '0' for system clock rate 62.5 MHz, use '1' for 125 MHz\n\n");
  printf("   <pkt_data_width_bits> = [144 | 288].\n");
  printf("   use '144' if parameter PKT_DATA_WIDTH of Verilog module ddr2_blk_rdwr is 144,\n");
  printf("   use '288' if parameter PKT_DATA_WIDTH is 288.\n\n");
  printf("Allowed combinations of <system clk frequency select> and <pkt_data_width_bits>:\n");
  printf("   ------------------------------|-------------------------\n");
  printf("   <system clk frequency select> | <pkt_data_width_bits>\n");
  printf("                  0              |          288\n");
  printf("                  1              |          144\n");
  printf("                  1              |          288\n");
  printf("   ------------------------------|-------------------------\n\n");
}

/*
 * Process the arguments.
 */
void process_args (int argc, char **argv ) {
  if (argc != 3) {
    print_usage(argv);

    exit(1);
  }

  sscanf(argv[1], "%d", &clk_rate_sel);
  if ((clk_rate_sel != 0) && (clk_rate_sel != 1) ) {
    print_usage(argv);

    exit(1);
  }

  sscanf(argv[2], "%d", &pkt_data_width_bits);
  if ((pkt_data_width_bits != 144) && (pkt_data_width_bits != 288) ) {
    print_usage(argv);

    exit(1);
  }

  if (! ( ((clk_rate_sel==0) && (pkt_data_width_bits==288)) ||
	  ((clk_rate_sel==1) && (pkt_data_width_bits==144)) ||
	  ((clk_rate_sel==1) && (pkt_data_width_bits==288)) ) ) {
    print_usage(argv);

    exit(1);
  }

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
 * Display a title bar
 */
void title_bar(void) {
  attron(A_REVERSE);

  move(0,0);
  clear_line();
  move(0,20);
  printw("DDR2 Block Read/Write Test");

  move(1,0);
  clear_line();
  move(1,8);

  if (clk_rate_sel == 0)
    printw("(system clk rate 62.5 MHz, ");
  else
    printw("(system clk rate 125 MHz, ");

  if (pkt_data_width_bits==144)
    printw("pkt_data_width 144-bit)");
  else
    printw("pkt_data_width 288-bit)");

  attroff(A_REVERSE);
}

/*
 * Reset the board
 */
void reset_board(void) {
   u_int val;
   int   i;

   //set Virtex-II Pro clock rate
   writeReg(&nf2, CPCI_CNET_CLK_SEL_REG, clk_rate_sel); //0=62.5 MHz, 1=125 MHz
   //sleep 5 second
   usleep(5000000);

   /* Read the current value of the control register so that we can modify
    * it to do a reset */
   readReg(&nf2, CPCI_CONTROL_REG, &val);

   /* Write to the control register to reset it */
   writeReg(&nf2, CPCI_CONTROL_REG, val | 0x100);

}

/*
 * Handle SIGINT gracefully
 */
void sigint_handler(int signum) {
  if (signum == SIGINT) {
    endwin();

    // Close the network descriptor
    closeDescriptor(&nf2);

    printf("Caught SIGINT. Exiting...\n");
    exit(0);
  }
}

/*
 * Show the status of the DRAM test when running in continuous mode
 *
 * Return: boolean value indicating success
 */
int dram_continuous(void) {
  unsigned int iter;
  unsigned int good;
  unsigned int bad;

  unsigned int blk_size_in_bytes;
  double bw;

  time_t now;

  //sleep 1 sec.
  usleep(1000000);

  // Read the iteration counters
  readReg(&nf2, DDR2_SUCCESS_REG, &good);
  readReg(&nf2, DDR2_FAILURE_REG, &bad);
  iter = good + bad;

  // Get the current time
  now = time(NULL);

  // Calculate the bandwidth
  blk_size_in_bytes = (pkt_data_width_bits == 144) ? 2034 : 2016;
  bw = 32.0 * 1024.0 * blk_size_in_bytes * 8.0 * 2.0 * iter;
  bw /= (now - start_time) * 1e9;

  printw("DRAM block read/write test: Iteration: %d   Good: %d   Bad: %d\n",
	 iter, good, bad);
  printw("Throughput for user logic to access DRAM: %3.2f Gbps\n", bw);

  // Have we seen any failures
  return (good != 0 && bad == 0);

} // dramContinuous

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

  // Record the start time
  start_time = time(NULL);

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
    move(4,0);

    dram_continuous();

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

    // look for key presses
    count = 0;
    ch = ERR;
    while (count < 20 && ch != 'q' && ch != 'Q' && prev_lines == LINES && prev_cols == COLS) {
      ch = getch();
      count++;
    }
    if (ch == 'q' || ch == 'Q') {
      return;
    }
  }
}


/*
 * "Main" function for continuous mode
 */
void main_continuous(void)
{
  // Set up curses
  w = initscr();
  cbreak();
  halfdelay(1);
  noecho();

  // Run the test in continuous mode
  run_continuous();

  // End the curses
  endwin();
}


int main(int argc, char *argv[]) {

  process_args(argc, argv);

  // Set the default device
  nf2.device_name = DEFAULT_IFACE;

  // Check that the interface is valid and open it if possible
  if (check_iface(&nf2)) {
    exit(1);
  }
  if (openDescriptor(&nf2)) {
    exit(1);
  }

  // Add a signal handler
  signal(SIGINT, sigint_handler);

  // Run the appropriate test
  main_continuous();

  // Close the network descriptor
  closeDescriptor(&nf2);

  return 0;
}
