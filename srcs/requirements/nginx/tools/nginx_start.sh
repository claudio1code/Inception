#!/bin/bash

# Create necessary directories for nginx
mkdir -p /etc/nginx/ssl
 
# Generate silence self-signed SSL certificate
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/C=BR/ST=SP/L=SaoPaulo/O=42SP/OU=Cadet/CN=clados-s.42.fr"
		> /dev/null 2>&1
fi

echo "NGINX is configured and starting..."

# Start nginx by replacing the script's process (PID 1)
exec "$@"
