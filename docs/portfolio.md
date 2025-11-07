# Portfolio - Static Website

[![HTML5](https://img.shields.io/badge/html5-%23E34F26.svg?style=flat&logo=html5&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/HTML)
[![CSS3](https://img.shields.io/badge/css3-%231572B6.svg?style=flat&logo=css3&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/CSS)
[![JavaScript](https://img.shields.io/badge/javascript-%23323330.svg?style=flat&logo=javascript&logoColor=%23F7DF1E)](https://developer.mozilla.org/en-US/docs/Web/JavaScript)
[![NGINX](https://img.shields.io/badge/nginx-%23009639.svg?style=flat&logo=nginx&logoColor=white)](https://nginx.org/)

## Table of Contents

1. [What is a Static Website?](#what-is-a-static-website)
2. [Why We Use Static Sites](#why-we-use-static-sites)
3. [Portfolio in Our Architecture](#portfolio-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Entrypoint Script Analysis](#entrypoint-script-analysis)
6. [Configuration Analysis](#configuration-analysis)
7. [Useful Commands](#useful-commands)
8. [Related Documentation](#related-documentation)

## What is a Static Website?

A static website consists of fixed content files (HTML, CSS, JavaScript) that are served directly to users without server-side processing. Unlike dynamic websites that generate content on-the-fly, static sites deliver pre-built pages that remain the same for every visitor.

### Key Characteristics
- **Pre-built Content**: HTML files generated beforehand
- **No Database**: Content stored in files, not databases
- **Fast Loading**: Direct file serving, minimal processing
- **Simple Deployment**: Just copy files to web server
- **Version Control**: Entire site can be tracked in Git
- **CDN-Friendly**: Easy to cache and distribute globally

### Static vs Dynamic Websites

| Aspect | Static Website | Dynamic Website |
|--------|----------------|-----------------|
| **Content Generation** | Pre-built | Real-time |
| **Database Required** | No | Usually yes |
| **Server Processing** | Minimal | Significant |
| **Performance** | Very fast | Variable |
| **Scalability** | Excellent | Requires planning |
| **Security** | High | More complex |
| **Cost** | Low | Higher |

## Why We Use Static Sites

In the Inception project, our static portfolio serves as a **showcase website** with specific advantages:

### 🚀 **Performance Benefits**
- Lightning-fast page loads (no database queries)
- Minimal server resources required
- Excellent caching capabilities
- CDN optimization ready

### 🔒 **Security Advantages**
- No backend code to exploit
- No database vulnerabilities
- Minimal attack surface
- No user input processing

### 💰 **Cost-Effective**
- Low hosting requirements
- Minimal server resources
- Easy to scale and cache
- No complex infrastructure needed

### 🛠️ **Development Simplicity**
- Standard HTML, CSS, JavaScript
- No framework dependencies
- Easy to maintain and update
- Version control friendly

## Portfolio in Our Architecture

```
NGINX (https://asadiqui.42.fr/portfolio/) → Static-Site Container (Port 80)
                                                     ↓
                                            NGINX serves static files
                                                     ↓
                                            Volume: /usr/share/nginx/html
                                                     ↓
                                            HTML, CSS, JS, Images
```

**Serving Flow**:
1. User requests `/portfolio/` path
2. Main NGINX proxies to static-site container
3. Container's NGINX serves static files directly
4. Browser receives pre-built HTML, CSS, JavaScript

## Dockerfile Analysis

Let's examine the Static Site Dockerfile line by line:

```dockerfile
# Use the specified version of Alpine
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal size and consistency.

```dockerfile
# Install Nginx and other dependencies
RUN apk update && \
    apk add --no-cache nginx bash
```
**Explanation**:
- **nginx**: Web server for serving static files
- **bash**: Required for entrypoint script

```dockerfile
# Copy HTML/CSS/JS files to the appropriate location
COPY portfolio/ /usr/share/nginx/html/
```
**Explanation**: Copies all portfolio website files to NGINX's default document root.

```dockerfile
# Copy the entrypoint script
COPY tools/static-site-entrypoint.sh /usr/local/bin/
```
**Explanation**: Copies custom entrypoint script for NGINX configuration.

```dockerfile
# Make the script executable and create necessary directories
RUN chmod +x /usr/local/bin/static-site-entrypoint.sh && \
    mkdir -p /run/nginx && \
    mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html
```
**Explanation**:
- **chmod +x**: Makes entrypoint script executable
- **mkdir -p /run/nginx**: Creates PID file directory
- **mkdir -p /var/log/nginx**: Creates log directory
- **chown**: Sets proper ownership for NGINX user

```dockerfile
# Expose port 80
EXPOSE 80
```
**Explanation**: Documents that container serves on port 80 (HTTP).

```dockerfile
# Set the entrypoint
ENTRYPOINT ["static-site-entrypoint.sh"]
```
**Explanation**: Uses custom script to configure and start NGINX.

## Entrypoint Script Analysis

The `static-site-entrypoint.sh` script configures NGINX for static file serving:

```bash
#!/bin/sh
```
**Explanation**: Uses POSIX shell for compatibility and simplicity.

```bash
# Create Nginx configuration file
cat << EOF > /etc/nginx/http.d/default.conf
server {
    listen 80;
    root /usr/share/nginx/html;
```
**Explanation**:
- **listen 80**: Serves on port 80 (HTTP)
- **root**: Sets document root to where our files are located

```bash
    location / {
        include /etc/nginx/mime.types;
        try_files \$uri \$uri/ /index.html;
    }
```
**Explanation**:
- **include mime.types**: Proper MIME type handling for different file types
- **try_files**: Attempts to serve requested file, directory, then fallback to index.html

```bash
    location ~* \.(?:jpg|jpeg|gif|png|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public";
    }
```
**Explanation**:
- **Image Caching**: Sets 7-day cache for image files
- **Cache-Control**: Allows public caching (CDNs, browsers)

```bash
    location ~* \.(?:css|js)$ {
        add_header Cache-Control "no-cache, public, must-revalidate, proxy-revalidate";
    }
```
**Explanation**:
- **CSS/JS Caching**: Forces revalidation for stylesheets and scripts
- **Development-Friendly**: Ensures changes are picked up quickly

```bash
# Start Nginx in the foreground
exec nginx -g 'daemon off;'
nginx -t
```
**Explanation**:
- **exec nginx -g 'daemon off;'**: Starts NGINX as main process (required for containers)
- **nginx -t**: Tests configuration syntax (though this runs after exec, so it's unreachable)

## Configuration Analysis

### NGINX Static File Configuration

Our configuration optimizes for static file serving:

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    
    location / {
        include /etc/nginx/mime.types;
        try_files $uri $uri/ /index.html;
    }
}
```

**Benefits**:
- **Direct File Serving**: No PHP or server-side processing
- **MIME Types**: Proper content-type headers for all file types
- **SPA Support**: Fallback to index.html for single-page applications

### Caching Strategy

```nginx
# Image files - long-term caching
location ~* \.(jpg|jpeg|gif|png|ico|svg)$ {
    expires 7d;
    add_header Cache-Control "public";
}

# CSS/JS files - revalidation required
location ~* \.(css|js)$ {
    add_header Cache-Control "no-cache, public, must-revalidate, proxy-revalidate";
}
```

**Strategy Explanation**:
- **Images**: Rarely change, cache for 7 days
- **CSS/JS**: May change during development, require revalidation
- **Public Caching**: Allows CDN and proxy caching

### Volume Mounting

```yaml
# In docker-compose.yml
volumes:
  - static-site:/usr/share/nginx/html
```

**Purpose**:
- **Data Persistence**: Files survive container restarts
- **Easy Updates**: Modify files on host filesystem
- **Backup-Friendly**: Simple file-based backup

## Useful Commands

### Container Operations
```bash
# Access static site container
docker exec -it static-site sh

# Check NGINX configuration
docker exec static-site nginx -t

# Reload NGINX configuration
docker exec static-site nginx -s reload

# View NGINX processes
docker exec static-site ps aux | grep nginx
```

### File Management
```bash
# List portfolio files
docker exec static-site ls -la /usr/share/nginx/html/

# View index.html
docker exec static-site cat /usr/share/nginx/html/index.html

# Check file permissions
docker exec static-site ls -la /usr/share/nginx/html/

# Add new file
docker exec static-site touch /usr/share/nginx/html/newfile.html
```

### Web Testing
```bash
# Test direct container access
curl -I http://localhost:80  # (if port mapped)

# Test through main NGINX proxy
curl -k -I https://asadiqui.42.fr/portfolio/

# Download specific file
curl -k https://asadiqui.42.fr/portfolio/css/style.css

# Test different file types
curl -k -I https://asadiqui.42.fr/portfolio/img/logo.png
```

### Log Analysis
```bash
# View NGINX access logs
docker exec static-site tail -f /var/log/nginx/access.log

# View NGINX error logs
docker exec static-site tail -f /var/log/nginx/error.log

# View container logs
docker logs static-site
```

### Performance Testing
```bash
# Basic performance test
ab -n 100 -c 10 https://asadiqui.42.fr/portfolio/

# Test specific file types
curl -w "@curl-format.txt" -o /dev/null -s https://asadiqui.42.fr/portfolio/css/style.css

# Check response headers
curl -k -I https://asadiqui.42.fr/portfolio/img/photo.jpg
```

### Content Management
```bash
# Update files from host
cp new-index.html ~/data/static-site/index.html

# Backup current site
tar -czf portfolio-backup.tar.gz ~/data/static-site/

# Restore from backup
tar -xzf portfolio-backup.tar.gz -C ~/data/

# Check disk usage
docker exec static-site du -sh /usr/share/nginx/html/
```

### Development Tools
```bash
# Watch for file changes (on host)
inotifywait -m -r ~/data/static-site/ -e modify,create,delete

# Live reload simulation (manual refresh needed)
docker exec static-site nginx -s reload

# Validate HTML files
docker exec static-site find /usr/share/nginx/html/ -name "*.html" -exec echo {} \;
```

## Website Structure

### Typical Portfolio Structure
```
/usr/share/nginx/html/
├── index.html          # Main homepage
├── css/
│   ├── style.css      # Main stylesheet
│   └── responsive.css  # Mobile styles
├── js/
│   ├── main.js        # Main JavaScript
│   └── animations.js   # Animation scripts
├── img/
│   ├── profile.jpg    # Profile photo
│   ├── projects/      # Project screenshots
│   └── icons/         # UI icons
├── fonts/             # Custom fonts
└── assets/            # Other assets
```

### Essential Files

#### index.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portfolio - Your Name</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <!-- Portfolio content -->
    <script src="js/main.js"></script>
</body>
</html>
```

#### CSS Best Practices
```css
/* Modern CSS features */
:root {
    --primary-color: #3498db;
    --secondary-color: #2c3e50;
}

/* Responsive design */
@media (max-width: 768px) {
    .container {
        padding: 1rem;
    }
}

/* Performance optimizations */
img {
    max-width: 100%;
    height: auto;
    loading: lazy;
}
```

## SEO and Performance

### SEO Optimization
```html
<!-- Meta tags for SEO -->
<meta name="description" content="Portfolio of [Your Name] - Web Developer">
<meta name="keywords" content="web development, portfolio, projects">
<meta name="author" content="Your Name">

<!-- Open Graph tags -->
<meta property="og:title" content="Your Portfolio">
<meta property="og:description" content="Portfolio description">
<meta property="og:image" content="img/og-image.jpg">
```

### Performance Optimization
- **Image Optimization**: Use WebP format, compress images
- **Minification**: Minimize CSS and JavaScript files
- **Caching**: Leverage browser and proxy caching
- **CDN**: Consider CDN for static assets
- **Critical CSS**: Inline above-the-fold CSS

## Troubleshooting

### Common Issues

#### 1. **404 Not Found**
```bash
# Check if files exist
docker exec static-site ls -la /usr/share/nginx/html/

# Verify NGINX configuration
docker exec static-site nginx -t

# Check file permissions
docker exec static-site ls -la /usr/share/nginx/html/index.html
```

#### 2. **CSS/JS Not Loading**
```bash
# Check MIME types
docker exec static-site grep -r "text/css" /etc/nginx/

# Test direct file access
curl -k https://asadiqui.42.fr/portfolio/css/style.css

# Check browser console for errors
```

#### 3. **Images Not Displaying**
```bash
# Verify image files exist
docker exec static-site find /usr/share/nginx/html/ -name "*.jpg" -o -name "*.png"

# Check image permissions
docker exec static-site ls -la /usr/share/nginx/html/img/

# Test image URL directly
curl -k -I https://asadiqui.42.fr/portfolio/img/photo.jpg
```

#### 4. **Performance Issues**
```bash
# Check file sizes
docker exec static-site du -sh /usr/share/nginx/html/*

# Monitor resource usage
docker stats static-site --no-stream

# Test cache headers
curl -k -I https://asadiqui.42.fr/portfolio/css/style.css | grep -i cache
```

## Development Workflow

### Local Development
```bash
# Edit files on host
vim ~/data/static-site/index.html

# Changes are immediately available (volume mount)
curl -k https://asadiqui.42.fr/portfolio/

# For major changes, rebuild container
docker compose build static-site
docker compose restart static-site
```

### Version Control
```bash
# Initialize git in portfolio directory
cd ~/data/static-site/
git init
git add .
git commit -m "Initial portfolio commit"

# Track changes
git status
git diff
git add modified-files
git commit -m "Update portfolio content"
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [🌐 **NGINX**](nginx.md) - Main reverse proxy configuration
- [📝 **WordPress**](wordpress.md) - Dynamic content comparison

---

**Technology Stack**: HTML5, CSS3, JavaScript  
**Web Server**: NGINX  
**Alpine Base**: 3.21  
**Access URL**: https://asadiqui.42.fr/portfolio/