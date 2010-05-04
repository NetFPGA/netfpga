/* ****************************************************************************
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
