FROM debian:13

# Install PHP-FPM, core components, database connector, and download tools
RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download and install the official WP-CLI binary, making it executable globally
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && mkdir -p /run/php

# Copy custom PHP-FPM service configurations and setup script into the container
COPY requirements/wordpress/conf/www.conf /etc/php/8.3/fpm/pool.d/www.conf
COPY requirements/wordpress/tools/wp_start.sh /usr/local/bin/wp_start.sh

# Ensure the startup script has correct execution privileges
RUN chmod +x /usr/local/bin/wp_start.sh

# Document that the container exposes the FastCGI communication port (9000)
EXPOSE 9000

# Set our custom automated tools script as the entrypoint
ENTRYPOINT ["/usr/local/bin/wp_start.sh"]

# Execute PHP-FPM in foreground mode (F or --nodaemonize) to enforce PID 1 control
CMD ["php-fpm8.3", "-F"]