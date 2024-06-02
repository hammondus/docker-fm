#!/usr/bin/env bash

# This script installs and sets up Docker and FMS in a Docker container
# Filename install.sh


## CONFIGURE FOR PRIMARY CONTAINER
#   0 for use existing, 1 for create primary container
PRIMARY=0

# Use this if you are not creating a Primary Server from Container
SEPARATEHOSTIP="192.168.1.1"                      # if PRIMARY == 0, enter the primary machine IP to connect

## CONFIGURE FOR NETWORK
NUMBEROFSEC=1                                       # number of secondary containers to create
IPADDRESS="192.168.1.2"                           # first IP address available for macVLAN driver to use to
                                                    # assign to containers. For example, if the IP address is 
                                                    # 192.168.36.152, $PRIMARY is 1 $NUMBEROFSEC is 2, the 
                                                    # script will assign 192.168.36.152 to the primary, X.153 
                                                    # to secondary container #1, X.154 to secondary #2
INTERFACE=ens33                                     # automatically set by the script, interface in use by host.
                                                    # macVLAN creates a bridge using the host as a gateway and 
                                                    # connects assigned IP addresses to the network
NETWORK=1                                           # (default = 1), 0 to use host bridge network option, 1 to
                                                    # create and use macVLAN network option.
NETWORKNAME="fmsnetwork"

IPADDRESSES=""           # if a list of concurrent addresses are not availible, this
                                                    # parameter can be used to specify ip addresses. Addresses
                                                    # should be separated by a comma. ie: 
                                                    # 192.168.36.139,192.168.36.153,192.168.36.160
MACHINENUM=1
CONNECT=1                                           # (default = 1), 0 to not automatically connect secondary
                                                    # container with primary machine/container

FQDN_PRIMARY=""                                     # FQDN primary on IPADDRESS
FQDN_ADDRESSES=""                                   # List of concurrent FQDN addresses based on IPADDRESSES.
                                                    # This parameter can be used to specify FQDN. This neede when OAuth is used.
                                                    # Addresses should be separated by a comma and sorted based on IPADDRESSES. ie: 
                                                    # if IPADDRESSES="192.168.36.139,192.168.36.153", then
                                                    # FQDN_ADDRESSES="myFQDN139.myDomain.com,myFQDN153.myDomain.com"

DOCKER_INSTALLED=0

## CONFIGURE FOR ASSISTED INSTALL:
INSTALLTYPE=1
LICENSE=1
FILENAME="filemaker-server"
USERNAME=""                                     # please change this
PASSWORD=""                                     # please change this
PIN=""                                          # please change this

## DEBUG MODE
# 0 == Debug Mode Off, 1 == Debug Mode On
DEBUG=0
INTERACTIVE=$1                                      # asks use for inputs

CERTIFICATE=1                                       # (default = 1), 0 to not look for/import certificates, 1 to import
DISABLE_MWPE_ROUTING=1                              # (default = 1), 1 to disable MWPE redirect, 0 to keep native behavior
EXPORT=0                                            # 1 to create .tar export of primary & secondary containers, 0 to not
IMPORT=1                                            # 1 to use existing prebuilt images OR look for .tar exports in /Images 
                                                    # folder, 0 will not import/look for images and create a new FileMaker
                                                    # image

SHARE=0                                             # create a shared directory between host & primary container
                                                    # shared = 1 would create a shared directory using the host's
                                                    # /opt/FileMaker/FileMaker Server/Data/, contianer has rw access to 
                                                    # container

# Configure for WebDirect, if not configured, container will be allocated to use all of host machine's cores and memory.
NUMBEROFCORES=2                                     # max number of cores to allocate
MEMORY="8192m"                                      # max number of memory to allocate in MB (ie: 2048m)
MEMLIMIT="10192m"

CURDIR="$( cd "$( dirname "$0" )" && pwd )"

UBUNTU_VERSION="$( lsb_release -r | cut -f 2 )"

