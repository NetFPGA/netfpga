#!/bin/bash

export NET_ID=~/.ssh/net_id
defined()
{
    [[ ${!1-X} == ${!1-Y} ]]
}

defined MACHINE_LIST || export MACHINE_LIST="machine1 machine2"
defined NET_USER || export NET_USER=`whoami`

defined SSH_AGENT_PID || eval `ssh-agent -s`
if [[ -z `ssh-add -l | grep $NET_ID` ]] ; then
    ssh-add $NET_ID
fi
