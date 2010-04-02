#!/bin/bash

# This script executes a command on all machines in $NET_MACHINES
# if the word _index is found in the arguments, it is replaced by the index
# of the machine in the list

source net_common.sh

index=0;
for machine in $MACHINE_LIST ; do
    # do the replacement of the _index variable
    cmd=`echo "$@" | sed {s/_index/$index/} -`
    echo "Executing \"$cmd\" on $machine..."
    ssh -t -i $NET_ID $NET_USER@$machine "$cmd"
    ((index++))
done
