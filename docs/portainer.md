# Portainer - Docker Container Management

[![Portainer](https://img.shields.io/badge/Portainer-13BEF9?style=flat&logo=portainer&logoColor=white)](https://www.portainer.io/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is Portainer?](#what-is-portainer)
2. [Why We Use Portainer](#why-we-use-portainer)
3. [Portainer in Our Architecture](#portainer-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Configuration Analysis](#configuration-analysis)
6. [Useful Commands](#useful-commands)
7. [Related Documentation](#related-documentation)

## What is Portainer?

Portainer is a lightweight management UI that allows you to easily manage your Docker environments. It provides a web-based interface for Docker management, making container orchestration accessible to users who prefer graphical interfaces over command-line tools.

### Key Features
- **Web-Based UI**: Modern, responsive web interface
- **Multi-Environment**: Manage multiple Docker environments
- **User Management**: Role-based access control
- **Container Management**: Start, stop, logs, console access
- **Image Management**: Pull, build, and manage Docker images
- **Volume Management**: Create and manage persistent storage
- **Network Management**: Configure Docker networks
- **Template System**: Deploy applications from templates

### Portainer Editions

| Feature | Community Edition (CE) | Business Edition (BE) |
|---------|----------------------|----------------------|
| **Price** | Free | Paid |
| **Environments** | Unlimited | Unlimited |
| **Users** | Unlimited | Unlimited |
| **RBAC** | Basic | Advanced |
| **Templates** | Community | Business + Community |
| **Support** | Community | Professional |

## Why We Use Portainer

In the Inception project, Portainer serves as our **Docker management interface** with specific advantages:

### 🖥️ **Visual Management**
- Graphical overview of all containers, images, and volumes
- Real-time monitoring of resource usage
- Easy access to container logs and terminal
- Visual network topology

### 🔧 **Operational Tools**
- Container lifecycle management (start, stop, restart, remove)
- Log viewing and searching
- File browser for container filesystems
- Terminal access to running containers

### 📊 **Monitoring & Analytics**
- Resource usage statistics (CPU, memory, network)
- Container health monitoring
- Event logging and alerts
- Performance metrics visualization

### 🛡️ **Security & Access Control**
- User authentication and authorization
- Role-based permissions
- Secure access through NGINX proxy
- Session management

## Portainer in Our Architecture

```
NGINX (https://asadiqui.42.fr/portainer/) → Portainer Container (Port 9000)
                                                    ↓
                                            Docker Socket (/var/run/docker.sock)
                                                    ↓
                                            Host Docker Engine
                                                    ↓
                                            All Project Containers
```

**Management Scope**:
- All Inception project containers
- Docker images and volumes
- Network configuration
- System-wide Docker resources

## Dockerfile Analysis

Let's examine the Portainer Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal size and security.

```dockerfile
RUN     apk update && \
                apk upgrade && \
                apk add --no-cache curl
```
**Explanation**:
- **`apk update`**: Updates package index
- **`apk upgrade`**: Upgrades installed packages
- **`curl`**: HTTP client for downloading Portainer binary

```dockerfile
WORKDIR /app
```
**Explanation**: Sets working directory for subsequent operations.

```dockerfile
RUN curl -L https://github.com/portainer/portainer/releases/download/2.19.4/portainer-2.19.4-linux-amd64.tar.gz -o portainer.tar.gz \
    && tar xzf portainer.tar.gz \
    && rm portainer.tar.gz
```
**Explanation**:
- **`curl -L`**: Downloads Portainer 2.19.4 binary (follows redirects)
- **`tar xzf`**: Extracts compressed archive
- **`rm portainer.tar.gz`**: Cleans up download file to reduce image size

```dockerfile
EXPOSE 9000
```
**Explanation**: Documents that container listens on port 9000 (Portainer's default port).

```dockerfile
ENTRYPOINT ["./portainer/portainer"]
```
**Explanation**: Sets Portainer binary as the main container process.

## Configuration Analysis

### Docker Socket Access

Portainer requires access to Docker socket to manage containers:

```yaml
# In docker-compose.yml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - portainer:/data
```

**Security Implications**:
- **Full Docker Access**: Can manage all containers on the host
- **Root Equivalent**: Docker socket provides root-level privileges
- **Container Isolation**: Access is contained within the Portainer interface

### NGINX Proxy Configuration

Portainer is accessed through NGINX reverse proxy:

```nginx
location /portainer/ {
    proxy_pass http://portainer:9000/;
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
- **Security**: No direct external access
- **Path-based Routing**: Accessible at `/portainer/` path

### Data Persistence

Portainer uses a dedicated volume for configuration:

```yaml
volumes:
  portainer:
    driver_opts:
      o: bind
      type: none
      device: ${HOME}/data/portainer
```

**Stored Data**:
- User accounts and authentication
- Environment configurations
- Templates and settings
- Application preferences

## Useful Commands

### Container Operations
```bash
# Access Portainer container
docker exec -it portainer sh

# Check Portainer version
docker exec portainer ./portainer/portainer --version

# View Portainer logs
docker logs portainer

# Restart Portainer
docker restart portainer
```

### Web Interface Testing
```bash
# Test Portainer access through NGINX
curl -k -I https://asadiqui.42.fr/portainer/

# Test direct container access
curl -I http://localhost:9000

# Check API endpoint
curl -k https://asadiqui.42.fr/portainer/api/status
```

### Docker Socket Testing
```bash
# Verify Docker socket access from Portainer container
docker exec portainer ls -la /var/run/docker.sock

# Test Docker API access
docker exec portainer sh -c "
echo 'GET /containers/json HTTP/1.0\r\n\r\n' | nc -U /var/run/docker.sock | head -20
"
```

### Data Management
```bash
# Check Portainer data directory
ls -la ~/data/portainer/

# Backup Portainer configuration
sudo tar -czf portainer-backup.tar.gz ~/data/portainer/

# Restore Portainer configuration
sudo tar -xzf portainer-backup.tar.gz -C ~/data/
```

### Performance Monitoring
```bash
# Monitor resource usage
docker stats portainer --no-stream

# Check system resources used by Portainer
docker exec portainer ps aux

# Monitor network connections
docker exec portainer netstat -tlnp
```

### Security Operations
```bash
# Check running processes
docker exec portainer ps aux | grep portainer

# Verify socket permissions
docker exec portainer ls -la /var/run/docker.sock

# Test container isolation
docker exec portainer id
```

## Web Interface Features

### Dashboard
- **System Overview**: Container, image, volume, and network counts
- **Resource Usage**: CPU, memory, and storage utilization
- **Quick Actions**: Common management tasks
- **Recent Activity**: Latest events and changes

### Container Management
- **Container List**: View all containers with status and basic info
- **Container Details**: Inspect configuration, environment, and mounts
- **Logs**: Real-time and historical log viewing
- **Console**: Interactive terminal access
- **Stats**: Resource usage monitoring

### Image Management
- **Image List**: All available Docker images
- **Image Details**: Layers, history, and metadata
- **Pull Images**: Download from registries
- **Build Images**: Create images from Dockerfiles

### Volume Management
- **Volume List**: All Docker volumes
- **Volume Details**: Usage and mount information
- **Create Volumes**: Configure persistent storage
- **Browse Files**: File system exploration

### Network Management
- **Network List**: All Docker networks
- **Network Details**: Connected containers and configuration
- **Create Networks**: Custom network configuration
- **Network Inspection**: Connectivity and routing

### Template Management
- **App Templates**: Pre-configured application stacks
- **Custom Templates**: User-defined deployment templates
- **Template Categories**: Organized template library
- **One-Click Deploy**: Simplified application deployment

## Security Considerations

### Access Control
- **Initial Setup**: Admin password required on first access
- **User Management**: Create additional users with specific roles
- **Role-Based Access**: Different permission levels
- **Session Management**: Automatic logout and session expiry

### Network Security
- **NGINX Proxy**: SSL termination and secure access
- **Internal Network**: No direct external exposure
- **Authentication**: Web-based login system
- **Authorization**: Permission-based feature access

### Docker Socket Security
- **Full Privileges**: Portainer has complete Docker access
- **Container Escape**: Potential for privilege escalation
- **Monitoring**: Log all administrative actions
- **Principle of Least Privilege**: Limit user permissions where possible

## Troubleshooting

### Common Issues

#### 1. **Cannot Access Web Interface**
```bash
# Check if Portainer is running
docker ps | grep portainer

# Test direct access
curl -I http://localhost:9000

# Check NGINX proxy configuration
docker exec nginx grep -A 10 portainer /etc/nginx/http.d/default.conf
```

#### 2. **Docker Socket Permission Denied**
```bash
# Check socket permissions
docker exec portainer ls -la /var/run/docker.sock

# Verify volume mount
docker inspect portainer | grep -A 5 "Mounts"

# Test socket connectivity
docker exec portainer docker ps
```

#### 3. **Data Persistence Issues**
```bash
# Check data volume
ls -la ~/data/portainer/

# Verify volume permissions
sudo chown -R 1000:1000 ~/data/portainer/

# Check volume mount
docker volume inspect srcs_portainer
```

### Performance Issues

#### 1. **Slow Response Times**
```bash
# Check resource usage
docker stats portainer

# Monitor container performance
docker exec portainer top

# Check system load
uptime
```

#### 2. **Memory Usage**
```bash
# Check memory consumption
docker exec portainer cat /proc/meminfo

# Monitor Portainer process
docker exec portainer ps aux | grep portainer
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [🌐 **NGINX**](nginx.md) - Reverse proxy configuration
- [🐳 **Docker Compose**](../README.md#docker-compose-operations) - Container orchestration

---

**Portainer Version**: 2.19.4  
**Alpine Base**: 3.21  
**Access URL**: https://asadiqui.42.fr/portainer/  
**Docker Socket**: Required for container management