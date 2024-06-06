# Installing FileMaker Server on Ubuntu in Docker

---

## Getting Started

Make sure to configure the ```fms_Docker_Installer.sh``` file to fit the parameters of the ```Assisted Install.txt``` file. Additionally, make sure that the ```filemaker-server-21.0.X.XXX-amd64.deb``` file is in the same directory as the script. If you do not have Docker installed, the script will ask if you want to install Docker. This script will create three Docker images:  

- ```fmsdocker:prep```: includes all of the FileMaker dependencies
- ```fmsdocker:primary```: includes the primary machine FileMaker Server installation (not including the ```Database``` folders unless shared as a volume)
- ```fmsdocker:secondary```: includes the secondary machine FileMaker Server installation

This script supports the FileMaker Server installation on Ubuntu 20 (amd64) and Ubuntu 22 (amd64/arm64).  

**Warning: Back up any FileMaker Server Docker containers to ensure they aren't removed.**  

### Files

- ```Dockerfile```
- ```filemaker-server-21.0.X.XXX-amd64.deb```
- ```fms_Docker_Installer.sh```
- ```Resources/```
    - ```createNetwork.sh```
    - ```createSecondary.sh```
    - ```setupConnection.sh```
    - ```stopServices.sh```

### Requirements

- Ubuntu 20 (amd64) or Ubuntu 22 (amd64/arm64).
- FileMaker Server Debian package placed in a directory.
- Only one FileMaker Server Debian package placed in a directory.
- *OPTIONAL* - SSL certificate, private key, and intermediate CA files placed in the same directory as the FileMaker Server Debian package.
- *OPTIONAL* - Static IP addresses reserved for MacVLAN.

### How to Run

#### Step 1. Place your FileMaker Server Debian package in a directory

The FileMaker Server Debian package will be used to install FileMaker Server in the containers. The ```fms_Docker_Installer.sh``` script file will search in the same directory as the ```fms_Docker_Installer.sh``` file for any Debian package that starts with "filemaker-server" and ends with ".deb".  

#### Step 2. Request and reserve a range of static IP addresses

Make sure to reserve the static IP addresses you will use for the Docker containers to ensure there are no IP address conflicts. The first address you reserve should be set to the ```IPADDRESS``` variable in the ```fms_Docker_Installer.sh``` file.  

#### Step 3. *OPTIONAL* - Modify the ```fms_Docker_Installer.sh``` file

View the available options in the "Configuration Options" section.  

#### Step 4. Run the ```fms_Docker_Installer.sh``` file

Run the ```fms_Docker_Installer.sh``` file:

- With pre-configured parameters: ```sudo ./fms_Docker_Installer.sh 1```
- Run interactively: ```sudo ./fms_Docker_Installer.sh```

---

## Resource Scripts

- **```/Resources/createNetwork.sh```**
    - Description:
        - Run on the host machine
        - Creates a MacVLAN network with the given parameters
    - Options:
        - ```SUBNET``` - IP address of the host machine
        - ```GATEWAY``` - Gateway of the network in use by host
        - ```INTERFACE``` - Interface of the network in use by host
- **```/Resources/createSecondary.sh```**
    - Description:
        - Run on the host machine
        - Creates secondary machine containers
    - Options:
        - ```MACHINENUMBER``` - Machine number used to prevent conflicts with other containers
        - ```MEMORY``` - Hard limit of memory in MB to use for the container \(i.e., 4096 MB\)
        - ```NUMBEROFCORES``` - Hard limit of cores to use for the container
        - ```HOSTNAME``` - Hostname of the container \(uses the convention ```fms-docker$number```\)
        - ```IPADDRESS``` - IP address for the container for MacVLAN
        - ```NETWORKNAME``` - Network name to connect for MacVLAN
        - ```CURDIR``` - Shared directory for setting up a connection
        - ```NETWORK``` - ```0``` for using bridged network, ```1``` for MacVLAN
        - ```CONNECT``` - ```0``` to not connect with a primary machine, ```1``` to connect with primary
        - ```PRIMARYMACHINE``` - If ```NETWORK``` = ```1``` AND ```CONNECT``` = ```1```, provide the IP address of the primary machine
        - ```USERNAME``` - If ```NETWORK``` = ```1``` AND ```CONNECT``` = ```1```, provide the Admin Console username
        - ```PASSWORD``` - If ```NETWORK``` = ```1``` AND ```CONNECT``` = ```1```, provide the Admin Console password
