/*
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 * Copyright (c) 2010 Paul Rodman <rodman@google.com>
 * Copyright (c) 2010 Maciej Żenczykowski <maze@google.com>
 *
 * Author: Glen Gibb <grg@stanford.edu>
 *         Jad Naous <jnaous@stanford.edu>
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

/* ****************************************************************************
 * Module: nf2_util.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Control card functionality
 *
 * Change history:
 *   3/10/10 - Paul Rodman & Maciej Żenczykowski
 *                           Added support for kernels 2.6.31 and beyond
 *                           (net_device api deprecated)
 *   7/8/2008 - Jad Naous: - fixed problem with newer kenrels where SA_SHIRQ is
 *                           not defined
 *                         - Fixed various warnings
 *
 * To Do: - Check that the timeout handler works okay when multiple ports
 *          are enabled
 *
 */

#include <linux/version.h>
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 8)
#include <linux/config.h>
#endif

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/init.h>
#include <linux/interrupt.h>

#include <linux/in.h>
#include <linux/netdevice.h>   /* struct device, and other headers */
#include <linux/etherdevice.h> /* eth_type_trans */
#include <linux/if_ether.h>

#include <asm/io.h>
#include <asm/uaccess.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 26)
#include <linux/semaphore.h>
#else
#include <asm/semaphore.h>
#endif

#include "../common/nf2.h"
#include "nf2kernel.h"
#include "nf2util.h"
#include "nf2_export.h"

#define KERN_DFLT_DEBUG KERN_INFO

/* JN: If we are working with an older kernel, it would probably
 * still use the SA_SHIRQ */
#ifndef IRQF_SHARED
#define IRQF_SHARED SA_SHIRQ
#endif

/* Control card device number */
static int devnum;

/* Function declarations */
static int nf2c_send(struct net_device *dev);
static void nf2c_rx(struct net_device *dev, struct nf2_packet *pkt);
static int nf2c_create_pool(struct nf2_card_priv *card);
static void nf2c_destroy_pool(struct nf2_card_priv *card);
static irqreturn_t nf2c_intr(int irq, void *dev_id
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 19)
			, struct pt_regs *regs
#endif
			);

static void nf2c_clear_dma_flags(struct nf2_card_priv *card);
static void nf2c_check_link_status(struct nf2_card_priv *card,
		struct net_device *dev, unsigned int ifnum);

/**
 * nf2c_open - open method called when the interface is brought up
 * @dev:	Net device
 *
 * Locking: state_lock - prevent the state variable and the corresponding
 *                       register from getting out of sync
 */
static int nf2c_open(struct net_device *dev)
{
	int err = 0;
	u32 mac_reset;
	u32 enable;
	struct nf2_iface_priv *iface =
		(struct nf2_iface_priv *)netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;

	PDEBUG(KERN_DFLT_DEBUG "nf2: bringing up card\n");

	/* Aquire the mutex for the state variables */
	if (down_interruptible(&card->state_lock))
		return -ERESTARTSYS;

	/* Tell the driver the carrier is down... */
	netif_carrier_off(dev);

	/* Check if any other interfaces are active.
	 * If no other interfaces are up install the IRQ handler
	 * Always attach the interrupt to the first device in the pool
	 */
	if (!card->ifup) {
		nf2_hw_reset(card);
		err = request_irq(card->pdev->irq, nf2c_intr, IRQF_SHARED,
				card->ndev[0]->name, card->ndev[0]);
		if (err)
			goto out;
		nf2_enable_irq(card);
	}

	/* Modify the ifup flag */
	card->ifup |= 1 << iface->iface;
	PDEBUG(KERN_DFLT_DEBUG "nf2: ifup: %x\n", card->ifup);

	/* Perform the necessary actions to enable the MAC */
	mac_reset = CNET_RESET_MAC_0 << iface->iface;
	iowrite32(mac_reset, card->ioaddr + CNET_REG_RESET);

	enable = ioread32(card->ioaddr + CNET_REG_ENABLE);
	enable |= (CNET_ENABLE_RX_FIFO_0 | CNET_ENABLE_TX_MAC_0) <<
		iface->iface |
		CNET_ENABLE_INGRESS_ARBITER |
		CNET_ENABLE_RX_DMA;
	iowrite32(enable, card->ioaddr + CNET_REG_ENABLE);

	/* We don't have means to access phy registers to check their link
	 * status until CNET bitfile has been downloaded
	 * Assumption is carrier on (as same as previous version of this
	 * code).
	 *
	 *  netif_carrier_on(dev);
	 *
	 *  Since, nf2_download enables PHY interrupts, no need to do
	 *  netif_carrier_on here
	 */


	netif_wake_queue(dev);

out:
	up(&card->state_lock);
	return err;
}

/**
 * nf2c_release - release method called when the interface is brought down
 * @dev:	Net device
 *
 * Locking: state_lock - prevent the state variable and the corresponding
 *                       register from getting out of sync
 *
 *          no locking for txbuff variables as other functions that modify
 *          these variables will not execute concurrently if nf2c_release
 *          has been called
 */
