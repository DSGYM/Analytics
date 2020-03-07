#!/bin/bash

### Installation of Docker
sudo apt-get update

sudo mkdir ./compose
sudo mkdir ./compose/certs
sudo mkdir ./compose/shinyproxy_raw
sudo mkdir ./compose/shinyproxy
sudo mkdir ./compose/nginx
sudo mkdir ./compose/mariadbdata

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

read -p 'Please enter your domain name: (Name must match the domain during certbox installation) ' domain

sudo cp /etc/letsencrypt/live/${domain}/fullchain.pem ./compose/certs/fullchain.pem
sudo cp /etc/letsencrypt/live/${domain}/privkey.pem	./compose/certs/privkey.pem

openssl pkcs12 -inkey ./compose/certs/privkey.pem -in ./compose/certs/fullchain.pem -export -out ./compose/shinyproxy/certificate.pfx

### ShinyProxy needs enough rights inside Docker container
sudo chmod 777 ./compose/certs/privkey.pem
sudo chmod 777 ./compose/certs/fullchain.pem
sudo chmod 777 ./compose/shinyproxy/certificate.pfx


cat > ./compose/nginx/Dockerfile <<EOF

FROM nginx

COPY ../certs/fullchain.pem /etc/certs/fullchain.pem
COPY ../certs/privkey.pem /etc/certs/privkey.pem
COPY nginx.conf /etc/certs/nginx.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]

EOF