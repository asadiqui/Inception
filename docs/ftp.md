# FTP Server - File Transfer Protocol

[![FTP](https://img.shields.io/badge/FTP-vsftpd-blue?style=flat&logo=files&logoColor=white)](https://security.appspot.com/vsftpd.html)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-0D597F?style=flat&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## Table of Contents

1. [What is FTP?](#what-is-ftp)
2. [Why We Use FTP](#why-we-use-ftp)
3. [FTP in Our Architecture](#ftp-in-our-architecture)
4. [Dockerfile Analysis](#dockerfile-analysis)
5. [Entrypoint Script Analysis](#entrypoint-script-analysis)
6. [Configuration Analysis](#configuration-analysis)
7. [Useful Commands](#useful-commands)
8. [Related Documentation](#related-documentation)

## What is FTP?

File Transfer Protocol (FTP) is a standard network protocol used for transferring files between a client and server on a computer network. FTP is built on a client-server model architecture using separate control and data connections between the client and the server.

### Key Features
- **File Transfer**: Upload and download files
- **Directory Management**: Create, delete, and navigate directories
- **User Authentication**: Username/password authentication
- **Active/Passive Modes**: Different connection methods
- **ASCII/Binary Modes**: Text and binary file transfer
- **Resume Support**: Continue interrupted transfers

### FTP vs SFTP/FTPS

| Protocol | Security | Port | Encryption |
|----------|----------|------|------------|
| **FTP** | None | 21 | No |
| **FTPS** | SSL/TLS | 21/990 | Yes |
| **SFTP** | SSH | 22 | Yes |

**Note**: Our implementation uses standard FTP for simplicity in the development environment.

## Why We Use FTP

In the Inception project, FTP serves as our **file access service** with specific advantages:

### 📁 **WordPress File Management**
- Direct access to WordPress files and directories
- Upload themes, plugins, and media files
- Edit configuration files and scripts
- Backup and restore website content

### 🔧 **Development Workflow**
- Easy file transfer during development
- Quick deployment of changes
- Testing file uploads and permissions
- Debugging file-related issues

### 💻 **External Client Support**
- Compatible with FileZilla, WinSCP, and other FTP clients
- Cross-platform file access
- Graphical and command-line interface support
- Bulk file operations

### 🔐 **Isolated Access**
- Dedicated FTP user with limited permissions
- Chrooted environment for security
- Access only to WordPress directory
- Network isolation through Docker

## FTP in Our Architecture

```
External FTP Client → Host (Port 21, 21000-21010) → FTP Container
                                                          ↓
                                                WordPress Volume
                                                   (/var/www/html)
```

**Connection Flow**:
1. Client connects to port 21 (command channel)
2. Authentication with FTP credentials
3. Passive mode: Client connects to ports 21000-21010 (data channels)
4. File operations on WordPress directory

## Dockerfile Analysis

Let's examine the FTP Dockerfile line by line:

```dockerfile
FROM alpine:3.21
```
**Explanation**: Uses Alpine Linux 3.21 as the base image for minimal size and security.

```dockerfile
RUN apk update && \
    apk add --no-cache vsftpd
```
**Explanation**:
- **vsftpd**: Very Secure FTP Daemon, a popular and secure FTP server
- **--no-cache**: Doesn't store package cache to reduce image size

```dockerfile
COPY tools/ftp-entrypoint.sh /usr/local/bin/ftp-entrypoint.sh
COPY conf/vsftpd.conf /tmp/vsftpd.conf
```
**Explanation**:
- Copies custom entrypoint script for FTP setup
- Copies FTP server configuration template

```dockerfile
RUN chmod +x /usr/local/bin/ftp-entrypoint.sh
```
**Explanation**: Makes the entrypoint script executable.

```dockerfile
ENTRYPOINT ["ftp-entrypoint.sh"]
```
**Explanation**: Sets our custom script as the container's entrypoint.

## Entrypoint Script Analysis

The `ftp-entrypoint.sh` script handles FTP server setup and configuration:

```bash
#!/bin/bash
set -e
```
**Explanation**: Uses bash shell with fail-fast error handling.

```bash
# Create FTP user if it doesn't exist
if ! id "$FTP_USER" &>/dev/null; then
    echo "Creating FTP user: $FTP_USER"
    adduser -D -h /var/www/html -s /bin/ash "$FTP_USER"
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
    
    # Add user to FTP allowed users list
    echo "$FTP_USER" >> /etc/vsftpd.userlist
fi
```
**Explanation**:
- **adduser -D**: Creates user without password prompt
- **-h /var/www/html**: Sets home directory to WordPress files
- **-s /bin/ash**: Sets shell (required for some FTP operations)
- **chpasswd**: Sets user password from environment variable
- **vsftpd.userlist**: Adds user to allowed users list

```bash
# Copy and configure vsftpd.conf on first run
if [ ! -e /etc/.firstrun ]; then
    cp /tmp/vsftpd.conf /etc/vsftpd/vsftpd.conf
    
    # Use the host's external IP address for passive mode
    # This is the IP that external FTP clients will connect to
    EXTERNAL_IP="10.0.2.15"
    
    # Set the passive address configuration
    if grep -q "pasv_address=" /etc/vsftpd/vsftpd.conf; then
        sed -i "s/pasv_address=.*/pasv_address=$EXTERNAL_IP/" /etc/vsftpd/vsftpd.conf
    else
        echo "pasv_address=$EXTERNAL_IP" >> /etc/vsftpd/vsftpd.conf
    fi
    
    # Ensure other passive mode settings are present
    if ! grep -q "pasv_addr_resolve=" /etc/vsftpd/vsftpd.conf; then
        echo "pasv_addr_resolve=NO" >> /etc/vsftpd/vsftpd.conf
    fi
    if ! grep -q "pasv_promiscuous=" /etc/vsftpd/vsftpd.conf; then
        echo "pasv_promiscuous=YES" >> /etc/vsftpd/vsftpd.conf
    fi
    
    echo "FTP configured with external IP: $EXTERNAL_IP"
    touch /etc/.firstrun
fi
```
**Explanation**:
- **First Run Check**: Only configures on first container run
- **External IP Configuration**: Sets IP for passive mode connections
- **Passive Mode Settings**: Configures passive FTP for external clients
- **pasv_addr_resolve=NO**: Don't resolve passive address
- **pasv_promiscuous=YES**: Allow connections from any IP

```bash
echo "FTP started on :21"
exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
```
**Explanation**:
- **exec**: Replaces script with vsftpd as main process
- Starts FTP server with our configuration file

## Configuration Analysis

### vsftpd.conf Configuration

Our FTP server uses these key configurations:

```conf
# Basic FTP settings
anonymous_enable=YES
local_enable=YES
write_enable=YES
```
**Purpose**: 
- Allows anonymous browsing (read-only)
- Enables local user authentication
- Permits file uploads and modifications

```conf
# User isolation and security
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/var/www/html
```
**Purpose**:
- **chroot_local_user**: Restricts users to their home directory
- **allow_writeable_chroot**: Allows writing in chroot environment
- **local_root**: Sets WordPress directory as FTP root

```conf
# Server configuration
listen=YES
listen_port=21
listen_address=0.0.0.0
seccomp_sandbox=NO
```
**Purpose**:
- **listen=YES**: Enables standalone server mode
- **listen_port=21**: Standard FTP command port
- **listen_address=0.0.0.0**: Accept connections from any IP
- **seccomp_sandbox=NO**: Disables sandbox for container compatibility

```conf
# Passive mode configuration
pasv_enable=YES
pasv_min_port=21000
pasv_max_port=21010
pasv_address=10.0.2.15
pasv_addr_resolve=NO
pasv_promiscuous=YES
```
**Purpose**:
- **Passive Mode**: Required for most modern FTP clients
- **Port Range**: Data connections use ports 21000-21010
- **External IP**: Advertises host IP for external client connections
- **Security Settings**: Configured for Docker networking

```conf
# User management
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
```
**Purpose**:
- **Whitelist Mode**: Only users in userlist can connect
- **Security**: Prevents unauthorized access

### Docker Compose Port Mapping

```yaml
ports:
  - "21:21"                    # FTP command channel
  - "21000-21010:21000-21010"  # FTP data channels (passive mode)
```

**Explanation**:
- **Port 21**: FTP control connection
- **Ports 21000-21010**: Passive mode data connections
- **Range**: Allows up to 11 concurrent data connections

## Useful Commands

### Container Operations
```bash
# Access FTP container
docker exec -it ftp sh

# Check FTP server status
docker exec ftp ps aux | grep vsftpd

# View FTP configuration
docker exec ftp cat /etc/vsftpd/vsftpd.conf

# Check FTP users
docker exec ftp cat /etc/vsftpd.userlist
```

### FTP Server Management
```bash
# Test FTP server connectivity
docker exec ftp nc -zv localhost 21

# Check listening ports
docker exec ftp netstat -tlnp | grep vsftpd

# View FTP logs
docker logs ftp

# Restart FTP service
docker restart ftp
```

### User Management
```bash
# Check if FTP user exists
docker exec ftp id ftpuser

# View user home directory
docker exec ftp ls -la /var/www/html

# Check user permissions
docker exec ftp ls -la /var/www/html -d

# Change user password
docker exec ftp sh -c 'echo "ftpuser:newpassword" | chpasswd'
```

### External FTP Client Testing
```bash
# Test FTP connection from host
ftp localhost 21

# Test with netcat
nc -zv localhost 21

# Test passive port range
nc -zv localhost 21000

# Command-line FTP client
ftp -p asadiqui.42.fr  # -p for passive mode
```

### File Operations Testing
```bash
# List files via FTP command
echo "ls" | ftp -inv localhost

# Upload test file
echo "put /etc/passwd test.txt" | ftp -inv localhost

# Download file
echo "get index.php" | ftp -inv localhost
```

### Network Debugging
```bash
# Check external IP configuration
docker exec ftp grep pasv_address /etc/vsftpd/vsftpd.conf

# Test network connectivity
docker exec ftp ping google.com

# Check Docker network
docker network inspect srcs_default | grep ftp -A 5
```

### Performance Monitoring
```bash
# Monitor FTP connections
docker exec ftp netstat -an | grep :21

# Check resource usage
docker stats ftp --no-stream

# Monitor file system usage
docker exec ftp df -h /var/www/html
```

## FTP Client Configuration

### FileZilla Setup
```
Host: asadiqui.42.fr (or your domain/IP)
Port: 21
Protocol: FTP (not SFTP)
Encryption: None
Logon Type: Normal
User: ftpuser
Password: ftppass
```

**Transfer Settings**:
- **Transfer Mode**: Passive (recommended)
- **File Type**: Auto-detect
- **Concurrent Transfers**: 1-2 (due to port range limit)

### Command Line FTP
```bash
# Connect with passive mode
ftp -p asadiqui.42.fr

# Login
Name: ftpuser
Password: ftppass

# Common commands
ftp> ls                    # List files
ftp> cd directory         # Change directory
ftp> put localfile        # Upload file
ftp> get remotefile       # Download file
ftp> binary               # Binary transfer mode
ftp> ascii                # ASCII transfer mode
ftp> quit                 # Exit
```

### WinSCP Configuration (Windows)
```
File Protocol: FTP
Host Name: asadiqui.42.fr
Port: 21
User Name: ftpuser
Password: ftppass
```

**Advanced Settings**:
- Connection → FTP → Passive Mode: Yes
- Connection → FTP → Transfer Mode: Binary

## Security Considerations

### Access Control
- **Chroot Jail**: Users restricted to WordPress directory
- **User Whitelist**: Only authorized users can connect
- **No Anonymous Uploads**: Anonymous users have read-only access
- **Password Authentication**: Required for write access

### Network Security
- **Docker Network**: FTP server isolated in container network
- **Port Restriction**: Limited port range for data connections
- **No External Root**: Root account cannot login via FTP
- **File Permissions**: WordPress file ownership maintained

### File System Security
- **Limited Access**: Only WordPress directory accessible
- **Permission Preservation**: File ownership and permissions maintained
- **No System Access**: Cannot access system files outside WordPress

## Troubleshooting

### Common Issues

#### 1. **Connection Refused**
```bash
# Check if FTP service is running
docker exec ftp ps aux | grep vsftpd

# Test port connectivity
nc -zv localhost 21

# Check firewall rules
iptables -L | grep 21
```

#### 2. **Login Failed**
```bash
# Check user exists
docker exec ftp id ftpuser

# Verify user in allowed list
docker exec ftp cat /etc/vsftpd.userlist

# Test password
docker exec ftp su ftpuser
```

#### 3. **Passive Mode Issues**
```bash
# Check passive configuration
docker exec ftp grep -E "pasv_" /etc/vsftpd/vsftpd.conf

# Test passive ports
nc -zv localhost 21000

# Check external IP setting
docker exec ftp grep pasv_address /etc/vsftpd/vsftpd.conf
```

#### 4. **File Permission Errors**
```bash
# Check WordPress directory permissions
docker exec ftp ls -la /var/www/html

# Fix ownership if needed
docker exec ftp chown -R ftpuser:ftpuser /var/www/html

# Check write permissions
docker exec ftp touch /var/www/html/test.txt
```

### Performance Issues

#### 1. **Slow Transfer Speeds**
```bash
# Check network performance
docker exec ftp ping -c 5 google.com

# Monitor I/O usage
docker stats ftp

# Check disk space
docker exec ftp df -h
```

#### 2. **Connection Timeouts**
```bash
# Check timeout settings
docker exec ftp grep timeout /etc/vsftpd/vsftpd.conf

# Monitor active connections
docker exec ftp netstat -an | grep :21

# Check system resources
docker exec ftp top
```

## Related Documentation

- [📖 **Main README**](../README.md) - Project overview and architecture
- [📝 **WordPress**](wordpress.md) - File system being accessed
- [🌐 **NGINX**](nginx.md) - Web server for same files

---

**FTP Server**: vsftpd (Very Secure FTP Daemon)  
**Alpine Base**: 3.21  
**Command Port**: 21  
**Data Ports**: 21000-21010  
**Access**: External FTP clients