#!/bin/bash

### Make directories for Analytics Suite
sudo apt-get update

sudo mkdir ./compose/certs
sudo mkdir ./compose/nginx
sudo mkdir ./compose/mariadbdata

### Install Docker
read -p "Do you want to install Docker and Docker Compose (y/n)?" CONT
if [ "$CONT" = "y" ]; then
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

### Docker Compose
sudo curl -L https://github.com/docker/compose/releases/download/1.26.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

else
  echo "Docker will not be installed"
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
else
  echo "SSL Certificates will not be installed"
fi

read -p 'Please enter your domain name: (Name must match the domain during certbox installation) ' domain

sudo certbot certonly --standalone -d ${domain}
sudo cp /etc/letsencrypt/live/${domain}/fullchain.pem ./compose/certs/fullchain.pem
sudo cp /etc/letsencrypt/live/${domain}/privkey.pem	./compose/certs/privkey.pem

openssl pkcs12 -inkey ./compose/certs/privkey.pem -in ./compose/certs/fullchain.pem -export -out ./compose/shinyproxy/certificate.pfx -passout pass:changeit

### ShinyProxy needs enough rights inside Docker container
sudo chmod 777 ./compose/certs/privkey.pem
sudo chmod 777 ./compose/certs/fullchain.pem
sudo chmod 777 ./compose/shinyproxy/certificate.pfx

sudo cp ./compose/certs/fullchain.pem ./compose/nginx/fullchain.pem
sudo cp ./compose/certs/privkey.pem	./compose/nginx/privkey.pem


cat > ./compose/nginx/nginx.conf <<EOF

events {
    
}

http {
    
server {

	root /var/www/html;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html;
       server_name $domain; # managed by Certbot


       location / {
       proxy_pass          http://127.0.0.1:5000;

       proxy_http_version 1.1;
       proxy_set_header Upgrade \$http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_read_timeout 600s;

       proxy_redirect    off;
       proxy_set_header  Host             \$http_host;
       proxy_set_header  X-Real-IP        \$remote_addr;
       proxy_set_header  X-Forwarded-For  \$proxy_add_x_forwarded_for;
       proxy_set_header  X-Forwarded-Proto \$scheme;

     }
	 
	 
       location /auth/ {
       proxy_pass          https://127.0.0.1:8443;

       proxy_http_version 1.1;
       proxy_set_header Upgrade \$http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_read_timeout 600s;

       proxy_redirect    off;
       proxy_set_header  Host             \$http_host;
       proxy_set_header  X-Real-IP        \$remote_addr;
       proxy_set_header  X-Forwarded-For  \$proxy_add_x_forwarded_for;
       proxy_set_header  X-Forwarded-Proto \$scheme;

     }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
	
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_certificate /etc/certs/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/certs/privkey.pem; # managed by Certbot

}

server {
    if (\$host = $domain) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot


	listen 80 ;
	listen [::]:80 ;
    server_name $domain;
    return 404; # managed by Certbot
}

}
EOF

cat > ./compose/shinyproxy/application.yml <<EOF

proxy:
  port: 5000
  #favicon-path: /opt/shinyproxy/favicon.ico
  authentication: keycloak
  admin-groups: admins
  users:
  - name: jack
    password: password
    groups: admins
  - name: jeff
    password: password
  #container-backend: docker-swarm
  docker:
      internal-networking: true
      container-network: sp-example-net
  specs:
  - id: 01_hello
    display-name: Hello Application
    description: Application which demonstrates the basics of a Shiny app
    container-cmd: ["R", "-e", "shinyproxy::run_01_hello()"]
    container-image: openanalytics/shinyproxy-demo
    container-network: "\${proxy.docker.container-network}"
    access-groups: test
  - id: euler
    display-name: Euler's number
    container-cmd: ["R", "-e", "shiny::runApp('/root/euler')"]
    container-image: euler-docker
    container-network: "\${proxy.docker.container-network}"
    access-groups: test
  keycloak:
      realm: master
      auth-server-url: https://${domain}/auth/
      resource: shinyoid
      credentials-secret: 81705e08-e4cc-46c3-b5cb-0cc64f9f609e
      
logging:
  file:
    shinyproxy.log

EOF


### Create Docker Network to allow Communication between containers

sudo docker network create -d overlay --attachable sp-example-net