interactive() {
    read -p "->  Do you want to create a primary container? (0 for no, 1 for yes) " PRIMARY
    if [ $PRIMARY == 0 ] ; then
        read -p "->  What is the IP address of the Primary Machine? " SEPARATEHOSTIP
    fi
    read -p "->  How many secondary containers do you want to create? " NUMBEROFSEC
    
    read -p "->  Do you want to create a MacVLAN network (0 for no, 1 for yes) " NETWORK
    if [ $NETWORK -eq 1 ] ; then
        read -p "->  What IP addresses are availible for the containers? " IPADDRESSES
    fi 

    read -p "->  Do you want to configure the system specs for the container? (0 for no, 1 for yes) " CONFIGURE
    
    if [ $CONFIGURE -eq 1 ] ; then
        read -p "->  How many cores should be configured per container? (your system has $(nproc) cores) " NUMBEROFCORES
        read -p "->  How much memory should configured per container? (ie: 4096m) (your system has $(free -m | grep -oP '\d+' | head -n 1)m) " MEMORY
    fi
    
    read -p "->  Do you want to import certificates? (0 for no, 1 for yes) " CERTIFICATE
    read -p "->  Do you want to disable MWPE routing? (0 for no, 1 for yes) " DISABLE_MWPE_ROUTING
    read -p "->  Do you want to turn debug on? (0 for no, 1 for yes) " DEBUG

    getAdminInfo
    echo ""

    if [ -d "/opt/FileMaker/FileMaker Server/Data" ] ; then
        echo "==== There is an existing installation of FileMaker Server. The script can share the following folders"
        echo "   - /opt/FileMaker/FileMaker Server/Data"
        echo "   - /opt/FileMaker/FileMaker Server/Logs"
        echo "   - /opt/FileMaker/FileMaker Server/CStore"
        echo "==== Note: Please backup these folders."
        read -p "->  Do you want to share this with the primary container? (0 for no, 1 for yes) " SHARE

    fi


    if [ $DEBUG -eq 1 ] ; then
        echo "   > Primary: $PRIMARY"
        echo "   > Number of Secondary Machines: $NUMBEROFSEC"
        echo "   > Search for Certificates: $CERTIFICATE"
        echo "   > Debug: $DEBUG"
        echo "   > DISABLE_MWPE_ROUTING: $DISABLE_MWPE_ROUTING"
        echo "   > First IP Address Available: $IPADDRESS"
        echo "   > First FQDN: $FQDN_PRIMARY"
        echo "   > Network: $NETWORKNAME"
    fi
}


getAdminInfo() {

    read -p "->  Input username: " USERNAME
    if [ -z "$USERNAME" ] ; then
        echo "==== ERROR: Username is empty." 
        exit 1
    fi

    read -s -p "->  Input password: " PASSWORD
    echo ""
    read -s -p "->  Confirm password: " CONFIRM_PASSWORD
    echo ""
    if [ $PASSWORD != $CONFIRM_PASSWORD ] ; then
        echo "==== ERROR: The case-sensitive passwords do not match." 
        exit 1
    fi

    read -s -p "->  Input 4 digit PIN number: " PIN
    if [ "${#PIN}" -eq  4 ] && [ -n "${PIN##*[![:digit:]]*}" ]; then
        echo ""
    else
        echo "==== ERROR: pin is not 4 digit." 
        exit 1
    fi
    read -s -p "->  Confirm PIN number: " CONFIRM_PIN
    if [[ $PIN != $CONFIRM_PIN ]]; then
        echo "==== ERRPR: PIN does not match."
        exit 1
    fi
    echo ""
}

