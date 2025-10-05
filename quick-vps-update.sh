#!/bin/bash

# Quick VPS Update Script for Student Services Platform
# Run this on your VPS to update to the simplified version

echo "🚀 Student Services Platform - Quick VPS Update"
echo "================================================"

# Check if running as student-services user
if [ "$USER" != "student-services" ]; then
    echo "❌ Please run as student-services user:"
    echo "   sudo su - student-services"
    echo "   Then run this script again"
    exit 1
fi

# Get GitHub repository URL
read -p "📝 Enter your GitHub repository (e.g., username/student-services-simplified): " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo "❌ GitHub repository is required"
    exit 1
fi

echo "🔄 Starting update process..."

# Stop service
echo "⏹️  Stopping service..."
sudo systemctl stop student-services

# Create backup
echo "💾 Creating backup..."
BACKUP_DIR=~/backups/$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

if [ -d ~/student-services_V2 ]; then
    cp -r ~/student-services_V2 $BACKUP_DIR/
    echo "✅ Backup created at: $BACKUP_DIR"
fi

# Download new code
echo "⬇️  Downloading new code..."
cd ~
rm -rf student-services-new
git clone https://github.com/$GITHUB_REPO.git student-services-new

if [ ! -d "student-services-new" ]; then
    echo "❌ Failed to clone repository. Check the repository name."
    exit 1
fi

cd student-services-new

# Setup environment
echo "🐍 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_simplified.txt

# Restore configuration
echo "⚙️  Restoring configuration..."
if [ -f "$BACKUP_DIR/student-services_V2/.env" ]; then
    cp "$BACKUP_DIR/student-services_V2/.env" .env
    echo "✅ Configuration restored"
else
    cp .env.example .env
    echo "⚠️  Using default configuration. Please edit .env file!"
fi

# Restore database
echo "🗄️  Restoring database..."
if [ -f "$BACKUP_DIR/student-services_V2"/*.db ]; then
    cp "$BACKUP_DIR/student-services_V2"/*.db .
    echo "✅ Database restored"
fi

# Test application
echo "🧪 Testing application..."
if python test_auth.py > /dev/null 2>&1; then
    echo "✅ Tests passed!"
else
    echo "⚠️  Tests failed. Please check configuration."
fi

# Replace installation
echo "🔄 Replacing installation..."
cd ~
if [ -d "student-services_V2" ]; then
    mv student-services_V2 student-services_V2_old
fi
mv student-services-new student-services_V2

# Update service
echo "🔧 Updating service..."
sudo tee /etc/systemd/system/student-services.service > /dev/null << EOF
[Unit]
Description=Student Services Platform (Simplified)
After=network.target

[Service]
Type=simple
User=student-services
WorkingDirectory=/home/student-services/student-services_V2
Environment=PATH=/home/student-services/student-services_V2/venv/bin
ExecStart=/home/student-services/student-services_V2/venv/bin/python run_simplified.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start service
echo "▶️  Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable student-services
sudo systemctl start student-services

# Check status
sleep 3
if sudo systemctl is-active --quiet student-services; then
    echo "✅ Service is running!"
    echo "🌐 Admin panel: https://yourdomain.com/admin/login"
    echo "📊 Check status: sudo systemctl status student-services"
    echo "📝 View logs: sudo journalctl -u student-services -f"
else
    echo "❌ Service failed to start. Check logs:"
    echo "   sudo journalctl -u student-services --no-pager -n 20"
fi

echo ""
echo "🎉 Update complete!"
echo "💾 Backup available at: $BACKUP_DIR"
