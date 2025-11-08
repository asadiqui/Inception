# cAdvisor - Container Monitoring

[![cAdvisor](https://img.shields.io/badge/cAdvisor-4285F4?style=flat&logo=google&logoColor=white)](https://github.com/google/cadvisor)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is cAdvisor?](#what-is-cadvisor)
2. [Why We Use cAdvisor](#why-we-use-cadvisor)
3. [cAdvisor in Our Architecture](#cadvisor-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Configuration Analysis](#configuration-analysis)
6. [Useful Commands](#useful-commands)
7. [Related Documentation](#related-documentation)

## What is cAdvisor?

cAdvisor (Container Advisor) is an open-source monitoring tool developed by Google that provides container users with resource usage and performance characteristics of their running containers. It runs as a daemon that collects, aggregates, processes, and exports information about running containers.

### Key Features
- **Real-Time Monitoring**: Live resource usage metrics
- **Resource Metrics**: CPU, memory, filesystem, and network statistics
- **Performance Analysis**: Historical resource usage data
- **Auto-Discovery**: Automatically discovers all containers
- **Multiple Export Formats**: Prometheus, InfluxDB, Elasticsearch
- **Web UI**: Built-in web interface for visualization
- **Lightweight**: Minimal resource footprint
- **Docker Native**: Deep integration with Docker

### Metrics Provided

| Category | Metrics |
|----------|---------|
| **CPU** | Total usage, per-core usage, load average |
| **Memory** | Usage, working set, cache, RSS, swap |
| **Network** | RX/TX bytes, packets, errors, dropped |
| **Filesystem** | Usage, read/write operations, I/O time |
| **Disk I/O** | Read/write bytes, operations, latency |

## Why We Use cAdvisor

In the Inception project, cAdvisor serves as our **container monitoring and performance analysis tool**:

### 📊 **Performance Monitoring**
- Real-time resource usage for all containers
- CPU, memory, network, and disk metrics
- Historical data for trend analysis
- Container-level performance isolation

### 🔍 **Troubleshooting**
- Identify resource bottlenecks
- Detect memory leaks
- Monitor network traffic patterns
- Analyze disk I/O performance

### 📈 **Capacity Planning**
- Understand resource requirements
- Plan for scaling needs
- Optimize container resource limits
- Identify underutilized resources

### 🎯 **Integration Benefits**
- Accessible via NGINX reverse proxy at `/cadvisor/`
- No authentication required (internal network only)
- Prometheus-compatible metrics export
- Minimal configuration required

## cAdvisor in Our Architecture

### Service Overview

```yaml
cadvisor:
  build: ./requirements/bonus/cadvisor
  pull_policy: build
  container_name: cadvisor
  ports:
    - "8081:8080"
  networks:
    - docker-network
  volumes:
    - /:/rootfs:ro
    - /var/run:/var/run:ro
    - /sys:/sys:ro
    - /var/lib/docker/:/var/lib/docker:ro
    - /dev/disk/:/dev/disk:ro
  image: cadvisor
  restart: always
  privileged: true
```

### Access Points

| Method | URL | Description |
|--------|-----|-------------|
| **Via NGINX** | `https://asadiqui.42.fr/cadvisor/` | Proxied through NGINX (recommended) |
| **Direct (Bonus)** | `http://localhost:8081` | Direct container access (port exposed for bonus) |

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Host System                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  cAdvisor Container (privileged)                       │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │  Monitors:                                       │ │ │
│  │  │  • /: Root filesystem (read-only)                │ │ │
│  │  │  • /var/run: Docker socket access                │ │ │
│  │  │  • /sys: System information                      │ │ │
│  │  │  • /var/lib/docker: Container data               │ │ │
│  │  │  • /dev/disk: Disk device information            │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                        │ │
│  │  Exposes: Port 8080 → Host 8081                       │ │
│  │  Serves: Web UI + Prometheus metrics                  │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  NGINX Reverse Proxy                                   │ │
│  │  /cadvisor/ → http://cadvisor:8080/                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓                                 │
│                      HTTPS (443)                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    External Access
           https://asadiqui.42.fr/cadvisor/
```

## Dockerfile Analysis

Let's examine our cAdvisor Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: 
- Uses Alpine Linux 3.21 as the base image
- Alpine is chosen for its minimal size (~5MB) and security
- Version 3.21 is the latest stable release

```dockerfile
# Install cAdvisor from Alpine packages
RUN apk update && \
    apk add --no-cache cadvisor && \
    rm -rf /var/cache/apk/*
```
**Explanation**:
- **apk update**: Updates the package index
- **apk add --no-cache cadvisor**: Installs cAdvisor without caching package files
- **rm -rf /var/cache/apk/**: Removes any remaining cache (extra cleanup)
- Alpine 3.21+ includes cAdvisor in its repository, making installation simple

```dockerfile
# Expose cAdvisor default port
EXPOSE 8080
```
**Explanation**:
- Documents that cAdvisor listens on port 8080
- This is the default cAdvisor web interface port
- EXPOSE is documentation only; actual port mapping is in docker-compose.yml

```dockerfile
# Run cAdvisor
ENTRYPOINT ["/usr/bin/cadvisor"]
CMD ["-logtostderr"]
```
**Explanation**:
- **ENTRYPOINT**: Sets the main executable to `/usr/bin/cadvisor`
- **CMD**: Default arguments (can be overridden)
- **-logtostderr**: Logs to stderr instead of files (Docker-friendly)
- Uses exec form (JSON array) for proper signal handling

### Build Process

```bash
# Build the image
docker build -t cadvisor ./requirements/bonus/cadvisor

# Image layers:
# 1. Alpine base (~5MB)
# 2. cAdvisor binary and dependencies (~30MB)
# Total: ~35MB
```

## Configuration Analysis

### Docker Compose Configuration

#### Volume Mounts (Critical for Monitoring)

```yaml
volumes:
  - /:/rootfs:ro
  - /var/run:/var/run:ro
  - /sys:/sys:ro
  - /var/lib/docker/:/var/lib/docker:ro
  - /dev/disk/:/dev/disk:ro
```

**Explanation**:

| Mount | Purpose | Permission |
|-------|---------|------------|
| `/:/rootfs:ro` | Host root filesystem access for container filesystem inspection | Read-only |
| `/var/run:/var/run:ro` | Docker socket access for container discovery | Read-only |
| `/sys:/sys:ro` | System information (cgroups, CPU, memory stats) | Read-only |
| `/var/lib/docker/:/var/lib/docker:ro` | Docker data directory (container metadata) | Read-only |
| `/dev/disk/:/dev/disk:ro` | Disk device information for I/O stats | Read-only |

**Security Note**: All mounts are read-only (`:ro`), limiting potential security impact.

#### Privileged Mode

```yaml
privileged: true
```

**Why privileged is needed**:
- Access to host system information via `/sys`
- Read cgroup statistics for resource metrics
- Access disk device information
- Monitor all containers (including system containers)

**Security consideration**: This is safe because:
- cAdvisor only reads data (all volumes are read-only)
- No write access to host filesystem
- Runs in isolated network
- Only accessible via NGINX reverse proxy on HTTPS

#### Port Mapping

```yaml
ports:
  - "8081:8080"
```

**Explanation**:
- Maps container port 8080 to host port 8081
- Allows direct access (bonus feature)
- NGINX proxy uses internal Docker network (doesn't need this port)

### NGINX Reverse Proxy Configuration

In [`nginx-entrypoint.sh`](/home/asadiqui/inception/srcs/requirements/nginx/tools/nginx-entrypoint.sh):

```nginx
# cAdvisor proxy
location /cadvisor/ {
    proxy_pass http://cadvisor:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
}
```

**Explanation**:
- **location /cadvisor/**: Matches URLs like `https://asadiqui.42.fr/cadvisor/`
- **proxy_pass http://cadvisor:8080/**: Forwards to cAdvisor container
- **proxy_set_header**: Preserves client information for cAdvisor
- **proxy_redirect off**: Disables automatic redirect rewriting

## Useful Commands

### Container Management

```bash
# Start cAdvisor
docker compose up -d cadvisor

# View logs
docker compose logs cadvisor

# Follow logs in real-time
docker compose logs -f cadvisor

# Restart cAdvisor
docker compose restart cadvisor

# Stop cAdvisor
docker compose stop cadvisor

# Remove cAdvisor
docker compose down cadvisor
```

### Access cAdvisor

```bash
# Via NGINX (HTTPS)
curl -k https://asadiqui.42.fr/cadvisor/

# Direct access (if port exposed)
curl http://localhost:8081/

# Open in browser (via NGINX - recommended)
firefox https://asadiqui.42.fr/cadvisor/

# Open in browser (direct)
firefox http://localhost:8081
```

### Monitoring Specific Containers

```bash
# View cAdvisor metrics for a specific container
curl -k https://asadiqui.42.fr/cadvisor/api/v1.3/docker/wordpress

# View all container metrics (JSON)
curl -k https://asadiqui.42.fr/cadvisor/api/v1.3/containers/ | jq

# Prometheus metrics endpoint
curl -k https://asadiqui.42.fr/cadvisor/metrics
```

### Debugging

```bash
# Check if cAdvisor is running
docker ps | grep cadvisor

# Inspect cAdvisor container
docker inspect cadvisor

# Check cAdvisor version
docker exec cadvisor /usr/bin/cadvisor -version

# Test network connectivity to cAdvisor
docker exec nginx ping -c 3 cadvisor
docker exec nginx curl -v http://cadvisor:8080/

# View cAdvisor process inside container
docker exec cadvisor ps aux
```

### Resource Usage Analysis

```bash
# View real-time stats for all containers
docker stats

# View cAdvisor's own resource usage
docker stats cadvisor

# Check cAdvisor container resource limits
docker inspect cadvisor --format '{{json .HostConfig.Memory}}'
```

## Using cAdvisor Web Interface

### Main Dashboard

Access: `https://asadiqui.42.fr/cadvisor/`

Features:
- **Total Usage**: System-wide resource usage
- **Subcontainers**: List of all running containers
- **CPU/Memory Graphs**: Real-time and historical charts

### Container Details

Access: Click on any container name

Available metrics:
- **CPU Usage**: Per-core breakdown, total usage percentage
- **Memory**: Usage, working set, cache, RSS
- **Network**: RX/TX bytes, packets, errors
- **Filesystem**: Total/available space, usage per mount
- **Processes**: List of processes inside container

### Time Range Selection

- Last minute
- Last hour
- Last day
- Custom range

### Export Formats

- JSON API (v1.3): `/api/v1.3/`
- Prometheus: `/metrics`
- Raw data: `/api/v2.0/`

## Integration with Monitoring Stack

### Prometheus Integration (Optional Enhancement)

cAdvisor exports metrics in Prometheus format at `/metrics`:

```yaml
# Example prometheus.yml snippet
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

### Grafana Dashboards (Optional Enhancement)

Popular cAdvisor Grafana dashboards:
- Dashboard ID 893: Docker monitoring
- Dashboard ID 11600: Container monitoring

## Performance Considerations

### Resource Usage

| Resource | Typical Usage |
|----------|---------------|
| **CPU** | 1-5% (varies with container count) |
| **Memory** | 50-100 MB |
| **Disk I/O** | Minimal (read-only access) |
| **Network** | Minimal (only when UI accessed) |

### Optimization Tips

1. **Reduce Data Retention**: Use `--housekeeping_interval` flag
2. **Disable Unused Features**: Use `--disable_metrics` flag
3. **Limit Container Discovery**: Use `--docker_only` flag

Example with custom flags:
```yaml
command:
  - "-logtostderr"
  - "-housekeeping_interval=10s"
  - "-docker_only=true"
```

## Security Considerations

### Why Privileged Mode is Safe

✅ **Read-Only Access**: All host mounts are read-only
✅ **No Write Permissions**: Cannot modify host filesystem
✅ **Network Isolation**: Only accessible via docker-network
✅ **HTTPS Only**: External access through NGINX with TLS
✅ **No Authentication Needed**: Internal tool, not exposed directly

### Best Practices

- ✅ Keep cAdvisor updated (rebuild image regularly)
- ✅ Monitor cAdvisor logs for errors
- ✅ Don't expose port 8081 externally (bonus only)
- ✅ Use NGINX reverse proxy for access control
- ⚠️ Never run cAdvisor with write access to host volumes

## Troubleshooting

### Common Issues

#### 1. cAdvisor Container Fails to Start

**Symptoms**: Container exits immediately

**Diagnosis**:
```bash
docker compose logs cadvisor
```

**Common Causes**:
- Missing privileged mode
- Host volume mount errors
- Port 8080 already in use

**Solution**:
```bash
# Check if port is in use
netstat -tulpn | grep 8080

# Ensure privileged mode is enabled
docker inspect cadvisor --format '{{.HostConfig.Privileged}}'
```

#### 2. Cannot Access cAdvisor via NGINX

**Symptoms**: 502 Bad Gateway or connection refused

**Diagnosis**:
```bash
# Test from NGINX container
docker exec nginx curl -v http://cadvisor:8080/

# Check if cAdvisor is running
docker ps | grep cadvisor

# Check NGINX logs
docker logs nginx
```

**Solution**:
```bash
# Restart both services
docker compose restart cadvisor nginx
```

#### 3. Missing Container Metrics

**Symptoms**: Some containers don't appear in cAdvisor

**Diagnosis**:
```bash
# Check Docker socket mount
docker inspect cadvisor --format '{{json .Mounts}}' | jq
```

**Solution**: Ensure `/var/run` is mounted correctly in docker-compose.yml

#### 4. High Memory Usage

**Symptoms**: cAdvisor consuming excessive memory

**Solution**:
```bash
# Restart cAdvisor to clear cache
docker compose restart cadvisor

# Add memory limit (optional)
# In docker-compose.yml:
# mem_limit: 256m
```

## Related Documentation

### Internal Documentation
- [NGINX Configuration](nginx.md) - Reverse proxy setup for cAdvisor
- [Docker Compose](../README.md#docker-compose-configuration) - Service orchestration
- [Adminer](adminer.md) - Database monitoring tool
- [Redis](redis.md) - Cache monitoring

### Official Resources
- [cAdvisor GitHub](https://github.com/google/cadvisor) - Official repository
- [cAdvisor Documentation](https://github.com/google/cadvisor/blob/master/docs/README.md) - Complete documentation
- [Runtime Options](https://github.com/google/cadvisor/blob/master/docs/runtime_options.md) - Command-line flags
- [Storage Drivers](https://github.com/google/cadvisor/blob/master/docs/storage/README.md) - Metric export options

### Tutorials
- [Monitoring Docker with cAdvisor](https://www.digitalocean.com/community/tutorials/how-to-monitor-docker-with-cadvisor-on-ubuntu-16-04)
- [cAdvisor + Prometheus + Grafana](https://prometheus.io/docs/guides/cadvisor/)

---

**Note**: This service is part of the bonus requirements for the Inception project. It provides container monitoring and performance analysis capabilities without requiring additional authentication or complex setup.
