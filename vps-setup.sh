#!/bin/bash

# Student Services Platform - Automated VPS Setup Script
# This script automates the complete VPS setup process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Welcome message
echo -e "${BLUE}"
echo "=================================="
echo "Student Services Platform VPS Setup"
echo "=================================="
echo -e "${NC}"
echo "This script will set up your VPS for production deployment."
echo "It will install and configure:"
echo "- System updates and security"
echo "- PostgreSQL database"
echo "- Nginx web server"
echo "- Python environment"
echo "- SSL certificates"
echo "- Monitoring tools"
echo ""

# Get user input
read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN
read -p "Enter your email for SSL certificates: " EMAIL
read -p "Enter your GitHub username: " GITHUB_USER
read -p "Enter your repository name: " REPO_NAME

# Validate inputs
if [[ -z "$DOMAIN" || -z "$EMAIL" || -z "$GITHUB_USER" || -z "$REPO_NAME" ]]; then
    error "All fields are required!"
fi

echo ""
echo "Configuration:"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Repository: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""

read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

log "Starting VPS setup..."

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
log "Installing essential packages..."
sudo apt install -y curl wget git unzip software-properties-common \
    apt-transport-https ca-certificates gnupg lsb-release \
    build-essential libpq-dev libssl-dev libffi-dev \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    htop iotop nethogs fail2ban ufw

# Configure firewall
log "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
echo "y" | sudo ufw enable

# Install and configure PostgreSQL
log "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
log "Configuring PostgreSQL..."
DB_PASSWORD=$(openssl rand -base64 32)
sudo -u postgres psql << EOF
CREATE DATABASE student_services;
CREATE USER student_services_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE student_services TO student_services_user;
ALTER USER student_services_user CREATEDB;
\q
EOF

# Install Redis
log "Installing Redis..."
sudo apt install -y redis-server
REDIS_PASSWORD=$(openssl rand -base64 32)

# Configure Redis
sudo sed -i "s/# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
sudo sed -i "s/bind 127.0.0.1/bind 127.0.0.1/" /etc/redis/redis.conf
sudo systemctl restart redis-server
sudo systemctl enable redis-server

# Install Nginx
log "Installing Nginx..."
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Install Certbot for SSL
log "Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

# Clone repository
log "Cloning repository..."
cd /home/$USER
git clone https://github.com/$GITHUB_USER/$REPO_NAME.git
cd $REPO_NAME

# Setup Python environment
log "Setting up Python environment..."
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Create environment file
log "Creating environment configuration..."
SECRET_KEY=$(openssl rand -base64 32)
cat > .env << EOF
# Environment
ENV=production
DEBUG=False
APP_URL=https://$DOMAIN

# Database
DATABASE_URL=postgresql://student_services_user:$DB_PASSWORD@localhost:5432/student_services
REDIS_URL=redis://:$REDIS_PASSWORD@localhost:6379

# API Configuration
API_HOST=127.0.0.1
API_PORT=8000
SECRET_KEY=$SECRET_KEY
ALGORITHM=HS256

# Admin Authentication (change these!)
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=change_this_after_setup

# Telegram Bot (add your tokens)
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ADMIN_ID=your_telegram_user_id

# Stripe (add your keys)
STRIPE_PUBLIC_KEY=pk_live_your_stripe_public_key
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# File Storage
UPLOAD_DIR=./static/uploads
DOWNLOAD_DIR=./static/downloads
MAX_FILE_SIZE=10485760

# Pricing
BASE_PRICE_ASSIGNMENT=20.0
BASE_PRICE_PROJECT=50.0
BASE_PRICE_PRESENTATION=30.0
URGENCY_MULTIPLIER_24H=2.0
EOF

# Create directories
log "Creating application directories..."
mkdir -p logs static/uploads static/downloads uploaded_works