static int nf2c_release(struct net_device *dev)
{
	u32 mac_reset;
	u32 enable;
	struct nf2_iface_priv *iface =
		(struct nf2_iface_priv *)netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;

	/* Aquire the mutex for the state variables */
	if (down_interruptible(&card->state_lock))
		return -ERESTARTSYS;

	/* Prevent transmission at the software level */
	netif_carrier_off(dev);
	netif_stop_queue(dev);

	/* Perform the necessary actions to disable the MAC */
	enable = ioread32(card->ioaddr + CNET_REG_ENABLE);
	enable &= ~((CNET_ENABLE_RX_FIFO_0 | CNET_ENABLE_TX_MAC_0) <<
			iface->iface);
	iowrite32(enable, card->ioaddr + CNET_REG_ENABLE);

	mac_reset = CNET_RESET_MAC_0 << iface->iface;
	iowrite32(mac_reset, card->ioaddr + CNET_REG_RESET);

	/* Update the ifup flag */
	card->ifup &= ~(1 << iface->iface);
	PDEBUG(KERN_ALERT "nf2: ifup: %x\n", card->ifup);

	/* Check if any other interfaces are active.
	 * If no other interfaces are up uninstall the IRQ handler
	 */
	if (!card->ifup) {
		free_irq(card->pdev->irq, card->ndev[0]);
		nf2_hw_reset(card);
		/* No need to call nf2_disable_irq(card) as the reset will
		 * disable the interrupts */

		/* Free any skb's in the transmit queue */
		if (card->free_txbuffs != tx_pool_size) {
			if (atomic_read(&card->dma_tx_in_progress))
				pci_unmap_single(card->pdev,
					card->dma_tx_addr,
					card->txbuff[card->rd_txbuff].skb->len,
					PCI_DMA_TODEVICE);

			while (card->free_txbuffs < tx_pool_size) {
				dev_kfree_skb(
					card->txbuff[card->rd_txbuff].skb);
				card->rd_txbuff = (card->rd_txbuff + 1) %
						  tx_pool_size;
				card->free_txbuffs++;
			}
		}
		atomic_set(&card->dma_tx_in_progress, 0);
		atomic_set(&card->dma_rx_in_progress, 0);
	}

	PDEBUG(KERN_DFLT_DEBUG "nf2: Queue stopped\n");

	up(&card->state_lock);
	return 0;
}

/**
 * nf2c_config - Configuration changes (passed on by ifconfig)
 * @dev:	Net device
 * @map:	ifmap
 *
 */
static int nf2c_config(struct net_device *dev, struct ifmap *map)
{
	if (dev->flags & IFF_UP) /* can't act on a running interface */
		return -EBUSY;

	/* Don't allow changing the I/O address */
	if (map->base_addr != dev->base_addr) {
		printk(KERN_WARNING "nf2: Can't change I/O address\n");
		return -EOPNOTSUPP;
	}

	/* Allow changing the IRQ */
	if (map->irq != dev->irq) {
		printk(KERN_WARNING "nf2: Can't change IRQ\n");
		return -EOPNOTSUPP;
	}

	/* ignore other fields */
	return 0;
}

/**
 * nf2c_tx - Transmit a packet (called by the kernel)
 * @skb:	socket buffer
 * @dev:	net device
 *
 */
static int nf2c_tx(struct sk_buff *skb, struct net_device *dev)
{
	int err = 0;
	unsigned long flags;
	struct nf2_iface_priv *iface = netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;

	/* Aquire a spinlock for the buffs vbles */
	spin_lock_irqsave(&card->txbuff_lock, flags);

	if (card->free_txbuffs == 0) {
		if (printk_ratelimit())
			printk(KERN_ALERT "nf2: no available transmit/receive"
					" buffers\n");
		err = 1;
	} else {
		card->txbuff[card->wr_txbuff].skb = skb;
		card->txbuff[card->wr_txbuff].iface = iface->iface;
		card->wr_txbuff = (card->wr_txbuff + 1) % tx_pool_size;
		card->free_txbuffs--;
		card->free_txbuffs_port[iface->iface]--;

		/* Stop the queue if the number of txbuffs drops to 0 */
		if (card->free_txbuffs_port[iface->iface] == 0) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: stopping queue %d\n",
					iface->iface);
			netif_stop_queue(dev);
		}

		/* Attempt to send the actual packet */
		nf2c_send(dev);

		/* save the timestamp */
		dev->trans_start = jiffies;
	}

	/*err_unlock:*/
	spin_unlock_irqrestore(&card->txbuff_lock, flags);

	return err;
}

/**
 * nf2c_send - Send an actual packet
 * @dev:	net device
 *
 * Atomic variable dma_tx_lock is used to prevent multiple packets from
 * being sent simultaneously (the hardware can only transfer one at once)
 *
 * Note: The txbuff lock is not used as an incorrect read of free_txbuffs is
 *       not fatal (this function will be called again).
 */
