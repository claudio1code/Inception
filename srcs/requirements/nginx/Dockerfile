FROM debian:13

# Install Nginx and OpenSSL, and clean up the package lists to reduce image size
RUN apt-get update && apt-get install -y \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

#copy the configuration and the start script to the container
COPY srcs/requirements/nginx/nginx.conf /etc/nginx/nginx.conf
COPY srcs/requirements/nginx/tools/nginx_start.sh /usr/local/bin/nginx_start.sh

# Ensure that the start script is executable
RUN chmod +x /usr/local/bin/nginx_start.sh

# Define the entry point to run the Nginx start script when the container starts 
# and expose port 80 for HTTP traffic
ENTRYPOINT ["/usr/local/bin/nginx_start.sh"]

# Start Nginx in the foreground to keep the container running
CMD ["nginx", "-g", "daemon off;"]