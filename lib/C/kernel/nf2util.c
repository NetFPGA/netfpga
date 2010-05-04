/* ****************************************************************************
 *
 * Module: nf2util.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Utility functions for nf2 driver
 *
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