static int nf2c_send(struct net_device *dev)
{
	int err = 0;
	int dma_len = 0;
	/*unsigned long flags;*/
	struct nf2_iface_priv *iface = netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;
	struct sk_buff *skb;
	unsigned int rd_iface;  /* iface of skb at front of Q*/

	/* Aquire a spinlock for the dma variables */
	/*spin_lock_irqsave(&card->dma_tx_lock, flags);*/

	/* Check if a DMA transfer is in progress and record the fact that
	 * we have started a transfer
	 */
	if (atomic_add_return(1, &card->dma_tx_in_progress) != 1) {
		atomic_dec(&card->dma_tx_in_progress);
		err = 1;
		goto err_unlock;
	}

	/* Check if there's something to send */
	if (card->free_txbuffs == tx_pool_size) {
		atomic_dec(&card->dma_tx_in_progress);
		err = 1;
		goto err_unlock;
	}

	/* Get the interface number of the skb we are sending. */
	rd_iface = card->txbuff[card->rd_txbuff].iface;

	/* Verify that the TX queue can accept a packet */
	if ((card->dma_can_wr_pkt & (1 << rd_iface)) == 0) {
		atomic_dec(&card->dma_tx_in_progress);
		err = 1;
		goto err_unlock;
	}

	/* Grab the skb */
	skb = card->txbuff[card->rd_txbuff].skb;

	/* Map the buffer into DMA space */
	card->dma_tx_addr = pci_map_single(card->pdev,
			skb->data, skb->len, PCI_DMA_TODEVICE);

	/* Start the transfer */
	iowrite32(card->dma_tx_addr,
			card->ioaddr + CPCI_REG_DMA_E_ADDR);

	/* Pad the skb to be at least 60 bytes. Call the padding function
	 * to ensure that there is no information leakage */
	if (skb->len < 60) {
		skb_pad(skb, 60 - skb->len);
		dma_len = 60;
	} else {
		dma_len = skb->len;
	}
	iowrite32(dma_len,
			card->ioaddr + CPCI_REG_DMA_E_SIZE);

	iowrite32(NF2_SET_DMA_CTRL_MAC(rd_iface) | DMA_CTRL_OWNER,
			card->ioaddr + CPCI_REG_DMA_E_CTRL);

	PDEBUG(KERN_DFLT_DEBUG "nf2: sending DMA pkt to iface: %d\n",
			rd_iface);

err_unlock:
	/*spin_unlock_irqrestore(&priv->card->dma_tx_lock, flags);*/

	return err;
}

/**
 * nf2c_rx - Receive a packet: retrieve, encapsulate,pass over to upper levels
 * @dev:	net device
 * @pkt:	nf2 packet
 *
 * Note: This is called from the interrupt handler. netif_rx schedules
 * the skb to be delivered to the kernel later (ie. bottom-half delivery).
 */
static void nf2c_rx(struct net_device *dev, struct nf2_packet *pkt)
{
	struct sk_buff *skb;
	struct nf2_iface_priv *iface = netdev_priv(dev);

	/*
	 * The packet has been retrieved from the transmission
	 * medium. Build an skb around it, so upper layers can handle it
	 */
	skb = dev_alloc_skb(pkt->len + 2);
	if (!skb) {
		if (printk_ratelimit())
			printk(KERN_NOTICE "nf2 rx: low on mem - packet"
					" dropped\n");
		iface->stats.rx_dropped++;
		goto out;
	}

	skb_reserve(skb, 2); /* align IP on 16B boundary */
	memcpy(skb_put(skb, pkt->len), pkt->data, pkt->len);

	/* Write metadata, and then pass to the receive level */
	skb->dev = dev;
	skb->protocol = eth_type_trans(skb, dev);
	skb->ip_summed = CHECKSUM_NONE; /* Check the checksum */
	iface->stats.rx_packets++;
	iface->stats.rx_bytes += pkt->len;
	netif_rx(skb);

out:
	return;
}

/**
 * nf2c_clear_dma_flags - Clear the DMA flags
 * @card: nf2 card private data
 *
 * clear the dma flags that record that a DMA transfer is in progress
 */
static void nf2c_clear_dma_flags(struct nf2_card_priv *card)
{
	unsigned long flags;
	unsigned int ifnum;

	PDEBUG(KERN_DFLT_DEBUG "nf2: clearing dma flags\n");

	/* Clear the dma_rx_in_progress flag */
	if (atomic_read(&card->dma_rx_in_progress)) {
		pci_unmap_single(card->pdev, card->dma_rx_addr,
				MAX_DMA_LEN,
				PCI_DMA_FROMDEVICE);

		atomic_dec(&card->dma_rx_in_progress);
	}

	/* Clear the dma_tx_in_progress flag
	 * Note: also frees the skb */
	if (atomic_read(&card->dma_tx_in_progress)) {
		pci_unmap_single(card->pdev, card->dma_tx_addr,
				card->txbuff[card->rd_txbuff].skb->len,
				PCI_DMA_TODEVICE);

		/* Aquire a spinlock for the buffs vbles */
		spin_lock_irqsave(&card->txbuff_lock, flags);

		/* Free the skb */
		dev_kfree_skb_irq(card->txbuff[card->rd_txbuff].skb);

		/* Note: make sure that txbuffs is incremented before
		 * dma_tx_in_progress is decremented due to the lack of
		 * locking in nf2c_send()
		 */
		ifnum = card->txbuff[card->rd_txbuff].iface;
		card->rd_txbuff = (card->rd_txbuff + 1) % tx_pool_size;
		card->free_txbuffs++;
		card->free_txbuffs_port[ifnum]++;
		atomic_dec(&card->dma_tx_in_progress);

		/* Re-enable the queues if necessary */
		if (card->free_txbuffs_port[ifnum] == 1)
			netif_wake_queue(card->ndev[ifnum]);

		spin_unlock_irqrestore(&card->txbuff_lock, flags);
	}
}

/**
 * nf2c_ioctl - Handle ioctl calls
 * @dev:	net device
 * @rq:		ifreq structure
 * @cmd:	ioctl cmd
 *
 */
