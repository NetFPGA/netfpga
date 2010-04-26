/* ****************************************************************************
 * vim:set shiftwidth=2 softtabstop=2 expandtab:
 *
 * Module: nf2_ethtool.c
 * Project: NetFPGA 2 Linux Kernel Driver
 * Description: ethtool functionality
 *
 * Initial version submitted by Kumar Sanghvi
 * Change history:
 *
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
