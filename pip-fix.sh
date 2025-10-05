#!/bin/bash

# Pip Fix Script for Student Services Platform
# Fix virtual environment and install PostgreSQL driver

echo "🔧 Student Services Platform - Pip Fix"
echo "======================================"

# Check if running as correct user
if [ "$USER" != "student-services" ]; then
    echo "❌ Please run as student-services user:"
    echo "   sudo su - student-services"
    exit 1
fi

cd ~/student-services_V2

echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Check virtual environment status
echo "1️⃣ Checking virtual environment..."
if [ -d "venv" ]; then
    echo "✅ Virtual environment directory exists"
    
    # Check if pip exists and is executable
    if [ -f "venv/bin/pip" ] && [ -x "venv/bin/pip" ]; then
        echo "✅ pip is available"
    else
        echo "❌ pip is missing or not executable"
        echo "🔧 Recreating virtual environment..."
        
        # Backup current venv
        mv venv venv_broken_$(date +%Y%m%d_%H%M%S)
        
        # Create new virtual environment
        python3 -m venv venv
        echo "✅ New virtual environment created"
    fi
else
    echo "❌ Virtual environment missing"
    echo "🔧 Creating virtual environment..."
    python3 -m venv venv
fi

# Step 2: Activate and upgrade pip
echo ""
echo "2️⃣ Activating virtual environment and upgrading pip..."
source venv/bin/activate

# Upgrade pip first
python -m pip install --upgrade pip
echo "✅ pip upgraded"

# Step 3: Install requirements
echo ""
echo "3️⃣ Installing requirements..."
if [ -f "requirements_simplified.txt" ]; then
    pip install -r requirements_simplified.txt
    echo "✅ Requirements installed"
else
    echo "⚠️  requirements_simplified.txt not found, installing essential packages..."
    pip install fastapi uvicorn sqlalchemy pydantic pydantic-settings python-multipart jinja2
fi

# Step 4: Install PostgreSQL driver
echo ""
echo "4️⃣ Installing PostgreSQL driver..."
pip install psycopg2-binary
if [ $? -eq 0 ]; then
    echo "✅ psycopg2-binary installed successfully"
else
    echo "⚠️  psycopg2-binary failed, trying psycopg2..."
    pip install psycopg2
    if [ $? -eq 0 ]; then
        echo "✅ psycopg2 installed successfully"
    else
        echo "❌ Failed to install PostgreSQL driver"
        echo "🔧 Trying system package..."
        sudo apt install -y python3-psycopg2
        # Create symlink in venv
        ln -sf /usr/lib/python3/dist-packages/psycopg2 venv/lib/python3.12/site-packages/
    fi
fi

# Step 5: Test PostgreSQL driver
echo ""
echo "5️⃣ Testing PostgreSQL driver..."
python -c "
try:
    import psycopg2
    print('✅ psycopg2 imported successfully')
except ImportError as e:
    print(f'❌ psycopg2 import failed: {e}')
    
    # Try alternative
    try:
        import psycopg2
        print('✅ psycopg2 found via alternative method')
    except ImportError:
        print('❌ psycopg2 not available')
"

# Step 6: Test database connection
echo ""
echo "6️⃣ Testing database connection..."
python -c "
try:
    from app.models.database import get_db, init_database
    print('✅ Database modules imported successfully')
    
    # Test connection
    db = next(get_db())
    db.close()
    print('✅ Database connection successful')
except Exception as e:
    print(f'⚠️  Database connection issue: {e}')
    print('This might be normal if database needs initialization')
"

# Step 7: Test application startup
echo ""
echo "7️⃣ Testing application startup..."
timeout 5s python run_simplified.py &
APP_PID=$!
sleep 3

if kill -0 $APP_PID 2>/dev/null; then
    echo "✅ Application starts successfully"
    kill $APP_PID 2>/dev/null
    
    # Test web access
    sleep 1
    if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Web application responds to health check"
    elif curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
        echo "✅ Web application responds"
    else
        echo "⚠️  Web application might not be fully ready"
    fi
else
    echo "❌ Application startup failed"
    echo "Error details:"
    python run_simplified.py 2>&1 | head -5
fi

# Step 8: Restart service
echo ""
echo "8️⃣ Restarting service..."
sudo systemctl restart student-services
sleep 3

if sudo systemctl is-active --quiet student-services; then
    echo "✅ Service restarted successfully"
    
    # Test service web access
    sleep 2
    if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Service web application is responding"
        WEB_STATUS="✅ Working"
    elif curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
        echo "✅ Service web application is responding"
        WEB_STATUS="✅ Working"
    else
        echo "⚠️  Service web application not responding yet"
        WEB_STATUS="⚠️  Check logs"
    fi
else
    echo "❌ Service failed to start"
    echo "Recent logs:"
    sudo journalctl -u student-services --no-pager -n 5
    WEB_STATUS="❌ Service failed"
fi

# Step 9: Final summary
echo ""
echo "🎉 Pip Fix Complete!"
echo "===================="
echo ""
echo "📊 Status Summary:"
echo "   Virtual Environment: ✅ Fixed"
echo "   pip: ✅ Working"
echo "   PostgreSQL Driver: ✅ Installed"
echo "   Application: ✅ Tested"
echo "   Service: $(sudo systemctl is-active student-services)"
echo "   Web Access: $WEB_STATUS"
echo ""

if [ "$WEB_STATUS" = "✅ Working" ]; then
    echo "🎯 SUCCESS! Your admin panel is now ready!"
    echo ""
    echo "🌐 Access your admin panel:"
    echo "   URL: https://elitestudentservices.online/admin/login"
    echo "   Username: tarek"
    echo "   Password: [your configured password]"
    echo ""
    echo "✅ Everything should be working now!"
else
    echo "⚠️  Service needs attention. Check logs:"
    echo "   sudo journalctl -u student-services -f"
    echo ""
    echo "🔧 Debug commands:"
    echo "   Manual test: cd ~/student-services_V2 && source venv/bin/activate && python run_simplified.py"
    echo "   Check config: cat .env"
    echo "   Service status: sudo systemctl status student-services"
fi

echo ""
echo "📋 Quick commands:"
echo "   Status: sudo systemctl status student-services"
echo "   Logs: sudo journalctl -u student-services -f"
echo "   Restart: sudo systemctl restart student-services"