static int nf2c_ioctl(struct net_device *dev, struct ifreq *rq, int cmd)
{
	struct nf2reg reg;
	struct mii_ioctl_data *data = if_mii(rq);
	u32 phy_id_lo, phy_id_hi, phy_id;

	struct nf2_iface_priv *iface =
		(struct nf2_iface_priv *)netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;


	switch (cmd) {
		/* Read a register */
	case SIOCREGREAD:
			if (copy_from_user(&reg, rq->ifr_data,
						sizeof(struct nf2reg))) {
				printk(KERN_ERR "nf2: Unable to copy data from"
						" user space\n");
				return -EFAULT;
			}

			nf2k_reg_read(dev, reg.reg, &reg.val);

			if (copy_to_user(rq->ifr_data, &reg,
						sizeof(struct nf2reg))) {
				printk(KERN_ERR "nf2: Unable to copy data to "
						"user space\n");
				return -EFAULT;
			}
			return 0;

			/* Write a register */
	case SIOCREGWRITE:
			if (copy_from_user(&reg, rq->ifr_data,
						sizeof(struct nf2reg))) {
				printk(KERN_ERR "nf2: Unable to copy data from "
						"user space\n");
				return -EFAULT;
			}

			nf2k_reg_write(dev, reg.reg, &(reg.val));
			return 0;

			/* Read address of MII PHY in use */
	case SIOCGMIIPHY:
			phy_id_lo = ioread32(card->ioaddr +
					MDIO_0_PHY_ID_LO_REG +
					(ADDRESS_DELTA * (iface->iface)));
			phy_id_hi = ioread32(card->ioaddr +
					MDIO_0_PHY_ID_HI_REG +
					(ADDRESS_DELTA * (iface->iface)));
			phy_id = (phy_id_hi << 16) | phy_id_lo;
			data->phy_id = phy_id;
			return 0;

			/* Read an MII register */
	case SIOCGMIIREG:
			data->val_out = ioread32(card->ioaddr +
					MDIO_0_BASE + (ADDRESS_DELTA *
						(iface->iface)) +
					data->reg_num);
			return 0;

	default:
			return -EOPNOTSUPP;
	}

	/* Should never reach here, but anyway :) */
	return -EOPNOTSUPP;
}

/**
 * nf2k_reg_read - handle register reads
 * @dev:	net device
 * @addr:	address
 * @data:	the data
 *
 */
int nf2k_reg_read(struct net_device *dev, unsigned int addr, void* data)
{
	struct nf2_iface_priv *iface = netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;
	void *from_addr = card->ioaddr + addr;

	if (!data) {
		printk(KERN_WARNING "nf2:  WARNING: register read with data "
				"address 0 requested\n");
		return 1;
	}

	if (!card->ioaddr) {
		printk(KERN_WARNING "nf2:  WARNING: card IO address is NULL "
				"during register read\n");
		return 1;
	}

	if (addr >= pci_resource_len(card->pdev, 0)) {
		printk(KERN_ERR "nf2:  ERROR: address exceeds bounds (0x%lx) "
			"during register read\n",
			(long unsigned int)pci_resource_len(card->pdev, 0) - 1);
		return 1;
	}

	memcpy_fromio(data, from_addr, sizeof(uint32_t));

	return 0;
}
EXPORT_SYMBOL(nf2k_reg_read);

/**
 * nf2k_reg_write - handle register writes
 * @dev:	net device
 * @addr:	address
 * @data:	the data
 *
 */
int nf2k_reg_write(struct net_device *dev, unsigned int addr, void* data)
{
	struct nf2_iface_priv *iface = netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;
	void *to_addr = card->ioaddr + addr;

	if (!data) {
		printk(KERN_WARNING "nf2:  WARNING: register write with data"
				" address 0 requested\n");
		return 1;
	}

	if (!card->ioaddr) {
		printk(KERN_WARNING "nf2:  WARNING: card IO address is NULL "
				"during register write\n");
		return 1;
	}

	if (addr >= pci_resource_len(card->pdev, 0)) {
		printk(KERN_ERR "nf2:  ERROR: address exceeds bounds (0x%lx) "
			"during register write\n",
			(long unsigned int)pci_resource_len(card->pdev, 0) - 1);
		return 1;
	}

	memcpy_toio(to_addr, data, sizeof(uint32_t));

	return 0;
}
EXPORT_SYMBOL(nf2k_reg_write);


/**
 * nf2c_stats - Return statistics to the caller
 * @dev:	net device
 *
 */
static struct net_device_stats *nf2c_stats(struct net_device *dev)
{
	struct nf2_iface_priv *iface = netdev_priv(dev);
	return &iface->stats;
}

/*
 * Set the MAC address of the interface
 */
static int nf2c_set_mac_address(struct net_device *dev, void *a)
{
	struct sockaddr *addr = (struct sockaddr *) a;

	/* Verify that the address is valid */
	if (!is_valid_ether_addr(addr->sa_data))
		return -EADDRNOTAVAIL;

	/* Copy the MAC address into the dev */
	memcpy(dev->dev_addr, addr->sa_data, dev->addr_len);

	return 0;
}

/*
 * Deal with a transmit timeout.
 *
 * FIXME: Consider adding locking to protect the enable register
 * (what if ifup is modified while this function is executing?)
 * Also What happens if this is executed while the ISR is running?
 * We need a lock on the intmask reg.
 */
