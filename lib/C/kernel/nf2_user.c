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
 * Module: nf2_user.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: User card functionality
 */

#include <linux/version.h>
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 8)
#include <linux/config.h>
#endif

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/init.h>

#include <linux/cdev.h>
#include <linux/fs.h>

#include <asm/uaccess.h>

#include <linux/poll.h>

#include "../common/nf2.h"
#include "nf2kernel.h"
#include "nf2util.h"

/* Name for the User devices */
static char *devname = "nf2u";

/* Function declarations */
static int nf2u_check_for_buffs(struct nf2_card_priv *card,
		struct nf2_user_priv *upriv, struct file *filp);
static int nf2u_send(struct nf2_card_priv *card);
static int nf2u_create_pool(struct nf2_card_priv *card);
static void nf2u_destroy_pool(struct nf2_card_priv *card);
static irqreturn_t nf2u_intr(int irq, void *dev_id, struct pt_regs *regs);

/**
 * nf2u_open - Open the device
 * @inode:	Inode structure
 * @filp:	File pointer
 *
 *
 * Records the nf2_user_priv data structure corresponding to the
 * filp struct.
 *
 * Attaches the interrupt handler.
 *
 * Locking: sem - prevent the user data structure from being modifed
 * 		  by multiple threads simultaneously
 */
static int nf2u_open(struct inode *inode, struct file *filp)
{
	struct nf2_user_priv *upriv;
	struct nf2_card_priv *card;
	int err = 0;
	u32 enable;

	upriv = container_of(inode->i_cdev, struct nf2_user_priv, cdev);
	filp->private_data = upriv; /* for other methods */
	card = upriv->card;

	if (down_interruptible(&upriv->sem))
		return -ERESTARTSYS;

	if (upriv->open_count++ == 0) {
		/* Reset the hardware */
		nf2_hw_reset(card);

		/* Enable the first MAC */
		iowrite32(CNET_RESET_MAC_0, card->ioaddr + CNET_REG_RESET);

		enable = ioread32(card->ioaddr + CNET_REG_ENABLE);
		enable |= CNET_ENABLE_RX_FIFO_0 | CNET_ENABLE_TX_MAC_0;
		iowrite32(enable, card->ioaddr + CNET_REG_ENABLE);

		err = request_irq(card->pdev->irq, nf2u_intr, SA_SHIRQ,
				devname, upriv);
		if (err) {
			printk(KERN_ERR "nf2: Unable to allocate interrupt "
					"handler: %d\n", err);
			goto out;
		}
		nf2_enable_irq(card);
	}

	upriv->open_count++;

out:
	up(&upriv->sem);
	return err;
}

/**
 * nf2u_release - Release the device (ie. close)
 * @inode:	Inode
 * @filp:	file pointer
 *
 *
 * Remove the interrupt handler.
 *
 * Locking: sem - prevent the user data structure from being modifed
 * 		  by multiple threads simultaneously
 */
static int nf2u_release(struct inode *inode, struct file *filp)
{
	struct nf2_user_priv *upriv =
			      (struct nf2_user_priv *)filp->private_data;
	struct nf2_card_priv *card = upriv->card;
	u32 enable;

	if (down_interruptible(&upriv->sem))
		return -ERESTARTSYS;

	upriv->open_count--;

	if (upriv->open_count == 0) {
		nf2_disable_irq(card);
		free_irq(card->pdev->irq, upriv);

		/* Disable the first MAC */
		enable = ioread32(card->ioaddr + CNET_REG_ENABLE);
		enable &= ~(CNET_ENABLE_RX_FIFO_0 | CNET_ENABLE_TX_MAC_0);
		iowrite32(enable, card->ioaddr + CNET_REG_ENABLE);
	}

	up(&upriv->sem);
	return 0;
}


/**
 * nf2u_read - Read data from the card
 * @filp:	File pointer
 * @buf:	user buffer
 * @count:	size
 * @f_pos:	offset
 *
 * Locking: sem - prevent the user data structure from being modifed
 * 		  by multiple threads simultaneously
 */
