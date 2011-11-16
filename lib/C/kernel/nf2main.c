/*
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 * Copyright (c) 2010 Paul Rodman <rodman@google.com>
 * Copyright (c) 2010 Maciej Żenczykowski <maze@google.com>
 *
 * Author: Glen Gibb <grg@stanford.edu>
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
 * Module: nf2main.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Main source file for kernel driver
 *		Code for control and user cards is in separate files.
 *
 * Change history:
 *                 11/16/11- Peter Membrey
 *                           Fix for init_MUTEX removal in 2.6.37
 *                 3/10/10 - Paul Rodman & Maciej Żenczykowski (google)
 *                           Added support for kernels 2.6.31 and beyond
 *                           (net_device api deprecated)
 *                 9/1/05  - Semi-functional driver :-)
 *                 9/2/05  - Split driver into multiple modules
 * 		   	     (user and control mode in separate modules)
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

#include <linux/in.h>
#include <linux/netdevice.h>   /* struct device, and other headers */
#include <linux/etherdevice.h> /* eth_type_trans */
#include <linux/if_ether.h>
#include <linux/moduleparam.h>
#include <linux/stat.h>

#include <asm/uaccess.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 26)
#include <linux/semaphore.h>
#else
#include <asm/semaphore.h>
#endif

#include "../common/nf2.h"
#include "nf2kernel.h"

MODULE_AUTHOR("Maintainer: Glen Gibb <grg@stanford.edu>");
MODULE_DESCRIPTION("Stanford NetFPGA 2 Driver");
MODULE_LICENSE("GPL");

/*
 * Timeout parameter
 */
int timeout = NF2_TIMEOUT;
module_param(timeout, int, S_IRUGO);

/*
 * Size of receive buffer pool
 */
int rx_pool_size = NUM_RX_BUFFS;
module_param(rx_pool_size, int, S_IRUGO);

/*
 * Size of transmit buffer pool
 */
int tx_pool_size = NUM_TX_BUFFS;
module_param(tx_pool_size, int, S_IRUGO);

/*
 * Major and minor device numbers. Defaults to dynamic allocation.
 */

int nf2_major = NF2_MAJOR;
int nf2_minor;
module_param(nf2_major, int, S_IRUGO);
module_param(nf2_minor, int, S_IRUGO);


/*
 * Function prototypes
 */
static void nf2_validate_params(void);


/*
 * pci_device_id - table of Vendor and Device IDs for the kernel to match
 *                 to identify the card(s) supported by this driver
 */
static struct pci_device_id ids[] = {
	{ PCI_DEVICE(PCI_VENDOR_ID_STANFORD, PCI_DEVICE_ID_STANFORD_NF2), },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, ids);


/**
 * nf2_get_revision - Get the revision from the config space
 * @pdev:	PCI device
 *
 */
static unsigned char nf2_get_revision(struct pci_dev *pdev)
{
	u8 revision;

	pci_read_config_byte(pdev, PCI_REVISION_ID, &revision);
	return revision;
}

/*
 * Check if the board is a control board
 */
/* static unsigned char nf2_is_control_board(void *ioaddr) */
/* { */
/* 	unsigned int board_id; */

/* 	board_id = ioread32(ioaddr + CPCI_REG_BOARD_ID); */
/* 	return board_id & ID_VERSION; */
/* } */

/**
 * nf2_probe - Probe function for the card
 * @pdev:	PCI device
 * @id:		PCI device id
 *
 * Identifies the card, performs initialization and sets up the necessary
 * data structures.
 */
static int nf2_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	int ret = -ENODEV;
	struct nf2_card_priv *card;
	int rev;
	int err;

	/* Enable the device */
	err = pci_enable_device(pdev);
	if (err) {
		printk(KERN_ERR "nf2: Unable to enable the PCI device, "
				"aborting.\n");
		goto err_out_none;
	}


	/* Grab the revision and make sure we know about it */
	rev = nf2_get_revision(pdev);
	printk(KERN_INFO "nf2: Found an NetFPGA-1G device (cfg revision "
			"%d)...\n", rev);
	if (rev != 0x00)
		return -ENODEV;

	/* Enable bus mastering */
	PDEBUG(KERN_INFO "nf2: Enabling bus mastering\n");
	pci_set_master(pdev);

	/* Test to make sure we can correctly set the DMA mask */
	PDEBUG(KERN_INFO "nf2: Setting DMA mask\n");
	err = pci_set_dma_mask(pdev, 0xFFFFFFFFULL);
	if (err) {
		printk(KERN_ERR "nf2: No usable DMA configuration, "
				"aborting.\n");
		goto err_out_none;
	}

	/* Request the memory region corresponding to the card */
	PDEBUG(KERN_INFO "nf2: Requesting memory region for NetFPGA-1G\n");
	if (!request_mem_region(pci_resource_start(pdev, 0),
				pci_resource_len(pdev, 0), "nf2")) {
		printk(KERN_ERR "nf2: cannot reserve MMIO region\n");
		goto err_out_none;
	}

	/* Create the card private data structure */
	PDEBUG(KERN_INFO "nf2: kmallocing memory for nf2_card_priv\n");
	card = (struct nf2_card_priv *)kmalloc(sizeof(struct nf2_card_priv),
			GFP_KERNEL);
	if (card == NULL) {
		printk(KERN_ERR "nf2: Could not allocate memory for card "
				"private data.\n");

		ret = -ENOMEM;
		goto err_out_free_mem_region;
	}
	/* Clear the contents of the data structure */
	memset(card, 0, sizeof(struct nf2_card_priv));

	/* Record the pdev corresponding to the card */
	card->pdev = pdev;

	/* Initialize the locking mechanisms */
	PDEBUG(KERN_INFO "nf2: initializing data structures in card\n");
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 37)
	sema_init(&card->state_lock, 1);
