#!/bin/bash

# This script copies to all machines in $NET_MACHINES
# First parameter is a directory or file, second parameter
# is the parent directory on remote machine

source net_common.sh

mkdir /tmp/exec_scp_priv

tar -czvf /tmp/exec_scp_priv/exec_scp_tmp.tgz $1

for machine in $MACHINE_LIST ; do
    echo "Copying $1 to $machine:$2...";
    scp -i $NET_ID /tmp/exec_scp_priv/exec_scp_tmp.tgz $NET_USER@$machine:$2
    ssh -i $NET_ID $NET_USER@$machine "cd $2; tar -zxf exec_scp_tmp.tgz; rm -f exec_scp_tmp.tgz" &
done

wait

rm -rf /tmp/exec_scp_priv
