#!/bin/bash

# VPS Troubleshooting Script for Student Services Platform
# Run this to diagnose and fix issues after update

echo "🔧 Student Services Platform - Troubleshooting"
echo "=============================================="

# Check current user
if [ "$USER" != "student-services" ]; then
    echo "❌ Please run as student-services user:"
    echo "   sudo su - student-services"
    exit 1
fi

echo "📍 Current location: $(pwd)"
echo "👤 Current user: $USER"
echo ""

# Step 1: Check if we're in the right directory
echo "1️⃣ Checking application directory..."
if [ -d ~/student-services_V2 ]; then
    cd ~/student-services_V2
    echo "✅ Found application directory"
else
    echo "❌ Application directory not found"
    exit 1
fi

# Step 2: Check virtual environment
echo ""
echo "2️⃣ Checking virtual environment..."
if [ -d "venv" ]; then
    echo "✅ Virtual environment exists"
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "❌ Virtual environment not found"
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements_simplified.txt
fi

# Step 3: Check configuration file
echo ""
echo "3️⃣ Checking configuration..."
if [ -f ".env" ]; then
    echo "✅ .env file exists"
    echo "📋 Configuration summary:"
    echo "   SECRET_KEY: $(grep SECRET_KEY .env | cut -d'=' -f2 | cut -c1-10)..."
    echo "   ADMIN_USERNAME: $(grep ADMIN_USERNAME .env | cut -d'=' -f2)"
    echo "   DATABASE_URL: $(grep DATABASE_URL .env | cut -d'=' -f2)"
else
    echo "❌ .env file missing"
    echo "Creating .env from template..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "⚠️  Please edit .env file with your settings"
    else
        echo "❌ No .env template found"
        exit 1
    fi
fi

# Step 4: Check required files
echo ""
echo "4️⃣ Checking required files..."
REQUIRED_FILES=("app/api/main.py" "app/services/auth.py" "config/config.py" "run_simplified.py")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done

# Step 5: Test configuration loading
echo ""
echo "5️⃣ Testing configuration loading..."
python3 -c "
try:
    from config.config import settings
    print('✅ Configuration loads successfully')
    print(f'   Admin username: {settings.admin_username}')
    print(f'   Database URL: {settings.database_url}')
except Exception as e:
    print(f'❌ Configuration error: {e}')
    exit(1)
"

# Step 6: Test database connection
echo ""
echo "6️⃣ Testing database connection..."
python3 -c "
try:
    from app.models.database import get_db, init_database
    init_database()
    db = next(get_db())
    db.close()
    print('✅ Database connection successful')
except Exception as e:
    print(f'❌ Database error: {e}')
    print('Creating new database...')
    try:
        from app.models.database import init_database
        init_database()
        print('✅ Database created successfully')
    except Exception as e2:
        print(f'❌ Failed to create database: {e2}')
"

# Step 7: Test authentication
echo ""
echo "7️⃣ Testing authentication..."
if [ -f "test_auth.py" ]; then
    python3 test_auth.py
else
    echo "❌ test_auth.py not found"
    echo "Testing authentication manually..."
    python3 -c "
try:
    from app.services.auth import auth_service
    from config.config import settings
    result = auth_service.authenticate_admin(settings.admin_username, settings.admin_password)
    if result:
        print('✅ Authentication test passed')
    else:
        print('❌ Authentication test failed')
except Exception as e:
    print(f'❌ Authentication error: {e}')
"
fi

# Step 8: Check service logs
echo ""
echo "8️⃣ Checking service logs..."
echo "Recent service logs:"
sudo journalctl -u student-services --no-pager -n 10 2>/dev/null || echo "No service logs found"

# Step 9: Test manual startup
echo ""
echo "9️⃣ Testing manual startup..."
echo "Attempting to start application manually..."
timeout 10s python3 run_simplified.py &
MANUAL_PID=$!
sleep 3

if kill -0 $MANUAL_PID 2>/dev/null; then
    echo "✅ Application starts manually"
    kill $MANUAL_PID 2>/dev/null
else
    echo "❌ Application fails to start manually"
    echo "Error output:"
    python3 run_simplified.py 2>&1 | head -10
fi

# Step 10: Fix common issues
echo ""
echo "🔧 Applying common fixes..."

# Fix 1: Update .env with proper values
echo "Checking .env configuration..."
if ! grep -q "SECRET_KEY.*[a-zA-Z0-9]" .env; then
    echo "Fixing SECRET_KEY..."
    sed -i 's/SECRET_KEY=.*/SECRET_KEY=your-secret-key-change-this-in-production-make-it-at-least-32-characters-long/' .env
fi

# Fix 2: Ensure database file exists
if [ ! -f "student_services.db" ] && [ ! -f "student-services.db" ]; then
    echo "Creating database..."
    python3 -c "
from app.models.database import init_database
init_database()
print('Database created')
"
fi

# Fix 3: Update systemd service with correct path
echo "Updating systemd service..."
sudo tee /etc/systemd/system/student-services.service > /dev/null << EOF
[Unit]
Description=Student Services Platform
After=network.target

[Service]
Type=simple
User=student-services
WorkingDirectory=/home/student-services/student-services_V2
Environment=PATH=/home/student-services/student-services_V2/venv/bin
ExecStart=/home/student-services/student-services_V2/venv/bin/python run_simplified.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Step 11: Restart service
echo ""
echo "🔄 Restarting service..."
sudo systemctl daemon-reload
sudo systemctl stop student-services 2>/dev/null
sudo systemctl start student-services

sleep 3

# Step 12: Final status check
echo ""
echo "📊 Final status check..."
if sudo systemctl is-active --quiet student-services; then
    echo "✅ Service is running!"
    
    # Test web access
    if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Web application is responding!"
    elif curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
        echo "✅ Web application is responding!"
    else
        echo "⚠️  Web application might not be responding yet"
    fi
    
    echo ""
    echo "🌐 Admin panel should be available at:"
    echo "   https://yourdomain.com/admin/login"
    echo "   or http://your-server-ip:8000/admin/login"
    
else
    echo "❌ Service is not running"
    echo ""
    echo "📝 Recent logs:"
    sudo journalctl -u student-services --no-pager -n 20
    echo ""
    echo "🔧 Manual troubleshooting:"
    echo "1. Check logs: sudo journalctl -u student-services -f"
    echo "2. Test manually: cd ~/student-services_V2 && source venv/bin/activate && python run_simplified.py"
    echo "3. Check .env file: cat .env"
fi

echo ""
echo "🎯 Troubleshooting complete!"
echo ""
echo "📋 Quick commands:"
echo "   Check status: sudo systemctl status student-services"
echo "   View logs: sudo journalctl -u student-services -f"
echo "   Restart: sudo systemctl restart student-services"
echo "   Test manually: cd ~/student-services_V2 && source venv/bin/activate && python run_simplified.py"