static void nf2c_tx_timeout(struct net_device *dev)
{
	struct nf2_iface_priv *iface = netdev_priv(dev);
	struct nf2_card_priv *card = iface->card;
	u32 enable, intmask;

	printk(KERN_ALERT "nf2: Transmit timeout on %s at %lu, latency %lu\n",
			dev->name, jiffies, jiffies - dev->trans_start);

	iface->stats.tx_errors++;

	/* Read the current status of enable and interrupt mask registers */
	enable = ioread32(card->ioaddr + CNET_REG_ENABLE);
	intmask = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_MASK);

	/* Reset the card! */
	nf2_hw_reset(card);

	/* Write the status of the enable registers */
	iowrite32(enable, card->ioaddr + CNET_REG_ENABLE);
	iowrite32(intmask, card->ioaddr + CPCI_REG_INTERRUPT_MASK);

	/* Clear the DMA flags */
	nf2c_clear_dma_flags(card);

	/* Call the send function if there's packets to send */
	if (card->free_txbuffs != tx_pool_size)
		nf2c_send(dev);

	/* Wake the stalled queue */
	netif_wake_queue(dev);
	return;
}

/**
 * nf2c_intr - Handle an interrupt
 * @irq:	Irq number
 * @dev_id:	devicd id
 * @regs:	regs
 *
 * Note: Keep this as short as possible!
 */
static irqreturn_t nf2c_intr(int irq, void *dev_id
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 19)
			, struct pt_regs *regs
