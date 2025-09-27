# DISCLAIMER: THIS IS A WORKING-PROGESS APP USING PROXMOX AND WIREGUARD, PLEASE DO NOT USE IF YOU ARE INEXPERIENCED WITH PROXMOX AND OR WIREGUARD
# 🔐 WireGuard Flask Client Generator

A simple, secure web interface for generating WireGuard client configurations with QR codes. Perfect for self-hosted VPN servers, allowing easy client onboarding with mobile device QR code scanning.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Flask](https://img.shields.io/badge/flask-2.3+-green.svg)
![WireGuard](https://img.shields.io/badge/wireguard-compatible-orange.svg)

## ✨ Features

- 🖥️ **Clean Web Interface** - Generate clients with one click
- 📱 **QR Code Generation** - Scan with WireGuard mobile app for instant setup
- 🔒 **Automatic IP Management** - Assigns next available IP in your subnet
- 📊 **Client Management** - View and remove active clients
- 🔐 **Basic Authentication** - Password-protected access
- 🐳 **Docker Support** - Easy containerized deployment
- 📝 **Comprehensive Logging** - Track all client generation activities
- 🔄 **Live WireGuard Integration** - Adds peers to running WireGuard interface
- 🌐 **Nginx Reverse Proxy** - Production-ready web server setup
- 🛡️ **Security Headers** - Built-in security best practices

## 🎯 Use Cases

- **Small Business** - Secure remote access for employees 
- **Development Teams** - Quick VPN access for developers
- **IoT Projects** - Secure device connections
- **Travel Security** - Generate temporary configs for trips

## 🚀 Quick Start

### Option 1: Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator

# Copy and edit configuration
cp config/app.conf.example config/app.conf
nano config/app.conf  # Set your public IP and preferences

# Start with Docker Compose
docker-compose up -d

# Access the interface
open http://localhost
```

### Option 2: Manual Installation

```bash
# Clone and install
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator
chmod +x scripts/install.sh
sudo ./scripts/install.sh

# Configure your public endpoint
sudo nano /opt/wg-web/app.py  # Set SERVER_PUBLIC_ENDPOINT

# Start services
sudo systemctl start wg-web nginx
```

### Option 3: Quick Test Run

```bash
# For testing only - requires existing WireGuard setup
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator
pip3 install -r requirements.txt
python3 app.py
```

## 📖 Documentation

- [📋 Installation Guide](docs/installation.md) - Detailed setup instructions
- [⚙️ Configuration Options](docs/configuration.md) - Customize your deployment
- [🔒 Security Considerations](docs/security.md) - Secure your installation
- [🔌 API Documentation](docs/api.md) - Programmatic access
- [🚨 Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🖼️ Screenshots

### Web Interface
![Web Interface](screenshots/web-interface.png)

### QR Code Generation
![QR Code](screenshots/qr-code.png)

### Mobile App Integration
![Mobile App](screenshots/mobile-app.png)

## 📱 Mobile App Setup

1. Install the official WireGuard app:
   - **Android**: [Google Play Store](https://play.google.com/store/apps/details?id=com.wireguard.android)
   - **iOS**: [App Store](https://apps.apple.com/app/wireguard/id1441195209)

2. Generate a client configuration in the web interface

3. Scan the QR code with the WireGuard app

4. Connect instantly!

## 🔧 Configuration

### Basic Configuration

Edit `config/app.conf`:
```ini
[server]
# Your server's public IP or domain
public_endpoint = YOUR_PUBLIC_IP
interface = wg0
port = 51820
network = 10.0.0.0/24

[flask]
host = 127.0.0.1
port = 5000
debug = false

[security]
basic_auth = true
https_redirect = true
```

### Environment Variables

```bash
export WG_PUBLIC_ENDPOINT="your.domain.com"
export WG_INTERFACE="wg0"
export WG_NETWORK="10.0.0.0/24"
export FLASK_PORT=5000
```

## 🔒 Security Features

- **Password Protection** - Basic authentication for web access
- **IP Validation** - Prevents duplicate IP assignments
- **Secure Headers** - XSS protection, content type validation
- **HTTPS Support** - SSL/TLS encryption ready
- **Input Sanitization** - Validates all user inputs
- **Logging** - Comprehensive audit trail

## 🐳 Docker Deployment

### Docker Compose (Recommended)

```yaml
version: '3.8'
services:
  wireguard-flask:
    build: .
    ports:
      - "80:80"
    volumes:
      - ./config:/app/config
      - /etc/wireguard:/etc/wireguard:ro
    environment:
      - WG_PUBLIC_ENDPOINT=your.domain.com
```

### Standalone Docker

```bash
docker build -t wireguard-flask-generator .
docker run -d \
  -p 80:5000 \
  -v /etc/wireguard:/etc/wireguard:ro \
  -e WG_PUBLIC_ENDPOINT=your.domain.com \
  wireguard-flask-generator
```

## 🛠️ Development

### Local Development

```bash
# Clone and setup
git clone https://github.com/yourusername/wireguard-flask-generator.git
cd wireguard-flask-generator

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run in development mode
export FLASK_ENV=development
python app.py
```

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-cov

# Run tests
pytest tests/

# Run with coverage
pytest --cov=app tests/
```

### Code Quality

```bash
# Lint code
flake8 app.py

# Format code
black app.py

# Type checking
mypy app.py
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-awesome-feature`
3. Make your changes and add tests
4. Commit your changes: `git commit -am 'Add awesome feature'`
5. Push to the branch: `git push origin feature-awesome-feature`
6. Submit a Pull Request

## 📋 Requirements

### System Requirements

- **Linux Server** (Ubuntu 20.04+ recommended)
- **WireGuard** installed and configured
- **Python 3.8+**
- **Root/sudo access** (for WireGuard configuration)

### Python Dependencies

- Flask 2.3+
- pyqrcode 1.2+
- pypng (for QR code PNG generation)

### Optional

- **Nginx** (for reverse proxy)
- **Docker** (for containerized deployment)
- **SSL Certificate** (for HTTPS)

## 🚦 Roadmap

- [ ] **Multi-language Support** - Internationalization
- [ ] **REST API** - Full programmatic access
- [ ] **Client Expiration** - Automatic client cleanup
- [ ] **Bandwidth Limits** - Per-client traffic controls
- [ ] **2FA Authentication** - Enhanced security
- [ ] **Dark Mode** - UI theme options
- [ ] **Client Statistics** - Usage analytics
- [ ] **Backup/Restore** - Configuration management
- [ ] **Multiple WG Interfaces** - Multi-server support
- [ ] **LDAP Integration** - Enterprise authentication

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[WireGuard](https://www.wireguard.com/)** - The amazing VPN protocol that makes this possible
- **[Flask](https://flask.palletsprojects.com/)** - Lightweight and powerful web framework
- **[PyQRCode](https://pythonhosted.org/PyQRCode/)** - Simple QR code generation library
- **[Bootstrap](https://getbootstrap.com/)** - Beautiful, responsive CSS framework

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/wireguard-flask-generator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/wireguard-flask-generator/discussions)
- **Email**: your-email@example.com

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/wireguard-flask-generator&type=Date)](https://star-history.com/#yourusername/wireguard-flask-generator&Date)

---

**Made with ❤️ for the self-hosted community**
