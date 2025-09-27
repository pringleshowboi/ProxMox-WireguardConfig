# Installation Guide

This guide provides detailed instructions for installing the WireGuard Flask Client Generator on various systems.

## 📋 Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+)
- **Architecture**: x86_64, ARM64
- **RAM**: Minimum 512MB, Recommended 1GB+
- **Storage**: 100MB for application, additional space for client configs and logs
- **Network**: Internet access for installation, WireGuard port (default 51820/udp) open

### Required Software

- **WireGuard**: Must be installed and configured with a working `wg0` interface
- **Python**: Version 3.8 or higher
- **Root Access**: Required for WireGuard configuration and system service installation

### Optional Software

- **Nginx**: For reverse proxy (recommended for production)
- **Docker**: For containerized deployment
- **SSL Certificate**: For HTTPS (recommended)

## 🚀 Installation Methods

### Method 1: Automated Installation (Recommended)

The easiest way to install is using the automated installation script:

```bash
# Download the repository
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator

# Run the installation script
sudo ./scripts/install.sh
```

The installation script will:
- ✅ Check system requirements
- ✅ Install system dependencies
- ✅ Create application directories
- ✅ Install Python dependencies
- ✅ Configure system services
- ✅ Set up nginx reverse proxy
- ✅ Configure basic authentication
- ✅ Set up firewall rules

### Method 2: Manual Installation

For more control over the installation process:

#### Step 1: Install System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv wireguard nginx apache2-utils curl git
```

**CentOS/RHEL/Fedora:**
```bash
# For CentOS 8+ / RHEL 8+ / Fedora
sudo dnf install -y python3 python3-pip wireguard nginx httpd-tools curl git

# For older CentOS 7
sudo yum install -y epel-release
sudo yum install -y python3 python3-pip wireguard nginx httpd-tools curl git
```

#### Step 2: Create Virtual Environment (Recommended)

```bash
# Create application directory
sudo mkdir -p /opt/wg-web
cd /opt/wg-web

# Create virtual environment
sudo python3 -m venv venv
sudo chown -R $USER:$USER venv

# Activate virtual environment
source venv/bin/activate
```

#### Step 3: Install Python Dependencies

```bash
# Install from requirements.txt
pip install -r requirements.txt

# Or install individually
pip install flask==2.3.3 pyqrcode==1.2.1 pypng==0.20220715.0 gunicorn==21.2.0
```

#### Step 4: Configure Application

```bash
# Copy configuration files
sudo cp config/app.conf.example /opt/wg-web/config/app.conf
sudo cp config/systemd/wg-web.service /etc/systemd/system/

