#!/bin/bash

# Student Services Platform - Domain and SSL Setup Script
# This script configures domain and SSL for your deployed application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Welcome message
echo -e "${BLUE}"
echo "========================================"
echo "Student Services Platform - Domain & SSL"
echo "========================================"
echo -e "${NC}"

# Check if running as correct user
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as your application user."
fi

# Get domain information
echo "This script will configure your domain and SSL certificate."
echo ""
read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN
read -p "Enter your email for SSL certificates: " EMAIL

# Validate inputs
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    error "Domain and email are required!"
fi

# Check if domain resolves to this server
log "Checking domain DNS resolution..."
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN)

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    warn "Domain $DOMAIN does not resolve to this server ($SERVER_IP)"
    warn "Current domain IP: $DOMAIN_IP"
    echo ""
    echo "Please update your DNS records:"
    echo "A     @     $SERVER_IP"
    echo "A     www   $SERVER_IP"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please update DNS and run this script again."
        exit 1
    fi
fi

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    error "Nginx is not installed. Please run the VPS setup script first."
fi

# Check if Certbot is installed
if ! command -v certbot &> /dev/null; then
    log "Installing Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Find application directory
APP_DIR=""
if [[ -d "/home/$USER/student-services-secure" ]]; then
    APP_DIR="/home/$USER/student-services-secure"
elif [[ -d "/home/$USER/student-services-platform" ]]; then
    APP_DIR="/home/$USER/student-services-platform"
else
    read -p "Enter the full path to your application directory: " APP_DIR
    if [[ ! -d "$APP_DIR" ]]; then
        error "Application directory not found: $APP_DIR"
    fi
fi

log "Using application directory: $APP_DIR"

# Create Nginx configuration
log "Creating Nginx configuration for $DOMAIN..."

sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null << EOF
# Student Services Platform - Nginx Configuration
# Domain: $DOMAIN

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=general:10m rate=30r/m;