## Checks for installation files
installation_check() {
    echo "==== Starting Pre-Installation Checks"

    ## Check for Docker
    if ! docker info > /dev/null 2>&1 ; then
        echo "==== Docker is not installed. Please install and try again."

        read -p "->  Do you want to install docker? (0 for no, 1 for yes) " DOCKER_INSTALLED
        if [ $DOCKER_INSTALLED -eq 1 ] ; then
            echo "==== Installing docker."
            ./Resources/installDocker.sh
            echo "==== Finished installing docker."
        else
            exit 1
        fi 
    fi 


    ## Check for custom IP addresses
    if [ ! -z "$IPADDRESSES" ] ; then
        NUMOFADDRESSES=$(echo "$IPADDRESSES" | grep -o , | wc -l)
        NUMOFADDRESSES=$(($NUMOFADDRESSES+1))
        TOTALCONTAINERS=$(($PRIMARY+$NUMBEROFSEC))
        if [ ! -z "$IPADDRESSES" ] && [ $NUMOFADDRESSES -ge $TOTALCONTAINERS ]; then
            echo "==== Using Custom list of IP Addresses: $IPADDRESSES"
        else
            echo "==== ERROR: Mismatch of number of custom IP Addresses ($NUMOFADDRESSES) and Machines Requested($TOTALCONTAINERS)." 
            exit 1
        fi
    fi
    
    ## REMOVE ANY POTENTIALLY CONFLICTING CONTAINERS
    echo "   > DEBUG: Closing Conflicting Docker Containers."

    if [ $PRIMARY -eq 1 ] ; then
        docker stop fms-primary > /dev/null 2>&1
        docker container rm fms-primary > /dev/null 2>&1
    fi

    docker stop fms-secondary > /dev/null 2>&1
    docker container rm fms-secondary > /dev/null 2>&1
    echo "   > DEBUG: Closed and remove existing fms-primary containers."

    if [ $CERTIFICATE -eq 1 ] ; then
        PRIVATEKEY=$(find . -type f -name "*.com_key.txt" -print)
        SIGNEDCERT=$(find . -type f -name "*.crt" -print)
        INTERCERT=$(find . -type f -name "*.ca-bundle" -print)

        if [ ! -z "$PRIVATEKEY" ] && [ ! -z "$SIGNEDCERT" ] && [ ! -z "$INTERCERT" ] ; then
            echo "==== Found Certificates in Present Directory"
            if [[ "$(echo $PRIVATEKEY | cut -c1-2)" == "./" ]] ; then
                PRIVATEKEY="$(echo $PRIVATEKEY | tail -c +3)"
            fi
            if [ "$(echo $SIGNEDCERT | cut -c1-2)" = "./" ] ; then
                SIGNEDCERT=$(echo $SIGNEDCERT | tail -c +3)
            fi
            if [ "$(echo $INTERCERT | cut -c1-2)" = "./" ] ; then
                INTERCERT=$(echo $INTERCERT | tail -c +3)
            fi
        else
            echo "==== No Certificates Found."
            CERTIFICATE=0
        fi

        if [ $DEBUG -eq 1 ] ; then
            echo "   > Signed Certificate: $SIGNEDCERT"
            echo "   > Private Key: $PRIVATEKEY"
            echo "   > Intermediate CA: $INTERCERT"
        fi
    fi

    echo "   > Configuring Each Container to Have:"
    echo "      > Cores: $NUMBEROFCORES"
    echo "      > Memory: $MEMORY"
}

## Pulls Ubuntu Image
# Builds FileMaker Server Docker Image
setup() {
    echo "==== Setting up Docker Environment"

    OUTCOME=$(sudo docker image inspect ubuntu: $UBUNTU_VERSION >/dev/null 2>&1 && echo 1 || echo 0)

    if [ $OUTCOME -eq 0 ] ; then
        echo "   - Pulling Ubuntu $UBUNTU_VERSION Docker image."
        if [ $DEBUG -eq 1 ] ; then
            docker pull ubuntu:$UBUNTU_VERSION
        else
            docker pull ubuntu:$UBUNTU_VERSION >/dev/null
        fi
    else
        echo "   - Using existing Ubuntu $UBUNTU_VERSION Docker Image"
    fi
    
    OUTCOME=$(sudo docker image inspect fmsdocker:prep >/dev/null 2>&1 && echo 1 || echo 0)
    DOCKER_BUILD_OPTION=" -f ./Dockerfile_u20 "

    # ubuntu 22 both arm64 and amd64 points the same docker file
    if [ "$UBUNTU_VERSION" == "22.04" ] ; then
        DOCKER_BUILD_OPTION=" -f ./Dockerfile_u22 "
    fi

    if [ $OUTCOME -eq 0 ] ; then
        echo "   - Building Docker image with FileMaker Dependencies. $DOCKER_BUILD_OPTION"
        if [ $DEBUG -eq 1 ] ; then
            docker build -t fmsdocker:prep $DOCKER_BUILD_OPTION .
        else
            docker build -t fmsdocker:prep $DOCKER_BUILD_OPTION . >/dev/null
        fi  
    else
        echo "   - Using existing Docker fmsdocker:prep image."
    fi

    echo "   - Finished Docker Set Up"
}

