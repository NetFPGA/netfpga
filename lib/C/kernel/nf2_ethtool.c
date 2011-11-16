/*-
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Kumar Sanghvi <divinekumar@gmail.com>
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
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 *
 * Module: nf2_ethtool.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: ethtool functionality
 */

#include <linux/netdevice.h>
#include <linux/ethtool.h>

/**
 * nf2_get_settings - get settings for ethtool
 * @dev:	net_device pointer
 * @ecmd: 	ethtool command
 *
 * Use to fill up ethtool values so that ethtool
 * command on the interface will return appropriate
 * values
 */
static int nf2_get_settings(struct net_device *dev,
		struct ethtool_cmd *ecmd)
{
	ecmd->supported = SUPPORTED_1000baseT_Full |
		SUPPORTED_MII;
	ecmd->advertising = ADVERTISED_TP;
	ecmd->port = PORT_MII;
	ecmd->speed = SPEED_1000;
	ecmd->duplex = DUPLEX_FULL;
	ecmd->autoneg = AUTONEG_DISABLE;

	return 0;
}

/**
 * nf2_set_settings - set values passed from ethtool
 * @dev:	net_device pointer
 * @ecmd:	ethtool command
 *
 * Can be used to configure the interface from the
 * parameters passed via ethtool command
 */
static int nf2_set_settings(struct net_device *dev,
		struct ethtool_cmd *ecmd)
{
	return 0;
}

static void nf2_get_drvinfo(struct net_device *dev,
		struct ethtool_drvinfo *drvinfo)
{

}

static int nf2_phys_id(struct net_device *dev, __u32 data)
{
	return 0;
}

static const struct ethtool_ops nf2_ethtool_ops = {
	.get_settings		= nf2_get_settings,
	.set_settings		= nf2_set_settings,
	.get_drvinfo		= nf2_get_drvinfo,
	.get_link		= ethtool_op_get_link,
	.phys_id		= nf2_phys_id,
};

void nf2_set_ethtool_ops(struct net_device *dev)
{
	SET_ETHTOOL_OPS(dev, &nf2_ethtool_ops);
}
