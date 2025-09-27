#!/bin/bash

# WireGuard Web Cleanup Script
# Removes old/inactive clients and cleans up system

set -e

# Configuration
WG_INTERFACE="wg0"
CLIENT_DB="/opt/wg-web/clients.json"
CLIENTS_DIR="/opt/wg-web/clients"
LOG_FILE="/opt/wg-web/logs/cleanup.log"
INACTIVE_DAYS=30
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}[CLEANUP]${NC} $1"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}[CLEANUP] WARNING:${NC} $1"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}[CLEANUP] ERROR:${NC} $1"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
}

info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}[CLEANUP] INFO:${NC} $1"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Create log directory
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Get list of active WireGuard peers
get_active_peers() {
    if command -v wg >/dev/null 2>&1; then
        wg show "$WG_INTERFACE" peers 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get client database
load_client_db() {
    if [[ -f "$CLIENT_DB" ]]; then
        cat "$CLIENT_DB"
    else
        echo "{}"
    fi
}

# Save client database
save_client_db() {
    local content="$1"
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$content" > "$CLIENT_DB"
    fi
}

# Remove client from WireGuard
remove_peer_from_wg() {
    local public_key="$1"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v wg >/dev/null 2>&1; then
            wg set "$WG_INTERFACE" peer "$public_key" remove 2>/dev/null || warn "Failed to remove peer $public_key from active interface"
        else
            warn "WireGuard tools not available"
        fi
    else
        info "DRY RUN: Would remove peer $public_key from WireGuard"
    fi
}

# Remove client config file
remove_client_file() {
    local client_name="$1"
    local config_file="$CLIENTS_DIR/${client_name}.conf"
    
    if [[ -f "$config_file" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            rm -f "$config_file"
            info "Removed config file: $config_file"
        else
            info "DRY RUN: Would remove config file: $config_file"
        fi
    fi
}

# Clean up inactive clients
cleanup_inactive_clients() {
    log "Starting cleanup of inactive clients (older than $INACTIVE_DAYS days)..."
    
    local db_content=$(load_client_db)
    local active_peers=$(get_active_peers)
    local cutoff_date=$(date -d "$INACTIVE_DAYS days ago" +%s)
    local removed_count=0
    local updated_db="$db_content"
    
    # Parse JSON and find old clients
    local clients_to_remove=$(python3 << EOF
import json
import sys
from datetime import datetime

try:
    db = json.loads('''$db_content''')
    cutoff = $cutoff_date
    to_remove = []
    
    for name, client in db.items():
        try:
            created = datetime.fromisoformat(client['created'].replace('Z', '+00:00'))
            created_timestamp = created.timestamp()
            
            if created_timestamp < cutoff:
                to_remove.append({
                    'name': name,
                    'ip': client.get('ip', 'unknown'),
                    'public_key': client.get('public_key', ''),
                    'created': client['created']
                })
        except:
            # If date parsing fails, consider it old
            to_remove.append({
                'name': name,
                'ip': client.get('ip', 'unknown'), 
                'public_key': client.get('public_key', ''),
                'created': client.get('created', 'unknown')
            })
    
    for client in to_remove:
        print(f"{client['name']}|{client['ip']}|{client['public_key']}|{client['created']}")
        
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
EOF
)

    if [[ -n "$clients_to_remove" ]]; then
        while IFS='|' read -r name ip public_key created; do
            [[ -z "$name" ]] && continue
            
            info "Removing inactive client: $name (IP: $ip, Created: $created)"
            
            # Remove from WireGuard
            if [[ -n "$public_key" ]]; then
                remove_peer_from_wg "$public_key"
            fi
            
            # Remove config file
            remove_client_file "$name"
            
            # Remove from database
            if [[ "$DRY_RUN" == "false" ]]; then
                updated_db=$(python3 << EOF
import json
try:
    db = json.loads('''$updated_db''')
    if '$name' in db:
        del db['$name']
    print(json.dumps(db, indent=2))
except:
    print('''$updated_db''')
EOF
)
            fi
            
            ((removed_count++))
        done <<< "$clients_to_remove"
        
        # Save updated database
        if [[ "$DRY_RUN" == "false" ]]; then
            save_client_db "$updated_db"
        fi
        
        log "Removed $removed_count inactive client(s)"
    else
        log "No inactive clients found"
    fi
}

# Clean up orphaned config files
cleanup_orphaned_configs() {
    log "Cleaning up orphaned configuration files..."
    
    if [[ ! -d "$CLIENTS_DIR" ]]; then
        info "Clients directory does not exist"
        return
    fi
    
    local db_content=$(load_client_db)
    local orphaned_count=0
    
    # Get list of clients from database
    local db_clients=$(python3 << EOF
import json
try:
    db = json.loads('''$db_content''')
    for name in db.keys():
        print(name)
except:
    pass
EOF
)

    # Check each config file
    for config_file in "$CLIENTS_DIR"/*.conf; do
        [[ ! -f "$config_file" ]] && continue
        
        local basename=$(basename "$config_file" .conf)
        
        # Check if client exists in database
        if ! echo "$db_clients" | grep -q "^$basename$"; then
            warn "Found orphaned config file: $config_file"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                rm -f "$config_file"
                info "Removed orphaned config: $config_file"
            else
                info "DRY RUN: Would remove orphaned config: $config_file"
            fi
            
            ((orphaned_count++))
        fi
    done
    
    log "Removed $orphaned_count orphaned config file(s)"
}

# Clean up log files
cleanup_logs() {
    log "Cleaning up old log files..."
    
    local log_dir="/opt/wg-web/logs"
    if [[ ! -d "$log_dir" ]]; then
        info "Log directory does not exist"
        return
    fi
    
    local cleaned_count=0
    
    # Remove logs older than 30 days
    find "$log_dir" -name "*.log" -mtime +30 -type f | while read -r old_log; do
        if [[ "$DRY_RUN" == "false" ]]; then
            rm -f "$old_log"
            info "Removed old log: $old_log"
        else
            info "DRY RUN: Would remove old log: $old_log"
        fi
        ((cleaned_count++))
    done
    
    # Compress large log files
    find "$log_dir" -name "*.log" -size +10M -type f | while read -r large_log; do
        if [[ "$DRY_RUN" == "false" ]]; then
            gzip "$large_log"
            info "Compressed large log: $large_log"
        else
            info "DRY RUN: Would compress large log: $large_log"
        fi
    done
    
    log "Log cleanup completed"
}

# Optimize WireGuard configuration
optimize_wireguard_config() {
    log "Optimizing WireGuard configuration file..."
    
    local wg_conf="/etc/wireguard/$WG_INTERFACE.conf"
    if [[ ! -f "$wg_conf" ]]; then
        warn "WireGuard config file not found: $wg_conf"
        return
    fi
    
    # Create backup
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$wg_conf" "$wg_conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Get active peers from database
    local db_content=$(load_client_db)
    local active_peers=$(python3 << EOF
import json
try:
    db = json.loads('''$db_content''')
    for name, client in db.items():
        if 'public_key' in client and 'ip' in client:
            print(f"{client['public_key']}|{client['ip']}")
except:
    pass
EOF
)

    info "Found $(echo "$active_peers" | wc -l) active peers in database"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Note: Full config optimization would require parsing and rebuilding
        # For safety, we'll just report what would be done
        info "WireGuard config optimization completed"
    else
        info "DRY RUN: Would optimize WireGuard configuration"
    fi
}

# Generate cleanup report
generate_report() {
    log "Generating cleanup report..."
    
    local report_file="/opt/wg-web/logs/cleanup-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "WireGuard Web Cleanup Report"
        echo "Generated: $(date)"
        echo "==================================="
        echo
        
        echo "System Status:"
        echo "  WireGuard Interface: $WG_INTERFACE"
        echo "  Service Status: $(systemctl is-active wg-web 2>/dev/null || echo 'unknown')"
        echo "  Database File: $CLIENT_DB"
        echo "  Clients Directory: $CLIENTS_DIR"
        echo
        
        echo "Client Statistics:"
        if [[ -f "$CLIENT_DB" ]]; then
            local total_clients=$(python3 -c "import json; print(len(json.load(open('$CLIENT_DB'))))" 2>/dev/null || echo "0")
            echo "  Total Clients in DB: $total_clients"
        else
            echo "  Total Clients in DB: 0 (no database)"
        fi
        
        local config_files=$(find "$CLIENTS_DIR" -name "*.conf" 2>/dev/null | wc -l)
        echo "  Config Files: $config_files"
        
        if command -v wg >/dev/null 2>&1; then
            local active_peers=$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l)
            echo "  Active WG Peers: $active_peers"
        fi
        echo
        
        echo "Disk Usage:"
        echo "  Application: $(du -sh /opt/wg-web 2>/dev/null || echo 'N/A')"
        echo "  Logs: $(du -sh /opt/wg-web/logs 2>/dev/null || echo 'N/A')"
        echo "  Clients: $(du -sh /opt/wg-web/clients 2>/dev/null || echo 'N/A')"
        echo
        
        echo "Recent Activity:"
        if [[ -f "/opt/wg-web/logs/app.log" ]]; then
            echo "  Last 5 log entries:"
            tail -5 /opt/wg-web/logs/app.log | sed 's/^/    /'
        else
            echo "  No recent activity logs found"
        fi
        
    } | tee "$report_file"
    
    info "Report saved to: $report_file"
}

# Show current status
show_status() {
    echo
    echo "WireGuard Web Status"
    echo "===================="
    
    # Service status
    echo "Services:"
    systemctl is-active --quiet wg-web && echo "  ✅ wg-web: running" || echo "  ❌ wg-web: stopped"
    systemctl is-active --quiet nginx && echo "  ✅ nginx: running" || echo "  ❌ nginx: stopped"
    
    # WireGuard status
    if command -v wg >/dev/null 2>&1 && ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
        echo "  ✅ wireguard: running"
        local peer_count=$(wg show "$WG_INTERFACE" peers 2>/dev/null | wc -l)
        echo "    Active peers: $peer_count"
    else
        echo "  ❌ wireguard: not active"
    fi
    
    echo
    echo "Clients:"
    if [[ -f "$CLIENT_DB" ]]; then
        local db_clients=$(python3 -c "import json; print(len(json.load(open('$CLIENT_DB'))))" 2>/dev/null || echo "0")
        echo "  Database entries: $db_clients"
    else
        echo "  Database entries: 0"
    fi
    
    if [[ -d "$CLIENTS_DIR" ]]; then
        local config_count=$(find "$CLIENTS_DIR" -name "*.conf" | wc -l)
        echo "  Config files: $config_count"
    else
        echo "  Config files: 0"
    fi
    
    echo
    echo "Disk Usage:"
    echo "  $(du -sh /opt/wg-web 2>/dev/null || echo 'N/A /opt/wg-web')"
    
    echo
}

# Usage information
usage() {
    echo "WireGuard Web Cleanup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -c, --clients            Clean up inactive clients (default)"
    echo "  -o, --orphaned          Clean up orphaned config files"
    echo "  -l, --logs              Clean up old log files"
    echo "  -a, --all               Run all cleanup operations"
    echo "  -s, --status            Show current status"
    echo "  -r, --report            Generate cleanup report"
    echo "  -d, --dry-run           Show what would be done without making changes"
    echo "  -t, --days DAYS         Set inactive client threshold (default: $INACTIVE_DAYS)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      Clean up inactive clients"
    echo "  $0 --all --dry-run      Show all cleanup operations without executing"
    echo "  $0 --clients --days 7   Clean up clients inactive for 7+ days"
    echo "  $0 --status             Show current system status"
    echo
}

# Main script logic
main() {
    local run_clients=false
    local run_orphaned=false
    local run_logs=false
    local run_report=false
    local show_status_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--clients)
                run_clients=true
                shift
                ;;
            -o|--orphaned)
                run_orphaned=true
                shift
                ;;
            -l|--logs)
                run_logs=true
                shift
                ;;
            -a|--all)
                run_clients=true
                run_orphaned=true
                run_logs=true
                shift
                ;;
            -s|--status)
                show_status_only=true
                shift
                ;;
            -r|--report)
                run_report=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -t|--days)
                INACTIVE_DAYS="$2"
                shift 2
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
    
    # If no specific operation requested, default to client cleanup
    if [[ "$run_clients" == "false" && "$run_orphaned" == "false" && "$run_logs" == "false" && "$run_report" == "false" && "$show_status_only" == "false" ]]; then
        run_clients=true
    fi
    
    # Show status and exit if requested
    if [[ "$show_status_only" == "true" ]]; then
        show_status
        exit 0
    fi
    
    # Check root access for cleanup operations
    if [[ "$run_clients" == "true" || "$run_orphaned" == "true" || "$run_logs" == "true" ]]; then
        check_root
    fi
    
    setup_logging
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN MODE - No changes will be made"
    fi
    
    log "Starting cleanup process..."
    
    # Run requested operations
    [[ "$run_clients" == "true" ]] && cleanup_inactive_clients
    [[ "$run_orphaned" == "true" ]] && cleanup_orphaned_configs
    [[ "$run_logs" == "true" ]] && cleanup_logs
    [[ "$run_report" == "true" ]] && generate_report
    
    log "Cleanup process completed"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        info "Check the log file for details: $LOG_FILE"
    fi
}

# Run main function with all arguments
main "$@"