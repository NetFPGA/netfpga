/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 * $Id$
 *
 * Module: selftest_sram.h
 * Project: NetFPGA selftest
 * Description: DMA selftest module
 *
 * Change history:
 *
 */

#ifndef _SELFTEST_DMA_H
#define _SELFTEST_DMA_H        1

// DMA_PKT_LEN (excluding CRC) must be no more than 1514 bytes
// for MTU constraint
#define DMA_PKT_LEN 1514
#define DMA_READ_BUF_SIZE (DMA_PKT_LEN+1)
#define DMA_WRITE_BUF_SIZE (DMA_PKT_LEN+1)

void dmaResetContinuous(void);
int dmaShowStatusContinuous(void);
void dmaStopContinuous(void);
int dmaGetResult(void);

#endif
