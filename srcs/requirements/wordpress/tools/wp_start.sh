#!/bin/bash

# Ensure the runtime web directory exists and has correct permissions
mkdir -p /var/www/html
cd /var/www/html

# Extract sensitive database and admin passwords from secure Docker Secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/credentials)

# Check if WordPress is already downloaded. If not, perform initial setup.
if [ ! -f "wp-config.php" ]; then

    echo "Downloading WordPress core core files via WP-CLI..."
    wp core download --allow-root --path=/var/www/html > /dev/null

    echo "Creating wp-config.php configuration file..."
    # Configures connection to MariaDB container on port 3306 using Secrets
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="wp_user" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --path=/var/www/html > /dev/null

    echo "Installing WordPress core system and setting up the website..."
    # Installs the site using the domain name defined in your .env file
    wp core install --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception 42SP" \
        --admin_user="clados-s" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="clados-s@student.42sp.org.br" \
        --path=/var/www/html > /dev/null

    echo "Creating a secondary non-administrator user for testing..."
    # Creates a standard user account required by the evaluation guidelines
    wp user create guest guest@example.com --role=author --user_pass="guest_password123" --allow-root > /dev/null
fi

# Ensure the web server user (www-data) owns all files for seamless runtime execution
chown -R www-data:www-data /var/www/html

echo "WordPress core is ready. Starting PHP-FPM daemon in foreground..."

# Replace shell process with PHP-FPM to preserve PID 1 signal management
exec "$@"