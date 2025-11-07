# Adminer - Database Administration Tool

[![Adminer](https://img.shields.io/badge/Adminer-1C4E80?style=flat&logo=php&logoColor=white)](https://www.adminer.org/)
[![PHP](https://img.shields.io/badge/php-%23777BB4.svg?style=flat&logo=php&logoColor=white)](https://www.php.net/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is Adminer?](#what-is-adminer)
2. [Why We Use Adminer](#why-we-use-adminer)
3. [Adminer in Our Architecture](#adminer-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Configuration Analysis](#configuration-analysis)
6. [Useful Commands](#useful-commands)
7. [Related Documentation](#related-documentation)

## What is Adminer?

Adminer (formerly known as phpMinAdmin) is a full-featured database management tool written in PHP. It's a single PHP file that provides a complete web-based interface for managing databases. Created by Jakub Vrána, Adminer is designed to be a lightweight, secure alternative to phpMyAdmin.

### Key Features
- **Single File**: Entire application in one PHP file
- **Multiple Databases**: MySQL, PostgreSQL, SQLite, MS SQL, Oracle
- **Lightweight**: Small footprint (~500KB)
- **Security**: Better security model than phpMyAdmin
- **User-Friendly**: Intuitive interface with modern design
- **Plugin System**: Extensible functionality

### Adminer vs phpMyAdmin

| Feature | Adminer | phpMyAdmin |
|---------|---------|------------|
| **File Size** | ~500KB (1 file) | ~30MB (many files) |
| **Installation** | Drop single file | Complex setup |
| **Security** | Better defaults | More configuration needed |
| **Performance** | Faster | More resource-intensive |
| **Themes** | Built-in themes | Limited styling |
| **Database Support** | Multiple DB types | MySQL-focused |

## Why We Use Adminer

In the Inception project, Adminer serves as our **database administration interface** with specific advantages:

### 🌐 **Web-Based Access**
- Accessible via HTTPS through NGINX proxy
- No need for desktop database clients
- Cross-platform compatibility
- Integrated with our authentication system

### 🔧 **Database Management**
- Visual table browsing and editing
- SQL query execution and optimization
- Database structure modification
- Import/Export functionality
- User and privilege management

### 🛡️ **Security Integration**
- Proxied through NGINX for SSL termination
- No direct external access
- Integrated with our domain and authentication
- Session-based security

### 📊 **Development Tools**
- Query profiling and analysis
- Database schema visualization  
- Data import/export capabilities
- SQL command history

## Adminer in Our Architecture

```
NGINX (https://asadiqui.42.fr/adminer/) → Adminer Container (Port 8080)
                                               ↓
                                         MariaDB Container
                                               ↓
                                         Database Content
```

**Access Flow**:
1. User accesses `https://asadiqui.42.fr/adminer/`
2. NGINX proxies request to Adminer container on port 8080
3. Adminer connects to MariaDB using internal Docker network
4. Database operations performed through web interface

## Dockerfile Analysis

Let's examine the Adminer Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal size and security.

```dockerfile
ARG PHP_VERSION=82
```
**Explanation**: Defines PHP version as a build argument for flexibility and maintainability.

```dockerfile
RUN     apk update && \
                apk upgrade && \
                apk add --no-cache php${PHP_VERSION} \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-session \
        php${PHP_VERSION}-iconv \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-mysqli \
                php${PHP_VERSION}-imap \
                php${PHP_VERSION}-cgi \
                php${PHP_VERSION}-pdo \
                php${PHP_VERSION}-pdo_mysql \
                php${PHP_VERSION}-soap \
                php${PHP_VERSION}-posix \
                php${PHP_VERSION}-gettext \
                php${PHP_VERSION}-ldap \
                php${PHP_VERSION}-ctype \
                php${PHP_VERSION}-dom \
                php${PHP_VERSION}-simplexml \
                wget
```
**Explanation**:
- **`apk update && apk upgrade`**: Updates package index and system packages
- **`php82`**: Core PHP interpreter
- **`php82-common`**: Common PHP libraries
- **`php82-session`**: Session handling for web interface
- **`php82-mysqli`**: MySQL/MariaDB connectivity
- **`php82-pdo`** & **`php82-pdo_mysql`**: PDO database abstraction layer
- **`php82-gd`**: Image processing (for charts, exports)
- **`php82-xml`** & **`php82-dom`**: XML processing for data imports/exports
- **`wget`**: For downloading Adminer application file

```dockerfile
WORKDIR /var/www
```
**Explanation**: Sets working directory where Adminer will be served from.

```dockerfile
RUN wget https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php && \
    mv adminer-4.8.1.php index.php && chown -R root:root /var/www/
```
**Explanation**:
- Downloads Adminer 4.8.1 from official GitHub releases
- Renames to `index.php` for web server default document
- Sets proper ownership for security

```dockerfile
EXPOSE 8080
```
**Explanation**: Documents that container listens on port 8080 (used by Docker networking).

```dockerfile
CMD     [ "php82", "-S", "[::]:8080", "-t", "/var/www" ]
```
**Explanation**:
- **`php82 -S`**: Starts PHP built-in web server
- **`[::]:8080`**: Listen on all interfaces (IPv4 and IPv6) on port 8080
- **`-t /var/www`**: Document root directory

## Configuration Analysis

### PHP Built-in Server

Adminer uses PHP's built-in development server with these characteristics:

**Advantages**:
- **Simplicity**: No web server configuration needed
- **Lightweight**: Minimal resource usage
- **Self-contained**: Everything in one container

**Configuration**:
```bash
php82 -S [::]:8080 -t /var/www
```
- **[::]:8080**: Binds to all interfaces on port 8080
- **-t /var/www**: Sets document root
- **Single-threaded**: Suitable for development/admin interface

### NGINX Proxy Configuration

Adminer is accessed through NGINX reverse proxy:

```nginx
location /adminer/ {
    proxy_pass http://adminer:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
}
```

**Benefits**:
- **SSL Termination**: HTTPS encryption handled by NGINX
- **Single Domain**: Integrated with main site
- **Security**: No direct external access to Adminer
- **Caching**: Potential for static asset caching

### Database Connection

Adminer connects to MariaDB using Docker service discovery:

**Connection Parameters**:
- **Server**: `mariadb` (Docker service name)
- **Port**: `3306` (default MariaDB port)
- **Username**: `root` or `dbuser`
- **Password**: From environment variables
- **Database**: `mariadb` (WordPress database)

## Useful Commands

### Container Operations
```bash
# Access Adminer container
docker exec -it adminer sh

# Check PHP version and modules
docker exec adminer php82 -v
docker exec adminer php82 -m

# Test web server
docker exec adminer curl http://localhost:8080

# Check container logs
docker logs adminer
```

### Web Interface Testing
```bash
# Test Adminer access through NGINX
curl -k -I https://asadiqui.42.fr/adminer/

# Test direct container access
curl -I http://localhost:8080

# Check response content
curl -k https://asadiqui.42.fr/adminer/ | head -20
```

### Database Connection Testing
```bash
# Test database connectivity from Adminer container
docker exec adminer php82 -r "
try {
    \$pdo = new PDO('mysql:host=mariadb;port=3306', 'root', '1234');
    echo 'Connection successful\n';
} catch (PDOException \$e) {
    echo 'Connection failed: ' . \$e->getMessage() . '\n';
}"
```

### File Management
```bash
# View Adminer source
docker exec adminer head -20 /var/www/index.php

# Check file permissions
docker exec adminer ls -la /var/www/

# Download fresh Adminer version
docker exec adminer wget -O /tmp/adminer-latest.php https://github.com/vrana/adminer/releases/latest/download/adminer.php
```

### Performance Monitoring
```bash
# Monitor PHP processes
docker exec adminer ps aux | grep php

# Check memory usage
docker stats adminer --no-stream

# Monitor network connections
docker exec adminer netstat -tlnp
```

### Security Testing
```bash
# Check listening ports
docker exec adminer ss -tlnp

# Test PHP configuration
docker exec adminer php82 -i | grep -E "(session|mysql|pdo)"

# Verify file ownership
docker exec adminer ls -la /var/www/index.php
```

### Backup Adminer Configuration
```bash
# Backup current Adminer file
docker cp adminer:/var/www/index.php ./adminer-backup.php

# Copy custom themes or plugins (if any)
docker cp adminer:/var/www/ ./adminer-backup/

# Restore from backup
docker cp ./adminer-backup.php adminer:/var/www/index.php
```

### Database Operations via Command Line
```bash
# Export database via Adminer container
docker exec adminer php82 -r "
\$pdo = new PDO('mysql:host=mariadb;dbname=mariadb', 'root', '1234');
\$stmt = \$pdo->query('SHOW TABLES');
while (\$row = \$stmt->fetch()) {
    print_r(\$row);
}"

# Check table structure
docker exec adminer php82 -r "
\$pdo = new PDO('mysql:host=mariadb;dbname=mariadb', 'root', '1234');
\$stmt = \$pdo->query('DESCRIBE wp_posts');
while (\$row = \$stmt->fetch(PDO::FETCH_ASSOC)) {
    print_r(\$row);
}"
```

## Web Interface Features

### Database Management
- **Server Connection**: Connect to multiple database servers
- **Database Selection**: Browse available databases
- **Table Management**: Create, modify, drop tables
- **Index Management**: Add, remove, optimize indexes

### Data Operations
- **Browse Data**: View table contents with pagination
- **Edit Records**: Modify individual records inline
- **Insert Data**: Add new records with form interface
- **Delete Records**: Remove single or multiple records

### SQL Operations
- **SQL Command**: Execute custom SQL queries
- **Export**: Generate SQL dumps or CSV files
- **Import**: Upload and execute SQL files
- **Query History**: Review previously executed queries

### Advanced Features
- **Database Design**: Visual schema browser
- **Privileges**: Manage user permissions
- **Processes**: View active connections and queries
- **Variables**: Check server configuration
- **Status**: Monitor server performance metrics

## Troubleshooting

### Common Issues

#### 1. **Connection Refused**
```bash
# Check if Adminer container is running
docker ps | grep adminer

# Test internal connectivity
docker exec adminer curl http://localhost:8080

# Check database connectivity
docker exec adminer ping mariadb
```

#### 2. **403 Forbidden / 404 Not Found**
```bash
# Verify NGINX proxy configuration
docker exec nginx cat /etc/nginx/http.d/default.conf | grep -A 10 adminer

# Check file permissions
docker exec adminer ls -la /var/www/
```

#### 3. **Database Connection Errors**
```bash
# Test database from Adminer container
docker exec adminer mysql -h mariadb -u root -p1234 -e "SELECT 1;"

# Check MariaDB user privileges
docker exec mariadb mysql -u root -p1234 -e "SHOW GRANTS FOR 'root'@'%';"
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [🗄️ **MariaDB**](mariadb.md) - Database server configuration
- [🌐 **NGINX**](nginx.md) - Reverse proxy setup
- [📝 **WordPress**](wordpress.md) - Primary database client

---

**Adminer Version**: 4.8.1  
**PHP Version**: 8.2  
**Alpine Base**: 3.21  
**Access URL**: https://asadiqui.42.fr/adminer/