# Configure Nginx
log "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Hide Nginx version
    server_tokens off;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    
    # Static files
    location /static/ {
        alias /home/$USER/$REPO_NAME/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Admin login rate limiting
    location /admin/login {
        limit_req zone=login burst=3 nodelay;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
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
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t
sudo systemctl reload nginx

# Create systemd services
log "Creating systemd services..."

# Web service
sudo tee /etc/systemd/system/student-services-web.service > /dev/null << EOF
[Unit]
Description=Student Services Web Application
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service

[Service]
Type=exec
User=$USER
Group=$USER
WorkingDirectory=/home/$USER/$REPO_NAME
Environment=PATH=/home/$USER/$REPO_NAME/venv/bin
ExecStart=/home/$USER/$REPO_NAME/venv/bin/gunicorn app.api.main:app --bind 127.0.0.1:8000 --workers 4 --worker-class uvicorn.workers.UvicornWorker --timeout 120 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=student-services-web

[Install]
WantedBy=multi-user.target
EOF

# Bot service
sudo tee /etc/systemd/system/student-services-bot.service > /dev/null << EOF
[Unit]
Description=Student Services Telegram Bot
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=exec
User=$USER
Group=$USER
WorkingDirectory=/home/$USER/$REPO_NAME
Environment=PATH=/home/$USER/$REPO_NAME/venv/bin
ExecStart=/home/$USER/$REPO_NAME/venv/bin/python app/bot/bot.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=student-services-bot

[Install]
WantedBy=multi-user.target
EOF

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable student-services-web
sudo systemctl enable student-services-bot

# Configure Fail2Ban
log "Configuring Fail2Ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
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
EOF

sudo systemctl restart fail2ban

# Setup SSL certificate
log "Setting up SSL certificate..."
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive --redirect

# Create backup scripts
log "Creating backup scripts..."
mkdir -p scripts

# Database backup script
cat > scripts/backup-database.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/$USER/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="student_services"
DB_USER="student_services_user"

mkdir -p $BACKUP_DIR
pg_dump -h localhost -U $DB_USER -d $DB_NAME > $BACKUP_DIR/backup_$DATE.sql
gzip $BACKUP_DIR/backup_$DATE.sql
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
echo "Database backup completed: backup_$DATE.sql.gz"
EOF

chmod +x scripts/backup-database.sh

# Health check script
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet student-services-web; then
    echo "Web service is down, restarting..."
    sudo systemctl restart student-services-web
    echo "Web service restarted at $(date)" >> logs/health-check.log
fi

if ! systemctl is-active --quiet student-services-bot; then
    echo "Bot service is down, restarting..."
    sudo systemctl restart student-services-bot
    echo "Bot service restarted at $(date)" >> logs/health-check.log
fi
EOF

chmod +x scripts/health-check.sh

# Add cron jobs
log "Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/$USER/$REPO_NAME/scripts/health-check.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */6 * * * /home/$USER/$REPO_NAME/scripts/backup-database.sh") | crontab -

# Initialize database
log "Initializing database..."
source venv/bin/activate
python scripts/init_db.py 2>/dev/null || echo "Database initialization script not found, skipping..."

# Start services
log "Starting services..."
sudo systemctl start student-services-web
sudo systemctl start student-services-bot

# Wait for services to start
sleep 5

# Check service status
log "Checking service status..."
if systemctl is-active --quiet student-services-web; then
    log "✅ Web service is running"
else
    warn "❌ Web service failed to start"
    sudo journalctl -u student-services-web -n 10
fi

if systemctl is-active --quiet student-services-bot; then
    log "✅ Bot service is running"
else
    warn "❌ Bot service failed to start (this is normal if bot token is not configured)"
fi

# Final setup instructions
echo ""
echo -e "${GREEN}=================================="
echo "🎉 VPS Setup Complete!"
echo "==================================${NC}"
echo ""
echo "Your Student Services Platform is now deployed!"
echo ""
echo "📋 Next Steps:"
echo "1. Update your .env file with real credentials:"
echo "   - Telegram bot token"
echo "   - Stripe API keys"
echo "   - Email settings"
echo ""
echo "2. Create admin user:"
echo "   cd /home/$USER/$REPO_NAME"
echo "   source venv/bin/activate"
echo "   python scripts/create_admin_simple.py"
echo ""
echo "3. Test your website:"
echo "   https://$DOMAIN"
echo "   https://$DOMAIN/admin"
echo ""
echo "📊 Service Management:"
echo "   sudo systemctl status student-services-web"
echo "   sudo systemctl status student-services-bot"
echo "   sudo journalctl -u student-services-web -f"
echo ""
echo "🔐 Important Files:"
echo "   Environment: /home/$USER/$REPO_NAME/.env"
echo "   Nginx config: /etc/nginx/sites-available/$DOMAIN"
echo "   SSL cert: Auto-renewed by certbot"
echo ""
echo "💾 Database Credentials:"
echo "   Database: student_services"
echo "   User: student_services_user"
echo "   Password: $DB_PASSWORD"
echo ""
echo "🔑 Redis Password: $REDIS_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Save these credentials securely!"
echo ""
echo "🎯 Your platform is ready for production use!"
echo ""

# Save credentials to file
cat > /home/$USER/SETUP_CREDENTIALS.txt << EOF
Student Services Platform - Setup Credentials
=============================================

Database:
- Host: localhost
- Database: student_services
- User: student_services_user
- Password: $DB_PASSWORD

Redis:
- Host: localhost
- Port: 6379
- Password: $REDIS_PASSWORD

Application:
- Domain: https://$DOMAIN
- Admin Panel: https://$DOMAIN/admin
- API Docs: https://$DOMAIN/api/docs

Secret Key: $SECRET_KEY

Setup completed on: $(date)

IMPORTANT: Keep this file secure and delete it after noting the credentials!
EOF

log "Credentials saved to /home/$USER/SETUP_CREDENTIALS.txt"
log "Setup completed successfully! 🚀"