static ssize_t nf2u_read(struct file *filp, char __user *buf, size_t count,
		loff_t *f_pos)
{
	struct nf2_user_priv *upriv = filp->private_data;
	struct nf2_card_priv *card = upriv->card;
	u32 reg;

	if (down_interruptible(&upriv->sem))
		return -ERESTARTSYS;

	/* Wait until there is data to be read */
	while (upriv->rx_rd_pos == upriv->rx_wr_pos) {
		up(&upriv->sem); /* release the lock */
		if (filp->f_flags & O_NONBLOCK)
			return -EAGAIN;
		PDEBUG("\"%s\" reading: going to sleep\n", current->comm);
		if (wait_event_interruptible(upriv->inq,
					(upriv->rx_rd_pos != upriv->rx_wr_pos)))
			return -ERESTARTSYS; /*signal:tell fs layer to handle */

		/* otherwise loop, but first reacquire the lock */
		if (down_interruptible(&upriv->sem))
			return -ERESTARTSYS;
	}

	/* Check to see if the wr_pos pointer has wrapped */
	if (upriv->rx_wr_pos > upriv->rx_rd_pos)
		count = min(count, (size_t)(upriv->rx_wr_pos -
					upriv->rx_rd_pos));
	else /* the write pointer has wrapped, return data up to upriv->end */
		count = min(count, (size_t)(0xFFFFFFFF - upriv->rx_rd_pos));

	/* Check to see if the read will empty a buffer */
	count = min(count, (size_t)(card->rd_pool->data +
				card->rd_pool->len - upriv->rx_buf_rd_pos));

	/* Copy the data to the user */
	if (copy_to_user(buf, upriv->rx_buf_rd_pos, count)) {
		up(&upriv->sem);
		return -EFAULT;
	}
	upriv->rx_rd_pos += count;
	upriv->rx_buf_rd_pos += count;

	/* Check if we've finished with the current buffer */
	if (upriv->rx_buf_rd_pos == card->rd_pool->data + card->rd_pool->len) {
		/* Re-enable the PKT_AVAIL interrupt if necessary */
		if (card->rd_pool == card->wr_pool->next) {
			reg = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_MASK);
			reg |= INT_PKT_AVAIL;
			iowrite32(reg, card->ioaddr + CPCI_REG_INTERRUPT_MASK);
		}

		card->rd_pool = card->rd_pool->next;
		upriv->rx_buf_rd_pos = card->rd_pool->data;
	}

	up(&upriv->sem);

	return count;
}

/**
 * nf2u_check_for_buffs - Get the amount of free write space
 * @card:	nf2 card
 * @upriv:	nf2 user private
 * @filp:	file pointer
 *
 * Locking - no need to lock the txbuff_lock as we are only reading free_txbuffs
 * and it doesn't matter if we get this wrong -- only decremented from the write
 * function which calls this func.
 */
static int nf2u_check_for_buffs(struct nf2_card_priv *card,
		struct nf2_user_priv *upriv, struct file *filp)
{
	/* Check if there are any free txbuffs */
	while (card->free_txbuffs == 0) {
		DEFINE_WAIT(wait);

		up(&upriv->sem);
		if (filp->f_flags & O_NONBLOCK)
			return -EAGAIN;
		PDEBUG("\"%s\" writing: going to sleep\n", current->comm);
		prepare_to_wait(&upriv->outq, &wait, TASK_INTERRUPTIBLE);
		if (card->free_txbuffs == 0)
			schedule();
		finish_wait(&upriv->outq, &wait);

		/* Check for signals and allow higher layers to handle */
		if (signal_pending(current))
			return -ERESTARTSYS;

		if (down_interruptible(&upriv->sem))
			return -ERESTARTSYS;
	}

	return 0;
}

/**
 * nf2u_write - Write data to the card
 * @filp:	File pointer
 * @buf:	user buffer
 * @count:	size
 * @f_pos:	offset
 *
 * Locking: sem - prevent the user data structure from being modifed
 * 		  by multiple threads simultaneously
 */
