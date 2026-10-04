#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y python3 python3-pip

pip3 install flask psycopg2-binary flask-cors

sudo tee /etc/systemd/system/gymtracker-backend.service > /dev/null <<'EOF'
[Unit]
Description=Gym Tracker Flask Backend
After=network.target

[Service]
User=vagrant
WorkingDirectory=/vagrant/backend
ExecStart=/usr/bin/python3 /vagrant/backend/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gymtracker-backend
sudo systemctl restart gymtracker-backend