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
    
    log "Creating backup archive..."
    
    # Create compressed archive
    tar -czf "$archive_path" -C "/tmp" "$backup_name" --warning=no-file-changed 2>/dev/null || true
    
    # Verify archive was created
    if [[ -f "$archive_path" ]]; then
        local size=$(du -h "$archive_path" | cut -f1)
        info "Backup created: $archive_path ($size)"
    else
        error "Failed to create backup archive"
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    find "$BACKUP_BASE_DIR" -name "wg-web-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    local remaining=$(find "$BACKUP_BASE_DIR" -name "wg-web-backup-*.tar.gz" | wc -l)
    info "$remaining backup(s) remaining in $BACKUP_BASE_DIR"
}

# Verify backup integrity
verify_backup() {
    local archive_path="$1"
    
    log "Verifying backup integrity..."
    
    if tar -tzf "$archive_path" >/dev/null 2>&1; then
        info "Backup verification successful"
        return 0
    else
        error "Backup verification failed - archive may be corrupted"
        return 1
    fi
}

# List existing backups
list_backups() {
    echo
    echo "Existing backups:"
    echo "=================="
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        local backups=$(find "$BACKUP_BASE_DIR" -name "wg-web-backup-*.tar.gz" -type f 2>/dev/null | sort -r)
        
        if [[ -n "$backups" ]]; then
            while IFS= read -r backup; do
                local size=$(du -h "$backup" | cut -f1)
                local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
                local name=$(basename "$backup")
                printf "  %-50s %8s  %s\n" "$name" "$size" "$date"
            done <<< "$backups"
        else
            echo "  No backups found"
        fi
    else
        echo "  Backup directory does not exist"
    fi
    echo
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
    fi
    
    echo
    warn "RESTORE OPERATION"
    warn "This will overwrite current configuration!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        info "Restore cancelled"
        return 0
    fi
    
    log "Stopping services..."
    systemctl stop wg-web nginx || true
    
    log "Creating pre-restore backup..."
    local pre_restore_backup="${BACKUP_BASE_DIR}/pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz"
    main_backup "pre-restore-$(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1 || true
    
    log "Extracting backup..."
    tar -xzf "$backup_file" -C / --warning=no-timestamp 2>/dev/null || error "Failed to extract backup"
    
    log "Reloading systemd and restarting services..."
    systemctl daemon-reload
    systemctl start wg-web nginx
    
    info "Restore completed successfully"
}

# Main backup function
main_backup() {
    local backup_name=${1:-$(generate_backup_name)}
    
    setup_backup_dir
    backup_application "$backup_name"
    backup_config "$backup_name"
    backup_data "$backup_name"
    create_system_info "$backup_name"
    create_archive "$backup_name"
    
    local archive_path="${BACKUP_BASE_DIR}/${backup_name}.tar.gz"
    verify_backup "$archive_path"
    cleanup_old_backups
    
    echo "$archive_path"
}

# Usage information
usage() {
    echo "WireGuard Web Backup Script"
    echo
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  -b, --backup              Create a new backup (default)"
    echo "  -l, --list               List existing backups"
    echo "  -r, --restore FILE       Restore from backup file"
    echo "  -v, --verify FILE        Verify backup integrity"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0                       Create backup with auto-generated name"
    echo "  $0 --list               Show all existing backups"
    echo "  $0 --restore backup.tar.gz  Restore from specific backup"
    echo
}

# Main script logic
main() {
    case "${1:-}" in
        -b|--backup)
            check_root
            log "Starting backup process..."
            backup_file=$(main_backup)
            log "Backup completed: $backup_file"
            ;;
        -l|--list)
            list_backups
            ;;
        -r|--restore)
            check_root
            if [[ -z "$2" ]]; then
                error "Please specify backup file to restore"
            fi
            restore_backup "$2"
            ;;
        -v|--verify)
            if [[ -z "$2" ]]; then
                error "Please specify backup file to verify"
            fi
            verify_backup "$2"
            ;;
        -h|--help)
            usage
            ;;
        "")
            check_root
            log "Starting backup process..."
            backup_file=$(main_backup)
            log "Backup completed: $backup_file"
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
    