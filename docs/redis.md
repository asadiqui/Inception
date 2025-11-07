# Redis - In-Memory Data Store & Cache

[![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=flat&logo=redis&logoColor=white)](https://redis.io/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is Redis?](#what-is-redis)
2. [Why We Use Redis](#why-we-use-redis)
3. [Redis in Our Architecture](#redis-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Configuration Analysis](#configuration-analysis)
6. [Useful Commands](#useful-commands)
7. [Related Documentation](#related-documentation)

## What is Redis?

Redis (Remote Dictionary Server) is an open-source, in-memory data structure store used as a database, cache, and message broker. Created by Salvatore Sanfilippo in 2009, Redis is known for its exceptional performance, supporting sub-millisecond response times and enabling millions of requests per second.

### Key Features
- **In-Memory Storage**: All data stored in RAM for ultra-fast access
- **Data Structures**: Strings, hashes, lists, sets, sorted sets, bitmaps
- **Persistence Options**: RDB snapshots and AOF logging
- **Replication**: Master-slave replication support
- **Clustering**: Horizontal scaling capabilities
- **Pub/Sub**: Message broker functionality
- **Atomic Operations**: ACID-compliant operations

### Redis Use Cases
- **Caching**: Application-level and database query caching
- **Session Storage**: Web application session management
- **Real-time Analytics**: Counting, ranking, and statistics
- **Message Queues**: Task queues and pub/sub messaging
- **Leaderboards**: Gaming and social media rankings

## Why We Use Redis

In the Inception project, Redis serves as our **WordPress caching layer** with specific advantages:

### 🚀 **Performance Acceleration**
- Caches WordPress database queries in memory
- Reduces database load and response times
- Stores frequently accessed WordPress objects
- Improves overall site performance

### 🔄 **WordPress Integration**
- Object caching for WordPress core functions
- Plugin and theme data caching
- User session management
- Transient data storage

### 💾 **Memory Management**
- Configured memory limits to prevent resource exhaustion
- LRU (Least Recently Used) eviction policy
- Optimized for web application caching patterns

### 🔧 **Development Benefits**
- Easy debugging and monitoring
- Clear cache functionality
- Development environment optimization
- Testing and staging support

## Redis in Our Architecture

```
WordPress Container → Redis Container (Port 6379)
        ↓                     ↓
Database Queries         Cached Results
        ↓                     ↓
MariaDB Container ←── Cache Miss ──→ Redis Memory
```

**Caching Flow**:
1. WordPress checks Redis for cached data
2. **Cache Hit**: Return data from Redis (fast)
3. **Cache Miss**: Query MariaDB, store result in Redis
4. Future requests served from Redis cache

## Dockerfile Analysis

Let's examine the Redis Dockerfile line by line:

```dockerfile
FROM alpine:3.18
```
**Explanation**: Uses Alpine Linux 3.18 as the base image. Note: This should be 3.21 for consistency with other services.

```dockerfile
ARG WP_REDIS_PASSWORD
ENV WP_REDIS_PASSWORD=${WP_REDIS_PASSWORD}
```
**Explanation**:
- **ARG**: Build-time variable for Redis password
- **ENV**: Runtime environment variable (currently unused in this setup)

```dockerfile
RUN apk update && \
        apk upgrade && \
        apk add --no-cache redis && \
```
**Explanation**:
- Updates Alpine package index
- Upgrades system packages
- Installs Redis server package

```dockerfile
        sed -i \
                -e "s|bind 127.0.0.1|#bind 127.0.0.1|g" \
                -e "s|# maxmemory <bytes>|maxmemory 20mb|g" \
                /etc/redis.conf && \
```
**Explanation**:
- **First sed**: Comments out `bind 127.0.0.1` to allow external connections
- **Second sed**: Sets maximum memory usage to 20MB

```dockerfile
        echo "maxmemory-policy allkeys-lru" >> /etc/redis.conf
```
**Explanation**: Adds LRU (Least Recently Used) eviction policy when memory limit is reached.

```dockerfile
EXPOSE 6379
```
**Explanation**: Documents that container listens on port 6379 (Redis default port).

```dockerfile
CMD ["redis-server", "--protected-mode", "no"]
```
**Explanation**:
- Starts Redis server as main process
- **--protected-mode no**: Disables protected mode for container networking

## Configuration Analysis

### Redis Server Configuration

Our setup modifies the default Redis configuration:

```conf
# Original: bind 127.0.0.1
# Modified: #bind 127.0.0.1 (commented out)
```
**Purpose**: Allows connections from other Docker containers.

```conf
# Original: # maxmemory <bytes>
# Modified: maxmemory 20mb
```
**Purpose**: Limits Redis memory usage to prevent system resource exhaustion.

```conf
# Added: maxmemory-policy allkeys-lru
```
**Purpose**: When memory limit is reached, evict least recently used keys.

### Memory Management

**LRU Eviction Policy**:
- **allkeys-lru**: Evict least recently used keys from all keys
- **Automatic**: No manual cache management required
- **Performance**: Maintains hot data in memory
- **Resource Control**: Prevents memory overuse

### WordPress Integration

Redis integrates with WordPress through configuration in `wp-config.php`:

```php
// Redis Configuration (set by WordPress entrypoint)
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_CACHE', true);
```

**WordPress Object Cache**:
- Caches database query results
- Stores WordPress transients
- Caches user sessions and metadata
- Improves plugin performance

## Useful Commands

### Container Operations
```bash
# Access Redis container
docker exec -it redis sh

# Connect to Redis CLI
docker exec -it redis redis-cli

# Check Redis server info
docker exec redis redis-cli INFO server

# Monitor Redis commands in real-time
docker exec redis redis-cli MONITOR
```

### Cache Management
```bash
# View all keys
docker exec redis redis-cli KEYS "*"

# Get specific key value
docker exec redis redis-cli GET "key_name"

# Flush all cache
docker exec redis redis-cli FLUSHALL

# Flush current database
docker exec redis redis-cli FLUSHDB

# Check cache hit/miss statistics
docker exec redis redis-cli INFO stats
```

### Memory Monitoring
```bash
# Check memory usage
docker exec redis redis-cli INFO memory

# View memory usage by key pattern
docker exec redis redis-cli --bigkeys

# Check memory configuration
docker exec redis redis-cli CONFIG GET "*memory*"

# Monitor memory usage over time
docker exec redis redis-cli INFO memory | grep used_memory_human
```

### Performance Testing
```bash
# Redis benchmark (basic performance test)
docker exec redis redis-benchmark -h localhost -p 6379 -c 10 -n 1000

# Test specific operations
docker exec redis redis-benchmark -h localhost -p 6379 -t set,get -n 10000

# Latency monitoring
docker exec redis redis-cli --latency -i 1

# Continuous stats monitoring
docker exec redis redis-cli --stat -i 1
```

### WordPress Cache Integration
```bash
# Check WordPress object cache from WordPress container
docker exec wordpress wp cache flush --allow-root

# View WordPress cache statistics
docker exec wordpress wp redis status --allow-root

# Test Redis connection from WordPress
docker exec wordpress wp eval "var_dump(wp_cache_get('test_key'));" --allow-root

# Set test cache value
docker exec wordpress wp eval "wp_cache_set('test_key', 'test_value', '', 3600);" --allow-root
```

### Configuration Management
```bash
# View current Redis configuration
docker exec redis redis-cli CONFIG GET "*"

# Get specific configuration
docker exec redis redis-cli CONFIG GET "maxmemory"

# View configuration file
docker exec redis cat /etc/redis.conf | grep -v "^#" | grep -v "^$"

# Check server parameters
docker exec redis redis-cli INFO server
```

### Data Analysis
```bash
# Check key expiration times
docker exec redis redis-cli TTL "key_name"

# View key types
docker exec redis redis-cli TYPE "key_name"

# Sample random keys
docker exec redis redis-cli RANDOMKEY

# Database size
docker exec redis redis-cli DBSIZE

# Check slow queries
docker exec redis redis-cli SLOWLOG GET 10
```

### Debugging and Troubleshooting
```bash
# Check Redis server status
docker exec redis redis-cli PING

# View connected clients
docker exec redis redis-cli CLIENT LIST

# Check server configuration
docker exec redis redis-cli CONFIG GET "*"

# Monitor key space events
docker exec redis redis-cli --csv psubscribe '*'

# Check for blocked clients
docker exec redis redis-cli INFO clients
```

### Backup and Restore
```bash
# Create RDB snapshot
docker exec redis redis-cli BGSAVE

# Check last save time
docker exec redis redis-cli LASTSAVE

# Copy RDB file from container
docker cp redis:/data/dump.rdb ./redis-backup.rdb

# Restore RDB file to container
docker cp ./redis-backup.rdb redis:/data/dump.rdb
docker restart redis
```

## Performance Optimization

### Memory Configuration
```bash
# Monitor memory fragmentation
docker exec redis redis-cli INFO memory | grep mem_fragmentation_ratio

# Check memory efficiency
docker exec redis redis-cli MEMORY USAGE "key_name"

# Active memory defragmentation (Redis 4.0+)
docker exec redis redis-cli CONFIG SET activedefrag yes
```

### Cache Hit Ratio
```bash
# Calculate cache hit ratio
docker exec redis redis-cli INFO stats | grep -E "(keyspace_hits|keyspace_misses)"

# Monitor hit ratio over time
watch 'docker exec redis redis-cli INFO stats | grep -E "(keyspace_hits|keyspace_misses)"'
```

## WordPress Cache Plugins

### Compatible Plugins
- **Redis Object Cache**: Official WordPress Redis plugin
- **W3 Total Cache**: Popular caching plugin with Redis support
- **WP Redis**: Lightweight Redis object cache
- **LiteSpeed Cache**: Advanced caching with Redis integration

### Plugin Configuration
```php
// wp-config.php additions for Redis Object Cache plugin
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);
define('WP_REDIS_DATABASE', 0);
```

## Troubleshooting

### Common Issues

#### 1. **Connection Refused**
```bash
# Check if Redis is running
docker ps | grep redis

# Test connection
docker exec redis redis-cli ping

# Check network connectivity
docker exec wordpress ping redis
```

#### 2. **Memory Issues**
```bash
# Check memory usage
docker exec redis redis-cli INFO memory

# Check memory limit
docker exec redis redis-cli CONFIG GET maxmemory

# Monitor memory over time
docker stats redis --no-stream
```

#### 3. **Cache Not Working**
```bash
# Check WordPress Redis plugin status
docker exec wordpress wp plugin status redis-cache --allow-root

# Test cache functionality
docker exec wordpress wp cache flush --allow-root

# Verify Redis connection from WordPress
docker exec wordpress wp redis status --allow-root
```

### Performance Issues

#### 1. **Slow Queries**
```bash
# Check slow log
docker exec redis redis-cli SLOWLOG GET 10

# Monitor command latency
docker exec redis redis-cli --latency

# Check for blocking operations
docker exec redis redis-cli INFO commandstats
```

#### 2. **High Memory Usage**
```bash
# Find memory-hungry keys
docker exec redis redis-cli --bigkeys

# Analyze memory usage by pattern
docker exec redis redis-cli MEMORY USAGE "*wp*"

# Check fragmentation
docker exec redis redis-cli INFO memory | grep fragmentation
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [📝 **WordPress**](wordpress.md) - Primary Redis client
- [🗄️ **MariaDB**](mariadb.md) - Database layer being cached

---

**Redis Version**: Latest (Alpine package)  
**Alpine Base**: 3.18 (should be updated to 3.21)  
**Memory Limit**: 20MB  
**Eviction Policy**: allkeys-lru