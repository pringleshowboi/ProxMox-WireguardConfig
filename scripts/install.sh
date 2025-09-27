#!/bin/bash

# WireGuard Flask Client Generator Installation Script
# This script installs and configures the WireGuard web interface

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use sudo $0"
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error "Cannot detect operating system"
    fi
    
    log "Detected OS: $OS $VERSION"
}

# Check if WireGuard is installed
check_wireguard() {
    if ! command -v wg &> /dev/null; then
        error "WireGuard is not installed. Please install WireGuard first."
    fi
    
    if ! systemctl is-enabled wg-quick@wg0 &> /dev/null; then
        warn "WireGuard wg0 interface is not enabled. You may need to configure it."
    fi
    
    log "WireGuard installation verified"
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    case $OS in
        ubuntu|debian)
            apt update
            apt install -y python3 python3-pip python3-venv nginx apache2-utils curl wget git
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip nginx httpd-tools curl wget git
            else
                yum install -y python3 python3-pip nginx httpd-tools curl wget git
            fi
            ;;
        *)
            error "Unsupported operating system: $OS"
            ;;
    esac
    
    log "System dependencies installed"
}

# Create application directories
create_directories() {
    log "Creating application directories..."
    
    mkdir -p /opt/wg-web/{clients,logs,config,backups}
    mkdir -p /var/log/wg-web
    
    # Set permissions
    chown -R root:root /opt/wg-web
    chmod 755 /opt/wg-web
    chmod 755 /opt/wg-web/clients
    chmod 755 /opt/wg-web/logs
    
    log "Directories created"
}

# Install Python dependencies
install_python_deps() {
    log "Installing Python dependencies..."
    
    # Install pip if not available
    if ! command -v pip3 &> /dev/null; then
        curl -s https://bootstrap.pypa.io/get-pip.py | python3
    fi
    
    # Install application dependencies
    pip3 install flask pyqrcode pypng gunicorn
    
    log "Python dependencies installed"
}

# Copy application files
copy_files() {
    log "Copying application files..."
    
    # Copy main application
    if [[ -f "app.py" ]]; then
        cp app.py /opt/wg-web/
    else
        error "app.py not found in current directory"
    fi
    
    # Copy configuration files
    if [[ -f "config/systemd/wg-web.service" ]]; then
        cp config/systemd/wg-web.service /etc/systemd/system/
    else
        error "systemd service file not found"
    fi
    
    # Copy nginx configuration
    if [[ -f "config/nginx.conf" ]]; then
        cp config/nginx.conf /etc/nginx/sites-available/wg-web
        ln -sf /etc/nginx/sites-available/wg-web /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    else
        warn "nginx.conf not found, skipping nginx setup"
    fi
    
    # Copy utility scripts
    if [[ -d "scripts" ]]; then
        cp -r scripts/* /opt/wg-web/scripts/ 2>/dev/null || true
        chmod +x /opt/wg-web/scripts/*.sh 2>/dev/null || true
    fi
    
    log "Files copied"
}

# Configure basic authentication
setup_auth() {
    log "Setting up authentication..."
    
    echo
    echo "==================================="
    echo "  Web Interface Authentication"
    echo "==================================="
    echo
    
    read -p "Enter username for web interface: " USERNAME
    if [[ -z "$USERNAME" ]]; then
        USERNAME="admin"
        log "Using default username: admin"
    fi
    
    if command -v htpasswd &> /dev/null; then
        htpasswd -c /etc/nginx/.htpasswd "$USERNAME"
    else
        warn "htpasswd not available, skipping basic auth setup"
    fi
    
    log "Authentication configured"
}

# Configure firewall
setup_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw --force enable
        ufw allow 22/tcp comment "SSH"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        ufw allow 51820/udp comment "WireGuard"
        log "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=51820/udp
        firewall-cmd --reload
        log "Firewalld configured"
    else
        warn "No firewall detected, please configure manually"
    fi
}

# Enable and start services
start_services() {
    log "Starting services..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable wg-web
    systemctl enable nginx
    
    # Test nginx configuration
    if nginx -t; then
        systemctl restart nginx
        log "Nginx started successfully"
    else
        error "Nginx configuration test failed"
    fi
    
    # Start WireGuard web service
    systemctl start wg-web
    
    # Check service status
    if systemctl is-active --quiet wg-web; then
        log "WireGuard web service started successfully"
    else
        error "Failed to start WireGuard web service"
    fi
    
    log "Services started"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > /usr/local/bin/wg-web-backup << 'EOF'
#!/bin/bash
# WireGuard Web Backup Script

BACKUP_DIR="/opt/wg-web/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="wg-web-backup-${DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_FILE"

tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
    --exclude='/opt/wg-web/logs/*.log' \
    --exclude='/opt/wg-web/backups' \
    /opt/wg-web/ \
    /etc/wireguard/wg0.conf \
    /etc/systemd/system/wg-web.service \
    /etc/nginx/sites-available/wg-web \
    /etc/nginx/.htpasswd 2>/dev/null

echo "Backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "wg-web-backup-*.tar.gz" -mtime +7 -delete
echo "Old backups cleaned up"
EOF

    chmod +x /usr/local/bin/wg-web-backup
    log "Backup script created at /usr/local/bin/wg-web-backup"
}

# Get server IP
get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "UNKNOWN")
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    echo
    echo "=================================="
    echo "     Server Information"
    echo "=================================="
    echo "Public IP: $SERVER_IP"
    echo "Local IP:  $LOCAL_IP"
    echo "=================================="
    echo
}

# Main installation function
main() {
    echo
    echo "========================================"
    echo "  WireGuard Flask Generator Installer"
    echo "========================================"
    echo
    
    check_root
    detect_os
    check_wireguard
    install_dependencies
    create_directories
    install_python_deps
    copy_files
    setup_auth
    setup_firewall
    start_services
    create_backup_script
    get_server_ip
    
    echo
    echo "=========================================="
    echo "         Installation Complete!"
    echo "=========================================="
    echo
    echo "🎉 WireGuard Flask Client Generator is now installed!"
    echo
    echo "📋 Next Steps:"
    echo "1. Edit /opt/wg-web/app.py and set SERVER_PUBLIC_ENDPOINT to: $SERVER_IP"
    echo "2. Restart the service: systemctl restart wg-web"
    echo "3. Access the web interface: http://$LOCAL_IP"
    echo
    echo "🔧 Management Commands:"
    echo "- Check status: systemctl status wg-web nginx"
    echo "- View logs: tail -f /opt/wg-web/logs/app.log"
    echo "- Create backup: wg-web-backup"
    echo
    echo "📖 Documentation:"
    echo "- Configuration: /opt/wg-web/config/"
    echo "- Logs: /opt/wg-web/logs/"
    echo "- Client configs: /opt/wg-web/clients/"
    echo
    echo "🔐 Security:"
    echo "- Web interface protected with basic auth"
    echo "- Firewall configured for required ports"
    echo "- Consider enabling HTTPS with Let's Encrypt"
    echo
    echo "❤️  Enjoy your new WireGuard client generator!"
}

# Run main function
main "$@"