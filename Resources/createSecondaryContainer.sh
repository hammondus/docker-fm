#!/usr/bin/env bash

##  This script creates a secondary container with the parameters passed. This script
#   will connect the new container with an existing primary machine with the parameter provided.

MACHINENUMBER=$1        # Specified for adding additional containers
                        # make sure to specify a number that is not in use if adding.
                        # Otherwise, script will replace the container with the number.
MEMORY=$8               # Max Limit for container to use, if container exceeds this amount, 
                        # Docker will kill the container.
NUMBEROFCORES=$9        # Number of Cores allocated to container for use.
HOSTNAME=${11}

# Network Options
IPADDRESS=$3            # IP Address of the container, specified for MacVLAN networks.
NETWORKNAME=$4          # Docker Network to join.
CURDIR=$5               # Used as a shared directory for adding certificates
NETWORK=${10}           # Used to determine if using a macvlan or bridged, 0 for bridged & 1 for macvlan
CONNECT=${12}

FQN_NAME=${13}          # FQN for secondary worker

# Connect Primary Machine with new Secondary
PRIMARYMACHINE=$2       # Primary Machine IP address
USERNAME=$6             # username of admin console - used to connect primary & new secondary
PASSWORD=$7             # password of admin console 

echo "   > Setting Up Secondary Container #$MACHINENUMBER with IP Address $IPADDRESS"

# removes any containers with the same name
OUTCOME=$(sudo docker container inspect fms-secondary$MACHINENUMBER >/dev/null 2>&1 && echo 1 || echo 0)
if [ "$OUTCOME" == "1" ] ; then
    echo "      - Stopping and removing any containers with name fms-secondary$MACHINENUMBER"
    docker stop fms-secondary$MACHINENUMBER > /dev/null 2>&1
    docker container rm fms-secondary$MACHINENUMBER > /dev/null 2>&1
fi

if [ "$NETWORK" == "0" ] ; then
    # if using a bridged network.
    echo "      - Container ID: $(docker run --detach --hostname $HOSTNAME --name $HOSTNAME --privileged --memory=$MEMORY --cpus=$NUMBEROFCORES -p 80:80 -p 443:443 -p 2399:2399 -p 5003:5003 --volume $CURDIR:/install fmsdocker:secondary)"
else
    # if using a macvlan network
    echo "      - Container ID: $(docker run --detach --hostname $HOSTNAME --name $HOSTNAME --privileged --memory=$MEMORY --cpus=$NUMBEROFCORES --network=$NETWORKNAME --volume $CURDIR:/install --ip=$IPADDRESS fmsdocker:secondary)"
fi

# Restart Secondary Container
docker exec fms-secondary$MACHINENUMBER bash -c "./install/Resources/stopServices.sh" > /dev/null 2>&1
docker exec fms-secondary$MACHINENUMBER bash -c "/bin/systemctl start fmshelper.service"

# set up connection with primary and secondary
if [ "$CONNECT" == "1" ] ; then
    if [ ! -z "$FQN_NAME" ] ; then
        docker exec fms-secondary$MACHINENUMBER bash -c "/install/Resources/setupConnection.sh $PRIMARYMACHINE $FQN_NAME $USERNAME $PASSWORD" > /dev/null
        echo "      - Established connection between Primary ($PRIMARYMACHINE) and Container #$MACHINENUMBER ($FQN_NAME)"
    else
        docker exec fms-secondary$MACHINENUMBER bash -c "/install/Resources/setupConnection.sh $PRIMARYMACHINE $IPADDRESS $USERNAME $PASSWORD" > /dev/null
        echo "      - Established connection between Primary ($PRIMARYMACHINE) and Container #$MACHINENUMBER ($IPADDRESS)"
    fi
fi

docker exec fms-secondary$MACHINENUMBER bash -c "echo 'nameserver 8.8.8.8' | tee /etc/resolv.conf > /dev/null"


# Restart Secondary Container
#docker exec fms-secondary$MACHINENUMBER bash -c "./install/Resources/stopServices.sh" 
#docker exec fms-secondary$MACHINENUMBER bash -c "/bin/systemctl start fmshelper.service"

echo "      > Finished Setting up Secondary Container #$MACHINENUMBER"