- **```/Resources/setupConnection.sh```**
    - Description:
        - Create a connection between a secondary machine container and a primary machine
    - Options:
        - ```PRIMARYIP $1``` - IP address of the primary machine
        - ```SECONDARYIP $2``` - IP address of the secondary machine
        - ```USERNAME $3``` - Admin Console username
        - ```PASSWORD $4``` - Admin Console password
- **```/Resources/stopServices.sh```**
    - Description:
        - Run in a container
        - Stops the FileMaker Server services

---

## Configuration Options

### General Options

- **Admin Console:** Configure the administrator settings for the primary machine using the following parameters:
    - ```USERNAME```
    - ```PASSWORD```
    - ```PIN```
- **Primary Machine Container:**
    - If you want a primary machine in a container, set ```PRIMARY``` to ```1```, otherwise set ```PRIMARY``` to ```0```.
    - If ```PRIMARY``` is set to ```0```, set ```SEPARATEHOSTIP``` to the IP address of the primary machine FileMaker Server.
- **```NUMBEROFSEC```:**
    - Set the number of secondary machine containers to create.
    - If set to ```0```, the script will not create any secondary machine containers.
- **```IMPORT```/```EXPORT```:**
    - If set to ```0```, do not import/export.
    - If set to ```1```, perform import/export.
    - ```IMPORT```:
        - Searches for ```.tar``` backup FileMaker Docker images.
        - If ```.tar``` backup FileMaker Docker images are not found, it searches for a previously built image from a previous run.
    - ```EXPORT```:
        - Creates a ```.tar``` backup FileMaker Docker image in the ```Images``` folder to move to other machines.
        - The ```.tar``` backup FileMaker Docker image includes a FileMaker primary machine or secondary machine server.

### Network Options

- **```IPADDRESS```:**
    - Set to the first available IP address for Docker.
- **```IPADDRESSES```:**
    - Set to a list of IP addresses if there are multiple IP addresses that aren't concurrent.
    - Use commas to separate IP address entries.
    - If not empty, overrides the ```IPADDRESS``` parameter.
- **```NETWORK```:**
    - Set to ```0``` to use a bridged network.
    - Set to ```1``` to create a MacVLAN network.

### Hardware Options

- **```NUMBEROFCORES```:**
    - Hard limit on the number of CPU cores available to each container.
    - If exceeded, Docker will kill the container.
- **```MEMORY```:**
    - Hard limit on the memory available to each container in MB \(i.e., 8192 MB\).
    - If exceeded, Docker will kill the container.

### FileMaker Server Options

- **```CERTIFICATE```:**
    - Set to ```0``` to not import a certificate.
    - Set to ```1``` to import certificates.
    - When set to ```1```, searches the same directory for certificates.