## Create Network for Multiple Containers
#
# Parameters: host ip-address, gateway, interface
create_network() {
    HOSTIPADDRESS=$(hostname -I | awk '{print $1}')

    echo "==== Setting up MACVLAN network with IP address $HOSTIPADDRESS and name $NETWORKNAME"
    GATEWAY=${HOSTIPADDRESS%*.*}
    GATEWAY=$GATEWAY.1
    INTERFACE=$(basename /sys/class/net/en*)

    ./Resources/createNetwork.sh $HOSTIPADDRESS $GATEWAY $INTERFACE $NETWORKNAME
    
    echo "   - Finished Setting up Network"
}

## Creates Primary Container
#
# Parameters: IP Address, current directory, fms installation file
create_primary_container() {
    if [ $PRIMARY -ne 0 ] ; then
        INSTALLTYPE=0
        prepare_assisted_installer

        if [ ! -z "$IPADDRESSES" ] ; then
            # if using a list of ip addresses
            IPADDRESS="$(echo $IPADDRESSES | cut -d',' -f$MACHINENUM)"
        fi

        if [ ! -z "$FQDN_ADDRESSES" ] ; then
            # if using a list of ip addresses
            FQDN_PRIMARY="$(echo $FQDN_ADDRESSES | cut -d',' -f$MACHINENUM)"
        fi

        MACHINENUM=$(($MACHINENUM+1))

        echo "==== Setting up Primary Container with IP address: $IPADDRESS $MACHINENUM $IMPORT $SHARE "

        if [ $IMPORT -eq 0 ] ; then

            if [ $SHARE -eq 1 ] ; then 
                # If there is a previous FileMaker Server Installation
                if [ $NETWORK -eq 0 ] ; then
                    # using host network
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged -p 80:80 -p 443:443 -p 5003:5003 -p 2399:2399 --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install --volume "/opt/FileMaker/FileMaker Server/Data":"/opt/FileMaker/FileMaker Server/Data" --volume "/opt/FileMaker/FileMaker Server/CStore":"/opt/FileMaker/FileMaker Server/CStore" --volume "/opt/FileMaker/FileMaker Server/Logs":"/opt/FileMaker/FileMaker Server/Logs" fmsdocker:prep)
                else
                    # macvlan
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged --network="$NETWORKNAME" --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install --volume "/opt/FileMaker/FileMaker Server/Data":"/opt/FileMaker/FileMaker Server/Data" --volume "/opt/FileMaker/FileMaker Server/CStore":"/opt/FileMaker/FileMaker Server/CStore" --volume "/opt/FileMaker/FileMaker Server/Logs":"/opt/FileMaker/FileMaker Server/Logs" fmsdocker:prep)
                fi
            else
                # If there isn't a previous installation
                if [ $NETWORK -eq 0 ] ; then
                    # using host network
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged -p 80:80 -p 443:443 -p 5003:5003 -p 2399:2399 --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install fmsdocker:prep)
                else
                    # macvlan
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged --network="$NETWORKNAME" --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install fmsdocker:prep)
                fi
            fi
    
            echo "   - Primary Container ID: $OUTPUT"

            #sleep 10
            
            # fixes DNS problems with apt
            docker exec fms-primary bash -c "echo 'nameserver 8.8.8.8' | tee /etc/resolv.conf > /dev/null"

            if [ $DEBUG -eq 1 ] ; then
                docker exec fms-primary bash -c "FM_ASSISTED_INSTALL=/install apt install /install/$file -y"
            else
                docker exec fms-primary bash -c "FM_ASSISTED_INSTALL=/install apt install /install/$file -y" > /dev/null 2>&1
            fi

            if [ -f "Assisted Install.txt" ] ; then
                rm Assisted\ Install.txt
            fi  
        else
            echo "   - Using Existing Prep Image"
            if [ $SHARE -eq 1 ] ; then 
                # If there is a previous FileMaker Server Installation
                if [ $NETWORK -eq 0 ] ; then
                    # using host network
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged -p 80:80 -p 443:443 -p 5003:5003 -p 2399:2399 --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install --volume "/opt/FileMaker/FileMaker Server/Data":"/opt/FileMaker/FileMaker Server/Data" --volume "/opt/FileMaker/FileMaker Server/CStore":"/opt/FileMaker/FileMaker Server/CStore" --volume "/opt/FileMaker/FileMaker Server/Logs":"/opt/FileMaker/FileMaker Server/Logs" fmsdocker:primary)
                else
                    # macvlan
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged --network="$NETWORKNAME" --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install --volume "/opt/FileMaker/FileMaker Server/Data":"/opt/FileMaker/FileMaker Server/Data" --volume "/opt/FileMaker/FileMaker Server/CStore":"/opt/FileMaker/FileMaker Server/CStore" --volume "/opt/FileMaker/FileMaker Server/Logs":"/opt/FileMaker/FileMaker Server/Logs" fmsdocker:primary)
                fi
            else
                # If there isn't a previous installation
                if [ $NETWORK -eq 0 ] ; then
                    # using host network
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged -p 80:80 -p 443:443 -p 5003:5003 -p 2399:2399 --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install fmsdocker:primary)
                else
                    # macvlan
                    OUTPUT=$(docker run --detach --hostname fms-primary --name fms-primary --privileged --network="$NETWORKNAME" --ip="$IPADDRESS" --memory=$MEMORY --cpus=$NUMBEROFCORES --volume $CURDIR:/install fmsdocker:primary)
                fi
            fi
            echo "    - Primary Container ID: $OUTPUT"
        fi

        if [ $NETWORK -eq 1 ] && [ $DISABLE_MWPE_ROUTING -eq 1 ] ; then
            # disable MWPE routing
            docker exec fms-primary bash -c "sed -i 's/<parameter name=\"mwperouting\">yes<\/parameter>/<parameter name=\"mwperouting\">no<\/parameter>/g' /opt/FileMaker/FileMaker\ Server/Web\ Publishing/conf/jwpc_prefs.xml"
            docker exec fms-primary bash -c "chmod +x /opt/FileMaker/FileMaker\ Server/Web\ Publishing/conf/jwpc_prefs.xml"            
        fi

        # copy debug file
        if [ "$DEBUG" == "1" ] &&  [ -f "./Resources/ReleaseDebugOn.txt" ]; then
            docker exec fms-primary bash -c "cp /install/Resources/ReleaseDebugOn.txt /opt/FileMaker/FileMaker\ Server/Database\ Server/bin"
        fi

        if [ $CERTIFICATE -eq 1 ] ; then
            add_certificates_primary
        fi

        docker commit fms-primary fmsdocker:primary > /dev/null 2>&1

        echo "   - Finished Setting up Primary Container"
    fi
}

