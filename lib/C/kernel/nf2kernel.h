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
 *
 * Module: nf2kernel.h
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: Header file for kernel driver
 */

#ifndef _NF2KERNEL_H
#define _NF2KERNEL_H	1

#ifdef __KERNEL__

#include <linux/cdev.h>
#include <linux/sockios.h>
#include <linux/netdevice.h>
#include <linux/fs.h>
#include <linux/mii.h>
#include <asm/atomic.h>

/* Define PCI Vendor and device IDs for the NetFPGA-1G card */
#define PCI_VENDOR_ID_STANFORD		0xFEED
#define PCI_DEVICE_ID_STANFORD_NF2	0x0001

/* Prefix for device names
 * - will have either c or u appended to indicate control or user
 */
#define NF2_DEV_NAME	"nf2"

/* How many interfaces does a single card support */
#ifndef MAX_IFACE
#define MAX_IFACE	4
#endif

/* Transmit timeout period */
#define NF2_TIMEOUT	(2 * HZ)

/* How many transmit buffers to allocate */
#define NUM_TX_BUFFS	16

/* How many transmit buffers to allocate */
#define NUM_RX_BUFFS	8

/* How large is the largest DMA transfer */
#define MAX_DMA_LEN	2048

/* Major device number for user devices */
#define NF2_MAJOR 0   /* dynamic major by default */

/* Maximum transmission size -- this should be
 * max packet size - 14 for the Ethernet header */
#define MTU 1986

/*
 * Debugging diagnostic printk
 */
#ifdef NF2_DEBUG
#  define PDEBUG(fmt, args...) printk(fmt, ## args)
#else
#  define PDEBUG(fmt, args...)	/* Don't do anything */
#endif

/**
 * nf2_iface_priv - Interface data structure
 * @card:	pointer to card this IF belongs to
 * @iface:	number of the interface
 * @stats:	statistics for this interface
 *
 * an instance of this structure exists for each interface/port
 * on a control card.
 * Not used for user cards.
 */

struct nf2_iface_priv {
	/* Which card does this IF belong to? */
	struct nf2_card_priv *card;

	/* What number interface is this? */
	unsigned int iface;

	/* Statistics for the interface */
	struct net_device_stats stats;
};


/**
 * nf2_user_priv - User card private data
 * @card:	pointer to the corresponding card
 * @open_count:	to keep track of no. of opening
 * @dev:	dev_t for user card
 * @cdev:	char device
 * @sem:	semaphore
 * @rx_wr_pos:
 * @rx_rd_pos:	No of bytes available for reading
 * @rx_buf_rd_pos: Actual read position
 * @inq:	read queue
 * @outq:	write queue
 *
 *
 * an instance of this structure exists for each user card.
 * Not used for control cards.
 */
struct nf2_user_priv {
	/* The card corresponding to this structure */
	struct nf2_card_priv *card;

	/* How many times has this been opened? */
	int open_count;

	/* dev_t for user cards */
	dev_t dev;

	/* Char device */
	struct cdev cdev;

	/* Mutual exclusion semaphore */
	struct semaphore sem;

	/* Track the number of bytes available for reading */
	u32 rx_wr_pos, rx_rd_pos;

	/* Actual read position */
	unsigned char *rx_buf_rd_pos;

	/* Read and write queues */
	wait_queue_head_t inq, outq;
};


/**
 * nf2_card_priv - Card data structrue
 * @pdev:	pointer to pci_dev
 * @ioaddr:	address in board memory
 * @is_ctrl:	is this control card
 * @txbuff:	trasmit buffer
 * @wr_txbuff:
 * @rd_txbuff:
 * @free_txbuffs:
 * @free_txbuffs_port:
 * @txbuff_lock:	spinlock
 * @dma_tx_addr:	addr for dma tx
 * @dma_rx_addr:	addr for dma rx
 * @dma_tx_in_progress:	is dma tx in progress
 * @dma_rx_in_progress: is dma rx in progress
 * @dma_tx_lock:	spinlock for dma tx
 * @dma_rx_lock:	spinlock for dma rx
 * @ppool:	packet pool for incoming packet
 * @ndev:	network devices
 * @ifup:	bitmask for up interfaces
 * @state_lock: semaphore for state vars
 * @upriv:	user card variables
 * @rd_pool:	last buffer used from pool
 * @wr_pool:	current buffer to process
 *
 * - an instance of this data structure exists for each card.
 */
struct nf2_card_priv {
	/* PCI device corresponding to the card */
	struct pci_dev *pdev;

	/* Address in memory of board */
	void *ioaddr;

	/* Control card */
	char is_ctrl;

	/* Transmit Buffers */
	struct txbuff *txbuff;

	/* Current and available txbuff */
	int wr_txbuff;
	int rd_txbuff;
	int free_txbuffs;
	int free_txbuffs_port[MAX_IFACE];

	/* Spinlock for the buffer variables */
	spinlock_t txbuff_lock;

	/* Address of the DMA transfer */
	u32 dma_tx_addr;
	u32 dma_rx_addr;

	/* Is a DMA transfer in progress? */
	atomic_t dma_tx_in_progress;
	atomic_t dma_rx_in_progress;
	/*int dma_tx_in_progress;*/
	/*int dma_rx_in_progress;*/

	/* Spinlock for the dma variables */
	atomic_t dma_tx_lock;
	atomic_t dma_rx_lock;
	/*spinlock_t dma_tx_lock;*/
	/*spinlock_t dma_rx_lock;*/

	/* Packet pool for incomming packets */
	struct nf2_packet *ppool;

	/* Interfaces that can currently transmit packets */
	int dma_can_wr_pkt;

	/* === Control Card Variables === */
	/* Network devices */
	struct net_device *ndev[MAX_IFACE];

	/* Which interfaces are currently up?
	 * Note: This is a bitmask*/
	unsigned int ifup;

	/* Semaphore for the state variables */
	struct semaphore state_lock;


	/* === User Card Variables === */
	struct nf2_user_priv *upriv;

	/* The current buffer to process and the last
	 * buffer used from the pool */
	struct nf2_packet *rd_pool, *wr_pool;
};


/**
 * txbuff - Buffer to hold packets to be transmitted
 * @skb:	socket buffer
 * @buff:	buffer
 * @len:	length field
 * @iface:	interface no
 *
 */
struct txbuff {
	struct sk_buff *skb;
	char *buff;
	u16 len;
	unsigned int iface;
};


/**
 * nf2_packet - A structure representing an in-flight packet being received.
 * @next:	pointer to next packet
 * @dev:	pointer to net_device
 * @len:	length of packet
 * @data:	data
 *
 */
struct nf2_packet {
	struct nf2_packet *next;
	struct net_device *dev;
	int len;
	u8 data[MAX_DMA_LEN + 2];
};


/*
 * Functions
 */
int nf2u_probe(struct pci_dev *pdev, const struct pci_device_id *id,
		struct nf2_card_priv *card);
void nf2u_remove(struct pci_dev *pdev, struct nf2_card_priv *card);
int nf2c_probe(struct pci_dev *pdev, const struct pci_device_id *id,
		struct nf2_card_priv *card);
void nf2c_remove(struct pci_dev *pdev, struct nf2_card_priv *card);

void nf2_set_ethtool_ops(struct net_device *dev);

/*
 * Variables
 */
extern int timeout;
extern int rx_pool_size;
extern int tx_pool_size;
extern int nf2_major;
extern int nf2_minor;

#endif	/* __KERNEL__ */

#endif	/* _NF2KERNEL_H */
