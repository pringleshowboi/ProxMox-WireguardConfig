#!/bin/bash

# WireGuard Web Backup Script
# Creates comprehensive backups of the WireGuard Flask Generator

set -e

# Configuration
BACKUP_BASE_DIR="/opt/wg-web/backups"
RETENTION_DAYS=30
COMPRESS_LEVEL=6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[BACKUP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[BACKUP] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[BACKUP] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[BACKUP] INFO:${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Create backup directory
setup_backup_dir() {
    mkdir -p "$BACKUP_BASE_DIR"
    chmod 700 "$BACKUP_BASE_DIR"
}

# Generate backup filename
generate_backup_name() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local hostname=$(hostname -s)
    echo "wg-web-backup-${hostname}-${timestamp}"
}

# Backup application files
backup_application() {
    local backup_name=$1
    local temp_dir="/tmp/${backup_name}"

    log "Creating temporary backup directory..."
    mkdir -p "$temp_dir/opt/wg-web"

    # Copy application files
    if [[ -d "/opt/wg-web" ]]; then
        log "Backing up application files..."
        cp -r /opt/wg-web/* "$temp_dir/opt/wg-web/" 2>/dev/null || true

        # Exclude log files from main backup
        rm -rf "$temp_dir/opt/wg-web/logs"/*.log 2>/dev/null || true
    else
        warn "Application directory /opt/wg-web not found"
    fi
}

# Backup configuration files
backup_config() {
    local backup_name=$1
    local temp_dir="/tmp/${backup_name}"

    log "Backing up configuration files..."

    # WireGuard configuration
    if [[ -f "/etc/wireguard/wg0.conf" ]]; then
        mkdir -p "$temp_dir/etc/wireguard"
        cp /etc/wireguard/wg0.conf "$temp_dir/etc/wireguard/"
    fi

    # Systemd service
    if [[ -f "/etc/systemd/system/wg-web.service" ]]; then
        mkdir -p "$temp_dir/etc/systemd/system"
        cp /etc/systemd/system/wg-web.service "$temp_dir/etc/systemd/system/"
    fi

    # Nginx configuration
    if [[ -f "/etc/nginx/sites-available/wg-web" ]]; then
        mkdir -p "$temp_dir/etc/nginx/sites-available"
        cp /etc/nginx/sites-available/wg-web "$temp_dir/etc/nginx/sites-available/"
    fi

    # Basic auth file
    if [[ -f "/etc/nginx/.htpasswd" ]]; then
        mkdir -p "$temp_dir/etc/nginx"
        cp /etc/nginx/.htpasswd "$temp_dir/etc/nginx/"
    fi
}

# Backup database and client configs
backup_data() {
    local backup_name=$1
    local temp_dir="/tmp/${backup_name}"

    log "Backing up client data..."

    # Client database
    if [[ -f "/opt/wg-web/clients.json" ]]; then
        cp /opt/wg-web/clients.json "$temp_dir/opt/wg-web/" 2>/dev/null || true
    fi

    # Client configuration files
    if [[ -d "/opt/wg-web/clients" ]]; then
        mkdir -p "$temp_dir/opt/wg-web/clients"
        cp /opt/wg-web/clients/*.conf "$temp_dir/opt/wg-web/clients/" 2>/dev/null || true
    fi
}

# Create system info
create_system_info() {
    local backup_name=$1
    local temp_dir="/tmp/${backup_name}"
    local info_file="$temp_dir/system_info.txt"

    log "Collecting system information..."

    {
        echo "WireGuard Flask Generator Backup"
        echo "Created: $(date)"
        echo "Hostname: $(hostname)"
        echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "Kernel: $(uname -r)"
        echo ""
        echo "WireGuard Status:"
        wg show 2>/dev/null || echo "WireGuard not active"
        echo ""
        echo "Service Status:"
        systemctl is-active wg-web || echo "wg-web: inactive"
        systemctl is-active nginx || echo "nginx: inactive"
        echo ""
        echo "Disk Usage:"
        du -sh /opt/wg-web 2>/dev/null || echo "N/A"
        echo ""
        echo "Client Count:"
        if [[ -f "/opt/wg-web/clients.json" ]]; then
            python3 -c "import json; print(len(json.load(open('/opt/wg-web/clients.json'))))" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
        echo ""
        echo "Network Configuration:"
        ip addr show | grep -E "(wg0|eth0)" || echo "No relevant interfaces"
    } > "$info_file"
}

# Create backup archive
create_archive() {
    local backup_name=$1
    local temp_dir="/tmp/${backup_name}"
    local archive_path="${BACKUP_BASE_DIR}/${backup_name}.tar.gz"

    log "Creating compressed archive..."
    tar -czf "$archive_path" -C "/tmp" "$backup_name" --remove-files --gzip --options "gzip:compression-level=${COMPRESS_LEVEL}"

    if [[ -f "$archive_path" ]]; then
        log "Backup successfully created: $archive_path"
    else
        error "Failed to create backup archive"
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find "$BACKUP_BASE_DIR" -type f -name "*.tar.gz" -mtime +${RETENTION_DAYS} -exec rm -f {} \;
}

# Main script
main() {
    check_root
    setup_backup_dir
    local backup_name=$(generate_backup_name)
    backup_application "$backup_name"
    backup_config "$backup_name"
    backup_data "$backup_name"
    create_system_info "$backup_name"
    create_archive "$backup_name"
    cleanup_old_backups
}

main
