FROM debian:12

# Install PHP-FPM 8.2 explicitly, core components, and database connector
RUN apt-get update && apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    wget \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Download and install the official WP-CLI binary
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && mkdir -p /run/php

# Copy configurations targeting the exact 8.2 path
COPY requirements/wordpress/conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY requirements/wordpress/tools/wp_start.sh /usr/local/bin/wp_start.sh

# Ensure the startup script has correct execution privileges
RUN chmod +x /usr/local/bin/wp_start.sh

# Document that the container exposes the FastCGI communication port (9000)
EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wp_start.sh"]

# Execute exact PHP version in foreground mode
CMD ["php-fpm8.2", "-F"]