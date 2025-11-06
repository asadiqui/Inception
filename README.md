# Inception (Docker + WordPress stack)

A self-contained, reproducible Docker environment that provisions a WordPress site running behind Nginx with HTTPS, backed by MariaDB, and enhanced with Redis. It also includes optional bonus services: FTP, Adminer, Portainer, and a separate static site.

This repository is structured for the 42 Inception project and aims to be easy to run locally with persistent data volumes.

---

## What you get

- Nginx (TLS-terminated, self‑signed) serving WordPress over HTTPS (443)
- WordPress (PHP‑FPM 8.2) auto‑installed and configured on first run
- MariaDB with database/users created on first run
- Redis cache wired to WordPress
- Bonus services (optional but included):
  - FTP (vsftpd) on ports 21 and 21000–21010 (passive mode)
  - Adminer (DB admin) on port 8080
  - Portainer (Docker UI) on ports 9000/9443 (and 8000 Agent Edge)
  - Static site (Nginx) on port 80
- Data persistence on host under `$HOME/data/{mariadb,wordpress,portainer}`

---

## Architecture at a glance

All containers are joined on a single user-defined bridge network `docker-network`.

- nginx
  - Ports: 443:443
  - Volumes: `wordpress:/var/www/html`
  - Depends on: wordpress, mariadb
  - Generates a self-signed TLS cert on first run (`/etc/nginx/ssl`)
- wordpress
  - Exposes PHP‑FPM internally on 9000 (not published)
  - Volumes: `wordpress:/var/www/html`
  - Auto-installs WordPress via WP-CLI and configures Redis
- mariadb
  - Volumes: `mariadb:/var/lib/mysql`
  - Initializes DB, user, and root password on first run
- redis
  - Internal only; tuned to 20MB with allkeys-lru policy
- ftp (bonus)
  - Ports: 21:21, 21000–21010:21000–21010 (passive)
  - Shares WordPress volume to allow file access
- adminer (bonus)
  - Ports: 8080:8080
- static-site (bonus)
  - Ports: 80:80
- portainer (bonus)
  - Ports: 9000:9000, 9443:9443, 8000:8000
  - Volumes: `portainer:/data`, plus host Docker socket

Persistent volumes map to host directories:

- `mariadb` → `$HOME/data/mariadb`
- `wordpress` → `$HOME/data/wordpress`
- `portainer` → `$HOME/data/portainer`

---

## Prerequisites

- Linux host (tested on Alpine-based containers; repo developed on Linux)
- Docker Engine and Docker Compose plugin
- make

---

## Quick start

1) Create a `.env` file at `srcs/.env` with your settings (template below).

2) Launch the stack:

```sh
make
```

This builds (if needed), creates data directories, and starts all services detached.

3) Open the services:

- WordPress: https://YOUR_DOMAIN_NAME (port 443; self-signed cert, accept the warning)
- Adminer:   http://localhost:8080
- Static:    http://localhost:80
- Portainer: https://localhost:9443 (or http://localhost:9000)
- FTP:       ftp://localhost:21 (passive ports 21000–21010)

Tip: If you use a custom domain (e.g., `example.localhost`), map it in `/etc/hosts`:

```
127.0.0.1   example.localhost
```

---

## Environment configuration (srcs/.env)

Required variables consumed by the Compose file and entrypoints:

```
# General
DOMAIN_NAME=example.localhost

# MariaDB
MYSQL_ROOT_PASSWORD=replace-me-strong
MYSQL_USER=wpuser
MYSQL_PASSWORD=replace-me-strong
MYSQL_DATABASE=wordpress

# WordPress install
WORDPRESS_TITLE=My Blog
WORDPRESS_ADMIN_USER=admin
WORDPRESS_ADMIN_PASSWORD=replace-me-strong
WORDPRESS_ADMIN_EMAIL=admin@example.localhost
WORDPRESS_USER=author
WORDPRESS_PASSWORD=replace-me-strong
WORDPRESS_EMAIL=author@example.localhost

# FTP (bonus)
FTP_USER=ftpuser
FTP_PASSWORD=replace-me-strong
# WORDPRESS_DIR is optional here (volume is mounted at /var/www/html in the container)
WORDPRESS_DIR=/var/www/html
```

Notes:
- `DOMAIN_NAME` is baked into the Nginx certificate and WordPress site URL. Using `localhost` works; a custom domain mapped in `/etc/hosts` gives a cleaner URL.
- Redis is auto-wired in WordPress (no password by default; for local dev only).

---

## Makefile commands

- `make` (alias of `all`): Create data dirs and start the stack
- `make build`: Build images and start/recreate containers
- `make down`: Stop and remove containers (preserves data)
- `make re`: Recreate from scratch (down + build up)
- `make clean`: Prune Docker artifacts and wipe `$HOME/data/{wordpress,mariadb,portainer}`
- `make fclean`: Aggressive prune (images, networks, volumes) and wipe data dirs
- `make logs`: Follow all service logs

All targets honor the Compose file at `srcs/docker-compose.yml` and env file `srcs/.env`.

---

## First-run behavior and internals

- Nginx (`requirements/nginx/tools/nginx-entrypoint.sh`)
  - Generates a self-signed cert for `$DOMAIN_NAME`
  - Configures FastCGI proxy to `wordpress:9000`
- WordPress (`requirements/wordpress/tools/wordpress-entrypoint.sh`)
  - Switches PHP‑FPM to listen on 9000
  - Waits for MariaDB, then runs `wp core download/config/install`
  - Sets Redis constants and enables caching
- MariaDB (`requirements/mariadb/tools/mariadb-entrypoint.sh`)
  - Enables networking (bind 0.0.0.0)
  - Initializes DB files and creates database, user, and root password
- Redis (`bonus/redis`)
  - Configured for 20MB max memory and allkeys‑lru eviction
- FTP (`bonus/ftp`)
  - vsftpd with passive ports 21000–21010; creates user from env
- Adminer (`bonus/adminer`) and Static site (`bonus/static-site`)
  - Lightweight PHP server / Nginx serving provided assets
- Portainer (`bonus/portainer`)
  - Unpacked upstream Portainer binaries; persists data to volume

---

## Security and caveats

- Self-signed TLS is for local use. For production, use real certificates and harden ciphers.
- FTP transmits credentials in plaintext; restrict access or prefer SFTP in real setups.
- Redis has no auth in this stack. Do not expose it publicly.
- Portainer is powerful—secure it with strong credentials and restrict exposure as needed.

---

## Troubleshooting

- See logs: `make logs`
- Containers won’t start after config changes: `make build`
- Reset everything: `make fclean` (this also deletes all data directories)
- Check data persisted under `$HOME/data/{mariadb,wordpress,portainer}`
- WordPress URL mismatch: ensure `DOMAIN_NAME` is correct. If changed after first run, you may need to update WordPress site/home URLs via WP-CLI or the DB.

---

## Repository layout

```
srcs/
  docker-compose.yml
  requirements/
    mariadb/|nginx/|wordpress/ (core stack)
    bonus/ (adminer, ftp, portainer, redis, static-site)
Makefile
```

---

