#!/bin/bash

# this script generates ssh keys and distributes
# them to all machines on the network

source net_common.sh

if [[ ! -d `dirname $NET_ID` ]] ; then
    echo "Error: the directory for $NET_ID should exist on all machines"
    exit 1
fi

if [[ ! -r $NET_ID ]] ; then
    echo "Generating key $NET_ID"
    ssh-keygen -t rsa -f $NET_ID
fi
auth_var=`cat $NET_ID.pub`
id_name=`basename $NET_ID`;


for machine in $MACHINE_LIST ; do
    echo "Copying $NET_ID to $machine..."
    scp $NET_ID* $NET_USER@$machine:
    ssh $NET_USER@$machine "mkdir -p ~/.ssh/; chmod 700 ~/.ssh/ ; chmod 600 $id_name*; mv $id_name* ~/.ssh; echo $auth_var >> ~/.ssh/authorized_keys ; chmod 600 ~/.ssh/authorized_keys"
done