#endif
			)
{

	struct net_device *netdev = dev_id;
	struct nf2_iface_priv *iface = netdev_priv(netdev);
	struct nf2_card_priv *card = iface->card;
	struct nf2_iface_priv *tx_iface;
	unsigned long flags;
	unsigned int ifnum;
	u32 err;
	u32 ctrl;
	u32 status;
	u32 status_orig;
	u32 prog_status;
	u32 int_mask;
	u32 cnet_err;

	unsigned int phy_intr_status;
	int i;

	/* get the interrupt mask */
	int_mask = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_MASK);

	/* disable interrupts so we don't get race conditions */
	nf2_disable_irq(card);
	smp_mb();

	/* Grab the interrupt status */
	status_orig = status = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_STATUS);

	if (status) {
		PDEBUG(KERN_DFLT_DEBUG "nf2: intr mask vector: 0x%08x\n", int_mask);
		PDEBUG(KERN_DFLT_DEBUG "nf2: intr status vector: 0x%08x\n", status);
	}

	/* only consider bits that are not masked plus INT_PKT_AVAIL*/
	status &= ~(int_mask & ~INT_PKT_AVAIL);

	/* Check if the interrrupt was generated by us */
	if (status) {
		PDEBUG(KERN_DFLT_DEBUG "nf2: intr to be handled: 0x%08x\n",
				status);

		/* Handle queue status change */
		if (status & INT_DMA_QUEUE_STATUS_CHANGE) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: intr: "
					"INT_DMA_QUEUE_STATUS_CHANGE\n");

			card->dma_can_wr_pkt =
				ioread32(card->ioaddr +
					CPCI_REG_DMA_QUEUE_STATUS) & 0xffff;
			PDEBUG(KERN_DFLT_DEBUG "nf2: can_wr_pkt status: 0x%04x\n",
					card->dma_can_wr_pkt);

			/* Call the send function if there are other
			 * packets to send */
			if (atomic_add_return(1, &card->dma_rx_in_progress) == 1) {
				if (card->free_txbuffs != tx_pool_size)
					nf2c_send(netdev);
			}
			atomic_dec(&card->dma_rx_in_progress);
		}

		/* Handle packet RX complete
		 * Note: don't care about the rx pool here as the packet is
		 * copied to an skb immediately so there is no need to have
		 * multiple packets in the rx pool
		 */
		if (status & INT_DMA_RX_COMPLETE) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: intr: "
					"INT_DMA_RX_COMPLETE\n");

			pci_unmap_single(card->pdev, card->dma_rx_addr,
					MAX_DMA_LEN,
					PCI_DMA_FROMDEVICE);

			card->wr_pool->len = ioread32(card->ioaddr +
					CPCI_REG_DMA_I_SIZE);

			ctrl = ioread32(card->ioaddr + CPCI_REG_DMA_I_CTRL);
			card->wr_pool->dev = card->ndev[(ctrl & 0x300) >> 8];

			atomic_dec(&card->dma_rx_in_progress);

			nf2c_rx(card->wr_pool->dev, card->wr_pool);

			/* reenable PKT_AVAIL interrupts */
			int_mask &= ~INT_PKT_AVAIL;
		}

		/* Handle packet TX complete */
		if (status & INT_DMA_TX_COMPLETE) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: intr: "
					"INT_DMA_TX_COMPLETE\n");

			/* make sure there is a tx dma in progress */
			if (atomic_read(&card->dma_tx_in_progress)) {
				pci_unmap_single(card->pdev, card->dma_tx_addr,
					card->txbuff[card->rd_txbuff].skb->len,
					PCI_DMA_TODEVICE);

				/* Establish which iface we were sending the
				 * packet on */
				ifnum = card->txbuff[card->rd_txbuff].iface;
				tx_iface = netdev_priv(card->ndev[ifnum]);

				/* Update the statistics */
				tx_iface->stats.tx_packets++;
				tx_iface->stats.tx_bytes +=
					card->txbuff[card->rd_txbuff].skb->len;

				/* Free the skb */
				dev_kfree_skb_irq(
					card->txbuff[card->rd_txbuff].skb);

				/* Aquire a spinlock for the buffs vbles */
				spin_lock_irqsave(&card->txbuff_lock, flags);

				/* Note: make sure that txbuffs is incremented
				 * before dma_tx_in_progress is decremented due
				 * to the lack of locking in nf2c_send()
				 */
				card->rd_txbuff = (card->rd_txbuff + 1) %
						  tx_pool_size;
				card->free_txbuffs++;
				card->free_txbuffs_port[ifnum]++;
				atomic_dec(&card->dma_tx_in_progress);

				/* Re-enable the queues if necessary */
				if (card->free_txbuffs_port[ifnum] == 1)
					netif_wake_queue(card->ndev[ifnum]);

				spin_unlock_irqrestore(&card->txbuff_lock,
						flags);

				/* Call the send function if there are other
				 * packets to send */
				if (card->free_txbuffs != tx_pool_size)
					nf2c_send(netdev);
			}
		}

		/* Handle PHY interrupts */
		if (status & INT_PHY_INTERRUPT) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: intr: "
					"INT_PHY_INTERRUPT\n");

			for (i = 0; i < MAX_IFACE; i++) {
				phy_intr_status = ioread32(card->ioaddr +
						MDIO_0_INTR_STATUS +
						ADDRESS_DELTA * i);
				PDEBUG(KERN_DFLT_DEBUG "PHY_INTR_STATUS for"
						" nf2c%d is %x\n", i,
						phy_intr_status);

				if (phy_intr_status & INTR_LINK_STATUS_POS)
					nf2c_check_link_status(card,
							card->ndev[i], i);
				else {
					PDEBUG(KERN_DFLT_DEBUG "---INT: not"
							" from nf2c%d\n", i);
				}
			}
		}

		/* Handle a packet RX notification
		 *
		 * Should not need to worry about this interrupt being asserted
		 * while a DMA transfer is in progress as the hardware should
		 * prevent this.
		 *
		 * ie. no need to do: !card->dma_rx_in_progress
		 */
		if (status & INT_PKT_AVAIL) {
			PDEBUG(KERN_DFLT_DEBUG "nf2: intr: INT_PKT_AVAIL\n");

			if (atomic_add_return(1, &card->dma_rx_in_progress)
					== 1) {
				PDEBUG(KERN_DFLT_DEBUG "nf2: dma_rx_in_progress"
					" is %d\n",
					atomic_read(&card->dma_rx_in_progress));
				card->dma_rx_addr = pci_map_single(card->pdev,
						card->wr_pool->data,
						MAX_DMA_LEN,
						PCI_DMA_FROMDEVICE);
				/* Start the transfer */
				iowrite32(card->dma_rx_addr,
						card->ioaddr +
						CPCI_REG_DMA_I_ADDR);
				iowrite32(DMA_CTRL_OWNER,
						card->ioaddr +
						CPCI_REG_DMA_I_CTRL);

			} else {
				PDEBUG(KERN_DFLT_DEBUG "nf2: received "
						"interrupt for new rx packet "
						"avail while still\n");
				PDEBUG(KERN_DFLT_DEBUG "processing last packet"
						" - TODO for performance, "
						"that's ok for now.\n");
				atomic_dec(&card->dma_rx_in_progress);
			}
			/* mask off subsequent PKT_AVAIL interrupts */
			int_mask |= INT_PKT_AVAIL;
		}

		/* The cnet is asserting an error */
		if (status & INT_CNET_ERROR) {
			cnet_err = ioread32(card->ioaddr + CNET_REG_ERROR);
			int_mask |= INT_CNET_ERROR;

			printk(KERN_ERR "nf2: CNET error "
					"(CNET reg 0x%x : %08x).\n",
					CNET_REG_ERROR, cnet_err);
		}

		/* CNET read timeout */
		if (status & INT_CNET_READ_TIMEOUT)
			printk(KERN_ERR "nf2: CNET read timeout occurred\n");

		/* Programming error occured */
		if (status & INT_PROG_ERROR)
			printk(KERN_ERR "nf2: CNET programming error\n");

		/* DMA transfer error */
		if (status & INT_DMA_TRANSFER_ERROR) {
			err = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2: DMA transfer error: 0x%08x\n",
					err);
			if (err & ERR_DMA_RETRY_CNT_EXPIRED) {
				printk(KERN_ERR "\t ERR_DMA_RETRY_CNT_EXPIRED"
						" - Too many unsuccessful "
						"retries.\n");
			}
			if (err & ERR_DMA_TIMEOUT) {
				printk(KERN_ERR "\t ERR_DMA_TIMEOUT - DMA "
						"transfer took"
						" too long.\n");
			}

			/* Check the programming status */
			prog_status = ioread32(card->ioaddr +
					CPCI_REG_PROG_STATUS);
			if (!(prog_status & PROG_DONE)) {
				printk(KERN_ERR "\t Note: Virtex is not "
						"currently"
						" programmed.\n");
			}
			nf2_reset_cpci(card);

			nf2c_clear_dma_flags(card);

			/* Call the send function if there's packets to send */
			if (card->free_txbuffs != tx_pool_size)
				nf2c_send(netdev);
		}

		/* DMA setup error */
		if (status & INT_DMA_SETUP_ERROR) {
			err = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2: DMA setup error: 0x%08x\n", err);
			if (err & ERR_DMA_RD_MAC_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_RD_MAC_ERROR - No "
						"data to read from MAC.\n");
			}
			if (err & ERR_DMA_WR_MAC_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_WR_MAC_ERROR - MAC "
						"Tx is full.\n");
			}
			if (err & ERR_DMA_WR_ADDR_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_WR_ADDR_ERROR - not"
						" on word boundary.\n");
			}
			if (err & ERR_DMA_RD_ADDR_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_RD_ADDR_ERROR - not"
						" on word boundary.\n");
			}
			if (err & ERR_DMA_WR_SIZE_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_WR_SIZE_ERROR - "
						"egress pkt too big (>2kB)\n");
			}
			if (err & ERR_DMA_RD_SIZE_ERROR) {
				printk(KERN_ERR "\t ERR_DMA_RD_SIZE_ERROR - "
						"ingress pkt too big "
						"(>2kB)\n");
			}
			if (err & ERR_DMA_BUF_OVERFLOW) {
				printk(KERN_ERR "\t ERR_DMA_BUF_OVERFLOW - CPCI"
						" internal buffer overflow\n");
			}

			nf2_reset_cpci(card);

			nf2c_clear_dma_flags(card);

			/* Call the send function if there's packets to send */
			if (card->free_txbuffs != tx_pool_size)
				nf2c_send(netdev);
		}

		/* DMA fatal error */
		if (status & INT_DMA_FATAL_ERROR) {
			err = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2: DMA fatal error: 0x%08x\n", err);

			nf2_reset_cpci(card);

			nf2c_clear_dma_flags(card);

			/* Call the send function if there's packets to send */
			if (card->free_txbuffs != tx_pool_size)
				nf2c_send(netdev);
		}

		/* Check for unknown errors */
		if (status & INT_UNKNOWN)
			printk(KERN_ERR "nf2: Unknown interrupt(s): 0x%08x\n",
					status);

	}

	if (status_orig)
		PDEBUG(KERN_DFLT_DEBUG "nf2: Reenabling interrupts: mask is 0x%08x\n",
				int_mask);

	/* Rewrite the interrupt mask including any changes */
	iowrite32(int_mask, card->ioaddr + CPCI_REG_INTERRUPT_MASK);

	if (status)
		return IRQ_HANDLED;
	else
		return IRQ_NONE;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 31)
