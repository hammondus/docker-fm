# docker-fm
AWS with docker, filemaker and nginx reverse proxy



Below is copy of README from Filemaker's Docker install

# Installing FileMaker Server on Ubuntu 20/22 in Docker


## Getting Started:
---------------------------
Make sure to configure the fms_Docker_Installer.sh to fit the parameters of 
the Assisted Install.txt. Additionally, make sure that the filemaker-server-19.6.1.XXX-amd64.deb 
file is in the same directory as the script. If you do not have Docker installed, the script will 
ask if you want to install Docker. This script will create three images: fmsdocker:prep, 
fmsdocker:primary, fmsdocker:secondary.

fmsdocker:prep includes all of the FileMaker dependencies, fmsdocker:primary includes the install of 
primary FileMaker Server, and fmsdocker:secondary includes the install of secondary primary server - 
without any Database folders, unless shared as a volume.

This script supports FileMaker server installation on ubuntu 20 (amd64) and ubuntu 22 (amd64/arm64)

** Warning: Backup any FileMaker Server Docker containers to make sure they aren't be removed. **


#### Files:
Dockerfile
filemaker-server-19.6.X.XXX-amd64.deb (JUST ONE PACKAGE SHOULD BE IN THE DIRECTORY)
fms_Docker_Installer.sh
/Resources/createNetwork.sh
/Resources/createSecondary.sh
/Resources/setupConnection.sh
/Resources/stopServices.sh

#### Requirements:
1. Debian package of FMS 20.1/19.6 placed in directory folder. Only one debian package should be 
in the directory.
2. [OPTIONAL] Place certificate, private key, and intermediateCA
in the directory folder.
3. [OPTIONAL] Static IP addresses put aside for macVLAN network.

#### How to Run:
---------------------------
**Step 1. Place your FileMaker Server Ubuntu debian installer in the current directory.**
The FileMaker Server Debian package will be used to install FileMaker Server in the containers. The 
script will search in the directory with the fms_Docker_Installer.sh for any debian package that 
starts with "filemaker-server" and ends with ".deb".

**Step 2. Request, put aside a range of static IP addresses**
Make sure to put aside the number of static IP addresses you are going to use
for the Docker containers to make sure there are no IP conflicts.
The first address you will use will be the IPADDRESS variable.

**Step 3. Configure fms_Docker_Installer.sh if necessary.**

View available options to configure in the "Options to Configure" Section.

**Step 4. Run the fms_Docker_Installer.sh**
Run `sudo ./fms_Docker_Installer.sh 1` if you have preconfigured parameters or run 
interactively using `sudo ./fms_Docker_Installer.sh`

## Additional Scripts
---------------------------
**/Resources/createNetwork.sh** - run on host machine
This script creates a MACVLAN network with the given parameters.

Options to configure:

SUBNET - IP address of the host machine
GATEWAY - gateway of network in use by host
INTERFACE - interface of network in use by host

**/Resources/createSecondary.sh** - run on host machine
This script creates secondary containers.

Options to configure:

MACHINENUMBER - machine number to prevent conflicts with other containers 
MEMORY - hard limit of memory in MB for container (ie: 4096m)
NUMBEROFCORES - hard limit of cores for container
HOSTNAME - hostname of container(use convention fms-docker$number)
IPADDRESS - IP address for container, applicable for macVLAN
NETWORKNAME - network name to connect, for macVLAN
CURDIR - shared directory for setting up a connection
NETWORK - 0 for using bridged network, 1 for macVLAN
CONNECT - 0 to not connect with a primary machine, 1 to connect with primary
PRIMARYMACHINE - (if NETWORK == 1 & CONNECT == 1) IP of primary machine address
USERNAME - (if NETWORK == 1 & CONNECT == 1) username of FAC
PASSWORD - (if NETWORK == 1 & CONNECT == 1) password of FAC


**/Resources/setupConnection.sh** - run in contianer
This script helps create a connection between a secondary container and primary machine/container

Options to configure as runtime parameters:

PRIMARYIP $1 - ip address of the first machine/container
SECONDARYIP $2 - ip address of the secondary container
USERNAME $3 - username of the FAC for primary machine/container
PASSWORD $4 - password of the FAC for secondary machine/container

**/Resources/stopServices.sh** - run in contianer


## Options to Configure:
---------------------------
**General Options:**
---------------------------
**Admin Console:** 
Configure the admin settings of the primary machine using parameters, USERNAME, PASSWORD, and PIN.

**Primary Container:** 
If you want a primary machine in a container, make sure PRIMARY is 1, otherwise PRIMARY should be 0. 
If PRIMARY is set to 0, set **SEPARATEHOSTIP** to the IP address of the primary FileMaker Server.

**NUMBEROFSEC**
Configure the number of secondary containers to configure. If 0, the script will not create any 
secondary containers.

