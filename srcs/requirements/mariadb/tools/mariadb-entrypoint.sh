#!/bin/bash
set -e

# Configure the server to be reachable by other containers
if [ ! -e /etc/.firstrun ]; then
    cat << EOF >> /etc/my.cnf.d/mariadb-server.cnf
[mysqld]
bind-address=0.0.0.0
skip-networking=0
EOF
    touch /etc/.firstrun
fi

# Initialize database if not exists
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --rpm >/dev/null 2>&1
    
    echo "Starting temporary MariaDB server for setup..."
    mysqld_safe --user=mysql --datadir=/var/lib/mysql --skip-networking &
    pid="$!"
    
    # Wait for MariaDB to start
    for i in {30..0}; do
        if echo 'SELECT 1' | mysql &> /dev/null; then
            break
        fi
        sleep 1
    done
    
    if [ "$i" = 0 ]; then
        echo >&2 'MariaDB init process failed.'
        exit 1
    fi
    
    echo "Setting up database and users..."
    cat > /tmp/setup.sql <<EOSQL
DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost');
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}');
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
    mysql < /tmp/setup.sql 2>/dev/null || true
    rm -f /tmp/setup.sql
    
    echo "Database setup complete."
    echo "Stopping temporary MariaDB server..."
    
    # Shutdown the temporary server gracefully
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    
    sleep 2
    
    echo "MariaDB initialization complete."
fi

echo "Starting MariaDB server..."
exec mysqld_safe --user=mysql --datadir=/var/lib/mysql
