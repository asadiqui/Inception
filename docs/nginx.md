# NGINX - Web Server & Reverse Proxy

[![NGINX](https://img.shields.io/badge/nginx-%23009639.svg?style=flat&logo=nginx&logoColor=white)](https://nginx.org/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is NGINX?](#what-is-nginx)
2. [Why We Use NGINX](#why-we-use-nginx)
3. [NGINX in Our Architecture](#nginx-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Entrypoint Script Analysis](#entrypoint-script-analysis)
6. [Configuration Analysis](#configuration-analysis)
7. [Useful Commands](#useful-commands)
8. [Related Documentation](#related-documentation)

## What is NGINX?

NGINX (pronounced "engine-x") is a high-performance web server, reverse proxy, load balancer, and HTTP cache. Originally created by Igor Sysoev in 2004, NGINX is known for its stability, rich feature set, simple configuration, and low resource consumption.

### Key Features
- **High Performance**: Can handle thousands of concurrent connections
- **Low Memory Usage**: Uses an asynchronous, event-driven approach
- **Reverse Proxy**: Routes requests to backend services
- **SSL/TLS Termination**: Handles encryption/decryption
- **Load Balancing**: Distributes traffic across multiple servers
- **Static Content Serving**: Efficiently serves files, images, etc.

### NGINX vs Apache

| Feature | NGINX | Apache |
|---------|-------|--------|
| **Architecture** | Event-driven | Process/Thread-based |
| **Memory Usage** | Low | Higher |
| **Static Content** | Excellent | Good |
| **Configuration** | Simple syntax | Complex modules |
| **Concurrency** | High | Moderate |

## Why We Use NGINX

In the Inception project, NGINX serves as the **single entry point** to our infrastructure, acting as:

### 🛡️ **SSL/TLS Termination**
- Handles all HTTPS encryption/decryption
- Manages SSL certificates
- Enforces HTTPS-only access
- Redirects HTTP to HTTPS

### 🔄 **Reverse Proxy**
- Routes requests to appropriate backend services
- Provides service abstraction and security
- Enables multiple services on single domain
- Load balancing capabilities

### 🌐 **Static Content Server**
- Serves portfolio/static website files
- Handles CSS, JavaScript, images efficiently
- Implements caching headers for performance

### 🔗 **Service Gateway**
- Single domain access to multiple services
- Path-based routing (/portfolio/, /adminer/, etc.)
- Centralized access control

## NGINX in Our Architecture

```
Internet → NGINX (Port 443) → Internal Services
    ↓
    ├── / → WordPress (PHP-FPM)
    ├── /portfolio/ → Static Site Files
    ├── /portainer/ → Portainer (Port 9000)
    └── /adminer/ → Adminer (Port 8080)
```

## Dockerfile Analysis

Let's examine the NGINX Dockerfile line by line:

```dockerfile
# Use the specified version of Alpine
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image. Alpine is chosen for its minimal size (~5MB) and security focus.

```dockerfile
# Install Nginx, OpenSSL, and Bash
RUN apk update && \
    apk add nginx openssl bash
```
**Explanation**: 
- `apk update`: Updates the Alpine package index
- `nginx`: The web server itself
- `openssl`: For SSL certificate generation and management
- `bash`: Required for our entrypoint script (Alpine uses ash by default)

```dockerfile
# Copy the executable script for Nginx configuration
COPY tools/nginx-entrypoint.sh /usr/local/bin/
```
**Explanation**: Copies our custom entrypoint script from the host to the container. This script handles initial configuration and certificate generation.

```dockerfile
# Change permissions of the executable file and create necessary directories
RUN chmod +x /usr/local/bin/nginx-entrypoint.sh && \
    mkdir -p /etc/nginx/ssl
```
**Explanation**:
- `chmod +x`: Makes the entrypoint script executable
- `mkdir -p /etc/nginx/ssl`: Creates directory for SSL certificates (with parent directories if needed)

```dockerfile
# Set the entrypoint script for the container
ENTRYPOINT [ "nginx-entrypoint.sh" ]
```
**Explanation**: Sets our custom script as the container's entrypoint. This ensures proper initialization before starting NGINX.

## Entrypoint Script Analysis

The `nginx-entrypoint.sh` script handles dynamic configuration:

```bash
#!/bin/bash
set -e
```
**Explanation**:
- `#!/bin/bash`: Specifies bash interpreter
- `set -e`: Exit immediately if any command fails (fail-fast behavior)

```bash
# On the first container run, generate a certificate and configure the server
if [ ! -e /etc/.firstrun ]; then
    # Ensure destinations exist so file writes won't fail inside the container
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/http.d
    mkdir -p /etc/nginx/ssl
```
**Explanation**: 
- Checks if this is the first run by looking for a marker file
- Creates necessary directories before writing configuration files:
  - `/etc/nginx/conf.d`: Standard nginx config directory (used by official nginx image)
  - `/etc/nginx/http.d`: Alpine nginx's config directory (included inside `http{}` block)
  - `/etc/nginx/ssl`: Directory for SSL certificates

```bash
    # Generate a certificate for HTTPS
    openssl req -x509 -days 365 -newkey rsa:2048 -nodes \
        -out '/etc/nginx/ssl/cert.crt' \
        -keyout '/etc/nginx/ssl/cert.key' \
        -subj "/CN=$DOMAIN_NAME" \
         >/dev/null 2>/dev/null
```
**Explanation**:
- `openssl req -x509`: Creates a self-signed X.509 certificate
- `-days 365`: Certificate valid for 1 year
- `-newkey rsa:2048`: Generates new 2048-bit RSA private key
- `-nodes`: No passphrase for the private key
- `-out/-keyout`: Output paths for certificate and key
- `-subj "/CN=$DOMAIN_NAME"`: Sets Common Name to our domain
- `>/dev/null 2>/dev/null`: Suppresses output

```bash
    cat << EOF >> /etc/nginx/http.d/default.conf
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}
```
**Explanation**:
- Creates HTTP server block that listens on port 80
- `listen [::]:80`: IPv6 support
- `return 301`: Permanent redirect to HTTPS
- `\$server_name\$request_uri`: Preserves original URL in redirect

```bash
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME;
```
**Explanation**:
- HTTPS server block on port 443
- `ssl`: Enables SSL/TLS
- `http2`: Enables HTTP/2 protocol for better performance

```bash
    ssl_certificate /etc/nginx/ssl/cert.crt;
    ssl_certificate_key /etc/nginx/ssl/cert.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
```
**Explanation**:
- Points to our generated SSL certificate and key
- Restricts to secure TLS versions (1.2 and 1.3)
- Specifies secure cipher suites for encryption

```bash
    # Portfolio/Static site location
    location /portfolio {
        alias /usr/share/nginx/html;
        try_files \$uri \$uri/ /portfolio/index.html;
        
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 7d;
            add_header Cache-Control "public";
        }
    }
```
**Explanation**:
- `alias`: Maps /portfolio/ URL to filesystem path
- `try_files`: Attempts to serve file, directory, then fallback
- Nested location for static assets with 7-day caching

```bash
    # Portainer proxy
    location /portainer/ {
        proxy_pass http://portainer:9000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
```
**Explanation**:
- Proxies /portainer/ requests to portainer container port 9000
- Preserves original client information in headers
- `proxy_redirect off`: Prevents automatic redirect rewriting

```bash
    # WordPress (default location)
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
```
**Explanation**:
- Sets document root to WordPress files
- Default index files to try
- Routes all requests to WordPress PHP files with query parameters

```bash
    location ~ [^/]\.php(/|\$) {
        try_files \$fastcgi_script_name =404;

        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
    }
```
**Explanation**:
- Handles PHP file requests
- `fastcgi_pass wordpress:9000`: Forwards to WordPress container's PHP-FPM
- Sets required FastCGI parameters for PHP execution
- `fastcgi_split_path_info`: Handles path info for WordPress permalinks

```bash
    touch /etc/.firstrun
fi

exec nginx -g 'daemon off;'
```
**Explanation**:
- Creates marker file to prevent reconfiguration
- `exec nginx -g 'daemon off;'`: Starts NGINX in foreground mode (required for containers)

## Configuration Analysis

### SSL/TLS Configuration

Our NGINX implements modern SSL/TLS best practices:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```
- Only allows secure TLS versions
- Disables older, vulnerable protocols (SSLv3, TLSv1.0, TLSv1.1)

```nginx
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
```
- Prioritizes ECDHE (Perfect Forward Secrecy)
- Uses AES-GCM for authenticated encryption
- Excludes weak ciphers

### Reverse Proxy Configuration

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```
**Purpose**: Preserves client information when proxying:
- **Host**: Original hostname requested
- **X-Real-IP**: Client's actual IP address
- **X-Forwarded-For**: Chain of proxy IPs
- **X-Forwarded-Proto**: Original protocol (http/https)

## Useful Commands

### Container Operations
```bash
# Access NGINX container
docker exec -it nginx sh

# Check NGINX configuration syntax
docker exec nginx nginx -t

# Reload NGINX configuration
docker exec nginx nginx -s reload

# View NGINX access logs
docker exec nginx tail -f /var/log/nginx/access.log

# View NGINX error logs
docker exec nginx tail -f /var/log/nginx/error.log
```

### SSL Certificate Management
```bash
# View certificate details
docker exec nginx openssl x509 -in /etc/nginx/ssl/cert.crt -text -noout

# Check certificate expiration
docker exec nginx openssl x509 -in /etc/nginx/ssl/cert.crt -noout -dates

# Test SSL connection
openssl s_client -connect asadiqui.42.fr:443 -servername asadiqui.42.fr

# Regenerate certificate (remove firstrun marker)
docker exec nginx rm -f /etc/.firstrun
docker restart nginx
```

### Configuration Testing
```bash
# Test HTTP to HTTPS redirect
curl -I http://asadiqui.42.fr

# Test HTTPS access
curl -k -I https://asadiqui.42.fr

# Test specific paths
curl -k -I https://asadiqui.42.fr/portfolio/
curl -k -I https://asadiqui.42.fr/adminer/

# Check proxy headers
curl -k -H "Host: test.com" https://asadiqui.42.fr/portainer/
```

### Performance Testing
```bash
# Basic performance test
ab -n 1000 -c 10 https://asadiqui.42.fr/

# SSL handshake performance
time openssl s_client -connect asadiqui.42.fr:443 < /dev/null

# Check worker processes
docker exec nginx ps aux | grep nginx
```

### Debugging Commands
```bash
# Check listening ports
docker exec nginx netstat -tlnp

# View current connections
docker exec nginx ss -tuln

# Check NGINX status
docker exec nginx nginx -V

# View loaded modules
docker exec nginx nginx -V 2>&1 | grep -o with-[a-z_]*
```

### Configuration Inspection
```bash
# View main NGINX config
docker exec nginx cat /etc/nginx/nginx.conf

# View our site config
docker exec nginx cat /etc/nginx/http.d/default.conf

# Check include files
docker exec nginx ls -la /etc/nginx/conf.d/
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [📝 **WordPress**](wordpress.md) - PHP-FPM backend service
- [🎨 **Portfolio**](portfolio.md) - Static site served by NGINX
- [⚙️ **Adminer**](adminer.md) - Proxied database interface
- [🐳 **Portainer**](portainer.md) - Proxied container management

---

**NGINX Version**: 1.24.x  
**Alpine Base**: 3.21  
**SSL/TLS**: TLSv1.2, TLSv1.3  
**HTTP/2**: Enabled