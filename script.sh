#!/bin/bash

### Installation of Docker
sudo apt-get update

if [ -x "$(command -v docker)" ]; then
    echo "Docker is already installed"
else
    echo "Docker will be installed"
    sudo apt-get install \
		  apt-transport-https \
		  ca-certificates \
		  curl \
		  gnupg-agent \
		  software-properties-common

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update   
sudo apt-get install docker-ce docker-ce-cli containerd.io
fi

### Add Certbot PPA

read -p "Do you want to install Certbox for SSL certifcates (y/n)?" CONT
if [ "$CONT" = "y" ]; then
  sudo apt-get update
  sudo apt-get install software-properties-common
  sudo add-apt-repository universe
  sudo add-apt-repository ppa:certbot/certbot
  sudo apt-get update
  
  ### Install Certbot
  sudo apt-get install certbot python-certbot-nginx
  ### Get the certificate only
  sudo certbot certonly --nginx
  
else
  echo "SSL Certificates will not be installed"
fi