static ssize_t nf2u_write(struct file *filp, const char __user *buf,
		size_t count, loff_t *f_pos)
{
	struct nf2_user_priv *upriv = filp->private_data;
	struct nf2_card_priv *card = upriv->card;
	int result;

	u16 len;

	if (down_interruptible(&upriv->sem))
		return -ERESTARTSYS;

	/* Make sure there's space to write */
	result = nf2u_check_for_buffs(card, upriv, filp);
	if (result)
		return result; /* nf2u_check_for_buffs called up(&upriv->sem) */

	/* Ok, space is there, accept something */
	count = min(count, (size_t)MAX_DMA_LEN + 2);

	PDEBUG("Going to accept %li bytes to %p from %p\n", (long)count,
			card->txbuff[card->wr_txbuff].buff, buf);
	if (copy_from_user(&len, buf, 2)) {
		up(&upriv->sem);
		return -EFAULT;
	}

	/* Check that the size of the block is less than or equal to the number
	 * of bytes being attempted to be transferred */
	if (len + 2 > count) {
		up(&upriv->sem);
		return -EFAULT;
	}
	count = len + 2;

	card->txbuff[card->wr_txbuff].len = len;
	if (copy_from_user(card->txbuff[card->wr_txbuff].buff, buf, 2)) {
		up(&upriv->sem);
		return -EFAULT;
	}
	card->wr_txbuff = (card->wr_txbuff + 1) % tx_pool_size;
	card->free_txbuffs--;

	up(&upriv->sem);

	return count;
}

/**
 * nf2u_poll - Poll function
 * @filp:	File pointer
 * @wait:	poll table
 *
 * To check if data is available and if we can send data
 * to the device
 */
static unsigned int nf2u_poll(struct file *filp, poll_table *wait)
{
	struct nf2_user_priv *upriv = filp->private_data;
	struct nf2_card_priv *card = upriv->card;
	unsigned int mask = 0;

	/*
	 * The buffer is circular; it is considered full
	 * if "wp" is right behind "rp" and empty if the
	 * two are equal.
	 */
	down(&upriv->sem);
	poll_wait(filp, &upriv->inq,  wait);
	poll_wait(filp, &upriv->outq, wait);
	if (upriv->rx_rd_pos != upriv->rx_wr_pos)
		mask |= POLLIN | POLLRDNORM;	/* readable */
	if (card->free_txbuffs != 0)
		mask |= POLLOUT | POLLWRNORM;	/* writable */
	up(&upriv->sem);
	return mask;
}

/**
 * nf2u_send - Send an actual packet
 * @card:	nf card
 *
 */
static int nf2u_send(struct nf2_card_priv *card)
{
	int err = 0;
	char *buff;
	u16 len;

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

	/* Grab the buffer and length */
	buff = card->txbuff[card->rd_txbuff].buff;
	len = card->txbuff[card->rd_txbuff].len;

	/* Map the buffer into DMA space */
	card->dma_tx_addr = pci_map_single(card->pdev,
					buff, len, PCI_DMA_TODEVICE);

	/* Start the transfer */
	iowrite32(card->dma_tx_addr,
			card->ioaddr + CPCI_REG_DMA_E_ADDR);
	iowrite32(len,
			card->ioaddr + CPCI_REG_DMA_E_SIZE);
	iowrite32(NF2_SET_DMA_CTRL_MAC(0) | DMA_CTRL_OWNER,
			card->ioaddr + CPCI_REG_DMA_E_CTRL);

err_unlock:
	/*spin_unlock_irqrestore(&card->dma_tx_lock, flags);*/

	return err;
}

/**
 * nf2u_ioctl - Handle ioctl calls
 * @inode:	Inode
 * @filp:	File pointer
 * @cmd:	Ioctl command
 * @arg:	args
 *
 */
static int nf2u_ioctl(struct inode *inode, struct file *filp, unsigned int cmd,
		unsigned long arg)
{
	struct nf2_user_priv *upriv;
	struct nf2_card_priv *card;

	struct nf2reg reg;

	upriv = container_of(inode->i_cdev, struct nf2_user_priv, cdev);
	card = upriv->card;

	switch (cmd) {
	/* Read a register */
	case SIOCREGREAD:
		if (copy_from_user(&reg, (void *)arg, sizeof(struct nf2reg))) {
			printk(KERN_ERR "nf2: Unable to copy data from user space\n");
			return -EFAULT;
		}
		reg.val = ioread32(card->ioaddr + reg.reg);
		if (copy_to_user((void *)arg, &reg, sizeof(struct nf2reg))) {
			printk(KERN_ERR "nf2: Unable to copy data to user space\n");
			return -EFAULT;
		}
		return 0;

	/* Write a register */
	case SIOCREGWRITE:
		if (copy_from_user(&reg, (void *)arg, sizeof(struct nf2reg))) {
			printk(KERN_ERR "nf2: Unable to copy data from user space\n");
			return -EFAULT;
		}
		iowrite32(reg.val, card->ioaddr + reg.reg);
		return 0;

	default:
		return -EOPNOTSUPP;
	}

	/* Should never reach here, but anyway :) */
	return -EOPNOTSUPP;
}