# Upstream backend
upstream student_services_backend {
    server 127.0.0.1:8000;
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL Configuration (will be updated by Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data: blob:; img-src 'self' data: https:; font-src 'self' data: https:;" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
    # Hide server information
    server_tokens off;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
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
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Static files with caching
    location /static/ {
        alias $APP_DIR/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff";
        
        # Security for uploaded files
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)\$ {
            deny all;
        }
    }
    
    # Favicon
    location = /favicon.ico {
        alias $APP_DIR/static/images/favicon.ico;
        expires 30d;
        access_log off;
    }
    
    # Robots.txt
    location = /robots.txt {
        alias $APP_DIR/static/robots.txt;
        expires 30d;
        access_log off;
    }
    
    # Admin login with strict rate limiting
    location /admin/login {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;
        
        proxy_pass http://student_services_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Admin panel with authentication
    location /admin/ {
        limit_req zone=general burst=10 nodelay;
        
        proxy_pass http://student_services_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        limit_req_status 429;
        
        proxy_pass http://student_services_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check (no rate limiting)
    location /health {
        access_log off;
        proxy_pass http://student_services_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Webhook endpoints
    location /webhook/ {
        limit_req zone=api burst=10 nodelay;
        
        proxy_pass http://student_services_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Longer timeout for webhooks
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Main application
    location / {
        limit_req zone=general burst=15 nodelay;
        
        proxy_pass http://student_services_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ \.(env|log|ini|conf|bak|old|tmp)\$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /404.html {
        root /var/www/html;
        internal;
    }
    
    location = /50x.html {
        root /var/www/html;
        internal;
    }
}
EOF

# Enable the site
log "Enabling Nginx site..."
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Remove default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
log "Testing Nginx configuration..."
if ! sudo nginx -t; then
    error "Nginx configuration test failed!"
fi

# Reload Nginx
sudo systemctl reload nginx

# Create directory for Let's Encrypt challenges
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html

# Obtain SSL certificate
log "Obtaining SSL certificate for $DOMAIN..."

# First, try to get certificate
if sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive --redirect; then
    log "✅ SSL certificate obtained successfully!"
else
    warn "SSL certificate installation failed. Trying alternative method..."
    
    # Try webroot method
    if sudo certbot certonly --webroot -w /var/www/html -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive; then
        log "✅ SSL certificate obtained with webroot method!"
        
        # Update Nginx configuration manually
        sudo sed -i "s|ssl_certificate .*|ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;|" /etc/nginx/sites-available/$DOMAIN
        sudo sed -i "s|ssl_certificate_key .*|ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;|" /etc/nginx/sites-available/$DOMAIN
        
        sudo nginx -t && sudo systemctl reload nginx
    else
        error "Failed to obtain SSL certificate. Please check DNS settings and try again."
    fi
fi

# Setup automatic renewal
log "Setting up automatic SSL renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test renewal
log "Testing SSL certificate renewal..."
sudo certbot renew --dry-run

# Update application environment
log "Updating application environment..."
if [[ -f "$APP_DIR/.env" ]]; then
    # Update APP_URL in .env file
    sudo sed -i "s|APP_URL=.*|APP_URL=https://$DOMAIN|" "$APP_DIR/.env"
    log "Updated APP_URL in .env file"
else
    warn ".env file not found at $APP_DIR/.env"
fi

# Configure Fail2Ban for Nginx
log "Configuring Fail2Ban for Nginx..."
sudo tee /etc/fail2ban/filter.d/nginx-limit-req.conf > /dev/null << 'EOF'
[Definition]
failregex = limiting requests, excess: .* by zone .*, client: <HOST>
ignoreregex =
EOF

sudo tee -a /etc/fail2ban/jail.local > /dev/null << EOF

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600
findtime = 600

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 86400
findtime = 600
EOF

sudo systemctl restart fail2ban

# Create SSL monitoring script
log "Creating SSL monitoring script..."
mkdir -p "$APP_DIR/scripts"

cat > "$APP_DIR/scripts/check-ssl.sh" << 'EOF'
#!/bin/bash
# SSL Certificate Monitoring Script

DOMAIN="$1"
if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

# Check certificate expiration
EXPIRY_DATE=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

echo "SSL Certificate for $DOMAIN:"
echo "Expires: $EXPIRY_DATE"
echo "Days until expiry: $DAYS_UNTIL_EXPIRY"

if [[ $DAYS_UNTIL_EXPIRY -lt 30 ]]; then
    echo "⚠️  Certificate expires in less than 30 days!"
    # You can add email notification here
fi

if [[ $DAYS_UNTIL_EXPIRY -lt 7 ]]; then
    echo "🚨 Certificate expires in less than 7 days!"
    # Force renewal
    sudo certbot renew --force-renewal
fi
EOF

chmod +x "$APP_DIR/scripts/check-ssl.sh"

# Add SSL check to crontab
(crontab -l 2>/dev/null; echo "0 6 * * * $APP_DIR/scripts/check-ssl.sh $DOMAIN") | crontab -

# Test the website
log "Testing website accessibility..."
sleep 5

if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
    log "✅ Website is accessible at https://$DOMAIN"
else
    warn "❌ Website may not be accessible. Check the application status."
fi

# Check SSL rating
log "Checking SSL configuration..."
echo "You can test your SSL configuration at:"
echo "https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"

# Final status check
log "Checking service status..."
if systemctl is-active --quiet nginx; then
    log "✅ Nginx is running"
else
    warn "❌ Nginx is not running"
fi

if systemctl is-active --quiet student-services-web 2>/dev/null; then
    log "✅ Web application is running"
else
    warn "❌ Web application is not running"
fi

# Display final information
echo ""
echo -e "${GREEN}========================================"
echo "🎉 Domain and SSL Setup Complete!"
echo "========================================${NC}"
echo ""
echo "🌐 Your website is now available at:"
echo "   https://$DOMAIN"
echo "   https://www.$DOMAIN"
echo ""
echo "🔐 Admin panel:"
echo "   https://$DOMAIN/admin"
echo ""
echo "📊 API documentation:"
echo "   https://$DOMAIN/api/docs"
echo ""
echo "🔒 SSL Certificate:"
echo "   ✅ Installed and configured"
echo "   ✅ Auto-renewal enabled"
echo "   ✅ Security headers configured"
echo ""
echo "🛡️ Security Features:"
echo "   ✅ Rate limiting enabled"
echo "   ✅ Fail2Ban configured"
echo "   ✅ Security headers set"
echo "   ✅ HTTPS redirect enabled"
echo ""
echo "📋 Next Steps:"
echo "1. Test your website: https://$DOMAIN"
echo "2. Check SSL rating: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo "3. Configure your application settings in $APP_DIR/.env"
echo "4. Create admin user if not done already"
echo ""
echo "🔧 Useful Commands:"
echo "   sudo systemctl status nginx"
echo "   sudo systemctl status student-services-web"
echo "   sudo certbot certificates"
echo "   sudo nginx -t"
echo ""
echo "📁 Configuration Files:"
echo "   Nginx: /etc/nginx/sites-available/$DOMAIN"
echo "   SSL: /etc/letsencrypt/live/$DOMAIN/"
echo "   App: $APP_DIR/.env"
echo ""
echo "🎯 Your Student Services Platform is now live with SSL! 🚀"
echo ""

log "Domain and SSL setup completed successfully!"
