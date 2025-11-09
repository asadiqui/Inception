# WordPress - Content Management System

[![WordPress](https://img.shields.io/badge/WordPress-%23117AC9.svg?style=flat&logo=WordPress&logoColor=white)](https://wordpress.org/)
[![PHP](https://img.shields.io/badge/php-%23777BB4.svg?style=flat&logo=php&logoColor=white)](https://www.php.net/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is WordPress?](#what-is-wordpress)
2. [Why We Use WordPress](#why-we-use-wordpress)
3. [WordPress in Our Architecture](#wordpress-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Entrypoint Script Analysis](#entrypoint-script-analysis)
6. [Configuration Analysis](#configuration-analysis)
7. [Useful Commands](#useful-commands)
8. [Related Documentation](#related-documentation)

## What is WordPress?

WordPress is the world's most popular content management system (CMS), powering over 40% of all websites on the internet. Originally launched in 2003 as a blogging platform, WordPress has evolved into a flexible CMS capable of powering everything from simple blogs to complex enterprise websites.

### Key Features
- **User-Friendly**: Intuitive admin interface
- **Extensible**: Thousands of themes and plugins
- **SEO-Friendly**: Built-in optimization features
- **Multi-User**: Role-based permission system
- **Responsive**: Mobile-friendly themes
- **Community**: Large developer ecosystem

### WordPress Architecture
- **Core**: Base WordPress functionality
- **Themes**: Control appearance and layout
- **Plugins**: Extend functionality
- **Database**: Stores content, settings, users
- **Media Library**: File and image management

## Why We Use WordPress

In the Inception project, WordPress serves as our **dynamic content management system** with specific advantages:

### 📝 **Content Management**
- Easy-to-use admin interface for non-technical users
- WYSIWYG editor for content creation
- Media management for images and files
- Built-in commenting system

### 🔧 **PHP-FPM Integration**
- Separates web server (NGINX) from PHP processing
- Better performance and security than traditional Apache+mod_php
- Process management and resource control
- FastCGI protocol for efficient communication

### 🚀 **Performance Features**
- Redis caching integration for database queries
- Optimized database queries
- CDN-ready architecture
- Caching-friendly permalink structure

### 👥 **Multi-User System**
- Administrator and regular user accounts
- Role-based permissions (Admin, Author, Editor, etc.)
- User registration and management

## WordPress in Our Architecture

```
NGINX (Port 443) → WordPress Container (PHP-FPM Port 9000)
                           ↓
                    MariaDB (Database)
                           ↓
                    Redis (Cache)
```

**Data Flow**:
1. NGINX receives HTTPS request
2. PHP files forwarded to WordPress container via FastCGI
3. WordPress processes request, queries MariaDB
4. Redis provides caching layer for performance
5. Response sent back through NGINX to client

## Dockerfile Analysis

Let's examine the WordPress Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal size and security.

```dockerfile
RUN apk update && apk add bash curl mariadb-client icu-data-full ghostscript \
        imagemagick openssl php82 php82-fpm php82-phar php82-json php82-mysqli \
        php82-curl php82-dom php82-exif php82-fileinfo php82-pecl-igbinary \
        php82-pecl-imagick php82-intl php82-mbstring php82-openssl \
        php82-xml php82-zip php82-iconv php82-shmop php82-simplexml php82-sodium \
        php82-xmlreader php82-zlib php82-tokenizer
```
**Explanation**:
- **Base Tools**: `bash`, `curl`, `openssl` for system operations
- **Database**: `mariadb-client` for database connectivity
- **Image Processing**: `ghostscript`, `imagemagick` for media handling
- **PHP Core**: `php82`, `php82-fpm` for PHP processing
- **PHP Extensions**: Essential extensions for WordPress functionality
  - `php82-mysqli`: MySQL database connectivity
  - `php82-json`: JSON data handling
  - `php82-curl`: HTTP requests
  - `php82-dom`: XML/HTML manipulation
  - `php82-zip`: Archive handling
  - `php82-pecl-imagick`: Advanced image processing

```dockerfile
RUN cd /usr/local/bin && \
    curl -o wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp && \
    ln -s /usr/bin/php82 /usr/bin/php
```
**Explanation**:
- Downloads WP-CLI (WordPress Command Line Interface)
- Makes it executable and places in PATH
- Creates PHP symlink for compatibility

```dockerfile
COPY tools/wordpress-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh
```
**Explanation**: Copies and makes executable the custom entrypoint script for WordPress setup.

```dockerfile
ENTRYPOINT [ "wordpress-entrypoint.sh" ]
```
**Explanation**: Sets the entrypoint to our custom script that handles WordPress installation and PHP-FPM startup.

## Entrypoint Script Analysis

The `wordpress-entrypoint.sh` script handles WordPress setup and configuration:

```bash
#!/bin/bash
set -e
cd /var/www/html
```
**Explanation**:
- Uses bash shell
- Exit on any error
- Change to WordPress directory

```bash
# Configure PHP-FPM on the first run
if [ ! -e /etc/.firstrun ]; then
    sed -i 's/listen = 127.0.0.1:9000/listen = 9000/g' /etc/php82/php-fpm.d/www.conf
    sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php82/php.ini
    touch /etc/.firstrun
fi
```
**Explanation**:
- **Listen Configuration**: Changes PHP-FPM to listen on all interfaces (not just localhost)
- **Memory Limit**: Increases from 128MB to 512MB for WordPress performance
- **First Run Marker**: Prevents reconfiguration on container restarts

```bash
# On the first volume mount, download and configure WordPress
if [ ! -e .firstmount ]; then
```
**Explanation**: Checks if WordPress has been installed on this volume (different from container first run).

```bash
    # Wait for MariaDB to be ready
    mariadb-admin ping --protocol=tcp --host=mariadb -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" --wait >/dev/null 2>/dev/null
```
**Explanation**: Waits for MariaDB container to be ready before proceeding with WordPress installation.

```bash
    # Check if WordPress is already installed
    if [ ! -f wp-config.php ]; then
        echo "Installing WordPress..."
```
**Explanation**: Only installs WordPress if wp-config.php doesn't exist (fresh installation).

```bash
        # Download and configure WordPress
        wp core download --allow-root || true
```
**Explanation**: Downloads latest WordPress core files using WP-CLI. `--allow-root` allows running as root user.

```bash
        wp config create --allow-root \
            --dbhost=mariadb \
            --dbuser="$MYSQL_USER" \
            --dbpass="$MYSQL_PASSWORD" \
            --dbname="$MYSQL_DATABASE"
```
**Explanation**: Creates wp-config.php with database connection settings using environment variables.

```bash
        wp config set WP_REDIS_HOST redis
        wp config set WP_REDIS_PORT 6379 --raw
        wp config set WP_CACHE true --raw
        wp config set FS_METHOD direct
```
**Explanation**:
- **Redis Configuration**: Sets up Redis connection constants in wp-config.php
  - `WP_REDIS_HOST`: Points to the redis container hostname
  - `WP_REDIS_PORT`: Redis port (6379)
- **WP_CACHE**: Enables WordPress object caching
- **FS_METHOD**: Sets filesystem method to direct (no FTP required)

```bash
        # Install and activate Redis Object Cache plugin before core install
        echo "Installing Redis Object Cache plugin..."
        wp plugin install redis-cache --activate --allow-root
```
**Explanation**:
- Installs the official **Redis Object Cache** plugin by Till Krüss
- Uses WP-CLI (`wp plugin install`) - the proper automated way per project requirements
- Plugin is activated immediately after installation
- Installed **before** WordPress core install so it's available from the start

```bash
        wp core install --allow-root \
            --skip-email \
            --url="$DOMAIN_NAME" \
            --title="$WORDPRESS_TITLE" \
            --admin_user="$WORDPRESS_ADMIN_USER" \
            --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
            --admin_email="$WORDPRESS_ADMIN_EMAIL"
```
**Explanation**: Installs WordPress with:
- Site URL and title from environment variables
- Admin user credentials (must not contain 'admin' per project requirements)
- Skip email sending during installation

```bash
        # Create a regular user if it doesn't already exist
        if ! wp user get "$WORDPRESS_USER" --allow-root > /dev/null 2>&1; then
            wp user create "$WORDPRESS_USER" "$WORDPRESS_EMAIL" --role=author --user_pass="$WORDPRESS_PASSWORD" --allow-root
        fi
```
**Explanation**: Creates a second user (non-admin) with 'author' role as required by project specifications.

```bash
        # Enable Redis object cache
        wp redis enable --allow-root
```
**Explanation**:
- Enables Redis object caching by creating the `object-cache.php` drop-in file
- This is done **after** WordPress core installation and plugin activation
- The drop-in connects WordPress to Redis using the constants set earlier
- This completes the Redis integration setup

```bash
    chmod o+w -R /var/www/html/wp-content
    touch .firstmount
```
**Explanation**:
- Sets write permissions for wp-content directory (uploads, plugins, themes)
- Creates marker file to prevent reinstallation

```bash
# Start PHP-FPM
exec /usr/sbin/php-fpm82 -F
```
**Explanation**: Starts PHP-FPM in foreground mode (`-F`) as the main container process.

## Configuration Analysis

### PHP-FPM Configuration

Our WordPress container modifies key PHP-FPM settings:

```conf
# Original: listen = 127.0.0.1:9000
# Modified: listen = 9000
```
**Purpose**: Allows NGINX container to connect to PHP-FPM across Docker network.

```conf
# Original: memory_limit = 128M
# Modified: memory_limit = 512M
```
**Purpose**: Increases memory for complex WordPress operations, plugin compatibility.

### WordPress Configuration

Key wp-config.php settings added by our script:

```php
// Database Configuration
define('DB_NAME', 'mariadb');
define('DB_USER', 'dbuser');
define('DB_PASSWORD', '1234');
define('DB_HOST', 'mariadb');
```
**Purpose**: Connects to MariaDB container using Docker service name.

```php
// Redis Cache Configuration
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```
**Purpose**: Enables Redis object caching for performance.

```php
// Filesystem Configuration
define('FS_METHOD', 'direct');
```
**Purpose**: Direct filesystem access (no FTP) for plugin/theme installation.

### User Roles

Our setup creates two users as required:

1. **Administrator** (`lmodir`):
   - Full site management access
   - Can install plugins/themes
   - User management capabilities

2. **Author** (`wpuser`):
   - Can create and publish posts
   - Limited admin access
   - Cannot modify site settings

## Useful Commands

### WordPress CLI (WP-CLI)
```bash
# Access WordPress container
docker exec -it wordpress bash

# Check WordPress info
docker exec wordpress wp --info --allow-root

# List users
docker exec wordpress wp user list --allow-root

# List installed plugins
docker exec wordpress wp plugin list --allow-root

# Update WordPress core
docker exec wordpress wp core update --allow-root

# Database operations
docker exec wordpress wp db check --allow-root
docker exec wordpress wp db optimize --allow-root
```

### Redis Cache Management
```bash
# Check Redis connection status
docker exec -w /var/www/html wordpress wp redis status --allow-root

# Enable Redis object cache
docker exec -w /var/www/html wordpress wp redis enable --allow-root

# Disable Redis object cache
docker exec -w /var/www/html wordpress wp redis disable --allow-root

# Flush Redis cache
docker exec -w /var/www/html wordpress wp cache flush --allow-root

# View Redis cache metrics
docker exec -w /var/www/html wordpress wp redis metrics --allow-root

# Check Redis from container directly
docker exec redis redis-cli PING
# Output: PONG

# Count cached keys
docker exec redis redis-cli DBSIZE

# View cached keys
docker exec redis redis-cli --scan | head -20
```

### Content Management
```bash
# Create new post
docker exec wordpress wp post create --post_title="Test Post" --post_content="Content here" --post_status=publish --allow-root

# List posts
docker exec wordpress wp post list --allow-root

# Create new page
docker exec wordpress wp post create --post_type=page --post_title="About" --post_status=publish --allow-root

# Manage comments
docker exec wordpress wp comment list --allow-root
```

### User Management
```bash
# Create new user
docker exec wordpress wp user create username email@domain.com --role=editor --user_pass=password --allow-root

# Change user password
docker exec wordpress wp user update admin --user_pass=newpassword --allow-root

# List user capabilities
docker exec wordpress wp user list-caps admin --allow-root
```

### Plugin and Theme Management
```bash
# List plugins
docker exec wordpress wp plugin list --allow-root

# Activate/deactivate plugin
docker exec wordpress wp plugin activate plugin-name --allow-root
docker exec wordpress wp plugin deactivate plugin-name --allow-root

# List themes
docker exec wordpress wp theme list --allow-root

# Switch theme
docker exec wordpress wp theme activate twentytwentyfour --allow-root
```

### Cache Management
```bash
# Flush WordPress cache (Redis-backed)
docker exec -w /var/www/html wordpress wp cache flush --allow-root

# Check Redis connection and status
docker exec -w /var/www/html wordpress wp redis status --allow-root
# Shows: Status, Client, Redis Version, Ping test, Metrics

# Enable/disable Redis object cache
docker exec -w /var/www/html wordpress wp redis enable --allow-root
docker exec -w /var/www/html wordpress wp redis disable --allow-root

# Direct Redis inspection
docker exec redis redis-cli INFO stats
docker exec redis redis-cli DBSIZE
```

### Database Operations
```bash
# Export database
docker exec wordpress wp db export backup.sql --allow-root

# Search and replace URLs
docker exec wordpress wp search-replace 'old-domain.com' 'new-domain.com' --allow-root

# Reset database
docker exec wordpress wp db reset --yes --allow-root
```

### File Permissions
```bash
# Fix WordPress permissions
docker exec wordpress chown -R www-data:www-data /var/www/html
docker exec wordpress chmod -R 755 /var/www/html
docker exec wordpress chmod -R 775 /var/www/html/wp-content
```

### PHP-FPM Management
```bash
# Check PHP-FPM status
docker exec wordpress ps aux | grep php-fpm

# View PHP-FPM pool status
docker exec wordpress curl http://localhost:9000/status

# Check PHP configuration
docker exec wordpress php -i | grep memory_limit

# Test PHP-FPM connection
docker exec nginx curl http://wordpress:9000
```

### Debugging
```bash
# Enable WordPress debug mode
docker exec wordpress wp config set WP_DEBUG true --raw --allow-root
docker exec wordpress wp config set WP_DEBUG_LOG true --raw --allow-root

# View debug log
docker exec wordpress tail -f /var/www/html/wp-content/debug.log

# Check error logs
docker exec wordpress tail -f /var/log/php82/error.log
```

### Redis Integration Verification
```bash
# Check Redis plugin status (shows connection, client, version, ping, metrics)
docker exec -w /var/www/html wordpress wp redis status --allow-root

# Verify Redis drop-in is present
docker exec wordpress ls -la /var/www/html/wp-content/object-cache.php

# Check cached keys count
docker exec redis redis-cli DBSIZE

# List sample cached keys
docker exec redis redis-cli --scan | head -10

# Monitor Redis operations in real-time
docker exec redis redis-cli MONITOR

# Get Redis statistics
docker exec redis redis-cli INFO stats

# Check specific WordPress cache key
docker exec redis redis-cli GET wp:options:alloptions

# View Redis memory usage
docker exec redis redis-cli INFO memory | grep used_memory_human
```

**Expected Results**:
- `wp redis status` should show: Status: Connected, Client: Predis, Redis Version: 7.0.x, Ping: PONG
- `object-cache.php` should exist (the Redis drop-in file)
- `DBSIZE` should return number of cached keys (increases after browsing site)
- Keys should follow pattern: `wp:options:*`, `wp:translation_files:*`, `wp:redis-cache:*`

**Troubleshooting Redis**:
```bash
# If Redis not working, reinstall plugin
docker exec -w /var/www/html wordpress wp plugin deactivate redis-cache --allow-root
docker exec -w /var/www/html wordpress wp plugin activate redis-cache --allow-root
docker exec -w /var/www/html wordpress wp redis enable --allow-root

# Check Redis connection from WordPress
docker exec wordpress nc -zv redis 6379

# Verify Redis config in wp-config.php
docker exec wordpress grep WP_REDIS /var/www/html/wp-config.php
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [🌐 **NGINX**](nginx.md) - Reverse proxy configuration
- [🗄️ **MariaDB**](mariadb.md) - Database backend
- [🔄 **Redis**](redis.md) - Caching layer
- [📁 **FTP**](ftp.md) - File access service

---

**WordPress Version**: Latest (downloaded via WP-CLI)  
**PHP Version**: 8.2  
**PHP-FPM**: FastCGI Process Manager  
**Alpine Base**: 3.21