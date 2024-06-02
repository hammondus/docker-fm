#!/usr/bin/env bash

apt-get remove docker docker-engine docker.io containerd runc -y

echo "   - adding Docker repositories"
apt-get update > /dev/null

apt-get install ca-certificates curl gnupg lsb-release -y
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update > /dev/null
echo "   - installing Docker"
apt-get install docker-ce -y > /dev/null

echo "   - installing CLI"
apt-get install docker-ce-cli -y > /dev/null

echo "   - installling containerd.io"
apt-get install containerd.io -y > /dev/null

echo "   - installling compose-plugin"
apt-get install docker-compose-plugin -y > /dev/null