create_secondary_image() {
    INSTALLTYPE=1
    prepare_assisted_installer

    echo "==== Creating Secondary Container Image"
    OUTPUT=$(docker run --detach --hostname fms-secondary --name fms-secondary --privileged --volume $CURDIR:/install fmsdocker:prep)

    echo "   - Secondary Container ID: $OUTPUT"

    # fixes DNS problems with apt
    docker exec fms-secondary bash -c "echo 'nameserver 8.8.8.8' | tee /etc/resolv.conf > /dev/null"

    # install FMS
    if [ $DEBUG -eq 1 ] ; then 
        docker exec fms-secondary bash -c "FM_ASSISTED_INSTALL=/install apt install /install/$file -y"
    else
        docker exec fms-secondary bash -c "FM_ASSISTED_INSTALL=/install apt install /install/$file -y" > /dev/null 2>&1
    fi

    if [ -f "Assisted Install.txt" ] ; then
        rm Assisted\ Install.txt
    fi

    if [ $DISABLE_MWPE_ROUTING -eq 1 ] ; then
        # disable MWPE routing
        docker exec fms-secondary bash -c "sed -i 's/<parameter name=\"mwperouting\">yes<\/parameter>/<parameter name=\"mwperouting\">no<\/parameter>/g' /opt/FileMaker/FileMaker\ Server/Web\ Publishing/conf/jwpc_prefs.xml"
        docker exec fms-secondary bash -c "chmod +x /opt/FileMaker/FileMaker\ Server/Web\ Publishing/conf/jwpc_prefs.xml"            
    fi

    # copy debug file
    if [ "$DEBUG" == "1" ] && [ -f "./Resources/ReleaseDebugOn.txt" ]; then
        docker exec fms-secondary bash -c "cp /install/Resources/ReleaseDebugOn.txt /opt/FileMaker/FileMaker\ Server/Database\ Server/bin"
    fi

    if [ $CERTIFICATE -eq 1 ] ; then
        add_certificates_secondary
    fi
    
    docker commit fms-secondary fmsdocker:secondary > /dev/null 2>&1
    docker stop fms-secondary > /dev/null 2>&1
    docker container rm fms-secondary > /dev/null 2>&1
    echo "   - Finished Creating Secondary Container Image"
}



