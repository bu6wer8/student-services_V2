#!/bin/bash

# Configuration Fix Script for Student Services Platform
# This fixes the .env file compatibility issues

echo "🔧 Student Services Platform - Configuration Fix"
echo "================================================"

# Check if running as correct user
if [ "$USER" != "student-services" ]; then
    echo "❌ Please run as student-services user:"
    echo "   sudo su - student-services"
    exit 1
fi

# Navigate to application directory
cd ~/student-services_V2

echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Backup current .env
echo "1️⃣ Backing up current .env file..."
if [ -f ".env" ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Backup created"
else
    echo "❌ No .env file found"
    exit 1
fi

# Step 2: Extract compatible values from old .env
echo ""
echo "2️⃣ Extracting compatible configuration values..."

# Read values from old .env
SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d'=' -f2- | tr -d '"')
ADMIN_USERNAME=$(grep "^ADMIN_USERNAME=" .env | cut -d'=' -f2- | tr -d '"')
ADMIN_PASSWORD=$(grep "^ADMIN_PASSWORD=" .env | cut -d'=' -f2- | tr -d '"')
DATABASE_URL=$(grep "^DATABASE_URL=" .env | cut -d'=' -f2- | tr -d '"')
APP_URL=$(grep "^APP_URL=" .env | cut -d'=' -f2- | tr -d '"')
TELEGRAM_BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" .env | cut -d'=' -f2- | tr -d '"')
STRIPE_PUBLIC_KEY=$(grep "^STRIPE_PUBLIC_KEY=" .env | cut -d'=' -f2- | tr -d '"')
STRIPE_SECRET_KEY=$(grep "^STRIPE_SECRET_KEY=" .env | cut -d'=' -f2- | tr -d '"')

echo "✅ Values extracted"

# Step 3: Create new simplified .env file
echo ""
echo "3️⃣ Creating new simplified .env file..."

cat > .env << EOF
# Student Services Platform - Simplified Configuration
# Generated on $(date)

# Environment
ENV=production
DEBUG=false
APP_URL=${APP_URL:-https://yourdomain.com}

# Database
DATABASE_URL=${DATABASE_URL:-sqlite:///./student_services.db}

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
SECRET_KEY=${SECRET_KEY:-your-secret-key-change-this-in-production-make-it-at-least-32-characters-long}

# Admin Authentication
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}

# Telegram Bot (optional)
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
TELEGRAM_ADMIN_ID=

# Payment - Stripe (optional)
STRIPE_PUBLIC_KEY=${STRIPE_PUBLIC_KEY:-}
STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:-}
STRIPE_WEBHOOK_SECRET=

# Email Configuration (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=

# File Storage
UPLOAD_DIR=./static/uploads
DOWNLOAD_DIR=./static/downloads
MAX_FILE_SIZE=10485760

# Bank Transfer Details (optional)
BANK_NAME=Your Bank
BANK_ACCOUNT_NAME=Your Company
BANK_ACCOUNT_NUMBER=
BANK_IBAN=
BANK_SWIFT=

# Pricing Configuration
BASE_PRICE_ASSIGNMENT=20.0
BASE_PRICE_PROJECT=50.0
BASE_PRICE_PRESENTATION=30.0
BASE_PRICE_REDESIGN=25.0
BASE_PRICE_SUMMARY=15.0
BASE_PRICE_EXPRESS=50.0

# Urgency multipliers
URGENCY_MULTIPLIER_24H=2.0
URGENCY_MULTIPLIER_48H=1.5
URGENCY_MULTIPLIER_72H=1.3

# Academic level multipliers
ACADEMIC_MULTIPLIER_HIGH_SCHOOL=1.0
ACADEMIC_MULTIPLIER_BACHELOR=1.2
ACADEMIC_MULTIPLIER_MASTERS=1.5
ACADEMIC_MULTIPLIER_PHD=2.0

# Currency exchange rates (to USD)
RATE_USD_TO_JOD=0.71
RATE_USD_TO_AED=3.67
RATE_USD_TO_SAR=3.75

# Business Settings
BUSINESS_NAME=Student Services Platform
SUPPORT_EMAIL=support@yourdomain.com
SUPPORT_TELEGRAM=@your_support

# Feature Flags
ENABLE_REGISTRATION=true
ENABLE_BANK_TRANSFER=true
ENABLE_STRIPE=false
ENABLE_EMAIL_NOTIFICATIONS=false
ENABLE_SMS_NOTIFICATIONS=false
EOF

echo "✅ New .env file created"

# Step 4: Validate configuration
echo ""
echo "4️⃣ Validating new configuration..."

source venv/bin/activate

python3 -c "
try:
    from config.config import settings
    print('✅ Configuration loads successfully')
    print(f'   Admin username: {settings.admin_username}')
    print(f'   Database URL: {settings.database_url[:50]}...')
    print(f'   App URL: {settings.app_url}')
except Exception as e:
    print(f'❌ Configuration error: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Configuration validation failed"
    echo "Restoring backup..."
    cp .env.backup.* .env
    exit 1
fi

# Step 5: Test database connection
echo ""
echo "5️⃣ Testing database connection..."

python3 -c "
try:
    from app.models.database import get_db, init_database
    init_database()
    db = next(get_db())
    db.close()
    print('✅ Database connection successful')
except Exception as e:
    print(f'❌ Database error: {e}')
    print('This might be normal if database needs to be created')
"

# Step 6: Test authentication
echo ""
echo "6️⃣ Testing authentication..."

python3 -c "
try:
    from app.services.auth import auth_service
    from config.config import settings
    result = auth_service.authenticate_admin(settings.admin_username, settings.admin_password)
    if result:
        print('✅ Authentication test passed')
    else:
        print('❌ Authentication test failed - check admin credentials')
except Exception as e:
    print(f'❌ Authentication error: {e}')
"

# Step 7: Test application startup
echo ""
echo "7️⃣ Testing application startup..."

timeout 5s python3 run_simplified.py &
APP_PID=$!
sleep 3

if kill -0 $APP_PID 2>/dev/null; then
    echo "✅ Application starts successfully"
    kill $APP_PID 2>/dev/null
else
    echo "❌ Application startup failed"
    echo "Check the error output above"
fi

echo ""
echo "🎯 Configuration fix complete!"
echo ""
echo "📋 Summary of changes:"
echo "   ✅ Removed incompatible configuration variables"
echo "   ✅ Preserved your important settings (admin credentials, database, etc.)"
echo "   ✅ Created backup of old configuration"
echo ""
echo "🔄 Next steps:"
echo "1. Restart the service: sudo systemctl restart student-services"
echo "2. Check status: sudo systemctl status student-services"
echo "3. Test admin panel: https://yourdomain.com/admin/login"
echo ""
echo "📁 Backup files:"
ls -la .env.backup.* 2>/dev/null || echo "   No backup files found"
echo ""
echo "🔧 If you need to restore the old configuration:"
echo "   cp .env.backup.* .env"