/**
 * nf2u_intr - Handle an interrupt
 * @irq:	The irq number
 * @dev_id:	device id
 * @regs:
 *
 * Note: Keep this as short as possible!
 */
static irqreturn_t nf2u_intr(int irq, void *dev_id, struct pt_regs *regs)
{
	struct nf2_user_priv *upriv = dev_id;
	struct nf2_card_priv *card = upriv->card;
	u32 result;

	/* Grab the interrupt status */
	u32 status = ioread32(card->ioaddr + CPCI_REG_INTERRUPT_STATUS);

	/* Check if the interrrupt was generated by us */
	if (status) {
		printk(KERN_NOTICE "nf2: interrupt: %x\n", status);

		/* Handle packet RX complete
		 * Note: don't care about the rx pool here as the packet is
		 * copied to an skb immediately so there is no need to have
		 * multiple packets in the rx pool
		 */
		if (status & INT_DMA_RX_COMPLETE) {
			pci_unmap_single(card->pdev, card->dma_rx_addr,
					MAX_DMA_LEN,
					PCI_DMA_FROMDEVICE);

			card->wr_pool->len = ioread32(card->ioaddr +
					CPCI_REG_DMA_I_SIZE);
			card->wr_pool->data[0] = (u8)(card->wr_pool->len &
					0xFF00 >> 8);
			card->wr_pool->data[1] = (u8)(card->wr_pool->len &
					0xFF);

			/*result = ioread32(card->ioaddr + CPCI_REG_DMA_I_CTRL);
			card->wr_pool->dev = card->ndev[(result & 0x300) >> 8];
			*/

			upriv->rx_wr_pos += card->wr_pool->len;

			atomic_dec(&card->dma_rx_in_progress);
			card->wr_pool = card->wr_pool->next;

			/* Finally, awake any reader */
			wake_up_interruptible_sync(&upriv->inq);
		}

		/* Handle packet TX complete */
		if (status & INT_DMA_TX_COMPLETE) {
			pci_unmap_single(card->pdev, card->dma_tx_addr,
					card->txbuff[card->rd_txbuff].len,
					PCI_DMA_TODEVICE);

			card->rd_txbuff = (card->rd_txbuff + 1) % tx_pool_size;
			card->free_txbuffs++;
			atomic_dec(&card->dma_tx_in_progress);

			/* Wake any writer that may be waiting */
			wake_up_interruptible_sync(&upriv->outq);

			/* Call the send function if there are other packets
			 * to send */
			if (card->free_txbuffs != tx_pool_size)
				nf2u_send(card);
		}

		/* Handle PHY interrupts */
		if (status & INT_PHY_INTERRUPT)
			printk(KERN_ALERT "nf2: Phy Interrrupt\n");

		/* Handle a packet RX notification
		 *
		 * Should not need to worry about this interrupt being
		 * asserted while a DMA transfer is in progress as the
		 * hardware should prevent this.
		 * ie. no need to do: !card->dma_rx_in_progress
		 */
		if (status & INT_PKT_AVAIL) {
			card->dma_rx_addr = pci_map_single(card->pdev,
					card->wr_pool->data + 2,
					MAX_DMA_LEN,
					PCI_DMA_FROMDEVICE);

			atomic_inc(&card->dma_rx_in_progress);

			/* Disable the PKT_AVAIL interrupt if necessary */
			if (card->rd_pool == card->wr_pool->next) {
				result = ioread32(card->ioaddr +
						CPCI_REG_INTERRUPT_MASK);
				result &= ~INT_PKT_AVAIL;
				iowrite32(result, card->ioaddr +
						CPCI_REG_INTERRUPT_MASK);
			}

			/* Start the transfer */
			iowrite32(card->dma_rx_addr,
					card->ioaddr + CPCI_REG_DMA_I_ADDR);
			iowrite32(DMA_CTRL_OWNER,
					card->ioaddr + CPCI_REG_DMA_I_CTRL);
		}

		/* The cnet is asserting an error */
		if (status & INT_CNET_ERROR)
			printk(KERN_ERR "nf2: CNET error detected\n");

		/* CNET read timeout */
		if (status & INT_CNET_READ_TIMEOUT)
			printk(KERN_ERR "nf2: CNET read timeout occurred\n");

		/* Programming error occured */
		if (status & INT_PROG_ERROR)
			printk(KERN_ERR "nf2: CNET programming error\n");

		/* DMA transfer error */
		if (status & INT_DMA_TRANSFER_ERROR) {
			result = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2:DMA transfer error: %x\n", result);

			nf2_reset_cpci(card);
		}

		/* DMA setup error */
		if (status & INT_DMA_SETUP_ERROR) {
			result = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2: DMA setup error: %x\n", result);

			nf2_reset_cpci(card);
		}

		/* DMA fatal error */
		if (status & INT_DMA_FATAL_ERROR) {
			result = ioread32(card->ioaddr + CPCI_REG_ERROR);
			printk(KERN_ERR "nf2: DMA fatal error: %x\n", result);

			nf2_reset_cpci(card);
		}

		/* Check for unknown errors */
		if (status & INT_UNKNOWN) {
			printk(KERN_ERR "nf2: Unknown interrupt(s): %x\n",
					status);
		}

		return IRQ_HANDLED;
	}

	return IRQ_NONE;
}

