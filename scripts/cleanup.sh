#!/bin/bash
# Cleanup old client configs and logs

set -e

echo "[INFO] Removing old client configs..."
rm -f /opt/wg-web/clients/*.conf

echo "[INFO] Clearing logs..."
rm -f /opt/wg-web/logs/*.log

echo "[INFO] Cleanup completed!"
