FROM debian:13

# Install the official MariaDB Server package and purge apt caches to optimize image size
RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# Copy our custom configuration layout and the initialization tools script into the image
COPY srcs/requirements/mariadb/conf/my.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY srcs/requirements/mariadb/tools/mariadb_start.sh /usr/local/bin/mariadb_start.sh

# Grant execution rights to our startup script inside the container filesystem
RUN chmod +x /usr/local/bin/mariadb_start.sh

# Document that the container listens on the standard MariaDB networking port (3306)
EXPOSE 3306

# Configure our custom tools script as the core entry point of the container lifecycle
ENTRYPOINT ["/usr/local/bin/mariadb_start.sh"]

# Execute the database daemon in foreground mode, binding to all internal network interfaces
CMD ["mysqld", "--user=mysql", "--bind-address=0.0.0.0"]