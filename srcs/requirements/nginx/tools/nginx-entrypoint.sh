#!/bin/bash
set -e

# On the first container run, generate a certificate and configure the server
if [ ! -e /etc/.firstrun ]; then
    # Ensure destinations exist so file writes won't fail inside the container
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/http.d
    mkdir -p /etc/nginx/ssl

    # Generate a certificate for HTTPS
    openssl req -x509 -days 365 -newkey rsa:2048 -nodes \
        -out '/etc/nginx/ssl/cert.crt' \
        -keyout '/etc/nginx/ssl/cert.key' \
        -subj "/CN=$DOMAIN_NAME" \
         >/dev/null 2>/dev/null

    # Configure nginx to serve static WordPress files and to pass PHP requests
    # to the WordPress container's php-fpm process
    cat << EOF >> /etc/nginx/http.d/default.conf
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/nginx/ssl/cert.crt;
    ssl_certificate_key /etc/nginx/ssl/cert.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    # Portfolio/Static site location
    location /portfolio {
        alias /usr/share/nginx/html;
        try_files \$uri \$uri/ /portfolio/index.html;
        
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 7d;
            add_header Cache-Control "public";
        }
    }
    
    # cAdvisor proxy - main path (priority prefix to override regex locations)
    location ^~ /cadvisor/ {
        rewrite ^/cadvisor/(.*)\$ /\$1 break;
        proxy_pass http://cadvisor:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Handle websockets for real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Rewrite Location headers in redirects
        proxy_redirect ~^/(.*)\$ /cadvisor/\$1;
    }
    
    # Adminer proxy  
    location /adminer/ {
        proxy_pass http://adminer:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

    # WordPress (default location)
    root /var/www/html;
    index index.php index.html index.htm;

    # Handle static file extensions with proper 404
    location ~* \.(txt|pdf|zip|doc|docx|xml|json)$ {
        try_files \$uri =404;
    }

    # WordPress assets and uploads
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        try_files \$uri =404;
        expires 7d;
        add_header Cache-Control "public";
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ [^/]\.php(/|\$) {
        try_files \$fastcgi_script_name =404;

        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
    }
}
EOF
    touch /etc/.firstrun
fi

exec nginx -g 'daemon off;'