## Creates Secondary Containers
#
# Parameters: Primary IP address, number of secondary, current directory, installation folder
create_secondary_container() {
    # if there is no primary machine, set host to predefined variable
    echo "==== Creating $NUMBEROFSEC Secondary Containers"


    if [ $NUMBEROFSEC -ne 0 ] ; then 
        # if not using list of ip addresses        
        IPPREFIX=${IPADDRESS%*.*}
        IPLASTOC=${IPADDRESS##*.}

        
        if [ $PRIMARY -eq 0 ] ; then
            # primary container was not created, using separate machine
            # don't use first ip address, use user specified address
            IPADDRESS=$SEPARATEHOSTIP

            if [ ! -z "$FQDN_PRIMARY" ] ; then
                IPADDRESS=$FQDN_PRIMARY
            else
                IPADDRESS=$SEPARATEHOSTIP
            fi
        else
            IPLASTOC=$((IPLASTOC+1))
        fi

        for ((i=1; i<=$NUMBEROFSEC; i++)) ;
        do
            if [ ! -z "$IPADDRESSES" ] ; then
                # if using a list of ip addresses
                CURIP="$(echo $IPADDRESSES | cut -d',' -f$MACHINENUM)"
            else
                # using concurrent ip addresses
                CURIP="$IPPREFIX.$IPLASTOC"
            fi

            if [ ! -z "$FQDN_ADDRESSES" ] ; then
                # if using a list of ip addresses
                FQDN_NAME="$(echo $FQDN_ADDRESSES | cut -d',' -f$MACHINENUM)"
            fi

            HOSTNAME="fms-secondary$i"

            MACHINENUM=$(($MACHINENUM+1)) # used for nonconcurrent IP addresses

            if [ $NETWORK -eq 0 ] ; then 
                CURIP=$(hostname -I | awk '{print $1}')
            fi

            #create secondary container
            ./Resources/createSecondaryContainer.sh $i $IPADDRESS $CURIP $NETWORKNAME $CURDIR $USERNAME $PASSWORD $MEMORY $NUMBEROFCORES $NETWORK $HOSTNAME $CONNECT $FQDN_NAME
            
            IPLASTOC=$((IPLASTOC+1))
        done

        echo "   - Finished Setting up Secondary Containers"
    fi
}

## Prepares Assisted Installer: Creates file for assisted installation using
#  given parameters.
prepare_assisted_installer() {
    printf "[Assisted Install]\n\n" > Assisted\ Install.txt
    printf "License Accepted=$LICENSE\n\n" >> Assisted\ Install.txt
    printf "Deployment Options=$INSTALLTYPE\n\n" >> Assisted\ Install.txt
    printf "Admin Console User=$USERNAME\n\n" >> Assisted\ Install.txt
    printf "Admin Console Password=$PASSWORD\n\n" >> Assisted\ Install.txt
    printf "Admin Console PIN=$PIN\n\n" >> Assisted\ Install.txt
    printf "License Certificate Path=" >> Assisted\ Install.txt
}

## Add Certificates - Primary
add_certificates_primary() {
    echo "   - Setting up Certificates for Primary Machine /install/$SIGNEDCERT /install/$PRIVATEKEY /install/$INTERCERT"
    docker exec fms-primary bash -c "fmsadmin certificate import /install/$SIGNEDCERT --keyfile /install/$PRIVATEKEY --intermediateCA /install/$INTERCERT -y -u admin -p admin" > /dev/null 2>&1

    restart_primary
    
    echo "   - Finished Adding Certificates for Primary Container"
}

## Add Certificates - Secondary
add_certificates_secondary() {
    echo "   - Setting up Certificates for Secondary Container"
    docker exec fms-secondary bash -c "fmsadmin certificate import /install/$SIGNEDCERT --keyfile /install/$PRIVATEKEY --intermediateCA /install/$INTERCERT -y -u admin -p admin" > /dev/null 2>&1

    # restart secondary
    docker exec fms-secondary bash -c "./install/Resources/stopServices.sh" > /dev/null 2>&1
    docker exec fms-secondary bash -c "/bin/systemctl start fmshelper.service"
    
    echo "   - Finished Adding Certificates for Secondary Container"
}

export_images() {
    VERSION=$(echo $file | grep -o -P '(?<=filemaker-server-).*(?=-amd64.deb)')

    if ! [ -d "Images" ] ; then
        mkdir Images
    fi
    if [ $PRIMARY == 1 ] && [ $NUMBEROFSEC -gt 0 ] ; then
        echo "==== Exporting Primary Image as \"/Images/fmsdockerprimary-$VERSION.tar\""
        docker save --output Images/fmsdockerprimary-$VERSION.tar fmsdocker:primary & 
        P1=$!

        echo "==== Exporting Secondary Image as \"/Images/fmsdockersecondary-$VERSION.tar\""
        docker save --output Images/fmsdockersecondary-$VERSION.tar fmsdocker:secondary &
        P2=$!

        wait $P1 $p2

        chmod +rw Images/fmsdockerprimary-$VERSION.tar
        chmod +rw Images/fmsdockersecondary-$VERSION.tar
    
    elif [ $PRIMARY == 1 ]; then
        echo "==== Exporting Primary Image as \"/Images/fmsdockerprimary-$VERSION.tar\""
        docker save --output Images/fmsdockerprimary-$VERSION.tar fmsdocker:primary
        chmod +rw Images/fmsdockerprimary-$VERSION.tar
    else 
        echo "==== Exporting Secondary Image as \"/Images/fmsdockersecondary-$VERSION.tar\""
        docker save --output Images/fmsdockersecondary-$VERSION.tar fmsdocker:secondary
        chmod +rw Images/fmsdockersecondary-$VERSION.tar
    fi
}

import_images() {
    echo "==== Starting Import - Images folder exists."

    OUTCOME=$(sudo docker image inspect fmsdocker:primary >/dev/null 2>&1 && echo 1 || echo 0)

    if [ $OUTCOME -eq 0 ] ; then
        echo "   - No existing prebuilt primary container. Searching for .tar file."
        ## Check for FMSServer Install
        found=0
        if [ -d "Images" ] ; then
            for fileIMPORT in Images/* ; do
                echo $fileIMPORT
                if [[ "$fileIMPORT" == "Images/fmsdockerprimary"* ]] ; then
                    echo "   - Using $fileIMPORT for FMS Installation."
                    found=1
                    break
                fi
            done

            if [ $found -eq 1 ] ; then
                VERSION=$(echo $fileIMPORT | grep -o -P '(?<=fmsdockerprimary-).*(?=-.tar)')
                echo "   - Importing Primary Image from \"/Images/fmsdockerprimary.tar\" version: $VERSION"
                docker load --input $fileIMPORT
            else
                IMPORT=0
                echo "==== Couldn't find any Primary Images to import."
            fi
        else
            IMPORT=0
            echo "==== Couldn't find a /Images folder or any other images."
        fi
    else
        echo "   - Docker already has a fmsdocker:primary image for Primary Server - not importing"
    fi

    OUTCOME=$(sudo docker image inspect fmsdocker:secondary >/dev/null 2>&1 && echo 1 || echo 0)
    if [ $OUTCOME -eq 0 ] && [ $IMPORT -eq 1 ] ; then
        echo "   - No existing prebuilt secondary container. Searching for .tar file."
        found=0
        if [ -d "Images" ] ; then
            for fileIMPORT in Images/* ; do
                if [[ "$fileIMPORT" == "Images/fmsdockersecondary"* ]] ; then
                    echo "   - Using $fileIMPORT for FMS Installation."
                    found=1
                    break
                fi
            done

            if [ $found -eq 1 ] ; then
                VERSION=$(echo $fileIMPORT | grep -o -P '(?<=fmsdockersecondary-).*(?=-.tar)')
                echo "   - Importing Secondary Image as \"/Images/fmsdockersecondary.tar\" version: $VERSION"
                docker load --input $fileIMPORT
            else
                IMPORT=0
                echo "==== Couldn't find any Secondary Images to import."
            fi
        else
            echo "==== Couldn't find image folder. Trying to create secondary image. "
            create_secondary_image   
        fi
    else
        if [ $IMPORT -eq 1 ]; then 
            echo "   - Docker already has a fmsdockers:prep image for Secondary Server - not importing"
        fi
    fi
    
    echo "==== Finished Importing"
}

## Restart Primary Container
restart_primary() {
    echo "   - Restarting Primary Container"
    docker exec fms-primary bash -c "./install/Resources/stopServices.sh" > /dev/null 2>&1
    docker exec fms-primary bash -c "/bin/systemctl start fmshelper.service > /dev/null 2>&1"
}

check_for_installer() {
    #check for root
    if [ "$(id -u)" -ne "0" ] ; then
        echo "==== ERROR: Docker requires root to connect to the docker daemon socket. Please run script as root and try again."
        exit 1
    fi

    found=0
    ## Check for FMSServer Install
    for file in * ; do
        if [[ "$file" == "$FILENAME"* ]]; then
            if [[ "$file" == *".deb" ]]; then
                echo "==== Using $file for FMS Installation."
                found=1
                break
            fi
        fi
    done

    if [ $found -eq 0 ] ; then
        echo "==== ERROR: FileMaker Server Install file not found in $CURDIR"
        echo "==== Finished ..."
        exit 1
    fi

    if [ $DEBUG -eq 1 ] ; then
        if ! docker info > /dev/null 2>&1 ; then
            echo "=== Docker is not installed. Please install and try again."
            exit 1
        fi 
    fi

    # sanity check for ubuntu version
    if [ "$UBUNTU_VERSION" == "20.04" ] || [ "$UBUNTU_VERSION" == "22.04" ] ; then
        echo "=== using Ubuntu version $UBUNTU_VERSION"
    else
        echo "=== this docker script only support ubuntu 20.04 and ubuntu 22.04 ."
        exit 1
    fi    
}

check_for_installer
installation_check
if [ "$INTERACTIVE" != "1" ] ; then
    interactive
else
    getAdminInfo    
fi
setup

if [ $NETWORK -eq 1 ] ; then
    create_network
else
    NETWORKNAME="bridge" # using bridge
    echo "==== No Network Option Set - Using existing $NETWORKNAME"
    if [ $PRIMARY -eq 1 ] && [ $NUMBEROFSEC -gt 0 ] ; then
        echo "==== ERROR: Only one container can be set up using bridge."
        exit 1
    fi
fi

if [ $IMPORT -eq 1 ] ; then
    # IMPORT IMAGES
    import_images
    if [ $IMPORT -eq 0 ] ; then
        # IMPORT FAILED, CREATE CONTAINERS
        create_primary_container

        # only do if secondary is needed
        if [ $NUMBEROFSEC -gt 0 ] ; then
    	create_secondary_image
        fi
    else
        create_primary_container
    fi
else
    if [ $PRIMARY -eq 1 ] ; then 
        create_primary_container
    fi
    create_secondary_image
fi

if [ $NUMBEROFSEC -gt 0 ] ; then 
    create_secondary_container
fi

if [ $PRIMARY -eq 1 ] ; then 
    restart_primary
fi

if [ $EXPORT -eq 1 ] && [ $IMPORT -ne 1 ] ; then 
    export_images
fi

if [ -f "Assisted Install.txt" ] ; then 
    rm "Assisted Install.txt"
fi

echo "==== Completed"
