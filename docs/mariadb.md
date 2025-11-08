# MariaDB - Database Server

[![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)](https://mariadb.org/)
[![MySQL](https://img.shields.io/badge/mysql-%2300f.svg?style=flat&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is MariaDB?](#what-is-mariadb)
2. [Why We Use MariaDB](#why-we-use-mariadb)
3. [MariaDB in Our Architecture](#mariadb-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Entrypoint Script Analysis](#entrypoint-script-analysis)
6. [Configuration Analysis](#configuration-analysis)
7. [Useful Commands](#useful-commands)
8. [Related Documentation](#related-documentation)

## What is MariaDB?

MariaDB is a popular open-source relational database management system (RDBMS) created by the original developers of MySQL. It was forked from MySQL in 2009 when Oracle acquired Sun Microsystems (MySQL's owner). MariaDB maintains high compatibility with MySQL while providing enhanced features, improved performance, and additional storage engines.

### Key Features
- **MySQL Compatibility**: Drop-in replacement for MySQL
- **Performance**: Optimized query processing and storage engines
- **Security**: Enhanced authentication and encryption
- **Open Source**: Truly open-source with no commercial restrictions
- **Storage Engines**: Multiple engines (InnoDB, MyISAM, Aria, etc.)
- **Replication**: Master-slave and master-master replication

### MariaDB vs MySQL

| Feature | MariaDB | MySQL |
|---------|---------|-------|
| **License** | GPL (fully open) | GPL + Commercial |
| **Performance** | Generally faster | Good performance |
| **Storage Engines** | More options | Limited options |
| **JSON Support** | Enhanced JSON functions | Basic JSON |
| **Thread Pool** | Built-in | Commercial only |
| **Development** | Community-driven | Oracle-controlled |

## Why We Use MariaDB

In the Inception project, MariaDB serves as our **primary data store** with specific advantages:

### 🗄️ **WordPress Database Backend**
- Stores all WordPress content (posts, pages, comments)
- User management and authentication data
- Plugin and theme configurations
- Site settings and customizations

### 🔒 **Security & Isolation**
- Runs in dedicated container (no web server mixing)
- Custom network isolation from external access
- Environment-based credential management
- Proper user privilege separation

### 📊 **Performance Features**
- InnoDB storage engine for ACID compliance
- Query caching for repeated operations
- Optimized for web application workloads
- Connection pooling capabilities

### 🔄 **Data Persistence**
- Volume mounting for data survival across container restarts
- Backup and restore capabilities
- Transaction safety and recovery

## MariaDB in Our Architecture

```
WordPress Container → MariaDB Container (Port 3306)
                           ↓
                    Volume: /home/login/data/mariadb
                           ↓
                    Host Filesystem (Persistent)
```

**Network Access**:
- **Internal Only**: Only accessible from docker-network
- **No External Ports**: Security through isolation
- **Service Discovery**: Accessible as 'mariadb' hostname

## Dockerfile Analysis

Let's examine the MariaDB Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal footprint and security.

```dockerfile
RUN apk update && \
    apk add mariadb mariadb-client bash
```
**Explanation**:
- **`mariadb`**: The database server package
- **`mariadb-client`**: Command-line tools for database management
- **`bash`**: Required for our entrypoint script (Alpine uses ash by default)

```dockerfile
COPY tools/mariadb-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/mariadb-entrypoint.sh
```
**Explanation**: Copies our custom entrypoint script and makes it executable.

```dockerfile
ENTRYPOINT [ "mariadb-entrypoint.sh" ]
```
**Explanation**: Sets our custom script as the container's entrypoint for proper initialization and startup.

## Entrypoint Script Analysis

The `mariadb-entrypoint.sh` script handles database initialization and startup:

```bash
#!/bin/bash
set -e
```
**Explanation**:
- Uses bash shell for advanced scripting features
- `set -e`: Exit immediately if any command fails

```bash
# Configure the server to be reachable by other containers
if [ ! -e /etc/.firstrun ]; then
    cat << EOF >> /etc/my.cnf.d/mariadb-server.cnf
[mysqld]
bind-address=0.0.0.0
skip-networking=0
EOF
    touch /etc/.firstrun
fi
```
**Explanation**:
- **bind-address=0.0.0.0**: Allows connections from any IP (default is localhost only)
- **skip-networking=0**: Enables TCP/IP networking (disabled by default in some configs)
- **First Run Check**: Only configures once to prevent overwriting on restart

```bash
# Initialize database if not exists
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB database..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --rpm >/dev/null 2>&1
```
**Explanation**:
- Checks if system database exists (fresh installation indicator)
- **mysql_install_db**: Creates system tables and initial database structure
- **--user=mysql**: Run as mysql user for security
- **--datadir**: Specify data directory location
- **--rpm**: Use RPM-style installation

```bash
    echo "Starting temporary MariaDB server for setup..."
    mysqld_safe --user=mysql --datadir=/var/lib/mysql --skip-networking &
    pid="$!"
```
**Explanation**:
- Starts MariaDB in background for initial setup
- **mysqld_safe**: Wrapper script that monitors mysqld process (Alpine Linux naming)
- **--skip-networking**: Only local connections during setup
- **&**: Run in background, store PID for later

> **Note**: Alpine Linux MariaDB package uses `mysqld_safe` instead of `mariadbd-safe`

```bash
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
```
**Explanation**:
- Waits up to 30 seconds for MariaDB to become responsive
- Tests connection with simple SELECT query
- Fails if database doesn't start within timeout

```bash
    echo "Setting up database and users..."
    mysql << EOF
DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` ;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' ;
GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
FLUSH PRIVILEGES ;
EOF
```
**Explanation**:
- **DELETE FROM mysql.user**: Removes anonymous and unnecessary users
- **SET PASSWORD**: Sets root password from environment variable
- **GRANT ALL ... TO 'root'@'%'**: Allows root access from any host
- **CREATE DATABASE**: Creates WordPress database
- **CREATE USER**: Creates application user with limited privileges
- **GRANT ALL ON database**: Gives user full access to WordPress database only
- **FLUSH PRIVILEGES**: Reloads privilege tables

```bash
    if ! kill -s TERM "$pid" || ! wait "$pid"; then
        echo >&2 'MariaDB init process failed.'
        exit 1
    fi
    
    echo "MariaDB initialization complete."
fi
```
**Explanation**:
- Gracefully stops temporary MariaDB instance
- **kill -s TERM**: Sends termination signal
- **wait**: Waits for process to exit cleanly
- Error handling if shutdown fails

```bash
echo "Starting MariaDB server..."
exec mysqld_safe --user=mysql --datadir=/var/lib/mysql
```
**Explanation**:
- Starts MariaDB as main container process
- **exec**: Replaces script process with MariaDB (proper PID 1)
- **mysqld_safe**: Production-ready wrapper with monitoring (Alpine Linux naming)

## Configuration Analysis

### MariaDB Server Configuration

Our script adds these configuration directives:

```ini
[mysqld]
bind-address=0.0.0.0
skip-networking=0
```

**bind-address=0.0.0.0**:
- **Purpose**: Allow connections from all network interfaces
- **Default**: 127.0.0.1 (localhost only)
- **Security**: Safe within Docker network isolation

**skip-networking=0**:
- **Purpose**: Enable TCP/IP networking
- **Default**: May be disabled in some distributions
- **Required**: For container-to-container communication

### Security Configuration

Our initialization script implements security best practices:

```sql
-- Remove anonymous users and test databases
DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost');

-- Create application-specific user with limited privileges
CREATE USER 'dbuser'@'%' IDENTIFIED BY 'password';
GRANT ALL ON `wordpress_db`.* TO 'dbuser'@'%';
```

**Security Benefits**:
- **Least Privilege**: Application user can only access WordPress database
- **No Anonymous Access**: Removes default anonymous accounts
- **Strong Authentication**: Password-protected accounts only

### Data Storage

```bash
# Data directory structure
/var/lib/mysql/
├── mysql/           # System database
├── performance_schema/  # Performance monitoring
├── wordpress_db/    # Application database
├── ib_logfile0     # InnoDB transaction logs
├── ib_logfile1     # InnoDB transaction logs
└── ibdata1         # InnoDB system tablespace
```

## Useful Commands

### Container Access
```bash
# Access MariaDB container
docker exec -it mariadb bash

# Connect to database as root
docker exec -it mariadb mysql -u root -p

# Connect as application user
docker exec -it mariadb mysql -u dbuser -p mariadb
```

### Database Operations
```bash
# Show databases
docker exec mariadb mysql -u root -p1234 -e "SHOW DATABASES;"

# Show tables in WordPress database
docker exec mariadb mysql -u root -p1234 -e "USE mariadb; SHOW TABLES;"

# Check user accounts
docker exec mariadb mysql -u root -p1234 -e "SELECT user,host FROM mysql.user;"

# Show user privileges
docker exec mariadb mysql -u root -p1234 -e "SHOW GRANTS FOR 'dbuser'@'%';"
```

### Backup and Restore
```bash
# Create full backup
docker exec mariadb mysqldump -u root -p1234 --all-databases > full_backup.sql

# Backup specific database
docker exec mariadb mysqldump -u root -p1234 mariadb > wordpress_backup.sql

# Restore from backup
docker exec -i mariadb mysql -u root -p1234 < full_backup.sql

# Restore specific database
docker exec -i mariadb mysql -u root -p1234 mariadb < wordpress_backup.sql
```

### Performance Monitoring
```bash
# Show current connections
docker exec mariadb mysql -u root -p1234 -e "SHOW PROCESSLIST;"

# Show server status
docker exec mariadb mysql -u root -p1234 -e "SHOW STATUS LIKE 'Connections';"

# Show server variables
docker exec mariadb mysql -u root -p1234 -e "SHOW VARIABLES LIKE 'max_connections';"

# Show InnoDB status
docker exec mariadb mysql -u root -p1234 -e "SHOW ENGINE INNODB STATUS\G"
```

### Database Maintenance
```bash
# Check table integrity
docker exec mariadb mysql -u root -p1234 -e "CHECK TABLE mariadb.wp_posts;"

# Repair table if needed
docker exec mariadb mysql -u root -p1234 -e "REPAIR TABLE mariadb.wp_posts;"

# Optimize tables
docker exec mariadb mysql -u root -p1234 -e "OPTIMIZE TABLE mariadb.wp_posts;"

# Analyze tables for query optimization
docker exec mariadb mysql -u root -p1234 -e "ANALYZE TABLE mariadb.wp_posts;"
```

### Log Analysis
```bash
# View MariaDB error log
docker exec mariadb tail -f /var/lib/mysql/*.err

# View slow query log (if enabled)
docker exec mariadb tail -f /var/lib/mysql/slow.log

# Check binary logs
docker exec mariadb mysql -u root -p1234 -e "SHOW BINARY LOGS;"
```

### Security Management
```bash
# Change root password
docker exec mariadb mysql -u root -p1234 -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('newpassword');"

# Create new user
docker exec mariadb mysql -u root -p1234 -e "CREATE USER 'newuser'@'%' IDENTIFIED BY 'password';"

# Grant privileges
docker exec mariadb mysql -u root -p1234 -e "GRANT SELECT,INSERT,UPDATE ON mariadb.* TO 'newuser'@'%';"

# Remove user
docker exec mariadb mysql -u root -p1234 -e "DROP USER 'olduser'@'%';"

# Flush privileges after changes
docker exec mariadb mysql -u root -p1234 -e "FLUSH PRIVILEGES;"
```

### Configuration Management
```bash
# View current configuration
docker exec mariadb mysql -u root -p1234 -e "SHOW VARIABLES;"

# Check specific setting
docker exec mariadb mysql -u root -p1234 -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"

# View configuration file
docker exec mariadb cat /etc/my.cnf.d/mariadb-server.cnf
```

### Debugging and Troubleshooting
```bash
# Check if MariaDB is running
docker exec mariadb ps aux | grep mysql

# Test connection from another container
docker exec wordpress mysql -h mariadb -u dbuser -p1234 -e "SELECT 1;"

# Check network connectivity
docker exec wordpress ping mariadb

# Verify port is listening
docker exec mariadb netstat -tlnp | grep 3306
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [📝 **WordPress**](wordpress.md) - Primary database client
- [⚙️ **Adminer**](adminer.md) - Web-based database administration
- [🔄 **Redis**](redis.md) - Complementary caching layer

---

**MariaDB Version**: 10.11.x (Alpine package)  
**MySQL Compatibility**: 8.0+  
**Storage Engine**: InnoDB (default)  
**Alpine Base**: 3.21