/*-
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * We are making the NetFPGA tools and associated documentation (Software)
 * available for public use and benefit with the expectation that others will
 * use, modify and enhance the Software and contribute those enhancements back
 * to the community. However, since we would like to make the Software
 * available for broadest use, with as few restrictions as possible permission
 * is hereby granted, free of charge, to any person obtaining a copy of this
 * Software) to deal in the Software under the copyrights without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any derivatives
 * without specific, written prior permission.
 */

/*
 * Module: nf2util.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for nf2 driver
 */

#include <linux/version.h>
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 8)
#include <linux/config.h>
#endif

#include <linux/kernel.h>
#include <linux/pci.h>
#include <linux/init.h>

#include "../common/nf2.h"
#include "nf2kernel.h"
#include "nf2util.h"

/**
 * nf2_hw_reset - Reset the HW
 * @card:	nf2 card
 *
 */
void nf2_hw_reset(struct nf2_card_priv *card)
{
	/* Reset the CPCI */
	iowrite32(RESET_CPCI, card->ioaddr + CPCI_REG_RESET);

	/* Reset the CNET */
	if (card->is_ctrl) {
		iowrite32(CTRL_CNET_RESET, card->ioaddr + CNET_REG_CTRL);
		iowrite32(CNET_RESET_MAC_3 |
				CNET_RESET_MAC_2 |
				CNET_RESET_MAC_1 |
				CNET_RESET_MAC_0,
				card->ioaddr + CNET_REG_RESET);

		/* Disable all MACs */
		iowrite32(0, card->ioaddr + CNET_REG_ENABLE);
	}

	/* Flush the writes */
	nf2_write_flush(card);
}

/**
 * nf2_reset_cpci - Reset the CPCI chip.
 * @card:	nf2 card
 *
 * Make sure to restore interrupts to their previous state
 */
void nf2_reset_cpci(struct nf2_card_priv *card)
{
	u32 intmask;

	intmask = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_MASK);
	iowrite32(RESET_CPCI, card->ioaddr + CPCI_REG_RESET);
	iowrite32(intmask, card->ioaddr + CPCI_REG_INTERRUPT_MASK);

	/* Flush the writes */
	nf2_write_flush(card);
}
