#!/bin/bash

# WireGuard Flask Client Generator Uninstall Script
# Completely removes the WireGuard web interface

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[UNINSTALL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[UNINSTALL] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[UNINSTALL] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[UNINSTALL] INFO:${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Confirmation prompt
confirm_uninstall() {
    echo
    echo "=========================================="
    echo "  WireGuard Flask Generator Uninstaller"
    echo "=========================================="
    echo
    warn "This will completely remove the WireGuard Flask Client Generator"
    warn "including all client configurations and data!"
    echo
    echo "The following will be removed:"
    echo "  • Application files (/opt/wg-web/)"
    echo "  • System service (wg-web.service)"
    echo "  • Nginx configuration"
    echo "  • Client configurations and database"
    echo "  • Log files"
    echo "  • Utility scripts"
    echo
    echo "The following will NOT be removed:"
    echo "  • WireGuard server configuration (/etc/wireguard/wg0.conf)"
    echo "  • System packages (nginx, python3, etc.)"
    echo "  • WireGuard installation"
    echo
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        info "Uninstall cancelled"
        exit 0
    fi
    
    echo
    read -p "Create a backup before uninstalling? (y/n): " backup_confirm
    
    if [[ "$backup_confirm" =~ ^[Yy] ]]; then
        create_final_backup
    fi
}

# Create final backup
create_final_backup() {
    log "Creating final backup before uninstall..."
    
    local backup_dir="/tmp/wg-web-final-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_file="${backup_dir}.tar.gz"
    
    mkdir -p "$backup_dir"
    
    # Copy application files if they exist
    if [[ -d "/opt/wg-web" ]]; then
        cp -r /opt/wg-web "$backup_dir/" 2>/dev/null || true
    fi
    
    # Copy configuration files
    mkdir -p "$backup_dir/config"
    [[ -f "/etc/systemd/system/wg-web.service" ]] && cp /etc/systemd/system/wg-web.service "$backup_dir/config/" 2>/dev/null || true
    [[ -f "/etc/nginx/sites-available/wg-web" ]] && cp /etc/nginx/sites-available/wg-web "$backup_dir/config/" 2>/dev/null || true
    [[ -f "/etc/nginx/.htpasswd" ]] && cp /etc/nginx/.htpasswd "$backup_dir/config/" 2>/dev/null || true
    
    # Create info file
    cat > "$backup_dir/uninstall_info.txt" << EOF
WireGuard Flask Generator - Final Backup
Created: $(date)
Uninstalled from: $(hostname)

This backup was created before uninstalling the WireGuard Flask Client Generator.

Contents:
- Application files from /opt/wg-web/
- Service configuration
- Nginx configuration  
- Authentication files
- Client database and configurations

To restore, extract this archive and run the install script
EOF
    
    # Create archive
    tar -czf "$backup_file" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")" 2>/dev/null
    rm -rf "$backup_dir"
    
    if [[ -f "$backup_file" ]]; then
        info "Final backup created: $backup_file"
        echo "  Size: $(du -h "$backup_file" | cut -f1)"
        echo
    else
        warn "Failed to create backup"
    fi
}

# Stop services
stop_services() {
    log "Stopping services..."
    
    # Stop wg-web service
    if systemctl is-active --quiet wg-web 2>/dev/null; then
        systemctl stop wg-web
        info "Stopped wg-web service"
    fi
    
    # Disable wg-web service
    if systemctl is-enabled --quiet wg-web 2>/dev/null; then
        systemctl disable wg-web
        info "Disabled wg-web service"
    fi
    
    # Note: We don't stop nginx as it might be used for other things
    if systemctl is-active --quiet nginx 2>/dev/null; then
        info "Nginx is running (not stopped - may be used by other services)"
    fi
}

# Remove application files
remove_application() {
    log "Removing application files..."
    
    if [[ -d "/opt/wg-web" ]]; then
        # Get size for reporting
        local size=$(du -sh /opt/wg-web 2>/dev/null | cut -f1 || echo "unknown")
        
        rm -rf /opt/wg-web
        info "Removed application directory (/opt/wg-web) - freed $size"
    else
        info "Application directory not found"
    fi
}

# Remove system service
remove_service() {
    log "Removing system service..."
    
    if [[ -f "/etc/systemd/system/wg-web.service" ]]; then
        rm -f /etc/systemd/system/wg-web.service
        systemctl daemon-reload
        info "Removed systemd service file"
    else
        info "Service file not found"
    fi
}

# Remove nginx configuration
remove_nginx_config() {
    log "Removing nginx configuration..."
    
    # Remove site configuration
    if [[ -f "/etc/nginx/sites-available/wg-web" ]]; then
        rm -f /etc/nginx/sites-available/wg-web
        info "Removed nginx site configuration"
    fi
    
    # Remove enabled site link
    if [[ -L "/etc/nginx/sites-enabled/wg-web" ]]; then
        rm -f /etc/nginx/sites-enabled/wg-web
        info "Removed nginx enabled site link"
    fi
    
    # Remove basic auth file
    if [[ -f "/etc/nginx/.htpasswd" ]]; then
        rm -f /etc/nginx/.htpasswd
        info "Removed nginx basic auth file"
    fi
    
    # Test nginx configuration and reload if valid
    if command -v nginx >/dev/null 2>&1; then
        if nginx -t 2>/dev/null; then
            systemctl reload nginx 2>/dev/null || true
            info "Reloaded nginx configuration"
        else
            warn "Nginx configuration test failed - manual intervention may be required"
        fi
    fi
}

# Remove utility scripts
remove_scripts() {
    log "Removing utility scripts..."
    
    local scripts=(
        "/usr/local/bin/wg-web-backup"
        "/usr/local/bin/wg-web-status"
        "/usr/local/bin/wg-web-update"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            rm -f "$script"
            info "Removed script: $script"
        fi
    done
}

# Remove log files and directories
remove_logs() {
    log "Removing log files..."
    
    # Remove main log directory (already removed with /opt/wg-web)
    if [[ -d "/var/log/wg-web" ]]; then
        rm -rf /var/log/wg-web
        info "Removed log directory: /var/log/wg-web"
    fi
    
    # Remove logrotate configuration
    if [[ -f "/etc/logrotate.d/wg-web" ]]; then
        rm -f /etc/logrotate.d/wg-web
        info "Removed logrotate configuration"
    fi
}

# Clean up WireGuard peers (optional)
cleanup_wireguard_peers() {
    log "Cleaning up WireGuard peers..."
    
    read -p "Remove all WireGuard peers added by this application? (y/n): " remove_peers
    
    if [[ "$remove_peers" =~ ^[Yy] ]]; then
        warn "This will remove ALL peers from the WireGuard interface"
        read -p "Are you sure? This cannot be undone. (type 'yes'): " confirm_peers
        
        if [[ "$confirm_peers" == "yes" ]]; then
            if command -v wg >/dev/null 2>&1; then
                # Get list of peers
                local peers=$(wg show wg0 peers 2>/dev/null || echo "")
                
                if [[ -n "$peers" ]]; then
                    local peer_count=0
                    while IFS= read -r peer; do
                        [[ -z "$peer" ]] && continue
                        wg set wg0 peer "$peer" remove 2>/dev/null || warn "Failed to remove peer: $peer"
                        ((peer_count++))
                    done <<< "$peers"
                    
                    info "Removed $peer_count peer(s) from WireGuard"
                    
                    # Save configuration
                    wg-quick save wg0 2>/dev/null || warn "Failed to save WireGuard configuration"
                else
                    info "No peers found to remove"
                fi
            else
                warn "WireGuard tools not available"
            fi
        else
            info "Skipping peer removal"
        fi
    else
        info "Keeping WireGuard peers (you may need to clean them up manually)"
    fi
}

# Remove Python packages (optional)
remove_python_packages() {
    read -p "Remove Python packages installed for this application? (y/n): " remove_py
    
    if [[ "$remove_py" =~ ^[Yy] ]]; then
        log "Removing Python packages..."
        
        local packages=(
            "flask"
            "pyqrcode"
            "pypng"
            "gunicorn"
        )
        
        for package in "${packages[@]}"; do
            if pip3 show "$package" >/dev/null 2>&1; then
                pip3 uninstall -y "$package" 2>/dev/null || warn "Failed to remove $package"
                info "Removed Python package: $package"
            fi
        done
    else
        info "Keeping Python packages (may be used by other applications)"
    fi
}

# Final cleanup and verification
final_cleanup() {
    log "Performing final cleanup..."
    
    # Remove any remaining temporary files
    find /tmp -name "*wg-web*" -type f -mtime +1 -delete 2>/dev/null || true
    
    # Clear systemd cache
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    
    info "Final cleanup completed"
}

# Verify removal
verify_removal() {
    log "Verifying removal..."
    
    local issues=()
    
    # Check for remaining files
    [[ -d "/opt/wg-web" ]] && issues+=("Application directory still exists: /opt/wg-web")
    [[ -f "/etc/systemd/system/wg-web.service" ]] && issues+=("Service file still exists")
    [[ -f "/etc/nginx/sites-available/wg-web" ]] && issues+=("Nginx config still exists")
    [[ -f "/usr/local/bin/wg-web-backup" ]] && issues+=("Utility scripts still exist")
    
    # Check for running services
    if systemctl is-active --quiet wg-web 2>/dev/null; then
        issues+=("wg-web service is still running")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        info "✅ Removal verification successful - all components removed"
    else
        warn "⚠️  Removal verification found issues:"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
}

# Display post-uninstall information
show_post_uninstall_info() {
    echo
    echo "=========================================="
    echo "      Uninstall Complete!"
    echo "=========================================="
    echo
    info "The WireGuard Flask Client Generator has been removed"
    echo
    echo "📋 What was removed:"
    echo "  ✅ Application files (/opt/wg-web/)"
    echo "  ✅ System service (wg-web.service)"
    echo "  ✅ Nginx configuration"
    echo "  ✅ Utility scripts"
    echo "  ✅ Log files"
    echo
    echo "📋 What was NOT removed:"
    echo "  🔶 WireGuard server (/etc/wireguard/wg0.conf)"
    echo "  🔶 System packages (nginx, python3, wireguard)"
    echo "  🔶 Nginx (may be used by other services)"
    echo
    echo "🔧 Manual cleanup (if needed):"
    echo "  • Review /etc/wireguard/wg0.conf for any remaining [Peer] sections"
    echo "  • Check nginx configuration: nginx -t"
    echo "  • Remove system packages if not needed elsewhere"
    echo
    echo "💾 Backup:"
    if ls /tmp/wg-web-final-backup-*.tar.gz 2>/dev/null; then
        echo "  📁 Final backup created in /tmp/"
        ls /tmp/wg-web-final-backup-*.tar.gz | sed 's/^/    /'
    else
        echo "  ❌ No backup was created"
    fi
    echo
    echo "🎉 Thank you for using WireGuard Flask Client Generator!"
}

# Usage information
usage() {
    echo "WireGuard Flask Client Generator Uninstall Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -y, --yes               Skip confirmation prompts"
    echo "  -f, --force             Force removal even if issues are detected"
    echo "  --no-backup             Skip creating final backup"
    echo "  --remove-peers          Remove all WireGuard peers without asking"
    echo "  --remove-packages       Remove Python packages without asking"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      Interactive uninstall with prompts"
    echo "  $0 -y --no-backup       Quick uninstall without backup"
    echo "  $0 --remove-peers       Uninstall and remove all WireGuard peers"
    echo
}

# Main uninstall function
main() {
    local skip_confirm=false
    local no_backup=false
    local remove_peers_auto=false
    local remove_packages_auto=false
    local force_removal=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            -f|--force)
                force_removal=true
                shift
                ;;
            --no-backup)
                no_backup=true
                shift
                ;;
            --remove-peers)
                remove_peers_auto=true
                shift
                ;;
            --remove-packages)
                remove_packages_auto=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    check_root
    
    # Confirmation (unless skipped)
    if [[ "$skip_confirm" == "false" ]]; then
        confirm_uninstall
    elif [[ "$no_backup" == "false" ]]; then
        create_final_backup
    fi
    
    # Perform uninstall steps
    log "Starting uninstall process..."
    
    stop_services
    remove_application
    remove_service
    remove_nginx_config
    remove_scripts
    remove_logs
    
    # Optional cleanups
    if [[ "$remove_peers_auto" == "true" ]] || [[ "$skip_confirm" == "false" ]]; then
        if [[ "$remove_peers_auto" == "true" ]]; then
            # Auto-remove peers
            if command -v wg >/dev/null 2>&1; then
                local peers=$(wg show wg0 peers 2>/dev/null || echo "")
                if [[ -n "$peers" ]]; then
                    while IFS= read -r peer; do
                        [[ -z "$peer" ]] && continue
                        wg set wg0 peer "$peer" remove 2>/dev/null || true
                    done <<< "$peers"
                    info "Removed WireGuard peers automatically"
                fi
            fi
        else
            cleanup_wireguard_peers
        fi
    fi
    
    if [[ "$remove_packages_auto" == "true" ]]; then
        # Auto-remove packages
        pip3 uninstall -y flask pyqrcode pypng gunicorn 2>/dev/null || true
        info "Removed Python packages automatically"
    elif [[ "$skip_confirm" == "false" ]]; then
        remove_python_packages
    fi
    
    final_cleanup
    verify_removal
    show_post_uninstall_info
    
    log "Uninstall completed successfully"
}

# Run main function with all arguments
main "$@"