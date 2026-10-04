#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y nginx

sudo cp /vagrant/frontend/index.html /var/www/html/index.html

sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api/ {
        proxy_pass http://192.168.56.11:5000/;
    }
}
EOF

sudo nginx -t

sudo systemctl enable nginx
sudo systemctl restart nginx