#!/usr/bin/env python3
"""
WireGuard Client Generator Flask Application
"""

from flask import Flask, render_template_string, jsonify, send_file
import subprocess
import os
import pyqrcode
import base64
import json
import secrets
import string
from datetime import datetime
import logging
from io import BytesIO

# Configuration - CHANGE THIS TO YOUR PUBLIC IP!
SERVER_PUBLIC_ENDPOINT = "YOUR_SERVER_PUBLIC_IP"  # <<<< CHANGE THIS!

WG_CONF = "/etc/wireguard/wg0.conf"
WG_INTERFACE = "wg0"
WG_LISTEN_PORT = 51820
CLIENT_DB_FILE = "/opt/wg-web/clients.json"
CLIENTS_DIR = "/opt/wg-web/clients"

# Flask app
app = Flask(__name__)
app.secret_key = secrets.token_hex(16)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Ensure directories exist
os.makedirs(CLIENTS_DIR, exist_ok=True)
os.makedirs("/opt/wg-web/logs", exist_ok=True)

def load_client_db():
    """Load client database"""
    if os.path.exists(CLIENT_DB_FILE):
        try:
            with open(CLIENT_DB_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_client_db(db):
    """Save client database"""
    try:
        with open(CLIENT_DB_FILE, 'w') as f:
            json.dump(db, f, indent=2)
    except Exception as e:
        logger.error(f"Error saving client DB: {e}")

def generate_keys():
    """Generate client key pair"""
    try:
        private_key = subprocess.check_output("wg genkey", shell=True).decode().strip()
        public_key = subprocess.check_output(f"echo {private_key} | wg pubkey", shell=True).decode().strip()
        return private_key, public_key
    except Exception as e:
        logger.error(f"Error generating keys: {e}")
        raise Exception("Failed to generate WireGuard keys")

def get_server_public_key():
    """Get server public key"""
    try:
        return subprocess.check_output(["wg", "show", WG_INTERFACE, "public-key"]).decode().strip()
    except Exception as e:
        logger.error(f"Error getting server public key: {e}")
        raise Exception("Failed to get server public key")

def get_used_ips():
    """Get list of IPs currently in use"""
    used_ips = ["10.0.0.1"]  # Server IP
    
    try:
        result = subprocess.run(["wg", "show", WG_INTERFACE, "allowed-ips"], 
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    ip = line.split('/')[0].strip()
                    if ip:
                        used_ips.append(ip)
    except:
        pass
    
    # Check client database
    db = load_client_db()
    for client in db.values():
        used_ips.append(client['ip'])
    
    return list(set(used_ips))

def get_next_ip():
    """Get next available IP"""
    used_ips = get_used_ips()
    
    for i in range(2, 255):
        candidate = f"10.0.0.{i}"
        if candidate not in used_ips:
            return candidate
    
    raise Exception("No available IPs left")

def add_peer_to_server(client_public_key, client_ip):
    """Add client peer to WireGuard server"""
    try:
        # Add peer to running interface
        subprocess.run([
            "wg", "set", WG_INTERFACE, 
            "peer", client_public_key, 
            "allowed-ips", f"{client_ip}/32"
        ], check=True)
        
        # Add to config file
        peer_conf = f"\n[Peer]\nPublicKey = {client_public_key}\nAllowedIPs = {client_ip}/32\n"
        with open(WG_CONF, "a") as f:
            f.write(peer_conf)
        
        logger.info(f"Added peer with IP {client_ip}")
        
    except Exception as e:
        logger.error(f"Error adding peer: {e}")
        raise Exception(f"Failed to add peer: {e}")

def generate_client_config(client_private_key, client_ip, server_public_key):
    """Generate client configuration"""
    return f"""[Interface]
PrivateKey = {client_private_key}
Address = {client_ip}/24
DNS = 1.1.1.1

[Peer]
PublicKey = {server_public_key}
Endpoint = {SERVER_PUBLIC_ENDPOINT}:{WG_LISTEN_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
"""

def generate_client_name():
    """Generate random client name"""
    return ''.join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(8))

@app.route("/")
def index():
    """Main page"""
    return render_template_string('''
<!DOCTYPE html>
<html>
<head>
    <title>WireGuard Client Generator</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .container { background: #f9f9f9; padding: 30px; border-radius: 10px; }
        h1 { color: #333; text-align: center; }
        .btn { padding: 15px 30px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; width: 100%; }
        .btn:hover { background: #0056b3; }
        .btn:disabled { background: #ccc; }
        #result { margin-top: 20px; }
        .config-box { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .qr-container { text-align: center; margin: 20px 0; }
        .error { color: red; background: #ffe6e6; padding: 10px; border-radius: 5px; }
        .success { color: green; background: #e6ffe6; padding: 10px; border-radius: 5px; }
        pre { font-size: 12px; overflow-x: auto; background: #f5f5f5; padding: 10px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 WireGuard Client Generator</h1>
        <p><strong>Instructions:</strong> Click the button below to generate a new WireGuard client configuration. You can scan the QR code with the WireGuard mobile app or download the config file.</p>
        
        <button id="generateBtn" class="btn" onclick="generateClient()">Generate New Client</button>
        
        <div id="result"></div>
    </div>

    <script>
        async function generateClient() {
            const btn = document.getElementById('generateBtn');
            const result = document.getElementById('result');
            
            btn.disabled = true;
            btn.textContent = 'Generating...';
            result.innerHTML = '';
            
            try {
                const response = await fetch('/generate', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    result.innerHTML = `
                        <div class="success">
                            <h3>✅ Success! Client Generated</h3>
                            <p><strong>Client Name:</strong> ${data.client_name}</p>
                            <p><strong>IP Address:</strong> ${data.ip}</p>
                        </div>
                        
                        <div class="qr-container">
                            <h4>📱 Scan with WireGuard App:</h4>
                            <img src="data:image/png;base64,${data.qr_code}" style="border: 1px solid #ccc;">
                        </div>
                        
                        <div class="config-box">
                            <h4>📄 Configuration File:</h4>
                            <pre>${data.config}</pre>
                        </div>
                    `;
                } else {
                    result.innerHTML = `<div class="error">❌ Error: ${data.error}</div>`;
                }
            } catch (error) {
                result.innerHTML = `<div class="error">❌ Network error: ${error.message}</div>`;
            } finally {
                btn.disabled = false;
                btn.textContent = 'Generate New Client';
            }
        }
    </script>
</body>
</html>
    ''')

@app.route("/generate", methods=["POST"])
def generate_client():
    """Generate new client"""
    try:
        # Check if endpoint is configured
        if SERVER_PUBLIC_ENDPOINT == "YOUR_SERVER_PUBLIC_IP":
            return jsonify({
                'success': False, 
                'error': 'Please configure SERVER_PUBLIC_ENDPOINT in the app.py file!'
            })
        
        client_name = generate_client_name()
        client_private, client_public = generate_keys()
        client_ip = get_next_ip()
        server_public_key = get_server_public_key()
        
        add_peer_to_server(client_public, client_ip)
        
        client_config = generate_client_config(client_private, client_ip, server_public_key)
        
        # Save config file
        config_file = os.path.join(CLIENTS_DIR, f"{client_name}.conf")
        with open(config_file, 'w') as f:
            f.write(client_config)
        
        # Generate QR code
        qr = pyqrcode.create(client_config)
        buffer = BytesIO()
        qr.png(buffer, scale=6)
        qr_code_b64 = base64.b64encode(buffer.getvalue()).decode()
        
        # Save to database
        db = load_client_db()
        db[client_name] = {
            'ip': client_ip,
            'public_key': client_public,
            'created': datetime.now().isoformat()
        }
        save_client_db(db)
        
        logger.info(f"Generated client {client_name} with IP {client_ip}")
        
        return jsonify({
            'success': True,
            'client_name': client_name,
            'ip': client_ip,
            'config': client_config,
            'qr_code': qr_code_b64
        })
        
    except Exception as e:
        logger.error(f"Error: {e}")
        return jsonify({'success': False, 'error': str(e)})

if __name__ == "__main__":
    print("Starting WireGuard Client Generator...")
    print(f"Endpoint: {SERVER_PUBLIC_ENDPOINT}")
    if SERVER_PUBLIC_ENDPOINT == "YOUR_SERVER_PUBLIC_IP":
        print("⚠️  WARNING: Please set SERVER_PUBLIC_ENDPOINT in app.py!")
    app.run(host="127.0.0.1", port=5000, debug=False)