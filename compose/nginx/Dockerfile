FROM nginx

COPY fullchain.pem /etc/certs/fullchain.pem
COPY privkey.pem /etc/certs/privkey.pem
COPY nginx.conf /etc/certs/nginx.conf

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]