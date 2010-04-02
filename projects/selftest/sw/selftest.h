/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id: selftest.h 2016 2007-07-24 20:24:15Z grg $
 *
 * Module: selftest.h
 * Project: NetFPGA selftest software
 * Description:
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_H
#define _SELFTEST_H	1

/*
 * The NF2 structure for all files to use
 */
extern struct nf2device nf2;

/*
 * Define a structure for a test interface
 *
 * Fields:
 *   name : module name
 *   reset_continuous : reset the interface and prepare for continuous testing
 *                      mode
 *   show_status_continuous : show the status of the continuous test
 */
struct test_module {
  char *name;
  void (*reset_continuous) (void);
  int (*show_status_continuous) (void);
  void (*stop_continuous) (void);
  int (*get_result) (void);
};

#endif