**IMPORT/EXPORT** = 0 to not import/export, 1 to import/export. 
IMPORT - searches for .tar backup for filemaker, if it doesn't exist, it searches for a previously 
built image that may exist if the script was ran before
EXPORT - creates an .tar backup in Images folder to move to other machines. This includes a 
filemaker primary or secondary server.

**Network Options:**
---------------------------
**Network:** 
Configure the IPADDRESS with the first IP address that is availible for Docker. IPADDRESSES can be 
used if there are multiple IP addresses that aren't concurrent. NETWORK, if 0, will use bridge as 
a default, if 1 will create a MACVLAN network.

**IPADDRESS** = one IP address before IP static addresses.

**IPADDRESSES** = custom list of IP addresses, use comma to separate between entries. 
If not empty, the script will use this over the IPADDRESS parameter.

**Hardware Options:**
---------------------------
**NUMBEROFCORES** = hard limit for cores available to each container

**MEMORY** = hard limit for memory available to each container in MB(ie: 8192m). 
If exceeded, Docker will kill the container.

**FileMaker Server Options:**
---------------------------

**CERTIFICATE** = 0 to not import certificate, 1 to import certificates.
Script will search in directory to see if there are certificates.

**MWPE** (1 is default) = 0 to keep native behavior - don't disable MWPE, 1 to disable 

**CONNECT** (1 is default) = 0 to not connect primary & secondary containers, 1 to connect

**SHARE** (1 is default) = 1 to enable shared directory with host & primary container, 0 disable. 
If enabled, Docker will share /opt/FileMaker/FileMaker Server/Data folder, which allows the container 
to read/write to the directory.

**DEBUG** (0 is default) = 1 to print debug messages and to copy ReleaseDebugOn.txt for testing. 
ReleaseDebugOn.txt must be placed in /Resources/ folder to copy. Logs can be accessed in 
/opt/FileMaker/FileMaker Server/Database/bin in each container. To access each container, 
run "docker exec -it <container name> /bin/bash"

## Useful Commands
`sudo docker stats` - shows running containers

`sudo docker container inspect <container name>` - inspect stats of container, network, and other information


`sudo docker container stop <container name>` - stop a container that is running

`sudo docker container rm <container name>` - remove a container that is not running

`sudo docker run --name <container name> <parameters> <image-name>` - run a container based off an image

`sudo docker exec -it <container name> /bin/bash` - create a shell window of a container to access files/execute commands

`sudo docker cp <file on host> <container name>:/<destination directory>` - copy file from host to a container

`sudo docker cp <container name>:/<file on container> <destination on host>` - copy file from container to host

`sudo docker system prune` - deletes unused images/containers on host machine to clear space

`sudo docker network inspect <network name>` - inspect network with name <network name> parameter, see connected containers and their ip addresses

## Debug:
---------------------------
**Port is already in use.**
docker: response from daemon: driver failed programming external connectivity on endpoint fms-docker ... 
Error starting userland proxy: listen tcp4 0.0.0.0:5003 bind: address already in use.

**Fix:** 
Stop FileMaker Server/NGINX or any other processes that may be using conflicting ports.

Ports that are used are: 80, 442, 2399, 5003

**Unable to find image 'for:latest' locally**

**Fix** 
Remove fmsdocker:prep, fmsdocker:primary, fmsdocker:secondary image by first stopping all fmsdocker containers 
and then using the command `sudo docker image rm <image name>`.

The fmsdocker:prep image was built using a Dockerfile in another directory and cannot be
used to create a container. Removing the image and rebuilding the container will fix
this error.

**System low on storage - Docker takes a large amount of space**

**Fix** 
Stop any currently running containers and run `sudo docker system prune` to clear any previous installations, 
containers/images that are not in use.

**RTNETLINK answers: File exists**

**Fix**
No additional steps are necessary. This warning occurs when the script is run twice without a reboot in between. 
The "createNetwork.sh" script will remove the macVLAN network, however it will not remove the link between the host 
system and macVLAN. Rebooting the system will remove this link.

## Logic:
---------------------------
1. (IMPORT = 1) Script checks to see if there are any prebuilt images/images to import. If there are any images 
in the /Images folder, the script will import it for use. If the import fails or if IMPORT=0, the script will 
proceed to install FMS
2. (IMPORT = 0/ import fails) The script pulls a Ubuntu 20.04 image and installs all FileMaker dependencies 
using the Dockerfile.
3. (NETWORK = 1) Script checks for an existing fmsdocker network and stops any containers that may be connected 
to the previous fmsnetwork. The script then creates the network and connects it to the host network.
4. Depending on primary/secondary config, the script installs FileMaker Server and saves the image as 
fmsdocker:primary or fmsdocker:secondary. Connets the container to the network, disables MWPE(if necessary), 
DNS, and adds certificates.
5. The script then creates multiple secondary containers based off of the fmsdocker:secondary image depending 
on the config set by the user.
6. (CONNECT = 1) Script connects secondary containers with the primary containers.
7. (EXPORT = 1) Script uses `docker save` to export the image to .tar in the /Images folder.
