#!/bin/bash
# WireGuard Flask Generator Setup Script

set -e

echo "[INFO] Creating directories..."
mkdir -p /opt/wg-web/{clients,logs,scripts,config,backups}

echo "[INFO] Setting permissions..."
chown -R root:root /opt/wg-web
chmod 755 /opt/wg-web
chmod 755 /opt/wg-web/clients

echo "[INFO] Creating systemd service..."
cat > /etc/systemd/system/wg-web.service << 'EOF'
[Unit]
Description=WireGuard Web Client Generator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/wg-web
ExecStart=/usr/bin/python3 /opt/wg-web/app.py
Restart=always
RestartSec=3
StandardOutput=append:/opt/wg-web/logs/app.log
StandardError=append:/opt/wg-web/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Reloading systemd..."
systemctl daemon-reload
systemctl enable wg-web
systemctl start wg-web

echo "[INFO] Setup completed!"
