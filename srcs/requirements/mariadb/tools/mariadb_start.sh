#!/bin/bash

# Ensure runtime directories exist and have the correct ownership for the 'mysql' system user
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# Retrieve credentials securely directly from the injected Docker Secrets files
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

# If the 'mysql' system directory does not exist inside the data folder,
# it means this is the VERY FIRST time the container is booting. We must initialize it.
if [ ! -d "/var/lib/mysql/mysql" ]; then

    echo "Initializing MariaDB basic system database storage..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # Create a temporary SQL script file that MariaDB will execute during bootstrap
    TMP_FILE="/tmp/init_db.sql"

	cat << EOF > $TMP_FILE
-- Força o carregamento das tabelas de permissão no modo bootstrap
FLUSH PRIVILEGES;

-- Secure the administrator 'root' account with a strong password for local access
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

-- Create the empty database instance dedicated to WordPress (name pulled from .env/compose)
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

-- Create the standard user that WordPress will use to connect from any remote IP inside the Docker network ('%')
CREATE USER IF NOT EXISTS 'wp_user'@'%' IDENTIFIED BY '${DB_PASSWORD}';

-- Grant full operational privileges to the standard user ONLY on the wordpress database tables
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO 'wp_user'@'%';

-- Refresh the internal privileges cache tables to apply all changes instantly
FLUSH PRIVILEGES;
EOF

    # Start the MariaDB engine temporarily in a minimal bootstrap mode to ingest the SQL script
    mysqld --user=mysql --bootstrap < $TMP_FILE
    rm -f $TMP_FILE
fi

echo "MariaDB configuration completed successfully. Starting server in foreground..."

# Replace the current shell process (PID 1) with the real MariaDB daemon execution
exec "$@"