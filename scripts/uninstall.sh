#!/bin/bash
# Uninstall WireGuard Flask Generator

set -e

echo "[INFO] Stopping service..."
systemctl stop wg-web
systemctl disable wg-web

echo "[INFO] Removing systemd service..."
rm -f /etc/systemd/system/wg-web.service
systemctl daemon-reload

echo "[INFO] Removing application files..."
rm -rf /opt/wg-web

echo "[INFO] WireGuard Flask Generator uninstalled!"
echo "[INFO] Note: WireGuard configuration files in /etc/wireguard are not removed."