#!/bin/bash

### Installation of Docker
sudo apt-get update

sudo mkdir ./compose
sudo mkdir ./compose/certs
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

cat > ./compose/nginx/Dockerfile <<EOF

FROM nginx

COPY fullchain.pem /etc/certs/fullchain.pem
COPY privkey.pem /etc/certs/privkey.pem
COPY nginx.conf /etc/certs/nginx.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
EOF

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
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_read_timeout 600s;

       proxy_redirect    off;
       proxy_set_header  Host             $http_host;
       proxy_set_header  X-Real-IP        $remote_addr;
       proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
       proxy_set_header  X-Forwarded-Proto $scheme;

     }
	 
	 
       location /auth/ {
       proxy_pass          https://127.0.0.1:8443;

       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_read_timeout 600s;

       proxy_redirect    off;
       proxy_set_header  Host             $http_host;
       proxy_set_header  X-Real-IP        $remote_addr;
       proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
       proxy_set_header  X-Forwarded-Proto $scheme;

     }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
	
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_certificate /etc/certs/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/certs/privkey.pem; # managed by Certbot

}

server {
    if ($host = $domain) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


	listen 80 ;
	listen [::]:80 ;
    server_name $domain;
    return 404; # managed by Certbot
}

}
EOF

### Shinyproxy
sudo git clone https://github.com/openanalytics/shinyproxy.git


