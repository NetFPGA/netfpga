/* ****************************************************************************
 * $Id: nf2util.h 3546 2008-04-03 00:12:27Z grg $
 *
 * Module: nf2util.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for nf2 driver
 *
 */

#ifndef _NF2UTIL_H
#define _NF2UTIL_H	1

#ifdef __KERNEL__

/*
 * Flush previous PCI writes through intermediate bridges
 * by doing a benign read
 */
static inline void nf2_write_flush(struct nf2_card_priv *card)
{
	(void)ioread32(card->ioaddr);
}

/*
 * Enable interrupts
 */
static inline void nf2_enable_irq(struct nf2_card_priv *card)
{
	iowrite32(0x00000000, card->ioaddr + CPCI_REG_INTERRUPT_MASK);
	nf2_write_flush(card);
}

/*
 * Disable interrupts
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
