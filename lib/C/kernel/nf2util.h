/*
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
 *
 * Module: nf2util.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for nf2 driver
 *
 */

#ifndef _NF2UTIL_H
#define _NF2UTIL_H	1

#ifdef __KERNEL__

/**
 * nf2_write_flush - flush PCI write
 * @card:	nf2 card
 *
 * Flush previous PCI writes through intermediate bridges
 * by doing a benign read
 */
static inline void nf2_write_flush(struct nf2_card_priv *card)
{
	(void)ioread32(card->ioaddr);
}

/**
 * nf2_enable_irq - Enable interrupts
 * @card:	nf2 card
 *
 */
static inline void nf2_enable_irq(struct nf2_card_priv *card)
{
	iowrite32(0x00000000, card->ioaddr + CPCI_REG_INTERRUPT_MASK);
	nf2_write_flush(card);
}

/**
 * nf2_disable_irq - Disable interrupts
 * @card:	nf2 card
 *
 */
static inline void nf2_disable_irq(struct nf2_card_priv *card)
{
	iowrite32(0xFFFFFFFF, card->ioaddr + CPCI_REG_INTERRUPT_MASK);
	nf2_write_flush(card);
}

void nf2_hw_reset(struct nf2_card_priv *card);
void nf2_reset_cpci(struct nf2_card_priv *card);

#endif /* __KERNEL__ */
#endif /* _NF2UTIL_H */
