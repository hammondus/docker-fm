#!/bin/bash
#
HOME_LOCATION=/home/ubuntu
SCRIPT_LOCATION=$HOME_LOCATION/install
STATE=$SCRIPT_LOCATION/state

if [ ! -d $STATE ]; then
  mkdir $STATE
fi

if [ ! -f $STATE/alias ]; then
  echo "alias update='sudo apt update && sudo apt upgrade -y'" >> $HOME_LOCATION/.bashrc
  touch $STATE/alias
fi

if [ ! -f $STATE/update ]; then
  sudo apt update && sudo apt upgrade -y
  touch $STATE/update
  echo
  echo 'Reboot and rerun install.sh'
  exit
fi


#Install Docker

if [ ! -f $STATE/docker ]; then
  echo 'Install Docker'
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl gnupg -y
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository to Apt sources:
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
  sudo groupadd docker
  sudo usermod -aG docker $USER
  touch $STATE/docker
fi

echo 'reboot and run   docker run hello-world'