#else
	init_MUTEX(&card->state_lock);
#endif
	spin_lock_init(&card->txbuff_lock);
	atomic_set(&card->dma_tx_in_progress, 0);
	atomic_set(&card->dma_rx_in_progress, 0);
	atomic_set(&card->dma_tx_lock, 0);
	atomic_set(&card->dma_rx_lock, 0);
	/*spin_lock_init(&card->dma_tx_lock);*/
	/*spin_lock_init(&card->dma_rx_lock);*/

	/* Store the netdevice associated with the pdev */
	pci_set_drvdata(pdev, card);

	/* Map the memory region */
	PDEBUG(KERN_INFO "nf2: mapping I/O space\n");
	card->ioaddr = ioremap(pci_resource_start(pdev, 0),
			pci_resource_len(pdev, 0));
	if (!card->ioaddr) {
		printk(KERN_ERR "nf2: cannot remap mem region %lx @ %lx\n",
				(long unsigned int)pci_resource_len(pdev, 0),
				(long unsigned int)pci_resource_start(pdev, 0));
		goto err_out_free_card;
	}

	/* Disable all MACs */
	iowrite32(0, card->ioaddr + CNET_REG_ENABLE);

	/* Work out whether the card is a control or user card */
	PDEBUG(KERN_INFO "nf2: calling control/user probe function\n");
	card->is_ctrl = 1;
	ret = nf2c_probe(pdev, id, card);
	/*card->is_ctrl = nf2_is_control_board(card->ioaddr);
	  if (card->is_ctrl)
	  {
	  ret = nf2c_probe(pdev, id, card);
	  }
	  else
	  {
	  ret = nf2u_probe(pdev, id, card);
	  }*/

	/* Check for errors from the control/user probes */
	if (ret < 0)
		goto err_out_iounmap;
	else {
		/* If we make it here then everything has succeeded */
		PDEBUG(KERN_INFO "nf2: device probe succeeded\n");
		return ret;
	}

	/* Error handling */
err_out_iounmap:
	iounmap(card->ioaddr);

err_out_free_card:
	pci_set_drvdata(pdev, NULL);
	kfree(card);

err_out_free_mem_region:
	release_mem_region(pci_resource_start(pdev, 0),
			pci_resource_len(pdev, 0));

err_out_none:
	pci_disable_device(pdev);
	return ret;
}

/**
 * nf2_remove - Remove the card
 * @pdev:	PCI device
 *
 */
static void nf2_remove(struct pci_dev *pdev)
{
	struct nf2_card_priv *card;

	/* clean up any allocated resources and stuff here.
	 * like call release_region();
	 */
	printk(KERN_ALERT "nf2: Unloading driver\n");

	/* Get the private data */
	card = (struct nf2_card_priv *)pci_get_drvdata(pdev);
	if (card) {
		/* Call the control/user release function */
		nf2c_remove(pdev, card);
		/*if (card->is_ctrl)
		  nf2c_remove(pdev, card);
		  else
		  nf2u_remove(pdev, card);*/

		/* Unmap the IO memory region */
		if (card->ioaddr) {
			printk(KERN_ALERT "nf2: unmapping ioaddr\n");
			iounmap(card->ioaddr);
		}

		/* Free the private data */
		printk(KERN_ALERT "nf2: freeing card\n");
		kfree(card);
	}

	/* Unset the driver data */
	printk(KERN_ALERT "nf2: setting drvdata to NULL\n");
	pci_set_drvdata(pdev, NULL);

	/* Release the memory */
	printk(KERN_ALERT "nf2: releasing mem region\n");
	release_mem_region(pci_resource_start(pdev, 0),
			pci_resource_len(pdev, 0));

	/* Disable the device */
	printk(KERN_ALERT "nf2: disabling device\n");
	pci_disable_device(pdev);

	printk(KERN_ALERT "nf2: finished removing\n");
}

/*
 * Validate the value of the params passed in and adjust them if necessary
 */
static void nf2_validate_params(void)
{
	if (timeout <= 0) {
		printk(KERN_WARNING "nf2: Value of timeout param must be "
				"positive. Value: %d\n", timeout);
		timeout = NF2_TIMEOUT;
	}

	if (rx_pool_size <= 0) {
		printk(KERN_WARNING "nf2: Value of rx_pool_size param must "
				"be positive. Value: %d\n", rx_pool_size);
		rx_pool_size = NUM_RX_BUFFS;
	}

	if (tx_pool_size <= 0) {
		printk(KERN_WARNING "nf2: Value of tx_pool_size param must be "
				"positive. Value: %d\n", tx_pool_size);
		tx_pool_size = NUM_TX_BUFFS;
	}

	if (nf2_major < 0) {
		printk(KERN_WARNING "nf2: Value of nf2_major param cannot be "
				"negative. Value: %d\n", nf2_major);
		rx_pool_size = NF2_MAJOR;
	}

	if (nf2_minor < 0) {
		printk(KERN_WARNING "nf2: Value of nf2_minor param cannot be "
				"negative. Value: %d\n", nf2_minor);
		rx_pool_size = 0;
	}
}

/*
 * pci_driver structure to set up callbacks for various PCI events
 */
static struct pci_driver pci_driver = {
	.name = "nf2",
	.id_table = ids,
	.probe = nf2_probe,
	.remove = nf2_remove,
};

static int pci_skel_init(void)
{
	/* Validate the params */
	nf2_validate_params();

	/* Register the driver */
	return pci_register_driver(&pci_driver);
}

static void pci_skel_exit(void)
{
	pci_unregister_driver(&pci_driver);
}

module_init(pci_skel_init);
module_exit(pci_skel_exit);