# Copy nginx configuration
sudo cp config/nginx.conf /etc/nginx/sites-available/wg-web
sudo ln -sf /etc/nginx/sites-available/wg-web /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
```

#### Step 5: Set Permissions

```bash
sudo chown -R root:root /opt/wg-web
sudo chmod 755 /opt/wg-web
sudo chmod +x /opt/wg-web/scripts/*.sh
```

#### Step 6: Configure Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable wg-web
sudo systemctl enable nginx

# Start services
sudo systemctl start wg-web
sudo systemctl start nginx
```

### Method 3: Docker Installation

For containerized deployment:

#### Using Docker Compose (Recommended)

```bash
# Clone repository
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator

# Copy and configure environment
cp config/app.conf.example config/app.conf
nano config/app.conf  # Edit configuration

# Set environment variables
export WG_PUBLIC_ENDPOINT="your.domain.com"
export WG_INTERFACE="wg0"

# Start services
docker-compose up -d
```

#### Using Docker Directly

```bash
# Build image
docker build -t wireguard-flask-generator .

# Run container
docker run -d \
  --name wg-flask-generator \
  --restart unless-stopped \
  -p 5000:5000 \
  -v /etc/wireguard:/etc/wireguard:rw \
  -v $(pwd)/clients:/app/clients \
  -v $(pwd)/logs:/app/logs \
  -e WG_PUBLIC_ENDPOINT="your.domain.com" \
  --privileged \
  --cap-add NET_ADMIN \
  wireguard-flask-generator
```

## ⚙️ Configuration

### Essential Configuration Steps

#### 1. Set Public Endpoint

Edit the main application file or configuration:

```bash
# Method 1: Edit app.py directly
sudo nano /opt/wg-web/app.py

# Find and modify this line:
SERVER_PUBLIC_ENDPOINT = "your.public.ip.or.domain"
```

```bash
# Method 2: Use configuration file
sudo nano /opt/wg-web/config/app.conf

# Set in [server] section:
public_endpoint = your.public.ip.or.domain
```

#### 2. Configure Basic Authentication

```bash
# Create username and password
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Uncomment auth lines in nginx config
sudo nano /etc/nginx/sites-available/wg-web

# Uncomment these lines:
auth_basic "WireGuard Admin Access";
auth_basic_user_file /etc/nginx/.htpasswd;
```

#### 3. Configure Firewall

**Using UFW (Ubuntu/Debian):**
```bash
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 51820/udp   # WireGuard
sudo ufw enable
```

**Using firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --reload
```

### Optional Configuration

#### SSL/HTTPS Setup with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx  # Ubuntu/Debian
# OR
sudo dnf install certbot python3-certbot-nginx  # Fedora/CentOS

# Get certificate
sudo certbot --nginx -d your.domain.com

# Test auto-renewal
sudo certbot renew --dry-run

# Add to crontab for auto-renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

#### Custom DNS Configuration

Edit `/opt/wg-web/app.py` to change default DNS servers:

```python
# In generate_client_config function
DNS = 1.1.1.1, 8.8.8.8        # Cloudflare + Google
# OR
DNS = 9.9.9.9                   # Quad9  
# OR  
DNS = 10.0.0.1                  # Your local DNS server
```

## 🔧 Post-Installation Setup

### 1. Run Setup Script

```bash
# Configure application settings automatically
sudo ./scripts/setup.sh
```

This script will:
- Auto-detect your public IP
- Update application configuration
- Set up log rotation
- Create utility scripts
- Configure monitoring

### 2. Verify Installation

```bash
# Check service status
sudo systemctl status wg-web nginx

# Check application health
curl http://localhost:5000

# Run status check script
wg-web-status
```

### 3. Test Client Generation

1. Open web browser and navigate to your server IP
2. Log in with credentials created during installation
3. Click "Generate New Client Configuration"
4. Verify QR code appears and configuration is valid

## 🔍 Troubleshooting Installation

### Common Issues

#### WireGuard Not Found
```bash
# Check if WireGuard is installed
which wg
systemctl status wg-quick@wg0

# If not installed:
sudo apt install wireguard  # Ubuntu/Debian
sudo dnf install wireguard-tools  # Fedora/CentOS
```

#### Permission Errors
```bash
# Fix ownership and permissions
sudo chown -R root:root /opt/wg-web
sudo chmod 755 /opt/wg-web
sudo chmod +x /opt/wg-web/app.py
```

#### Service Won't Start
```bash
# Check service logs
sudo journalctl -u wg-web -f

# Check application logs
sudo tail -f /opt/wg-web/logs/error.log

# Common fixes:
sudo systemctl daemon-reload
sudo systemctl restart wg-web
```

#### Nginx Configuration Errors
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

#### Python Dependencies Issues
```bash
# Reinstall dependencies
pip3 install --upgrade --force-reinstall -r requirements.txt

# Check Python version
python3 --version  # Should be 3.8+
```

### Port Conflicts

If port 5000 is already in use:

```bash
# Check what's using port 5000
sudo netstat -tlnp | grep :5000
sudo lsof -i :5000

# Change port in configuration
sudo nano /opt/wg-web/app.py
# Modify: app.run(host="127.0.0.1", port=5000)

# Update nginx configuration accordingly
sudo nano /etc/nginx/sites-available/wg-web
# Update: proxy_pass http://127.0.0.1:NEW_PORT;
```

## 📊 Performance Tuning

### For High Client Volume

#### Use Gunicorn (Production WSGI Server)

```bash
# Install gunicorn
pip3 install gunicorn

# Create gunicorn configuration
sudo nano /opt/wg-web/gunicorn.conf.py
```

```python
# gunicorn.conf.py
bind = "127.0.0.1:5000"
workers = 3
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
preload_app = True
```

#### Update systemd service:

```bash
sudo nano /etc/systemd/system/wg-web.service

# Change ExecStart line:
ExecStart=/opt/wg-web/venv/bin/gunicorn --config /opt/wg-web/gunicorn.conf.py app:app
```

#### Database Optimization

For large numbers of clients, consider using a proper database:

```bash
pip3 install sqlite3  # Built into Python
# OR
pip3 install psycopg2-binary  # PostgreSQL
```

## 🔄 Updates and Maintenance

### Updating the Application

```bash
# Using the update script
sudo wg-web-update

# Manual update
cd /path/to/repository
git pull origin main
sudo systemctl restart wg-web
```

### Backup and Restore

```bash
# Create backup
sudo wg-web-backup

# List backups  
sudo wg-web-backup --list

# Restore from backup
sudo wg-web-backup --restore /path/to/backup.tar.gz
```

### Log Maintenance

```bash
# View logs
sudo tail -f /opt/wg-web/logs/app.log

# Rotate logs manually
sudo logrotate /etc/logrotate.d/wg-web

# Clean old logs
sudo find /opt/wg-web/logs -name "*.log" -mtime +30 -delete
```

## 🔐 Security Considerations

### File Permissions

Ensure proper file permissions are set:

```bash
# Application files
sudo chown -R root:root /opt/wg-web
sudo chmod 755 /opt/wg-web
sudo chmod 600 /opt/wg-web/clients.json

# Configuration files
sudo chmod 600 /etc/nginx/.htpasswd
sudo chmod 600 /opt/wg-web/config/app.conf
```

### Network Security

- Use HTTPS in production
- Implement IP-based access restrictions
- Regular security updates
- Monitor access logs
- Use strong passwords for basic auth

### Regular Maintenance

```bash
# Weekly security updates
sudo apt update && sudo apt upgrade  # Ubuntu/Debian
sudo dnf update                       # Fedora/CentOS

# Monthly cleanup
sudo wg-web-cleanup --all

# Quarterly backup verification
sudo wg-web-backup --verify /path/to/recent/backup.tar.gz
```

## 📞 Getting Help

If you encounter issues during installation:

1. **Check the logs**: `/opt/wg-web/logs/app.log` and `journalctl -u wg-web`
2. **Run diagnostics**: `wg-web-status`
3. **Review troubleshooting**: See [troubleshooting.md](troubleshooting.md)
4. **Community support**: [GitHub Issues](https://github.com/yourusername/wireguard-flask-generator/issues)
5. **Documentation**: [Configuration Guide](configuration.md)

---

**Next Steps**: After installation, see [Configuration Guide](configuration.md) for advanced setup options.