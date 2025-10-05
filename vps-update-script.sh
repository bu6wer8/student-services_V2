#!/bin/bash

# Student Services Platform - VPS Update Script
# This script updates your VPS with the simplified version from GitHub

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="your-username/student-services-simplified"  # Update this with your GitHub repo
APP_DIR="/home/student-services/student-services_V2"
BACKUP_DIR="/home/student-services/backups"
SERVICE_NAME="student-services"

echo -e "${BLUE}Student Services Platform - VPS Update Script${NC}"
echo "=================================================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as correct user
if [ "$USER" != "student-services" ]; then
    print_error "This script should be run as the 'student-services' user"
    echo "Please run: sudo su - student-services"
    exit 1
fi

# Check if GitHub repo URL is updated
if [[ "$GITHUB_REPO" == "your-username/student-services-simplified" ]]; then
    print_error "Please update the GITHUB_REPO variable in this script with your actual GitHub repository URL"
    echo "Edit this script and change: GITHUB_REPO=\"your-username/student-services-simplified\""
    exit 1
fi

print_status "Starting VPS update process..."

# Step 1: Create backup directory
print_status "Creating backup directory..."
mkdir -p "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
CURRENT_BACKUP="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"

# Step 2: Stop the service
print_status "Stopping the student-services service..."
sudo systemctl stop "$SERVICE_NAME" || print_warning "Service might not be running"

# Step 3: Backup current installation
print_status "Backing up current installation..."
if [ -d "$APP_DIR" ]; then
    cp -r "$APP_DIR" "$CURRENT_BACKUP/app_backup"
    print_status "Backup created at: $CURRENT_BACKUP/app_backup"
else
    print_warning "Application directory not found at $APP_DIR"
fi

# Step 4: Backup database
print_status "Backing up database..."
if [ -f "$APP_DIR/student_services.db" ]; then
    cp "$APP_DIR/student_services.db" "$CURRENT_BACKUP/database_backup.db"
    print_status "Database backup created"
elif [ -f "$APP_DIR/student-services.db" ]; then
    cp "$APP_DIR/student-services.db" "$CURRENT_BACKUP/database_backup.db"
    print_status "Database backup created"
else
    print_warning "SQLite database not found for backup"
fi

# Step 5: Backup environment file
print_status "Backing up environment configuration..."
if [ -f "$APP_DIR/.env" ]; then
    cp "$APP_DIR/.env" "$CURRENT_BACKUP/env_backup"
    print_status "Environment file backed up"
else
    print_warning ".env file not found"
fi

# Step 6: Clone/update from GitHub
print_status "Downloading latest code from GitHub..."
cd /home/student-services

if [ -d "student-services-simplified-new" ]; then
    rm -rf student-services-simplified-new
fi

git clone "https://github.com/$GITHUB_REPO.git" student-services-simplified-new
cd student-services-simplified-new

# Step 7: Setup virtual environment
print_status "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Step 8: Install dependencies
print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements_simplified.txt

# Step 9: Restore environment configuration
print_status "Restoring environment configuration..."
if [ -f "$CURRENT_BACKUP/env_backup" ]; then
    cp "$CURRENT_BACKUP/env_backup" .env
    print_status "Environment configuration restored"
else
    print_warning "No previous .env file found. Using default configuration."
    cp .env.example .env
    print_warning "Please edit .env file with your settings"
fi

# Step 10: Restore database
print_status "Restoring database..."
if [ -f "$CURRENT_BACKUP/database_backup.db" ]; then
    cp "$CURRENT_BACKUP/database_backup.db" student_services.db
    print_status "Database restored"
else
    print_warning "No database backup found. Will create new database."
fi

# Step 11: Test the application
print_status "Testing the application..."
python test_auth.py
if [ $? -eq 0 ]; then
    print_status "Application tests passed!"
else
    print_error "Application tests failed!"
    print_error "Please check the configuration and try again."
    exit 1
fi

# Step 12: Replace old installation
print_status "Replacing old installation..."
cd /home/student-services

if [ -d "$APP_DIR" ]; then
    mv "$APP_DIR" "$CURRENT_BACKUP/old_installation"
fi

mv student-services-simplified-new "$APP_DIR"

# Step 13: Update systemd service
print_status "Updating systemd service..."
sudo tee /etc/systemd/system/student-services.service > /dev/null << EOF
[Unit]
Description=Student Services Platform (Simplified)
After=network.target

[Service]
Type=simple
User=student-services
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python run_simplified.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Step 14: Reload and start service
print_status "Reloading systemd and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable student-services
sudo systemctl start student-services

# Step 15: Check service status
sleep 5
print_status "Checking service status..."
if sudo systemctl is-active --quiet student-services; then
    print_status "Service is running successfully!"
else
    print_error "Service failed to start. Checking logs..."
    sudo journalctl -u student-services --no-pager -n 20
    exit 1
fi

# Step 16: Test web access
print_status "Testing web access..."
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health | grep -q "200"; then
    print_status "Web application is responding!"
else
    print_warning "Web application might not be responding yet. Check logs if needed."
fi

# Final status
echo ""
echo "=================================================="
print_status "VPS Update Complete!"
echo ""
print_status "✅ Service updated and running"
print_status "✅ Database preserved"
print_status "✅ Configuration restored"
print_status "✅ Backup created at: $CURRENT_BACKUP"
echo ""
print_status "Admin panel should be available at:"
print_status "https://yourdomain.com/admin/login"
echo ""
print_warning "If you have any issues, you can restore from backup:"
print_warning "sudo systemctl stop student-services"
print_warning "mv $APP_DIR $APP_DIR.failed"
print_warning "mv $CURRENT_BACKUP/old_installation $APP_DIR"
print_warning "sudo systemctl start student-services"
echo ""
print_status "Check service logs with: sudo journalctl -u student-services -f"
echo "=================================================="
