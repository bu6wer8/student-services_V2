# 🚀 Complete VPS Deployment Guide
## Student Services Platform - Production Deployment

This comprehensive guide will take you from a fresh VPS to a fully deployed, secure, and monitored Student Services Platform with domain, SSL, and all production features.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Domain Setup](#domain-setup)
3. [VPS Initial Setup](#vps-initial-setup)
4. [Security Hardening](#security-hardening)
5. [Database Setup](#database-setup)
6. [Application Deployment](#application-deployment)
7. [Nginx Configuration](#nginx-configuration)
8. [SSL Certificate Setup](#ssl-certificate-setup)
9. [Systemd Services](#systemd-services)
10. [Monitoring & Logging](#monitoring--logging)
11. [Backup Strategy](#backup-strategy)
12. [Maintenance & Updates](#maintenance--updates)
13. [Troubleshooting](#troubleshooting)

---

## 🔧 Prerequisites

### What You Need:
- **VPS**: Ubuntu 22.04 LTS (2GB RAM minimum, 4GB recommended)
- **Domain**: Purchased domain name (e.g., yourdomain.com)
- **GitHub**: Repository with your Student Services Platform code
- **Basic Knowledge**: Command line basics

### Recommended VPS Providers:
- **DigitalOcean**: $12/month droplet
- **Vultr**: $12/month instance
- **Linode**: $12/month nanode
- **Hetzner**: €4.51/month CX21

---

## 🌐 Domain Setup

### Step 1: Purchase Domain
Choose a domain registrar:
- **Namecheap** (recommended)
- **GoDaddy**
- **Cloudflare Registrar**
- **Google Domains**

### Step 2: Configure DNS
Point your domain to your VPS IP address:

```bash
# DNS Records to add:
A     @              YOUR_VPS_IP
A     www            YOUR_VPS_IP
AAAA  @              YOUR_VPS_IPv6 (if available)
AAAA  www            YOUR_VPS_IPv6 (if available)
```

### Step 3: Cloudflare Setup (Recommended)
1. **Sign up** for Cloudflare (free plan)
2. **Add your domain** to Cloudflare
3. **Update nameservers** at your registrar
4. **Configure DNS** in Cloudflare dashboard
5. **Enable proxy** (orange cloud) for web traffic

**Benefits of Cloudflare:**
- Free SSL certificate
- DDoS protection
- CDN acceleration
- Analytics

---

## 🖥️ VPS Initial Setup

### Step 1: Connect to VPS
```bash
# SSH into your VPS
ssh root@YOUR_VPS_IP

# Or if you have a user account
ssh username@YOUR_VPS_IP
```

### Step 2: Update System
```bash
# Update package lists
apt update

# Upgrade all packages
apt upgrade -y

# Install essential packages
apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
```

### Step 3: Create Application User
```bash
# Create a dedicated user for the application
adduser student-services

# Add user to sudo group
usermod -aG sudo student-services

# Switch to the new user
su - student-services
```

### Step 4: Setup SSH Key Authentication
```bash
# On your local machine, generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to VPS
ssh-copy-id student-services@YOUR_VPS_IP

# Test SSH key login
ssh student-services@YOUR_VPS_IP
```

---

## 🛡️ Security Hardening

### Step 1: Configure Firewall
```bash
# Install UFW (Uncomplicated Firewall)
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change 22 to your custom port if needed)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Step 2: Secure SSH
```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Make these changes:
Port 2222                    # Change from default 22
PermitRootLogin no          # Disable root login
PasswordAuthentication no   # Disable password auth
PubkeyAuthentication yes    # Enable key auth
MaxAuthTries 3              # Limit auth attempts
ClientAliveInterval 300     # Keep connections alive
ClientAliveCountMax 2       # Max missed heartbeats

# Restart SSH service
sudo systemctl restart sshd

# Update firewall for new SSH port
sudo ufw delete allow 22/tcp
sudo ufw allow 2222/tcp
```

### Step 3: Install Fail2Ban
```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Create custom configuration
sudo nano /etc/fail2ban/jail.local

# Add this content:
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

# Start and enable Fail2Ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban
```

### Step 4: Setup Automatic Updates
```bash
# Install unattended upgrades
sudo apt install -y unattended-upgrades

# Configure automatic updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Edit configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Enable security updates
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

# Enable automatic reboot if required
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

---

## 🗄️ Database Setup

### Step 1: Install PostgreSQL
```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check status
sudo systemctl status postgresql
```

### Step 2: Configure PostgreSQL
```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE student_services;
CREATE USER student_services_user WITH ENCRYPTED PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE student_services TO student_services_user;
ALTER USER student_services_user CREATEDB;

# Exit PostgreSQL
\q
```

### Step 3: Secure PostgreSQL
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/14/main/postgresql.conf

# Find and modify these lines:
listen_addresses = 'localhost'
port = 5432
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB

# Edit authentication configuration
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Ensure these lines exist:
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Step 4: Install Redis (Optional - for caching)
```bash
# Install Redis
sudo apt install -y redis-server

# Configure Redis
sudo nano /etc/redis/redis.conf

# Find and modify:
bind 127.0.0.1
port 6379
requirepass your_redis_password_here
maxmemory 256mb
maxmemory-policy allkeys-lru

# Restart Redis
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

---

## 🚀 Application Deployment

### Step 1: Install Python and Dependencies
```bash
# Install Python 3.11
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip

# Install system dependencies
sudo apt install -y build-essential libpq-dev libssl-dev libffi-dev

# Create Python symlink
sudo ln -sf /usr/bin/python3.11 /usr/bin/python3
```

### Step 2: Clone Repository
```bash
# Navigate to home directory
cd /home/student-services

# Clone your repository
git clone https://github.com/yourusername/student-services-secure.git

# Navigate to project directory
cd student-services-secure

# Set proper permissions
sudo chown -R student-services:student-services /home/student-services/student-services-secure
```

### Step 3: Setup Python Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install requirements
pip install -r requirements.txt

# Install additional production packages
pip install gunicorn supervisor
```

### Step 4: Configure Environment
```bash
# Create production environment file
cp .env.example .env

# Edit environment configuration
nano .env

# Add your production settings:
ENV=production
DEBUG=False
APP_URL=https://yourdomain.com

# Database
DATABASE_URL=postgresql://student_services_user:your_secure_password_here@localhost:5432/student_services
REDIS_URL=redis://:your_redis_password_here@localhost:6379

# API Configuration
API_HOST=127.0.0.1
API_PORT=8000
SECRET_KEY=your-super-secret-key-32-characters-minimum

# Telegram Bot
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ADMIN_ID=your_telegram_user_id

# Stripe
STRIPE_PUBLIC_KEY=pk_live_your_stripe_public_key
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Step 5: Initialize Database
```bash
# Create admin user
python scripts/create_admin_simple.py

# Initialize database
python scripts/init_db.py

# Test the application
python app/api/main.py
```

---

## 🌐 Nginx Configuration

### Step 1: Install Nginx
```bash
# Install Nginx
sudo apt install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

### Step 2: Create Nginx Configuration
```bash
# Create site configuration
sudo nano /etc/nginx/sites-available/student-services

# Add this configuration:
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Hide Nginx version
    server_tokens off;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    # Static files
    location /static/ {
        alias /home/student-services/student-services-secure/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Admin login rate limiting
    location /admin/login {
        limit_req zone=login burst=3 nodelay;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:8000;
    }
}

# Enable the site
sudo ln -s /etc/nginx/sites-available/student-services /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### Step 3: Configure Nginx Security
```bash
# Edit main Nginx configuration
sudo nano /etc/nginx/nginx.conf

# Add these settings in the http block:
http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Security
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate limiting
    limit_req_status 429;
    limit_conn_status 429;
    
    # File upload limits
    client_max_body_size 10M;
    
    # Include sites
    include /etc/nginx/sites-enabled/*;
}

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🔒 SSL Certificate Setup

### Step 1: Install Certbot
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Or install via snap (alternative)
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

### Step 2: Obtain SSL Certificate
```bash
# Get SSL certificate for your domain
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Follow the prompts:
# 1. Enter email address
# 2. Agree to terms
# 3. Choose whether to share email with EFF
# 4. Select redirect option (recommended: 2)
```

### Step 3: Test SSL Configuration
```bash
# Test SSL certificate
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Check SSL rating at: https://www.ssllabs.com/ssltest/
```

### Step 4: Setup Auto-Renewal
```bash
# Create renewal script
sudo nano /etc/cron.d/certbot

# Add this content:
0 12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew --nginx

# Or use systemd timer (alternative)
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## ⚙️ Systemd Services

### Step 1: Create Web Application Service
```bash
# Create systemd service file
sudo nano /etc/systemd/system/student-services-web.service

# Add this content:
[Unit]
Description=Student Services Web Application
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service

[Service]
Type=exec
User=student-services
Group=student-services
WorkingDirectory=/home/student-services/student-services-secure
Environment=PATH=/home/student-services/student-services-secure/venv/bin
ExecStart=/home/student-services/student-services-secure/venv/bin/gunicorn app.api.main:app --bind 127.0.0.1:8000 --workers 4 --worker-class uvicorn.workers.UvicornWorker --timeout 120 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=student-services-web

[Install]
WantedBy=multi-user.target
```

### Step 2: Create Telegram Bot Service
```bash
# Create bot service file
sudo nano /etc/systemd/system/student-services-bot.service

# Add this content:
[Unit]
Description=Student Services Telegram Bot
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=exec
User=student-services
Group=student-services
WorkingDirectory=/home/student-services/student-services-secure
Environment=PATH=/home/student-services/student-services-secure/venv/bin
ExecStart=/home/student-services/student-services-secure/venv/bin/python app/bot/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=student-services-bot

[Install]
WantedBy=multi-user.target
```

### Step 3: Enable and Start Services
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable student-services-web
sudo systemctl enable student-services-bot

# Start services
sudo systemctl start student-services-web
sudo systemctl start student-services-bot

# Check status
sudo systemctl status student-services-web
sudo systemctl status student-services-bot

# View logs
sudo journalctl -u student-services-web -f
sudo journalctl -u student-services-bot -f
```

---

## 📊 Monitoring & Logging

### Step 1: Setup Log Rotation
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/student-services

# Add this content:
/home/student-services/student-services-secure/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 student-services student-services
    postrotate
        systemctl reload student-services-web
        systemctl reload student-services-bot
    endscript
}

# Test logrotate
sudo logrotate -d /etc/logrotate.d/student-services
```

### Step 2: Install Monitoring Tools
```bash
# Install htop for system monitoring
sudo apt install -y htop iotop nethogs

# Install log analysis tools
sudo apt install -y goaccess

# Create log analysis script
nano /home/student-services/scripts/analyze-logs.sh

#!/bin/bash
# Analyze Nginx logs
goaccess /var/log/nginx/access.log -o /home/student-services/student-services-secure/static/reports/access-report.html --log-format=COMBINED --real-time-html

chmod +x /home/student-services/scripts/analyze-logs.sh
```

### Step 3: Setup Health Monitoring
```bash
# Create health check script
nano /home/student-services/scripts/health-check.sh

#!/bin/bash
# Health check script

# Check web service
if ! systemctl is-active --quiet student-services-web; then
    echo "Web service is down, restarting..."
    sudo systemctl restart student-services-web
    echo "Web service restarted at $(date)" >> /home/student-services/logs/health-check.log
fi

# Check bot service
if ! systemctl is-active --quiet student-services-bot; then
    echo "Bot service is down, restarting..."
    sudo systemctl restart student-services-bot
    echo "Bot service restarted at $(date)" >> /home/student-services/logs/health-check.log
fi

# Check database connection
if ! pg_isready -h localhost -p 5432 -U student_services_user; then
    echo "Database connection failed at $(date)" >> /home/student-services/logs/health-check.log
fi

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "Disk usage is ${DISK_USAGE}% at $(date)" >> /home/student-services/logs/health-check.log
fi

chmod +x /home/student-services/scripts/health-check.sh

# Add to crontab
crontab -e

# Add this line:
*/5 * * * * /home/student-services/scripts/health-check.sh
```

### Step 4: Setup Email Alerts (Optional)
```bash
# Install mail utilities
sudo apt install -y mailutils

# Configure postfix for sending emails
sudo dpkg-reconfigure postfix

# Create alert script
nano /home/student-services/scripts/send-alert.sh

#!/bin/bash
# Send email alert

SUBJECT="$1"
MESSAGE="$2"
EMAIL="your-email@example.com"

echo "$MESSAGE" | mail -s "$SUBJECT" "$EMAIL"

chmod +x /home/student-services/scripts/send-alert.sh
```

---

## 💾 Backup Strategy

### Step 1: Database Backup
```bash
# Create database backup script
nano /home/student-services/scripts/backup-database.sh

#!/bin/bash
# Database backup script

BACKUP_DIR="/home/student-services/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="student_services"
DB_USER="student_services_user"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create database backup
pg_dump -h localhost -U $DB_USER -d $DB_NAME > $BACKUP_DIR/backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/backup_$DATE.sql

# Remove backups older than 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

echo "Database backup completed: backup_$DATE.sql.gz"

chmod +x /home/student-services/scripts/backup-database.sh
```

### Step 2: Application Backup
```bash
# Create application backup script
nano /home/student-services/scripts/backup-application.sh

#!/bin/bash
# Application backup script

BACKUP_DIR="/home/student-services/backups/application"
DATE=$(date +%Y%m%d_%H%M%S)
APP_DIR="/home/student-services/student-services-secure"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create application backup (excluding venv and logs)
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz \
    --exclude='venv' \
    --exclude='logs' \
    --exclude='__pycache__' \
    --exclude='.git' \
    -C /home/student-services student-services-secure

# Remove backups older than 7 days
find $BACKUP_DIR -name "app_backup_*.tar.gz" -mtime +7 -delete

echo "Application backup completed: app_backup_$DATE.tar.gz"

chmod +x /home/student-services/scripts/backup-application.sh
```

### Step 3: Automated Backup Schedule
```bash
# Add backup jobs to crontab
crontab -e

# Add these lines:
# Database backup every 6 hours
0 */6 * * * /home/student-services/scripts/backup-database.sh

# Application backup daily at 2 AM
0 2 * * * /home/student-services/scripts/backup-application.sh

# Weekly full system backup
0 3 * * 0 /home/student-services/scripts/backup-full.sh
```

### Step 4: Remote Backup (Optional)
```bash
# Install rclone for cloud backup
curl https://rclone.org/install.sh | sudo bash

# Configure rclone (follow prompts)
rclone config

# Create remote backup script
nano /home/student-services/scripts/backup-remote.sh

#!/bin/bash
# Remote backup script

LOCAL_BACKUP_DIR="/home/student-services/backups"
REMOTE_NAME="your-cloud-storage"  # Name from rclone config
REMOTE_PATH="student-services-backups"

# Sync backups to cloud storage
rclone sync $LOCAL_BACKUP_DIR $REMOTE_NAME:$REMOTE_PATH

echo "Remote backup completed at $(date)"

chmod +x /home/student-services/scripts/backup-remote.sh
```

---

## 🔄 Maintenance & Updates

### Step 1: Update Script
```bash
# Create update script
nano /home/student-services/scripts/update-application.sh

#!/bin/bash
# Application update script

APP_DIR="/home/student-services/student-services-secure"
cd $APP_DIR

echo "Starting application update..."

# Backup current version
./scripts/backup-application.sh

# Pull latest changes
git pull origin main

# Activate virtual environment
source venv/bin/activate

# Update dependencies
pip install -r requirements.txt

# Run database migrations (if any)
python scripts/migrate.py

# Restart services
sudo systemctl restart student-services-web
sudo systemctl restart student-services-bot

# Check service status
sleep 5
sudo systemctl status student-services-web
sudo systemctl status student-services-bot

echo "Application update completed!"

chmod +x /home/student-services/scripts/update-application.sh
```

### Step 2: System Maintenance
```bash
# Create maintenance script
nano /home/student-services/scripts/maintenance.sh

#!/bin/bash
# System maintenance script

echo "Starting system maintenance..."

# Update system packages
sudo apt update
sudo apt upgrade -y

# Clean package cache
sudo apt autoremove -y
sudo apt autoclean

# Clean logs older than 30 days
sudo journalctl --vacuum-time=30d

# Clean temporary files
sudo find /tmp -type f -atime +7 -delete

# Update SSL certificates
sudo certbot renew --quiet

# Restart services if needed
if [ -f /var/run/reboot-required ]; then
    echo "System reboot required"
    # Uncomment the next line to auto-reboot
    # sudo reboot
fi

echo "System maintenance completed!"

chmod +x /home/student-services/scripts/maintenance.sh

# Schedule monthly maintenance
crontab -e

# Add this line:
0 4 1 * * /home/student-services/scripts/maintenance.sh
```

---

## 🆘 Troubleshooting

### Common Issues and Solutions

#### 1. Application Won't Start
```bash
# Check service status
sudo systemctl status student-services-web

# Check logs
sudo journalctl -u student-services-web -n 50

# Check Python environment
source /home/student-services/student-services-secure/venv/bin/activate
python -c "import app.api.main"

# Check database connection
psql -h localhost -U student_services_user -d student_services
```

#### 2. SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Test certificate renewal
sudo certbot renew --dry-run

# Check Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

#### 3. Database Connection Problems
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database connectivity
pg_isready -h localhost -p 5432

# Check database logs
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Reset database connection
sudo systemctl restart postgresql
```

#### 4. High Memory Usage
```bash
# Check memory usage
free -h
htop

# Check application memory
ps aux | grep python

# Restart services to free memory
sudo systemctl restart student-services-web
sudo systemctl restart student-services-bot
```

#### 5. Disk Space Issues
```bash
# Check disk usage
df -h

# Find large files
sudo du -h / | sort -rh | head -20

# Clean logs
sudo journalctl --vacuum-size=100M

# Clean old backups
find /home/student-services/backups -mtime +30 -delete
```

### Emergency Recovery

#### 1. Service Recovery
```bash
# Stop all services
sudo systemctl stop student-services-web
sudo systemctl stop student-services-bot
sudo systemctl stop nginx

# Start services one by one
sudo systemctl start postgresql
sudo systemctl start redis-server
sudo systemctl start nginx
sudo systemctl start student-services-web
sudo systemctl start student-services-bot
```

#### 2. Database Recovery
```bash
# Restore from backup
gunzip /home/student-services/backups/database/backup_YYYYMMDD_HHMMSS.sql.gz
psql -h localhost -U student_services_user -d student_services < backup_YYYYMMDD_HHMMSS.sql
```

#### 3. Application Recovery
```bash
# Restore from backup
cd /home/student-services
tar -xzf backups/application/app_backup_YYYYMMDD_HHMMSS.tar.gz
sudo systemctl restart student-services-web student-services-bot
```

---

## 📞 Support and Resources

### Documentation
- **FastAPI**: https://fastapi.tiangolo.com/
- **Nginx**: https://nginx.org/en/docs/
- **PostgreSQL**: https://www.postgresql.org/docs/
- **Let's Encrypt**: https://letsencrypt.org/docs/

### Monitoring Tools
- **Uptime Robot**: Free uptime monitoring
- **Pingdom**: Website monitoring
- **New Relic**: Application performance monitoring
- **Datadog**: Infrastructure monitoring

### Security Resources
- **SSL Labs**: https://www.ssllabs.com/ssltest/
- **Security Headers**: https://securityheaders.com/
- **Mozilla Observatory**: https://observatory.mozilla.org/

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Domain purchased and DNS configured
- [ ] VPS provisioned with Ubuntu 22.04
- [ ] SSH key authentication setup
- [ ] GitHub repository ready

### Security Setup
- [ ] Firewall configured (UFW)
- [ ] SSH hardened (custom port, key auth only)
- [ ] Fail2Ban installed and configured
- [ ] Automatic updates enabled

### Application Setup
- [ ] PostgreSQL installed and configured
- [ ] Redis installed (optional)
- [ ] Python environment setup
- [ ] Application deployed and tested
- [ ] Environment variables configured

### Web Server Setup
- [ ] Nginx installed and configured
- [ ] SSL certificate obtained and installed
- [ ] Security headers configured
- [ ] Rate limiting enabled

### Services Setup
- [ ] Systemd services created and enabled
- [ ] Services started and tested
- [ ] Log rotation configured

### Monitoring Setup
- [ ] Health checks configured
- [ ] Log monitoring setup
- [ ] Backup strategy implemented
- [ ] Update procedures documented

### Final Testing
- [ ] Website accessible via HTTPS
- [ ] Admin panel login working
- [ ] Telegram bot responding
- [ ] Payment processing tested
- [ ] SSL rating A+ on SSL Labs
- [ ] All services auto-start on reboot

---

## 🎉 Congratulations!

You now have a fully deployed, secure, and production-ready Student Services Platform!

### What You've Accomplished:
- ✅ **Secure VPS** with hardened SSH and firewall
- ✅ **Domain with SSL** certificate and A+ rating
- ✅ **Production database** with PostgreSQL
- ✅ **High-performance web server** with Nginx
- ✅ **Automated services** with systemd
- ✅ **Monitoring and logging** system
- ✅ **Backup strategy** for data protection
- ✅ **Update procedures** for maintenance

### Your Platform Features:
- 🔐 **Secure admin panel** with CAPTCHA protection
- 🤖 **Telegram bot** for customer interaction
- 💳 **Payment processing** with Stripe
- 📊 **Analytics dashboard** for business insights
- 🛡️ **Security hardening** against attacks
- 📈 **Performance optimization** for speed
- 🔄 **Automated backups** for data safety

**Your Student Services Platform is now live and ready to serve customers!** 🚀

---

*This guide was created for the Student Services Platform. For support, please refer to the project documentation or create an issue in the GitHub repository.*
