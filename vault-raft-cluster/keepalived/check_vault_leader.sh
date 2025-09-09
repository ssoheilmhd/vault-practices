#!/bin/bash

curl -s "http://127.0.0.1:8200/v1/sys/health" | grep -w "standby\"\:false" > /dev/null
this_node_is_leader=$?

if [[ $this_node_is_leader = 0 ]]
then
    exit 0
else
    exit 1
fi
