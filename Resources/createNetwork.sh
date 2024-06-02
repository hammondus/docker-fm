#!/usr/bin/env bash

## This script creates a MACVLAN network with the parameters passed.

SUBNET=$1           # IP address of the host machine
GATEWAY=$2          # ip address of the gateway in use by the network of the host
INTERFACE=$3        # interface of the network in use by the host - find using ip r
NETWORKNAME=$4

# Checks for existing networks and removes containers that are connected
# Network is purged because there may be conflicting IP addresses in use.

OUTCOME=$(sudo docker network ls | grep $NETWORKNAME >/dev/null && echo 1 || echo 0)
if [ $OUTCOME -eq 1 ] ; then
    echo "   - Removing network with the name $NETWORKNAME"
    OUTCOME=$(docker network inspect $NETWORKNAME | grep Name | tail -n +2 | cut -d':' -f2 | tr -d ',"')
    VALUE=$(echo $OUTCOME | cut -d' ' -f 1)
    while [ -n "$OUTCOME" ];
    do
        docker container stop $VALUE > /dev/null
        echo "   - Removing $(docker container rm $VALUE)"
        OUTCOME=$(docker network inspect $NETWORKNAME | grep Name | tail -n +2 | cut -d':' -f2 | tr -d ',"')
        VALUE=$(echo $OUTCOME | cut -d' ' -f 1)
    done
    docker network rm $NETWORKNAME > /dev/null
fi

echo "   - Creating MACVLAN Network named $NETWORKNAME"

echo "      Parameters:"
echo "      - Gateway: $GATEWAY" 
echo "      - Subnet/Host-Address: $SUBNET" 
echo "      - Interface: $INTERFACE"

docker network create -d macvlan --subnet=$SUBNET/24 --gateway=$GATEWAY -o parent=$INTERFACE $NETWORKNAME
#echo "   - Network ID: $(docker network create -d macvlan --subnet=$SUBNETT/24 --gateway=$GATEWAY -o parent=$INTERFACE --aux-address \'host=$SUBNET\' $NETWORKNAME)"
sleep 5

# links network with system
ip link add $NETWORKNAME link $INTERFACE type macvlan mode bridge > /dev/null
ip link set $NETWORKNAME up > /dev/null

# enable promiscuous mode on macvlan network adaptor. 
# this is needed if you run VM on apple silicon arm machine, since we are using static ip on the docker containers
ifconfig $NETWORKNAME promisc