/**
 * nf2_fops - file_operations structure
 *
 *
 * It contains the callbacks for
 * the char device
 */
struct file_operations nf2_fops = {
	.owner =    THIS_MODULE,
	.llseek =   no_llseek,
	.read =     nf2u_read,
	.write =    nf2u_write,
	.poll =	    nf2u_poll,
	.ioctl =    nf2u_ioctl,
	.open =     nf2u_open,
	.release =  nf2u_release,
	/*.fasync =   nf2u_fasync,*/
};

/**
 * nf2u_create_pool - Create the pool of buffers for DMA transfers
 * @card:	nf2 card private data
 *
 */
static int nf2u_create_pool(struct nf2_card_priv *card)
{
	struct nf2_packet *pkt;
	int i;

	for (i = 0; i < rx_pool_size + 1; i++) {
		pkt = kmalloc(sizeof(struct nf2_packet), GFP_KERNEL);
		if (pkt == NULL) {
			printk(KERN_NOTICE "nf2: Out of memory while "
					"allocating packet pool\n");
			return -ENOMEM;
		}
		pkt->dev = NULL;
		if (i == 0)
			pkt->next = pkt;
		else
			pkt->next = card->ppool;
		card->ppool = pkt;
	}

	card->rd_pool = card->wr_pool = card->ppool;

	return 0;
}

/**
 * nf2u_destroy_pool - Destroy buffer pool available for DMA transfers
 * @card:	nf2 card private data
 *
 */
static void nf2u_destroy_pool(struct nf2_card_priv *card)
{
	struct nf2_packet *pkt, *prev;

	pkt = card->ppool;
	prev = NULL;
	while (pkt != card->ppool || prev == NULL) {
		prev = pkt;
		pkt = pkt->next;
		kfree(prev);
	}

	card->rd_pool = card->wr_pool = card->ppool = NULL;
}

/**
 * nf2u_probe - Probe function
 * @pdev:	PCI device
 * @id:		PCI device id
 * @card:	nf2 card private data
 *
 * Identifies the card, performs initialization and sets up the necessary
 * data structures.
 */
int nf2u_probe(struct pci_dev *pdev, const struct pci_device_id *id,
		struct nf2_card_priv *card)
{
	int ret = -ENODEV;
	int result, i;

	struct nf2_user_priv *upriv = NULL;

	int err;

	/* Create the rx pool */
	PDEBUG(KERN_INFO "nf2: creating rx pool\n");
	err = nf2u_create_pool(card);
	if (err) {
		ret = err;
		goto err_exit;
	}