static const struct net_device_ops nf2c_netdev_ops = {
	.ndo_open		= nf2c_open,
	.ndo_stop		= nf2c_release,
	.ndo_set_config		= nf2c_config,
	.ndo_start_xmit		= nf2c_tx,
#ifdef CONFIG_PCI
	.ndo_do_ioctl		= nf2c_ioctl,
#endif
	.ndo_get_stats		= nf2c_stats,
	.ndo_tx_timeout		= nf2c_tx_timeout,
	/*	.ndo_set_multicast_list	= */
	/*	.ndo_change_mtu		= */
	.ndo_set_mac_address	= nf2c_set_mac_address,
	/*	.ndo_validate_addr	= */
#ifdef CONFIG_NET_POLL_CONTROLLER
	/*	.ndo_poll_controller	= */
#endif
};
#endif

/*
 * Link Status Check
 */
static void nf2c_check_link_status(struct nf2_card_priv *card,
		struct net_device *dev, unsigned int ifnum)
{
	unsigned int phy_aux_status;

	phy_aux_status = ioread32(card->ioaddr + MDIO_0_AUX_STATUS + \
			ADDRESS_DELTA * ifnum);
	PDEBUG(KERN_DFLT_DEBUG "---PHY_AUX_STATUS is %x\n", phy_aux_status);

	if (phy_aux_status & AUX_LINK_STATUS_POS) {
		PDEBUG(KERN_DFLT_DEBUG "-----Link %d is up\n", ifnum);
		netif_carrier_on(dev);
	} else {
		PDEBUG(KERN_DFLT_DEBUG "-----Link %d is down\n", ifnum);
		netif_carrier_off(dev);
	}
}


/**
 * nf2c_init - The init function (sometimes called probe).
 * @dev:	net device
 *
 * It is invoked by register_netdev()
 */
static void nf2c_init(struct net_device *dev)
{
	struct nf2_iface_priv *iface;

	ether_setup(dev); /* assign some of the fields */


#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 31)
	dev->netdev_ops = &nf2c_netdev_ops;
#else
	dev->open            = nf2c_open;
	dev->stop            = nf2c_release;
	dev->set_config      = nf2c_config;
	dev->hard_start_xmit = nf2c_tx;
	dev->do_ioctl        = nf2c_ioctl;
	dev->get_stats       = nf2c_stats;
	dev->tx_timeout      = nf2c_tx_timeout;
	dev->watchdog_timeo  = timeout;
	dev->set_mac_address = nf2c_set_mac_address;
	dev->mtu             = MTU;
#endif
	iface = netdev_priv(dev);
	memset(iface, 0, sizeof(struct nf2_iface_priv));
}