- **```MWPE```:**
    - Default value is ```1```.
    - Set to ```0``` to keep the native behavior \(don't disable MWPE\).
    - Set to ```1``` to disable MWPE.
- **```CONNECT```:**
    - Default value is ```1```.
    - Set to ```0``` to not connect primary machine and secondary machine containers.
    - Set to ```1``` to connect primary machine and secondary machine containers.
- **```SHARE```:**
    - Default value is ```1```.
    - Set to ```1``` to enable a shared directory between the host and primary machine container.
    - Set to ```0``` disable sharing a directory between the host and primary machine container.
    - If enabled, Docker will share the ```/opt/FileMaker/FileMaker Server/Data``` to the container with read/write permissions.
- **```DEBUG```:**
    - Default value is ```0```.
    - Set to ```1``` to print debug messages and to copy the ```ReleaseDebugOn.txt``` to the FileMaker Server installation folder for testing.
    - The ```ReleaseDebugOn.txt``` file must be placed in ```Resources``` folder for the file to be copied.
    - Generated debug logs can be accessed in ```/opt/FileMaker/FileMaker Server/Database/bin``` in each container.
    - To access each container, run:  
        > ```docker exec -it <container name> /bin/bash```  

---

## Useful Docker Commands

- **Show running containers:**  
    > ```sudo docker stats```  
- **Show the statistics of a container:**  
    > ```sudo docker container inspect <container name>```  
- **Stop a running container:**  
    > ```sudo docker container stop <container name>```   
- **Remove a stopped container:**  
    > ```sudo docker container rm <container name>```
- **Run a container from an image:**  
    > ```sudo docker run --name <container name> <parameters> <image-name>```  
- **Access a container's bash prompt:**  
    > ```sudo docker exec -it <container name> /bin/bash```  
- **Copy a file from the host computer to a container:**  
    > ```sudo docker cp <file on host> <container name>:/<destination directory>```  
- **Copy a file from a container to the host computer:**  
    > ```sudo docker cp <container name>:/<file on container> <destination on host>```  
- **Delete unused images and containers on the host machine:**  
    > ```sudo docker system prune```  
- **Check a named network for running containers and their IP addresses:**  
    > ```sudo docker network inspect <network name>```  

---

## Common Errors

- **Port is already in use.**
    - **Error:**
        > ```docker: response from daemon: driver failed programming external connectivity on endpoint fms-docker ...```  
        > ```Error starting userland proxy: listen tcp4 0.0.0.0:5003 bind: address already in use.```  
    - **Fix:**
        - Stop FileMaker Server, Nginx, or any other processes that may be using conflicting ports.
        - Ports that are used are:
            - 80
            - 442
            - 2399
            - 5003
- **Unable to find image 'for:latest' locally**
    - **Fix:**
        - Remove fmsdocker:prep, fmsdocker:primary, fmsdocker:secondary images:
            1. Stop all fmsdocker containers
            2. Run the following command:  
                > ```sudo docker image rm <image name>```  
        - The fmsdocker:prep image was built using a Dockerfile in another directory and cannot be used to create a container. Removing the image and rebuilding the container will fix this error.
- **System low on storage - Docker takes a large amount of space**
    - **Fix:**
        - Stop any currently running containers, then run the following command to clear any previous installations, containers, or images that are not in use:  
            > ```sudo docker system prune```  
- **RTNETLINK answers: File exists**
    - **Fix:**
        - No additional steps are necessary. This warning occurs when the script is run twice without a reboot in between.
        - The ```createNetwork.sh``` script will remove the MacVLAN network. However, it will not remove the link between the host system and MacVLAN. Rebooting the system will remove this link.

---

## Script Sequence Logic

1. **If ```IMPORT``` is set to ```1```:**
    - The script checks whether there are any pre-built Docker images to import.
    - If there are any images in the ```Images``` folder, the script will import it for use.
2. **If the import process fails or ```IMPORT``` is set to ```0```:**
    - The script pulls a Ubuntu 20.04 image and installs all FileMaker dependencies using the ```Dockerfile``` file.
3. **If ```NETWORK``` is set to ```1```:**
    - The Script checks for an existing ```fmsdocker``` network and stops any containers that may be connected to the previous ```fmsnetwork``` network.
    - The script then creates the network and connects it to the host network.
4. **Create and configure images, containers, and networks:**
    - Depending on primary machine or secondary machine configuration, the script installs FileMaker Server and saves the Docker image as ```fmsdocker:primary``` or ```fmsdocker:secondary```.`
    - The script connects the container to the network, disables MWPE if necessary, connects the container to DNS, and adds SSL certificates.
5. **Create secondary machine containers:**
    - The script creates multiple secondary machine containers based on the ```fmsdocker:secondary``` Docker image, depending on the configuration set by the user.
6. **If ```CONNECT``` is set to ```1```:**
    - The script connects secondary machine containers with the primary machine.
7. **If ```EXPORT``` is set to ```1```:**
    - The script uses the ```docker save``` command to export the image to a ```.tar``` backup FileMaker Docker image in the ```Images``` folder.
