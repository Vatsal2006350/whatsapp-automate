# Deployment Guide

## Option 1: DigitalOcean Droplet (Recommended)

### 1. Create a Droplet
- Go to digitalocean.com
- Create a Droplet: Ubuntu 22.04, $6/mo (1GB RAM)
- Add your SSH key

### 2. SSH into your server
```bash
ssh root@your-server-ip
```

### 3. Install dependencies
```bash
# Update system
apt update && apt upgrade -y

# Install Python and pip
apt install -y python3 python3-pip python3-venv git

# Install Playwright dependencies (for Chromium)
apt install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
  libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
  libgbm1 libasound2 libpango-1.0-0 libcairo2
```

### 4. Clone your project
```bash
cd /opt
git clone https://github.com/YOUR_USERNAME/whatsapp-automate.git
cd whatsapp-automate
```

Or copy files with scp:
```bash
# From your local machine:
scp -r /Users/vatsalshah/Desktop/Code/whatsapp-automate root@your-server-ip:/opt/
```

### 5. Set up virtual environment
```bash
cd /opt/whatsapp-automate
python3 -m venv venv
source venv/bin/activate
pip install jaclang flask python-dotenv schedule playwright openai
playwright install chromium
```

### 6. Configure .env
```bash
cp .env.example .env
nano .env
# Add your OPENAI_API_KEY, CHAT_NAME, schedule time, etc.
# Set HEADLESS=true for server
```

### 7. First-time WhatsApp login (need display for QR code)
```bash
# Option A: Use VNC or X forwarding
# Option B: Run once locally, then copy wa-profile/ folder to server

# If using X forwarding:
ssh -X root@your-server-ip
export DISPLAY=:0
source venv/bin/activate
jac run send_now.jac  # Scan QR code, then Ctrl+C after login
```

### 8. Create systemd service
```bash
cat > /etc/systemd/system/whatsapp-daily.service << 'EOF'
[Unit]
Description=WhatsApp Daily Message
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/whatsapp-automate
Environment=PATH=/opt/whatsapp-automate/venv/bin
ExecStart=/opt/whatsapp-automate/venv/bin/jac run app.jac
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 9. Start the service
```bash
systemctl daemon-reload
systemctl enable whatsapp-daily
systemctl start whatsapp-daily

# Check status
systemctl status whatsapp-daily

# View logs
journalctl -u whatsapp-daily -f
```

### 10. (Optional) Set up nginx reverse proxy with SSL
```bash
apt install -y nginx certbot python3-certbot-nginx

# Create nginx config
cat > /etc/nginx/sites-available/whatsapp << 'EOF'
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/whatsapp /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Add SSL (free with Let's Encrypt)
certbot --nginx -d your-domain.com
```

---

## Option 2: Railway/Render (Limited)

These platforms have ephemeral filesystems, so WhatsApp session won't persist.
Not recommended for this use case.

---

## Option 3: Run on Raspberry Pi at Home

Works great! Same steps as VPS but on your Pi.
- Always on, low power
- Use your home network

---

## Important Notes

1. **WhatsApp Session**: The `wa-profile/` folder contains your WhatsApp session.
   - Back it up!
   - First login must be done with a display (to scan QR code)

2. **Headless Mode**: Always set `HEADLESS=true` on server

3. **Security**:
   - Don't expose port 5000 directly to internet
   - Use nginx + SSL
   - Consider adding authentication to the web UI

4. **Monitoring**: Check logs regularly
   ```bash
   journalctl -u whatsapp-daily -f
   ```