	/* Create the user priv data structure */
	PDEBUG(KERN_INFO "nf2: kmallocing memory for nf2_user_priv\n");
	card->upriv = upriv = kmalloc(sizeof(struct nf2_user_priv), GFP_KERNEL);
	if (upriv == NULL) {
		printk(KERN_ERR "nf2: Could not allocate nf2 user private data"
				" structure.\n");
		ret = -ENOMEM;
		goto err_exit;
	}
	upriv->card = card;
	upriv->open_count = 0;
	init_waitqueue_head(&upriv->inq);
	init_waitqueue_head(&upriv->outq);
	init_MUTEX(&upriv->sem);
	upriv->rx_wr_pos = 0;
	upriv->rx_rd_pos = 0;

	/* Allocate memory in the txbuffers */
	PDEBUG(KERN_INFO "nf2: kmallocing memory for tx buffers\n");
	card->txbuff = kmalloc(sizeof(struct txbuff) * tx_pool_size,
			GFP_KERNEL);
	if (card->txbuff == NULL) {
		printk(KERN_ERR "nf2: Could not allocate nf2 user card tx "
				"buffers.\n");
		ret = -ENOMEM;
		goto err_free_mem;
	}
	card->free_txbuffs = tx_pool_size;
	for (i = 0; i < tx_pool_size; i++)
		card->txbuff[i].buff = NULL;
	for (i = 0; i < tx_pool_size; i++) {
		card->txbuff[i].buff = kmalloc(sizeof(u8) * (MAX_DMA_LEN),
				GFP_KERNEL);
		if (card->txbuff[i].buff == NULL) {
			printk(KERN_ERR "nf2: Could not allocate nf2 user card"
					" tx buffers.\n");
			ret = -ENOMEM;
			goto err_free_mem;
		}
	}

	/*
	 * Get a range of minor numbers to work with, asking for a dynamic
	 * major unless directed otherwise at load time.
	 */
	PDEBUG(KERN_INFO "nf2: requesting device number\n");
	upriv->dev = 0;
	if (nf2_major) {
		upriv->dev = MKDEV(nf2_major, nf2_minor++);
		result = register_chrdev_region(upriv->dev, 1, "nf2");
	} else {
		result = alloc_chrdev_region(&upriv->dev, nf2_minor, 1, "nf2");
		nf2_major = MAJOR(upriv->dev);
		nf2_minor = MINOR(upriv->dev) + 1;
	}
	if (result < 0) {
		printk(KERN_WARNING "nf2: can't get major %d\n", nf2_major);
		goto err_free_mem;
	}

	/* Set up the cdev */
	PDEBUG(KERN_INFO "nf2: initializing the cdev\n");
	cdev_init(&upriv->cdev, &nf2_fops);
	upriv->cdev.owner = THIS_MODULE;
	upriv->cdev.ops = &nf2_fops;
	err = cdev_add(&upriv->cdev, upriv->dev, 1);
	if (err) {
		printk(KERN_ERR "nf2: Error %d while adding cdev\n", err);
		goto err_unreg;
	}

	/* Reset the hardware */
	PDEBUG(KERN_INFO "nf2: resetting the hardware\n");
	nf2_hw_reset(card);

	return 0; /* Success */

err_unreg:
	/* Unregister the char device */
	unregister_chrdev_region(upriv->dev, 1);

err_free_mem:
	/* Free any allocated memory */
	if (card->txbuff != NULL) {
		for (i = 0; i < tx_pool_size; i++) {
			if (card->txbuff[i].buff != NULL)
				kfree(card->txbuff[i].buff);
		}
		kfree(card->txbuff);
	}
	kfree(upriv);

	nf2u_destroy_pool(card);

err_exit:
	return ret;
}


/**
 * nf2u_remove - Called when the device driver is unloaded
 * @pdev:	PCI device
 * @card:	nf2 card private data
 *
 */
void nf2u_remove(struct pci_dev *pdev, struct nf2_card_priv *card)
{
	struct nf2_user_priv *upriv = card->upriv;
	int i;

	unregister_chrdev_region(upriv->dev, 1);
	if (card->txbuff != NULL) {
		for (i = 0; i < tx_pool_size; i++) {
			if (card->txbuff[i].buff != NULL)
				kfree(card->txbuff[i].buff);
		}
		kfree(card->txbuff);
	}
	kfree(upriv);

	nf2u_destroy_pool(card);
}