/**
 * nf2c_create_pool - Create the pool of buffers for DMA transfers
 * @card:	nf2 card private data
 *
 * Only one is used by the control card
 */
static int nf2c_create_pool(struct nf2_card_priv *card)
{
	card->ppool = kmalloc(sizeof(struct nf2_packet), GFP_KERNEL);
	if (card->ppool == NULL) {
		printk(KERN_NOTICE "nf2: Out of memory while allocating "
				"packet pool\n");
		return -ENOMEM;
	}
	card->ppool->dev = NULL;
	card->ppool->next = card->ppool;

	card->rd_pool = card->wr_pool = card->ppool;

	return 0;
}

/**
 * nf2c_destroy_pool - Destroy the pool of buffers available for DMA transfers
 * @card:	nf2 card private data
 *
 */
static void nf2c_destroy_pool(struct nf2_card_priv *card)
{
	kfree(card->ppool);
}

/**
 * nf2_probe - probe function
 * @pdev:	PCI device
 * @id:		PCI device id
 * @card:	nf2 card private data
 *
 * Identifies the card, performs initialization and sets up the necessary
 * data structures.
 */
int nf2c_probe(struct pci_dev *pdev, const struct pci_device_id *id,
		struct nf2_card_priv *card)
{
	int ret = -ENODEV;

	struct net_device *netdev;
	struct nf2_iface_priv *iface;

	int i;
	int result;

	int err;

	char *devname = "nf2c%d";

	/* Create the rx pool */
	err = nf2c_create_pool(card);
	if (err != 0) {
		ret = err;
		goto err_out_free_none;
	}

	/* Create the tx pool */
	PDEBUG(KERN_DFLT_DEBUG "nf2: kmallocing memory for tx buffers\n");
	card->txbuff = kmalloc(sizeof(struct txbuff) * tx_pool_size,
			GFP_KERNEL);
	if (card->txbuff == NULL) {
		printk(KERN_ERR "nf2: Could not allocate nf2 user card "
				"tx buffers.\n");
		ret = -ENOMEM;
		goto err_out_free_rx_pool;
	}
	card->free_txbuffs = tx_pool_size;
	for (i = 0; i < MAX_IFACE; i++)
		card->free_txbuffs_port[i] = tx_pool_size / MAX_IFACE;

	/* Set up the network device... */
	for (i = 0; i < MAX_IFACE; i++) {
		netdev = card->ndev[i] = alloc_netdev(
				sizeof(struct nf2_iface_priv),
				devname, nf2c_init);
		if (netdev == NULL) {
			printk(KERN_ERR "nf2: Could not allocate ethernet "
					"device.\n");

			ret = -ENOMEM;
			goto err_out_free_etherdev;
		}
		netdev->irq = pdev->irq;
		iface = (struct nf2_iface_priv *)netdev_priv(netdev);

		iface->card = card;
		iface->iface = i;

		/*
		 * Assign the hardware address of the board: use "\0NF2Cx",
		 * where x is the device number.
		 */
		memcpy(netdev->dev_addr, "\0NF2C0", ETH_ALEN);
		netdev->dev_addr[ETH_ALEN - 1] = devnum++;

		/* call the ethtool ops */
		nf2_set_ethtool_ops(netdev);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 0)
                SET_NETDEV_DEV(netdev, &(pdev->dev));
#endif
	}

	/* Register the network devices */
	PDEBUG(KERN_DFLT_DEBUG "nf2: registering network devices\n");
	for (i = 0; i < MAX_IFACE; i++) {
		if (card->ndev[i]) {
			result = register_netdev(card->ndev[i]);
			if (result) {
				printk(KERN_ERR "nf2: error %i registering "
						"device \"%s\"\n",
						result,
						card->ndev[i]->name);
			} else {
				PDEBUG(KERN_ALERT "nf2: registered "
						"netdev %d\n", i);
			}
		}
	}

	/* If we make it here then everything has succeeded */
	return 0;

	/* Error handling points. Undo any resource allocation etc */
err_out_free_etherdev:
	for (i = 0; i < MAX_IFACE; i++)
		if (card->ndev[i])
			free_netdev(card->ndev[i]);
	if (card->txbuff != NULL)
		kfree(card->txbuff);

err_out_free_rx_pool:
	nf2c_destroy_pool(card);

err_out_free_none:
	return ret;
}

/**
 * nf2c_remove - Called when the device driver is unloaded
 * @pdev:	PCI device
 * @card:	nf2 card private data
 *
 */
void nf2c_remove(struct pci_dev *pdev, struct nf2_card_priv *card)
{
	int i;

	/* Release the ethernet data structures */
	for (i = 0; i < MAX_IFACE; i++) {
		if (card->ndev[i]) {
			unregister_netdev(card->ndev[i]);
			free_netdev(card->ndev[i]);
		}
	}

	/* Free any skb's in the transmit queue */
	if (card->free_txbuffs != tx_pool_size) {
		while (card->free_txbuffs < tx_pool_size) {
			dev_kfree_skb(card->txbuff[card->rd_txbuff].skb);
			card->rd_txbuff = (card->rd_txbuff + 1) % tx_pool_size;
			card->free_txbuffs++;
		}
	}

	/* Destroy the txbuffs */
	if (card->txbuff != NULL)
		kfree(card->txbuff);

	/* Destroy the rx pool */
	nf2c_destroy_pool(card);
}
