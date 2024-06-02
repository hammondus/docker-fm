FROM ubuntu:22.04

# update all software download sources
RUN DEBIAN_FRONTEND=noninteractive      \
    apt update
 
# upgrade all installed software
# packages
RUN DEBIAN_FRONTEND=noninteractive      \
    apt full-upgrade                 -y

# update all software download sources
RUN DEBIAN_FRONTEND=noninteractive      \
    apt update

# install filemaker server dependencies
RUN DEBIAN_FRONTEND=noninteractive      \
    apt install                      -y \
        acl                             \
        apt-utils                       \
        apache2-bin                     \
        apache2-utils                   \
        avahi-daemon                    \
        ca-certificates                 \
        curl                            \
        expect                          \
        firewalld                       \
        fonts-baekmuk                   \
        fonts-liberation2               \
        fonts-noto                      \
        fonts-takao                     \
        fonts-wqy-zenhei                \
        logrotate                       \
        lsb-release                     \
        net-tools                       \
        nginx                           \
        openssl                         \
        policycoreutils                 \
        sysstat                         \
        unzip                           \
        zip                             
 
# install user management
RUN DEBIAN_FRONTEND=noninteractive      \
    apt install                      -y \
        init
 
# clean up installations
RUN DEBIAN_FRONTEND=noninteractive      \
    apt --fix-broken install         -y
RUN DEBIAN_FRONTEND=noninteractive      \
    apt autoremove                   -y
RUN DEBIAN_FRONTEND=noninteractive      \
    apt clean                        -y

# COPY . /install/
 
# document the ports that should be
# published when filemaker server
# is installed
EXPOSE 80
EXPOSE 443
EXPOSE 2399
EXPOSE 5003
 
# when containers run, start this
# command as root to initialize
# user management
USER root
CMD ["/sbin/init"]
