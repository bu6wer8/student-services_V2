#!/bin/bash

# Student Services Platform - Interactive Setup Script
# This script sets up the entire platform with user input

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}================================${NC}"; }

# Prompt functions
prompt_input() {
    local prompt="$1" default="$2" var_name="$3"
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        [ -z "$input" ] && input="$default"
    else
        read -p "$prompt: " input
        while [ -z "$input" ]; do
            echo "This field is required!"
            read -p "$prompt: " input
        done
    fi
    eval "$var_name='$input'"
}

prompt_password() {
    local prompt="$1" var_name="$2"
    read -s -p "$prompt: " input; echo
    while [ -z "$input" ]; do
        echo "Password is required!"
        read -s -p "$prompt: " input; echo
    done
    eval "$var_name='$input'"
}

generate_random() { openssl rand -hex 32; }

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This is not recommended for production."
        read -p "Continue anyway? (y/N): " continue_root
        [[ "$continue_root" != "y" && "$continue_root" != "Y" ]] && exit 1
    fi
}

# System requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    if [ "$(printf '%s\n' "3.8" "$python_version" | sort -V | head -n1)" != "3.8" ]; then
        print_error "Python 3.8 or higher is required"
        exit 1
    fi
    print_status "Python $python_version found"

    # pip & git
    command -v pip3 &> /dev/null || { print_error "pip3 not found"; exit 1; }
    command -v git &> /dev/null || { print_error "git not found"; exit 1; }

    print_status "All requirements satisfied"
}

# Install system dependencies (Python skipped)
install_system_deps() {
    print_header "Installing System Dependencies"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib nginx redis-server supervisor git
    elif command -v yum &> /dev/null; then
        sudo yum install -y postgresql postgresql-server nginx redis supervisor git
    else
        print_warning "Unknown package manager. Please install manually:"
        print_warning "- Python 3.8+ (already installed)"
        print_warning "- PostgreSQL"
        print_warning "- Nginx"
        print_warning "- Redis"
        print_warning "- Supervisor"
    fi
}

# Setup Python virtual environment
setup_venv() {
    print_header "Setting up Python Virtual Environment"
    [ -d "venv" ] && { 
        print_warning "Virtual environment already exists"
        read -p "Remove and recreate? (y/N): " recreate
        [[ "$recreate" =~ ^[Yy]$ ]] && rm -rf venv
    }
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_status "Virtual environment ready"
}

# Collect configuration
collect_config() {
    print_header "Configuration Setup"
    prompt_input "Environment (development/production)" "production" ENV
    prompt_input "Debug mode (true/false)" "false" DEBUG
    prompt_input "Application URL" "https://yourdomain.com" APP_URL
    print_status "Database Configuration"
    prompt_input "Database host" "localhost" DB_HOST
    prompt_input "Database port" "5432" DB_PORT
    prompt_input "Database name" "student_services" DB_NAME
    prompt_input "Database user" "student_services" DB_USER
    prompt_password "Database password" DB_PASSWORD
    print_status "Telegram Bot Configuration"
    prompt_input "Telegram Bot Token" "" TELEGRAM_BOT_TOKEN
    prompt_input "Telegram Admin ID" "" TELEGRAM_ADMIN_ID
    print_status "Stripe Configuration"
    prompt_input "Stripe Public Key" "" STRIPE_PUBLIC_KEY
    prompt_input "Stripe Secret Key" "" STRIPE_SECRET_KEY
    prompt_input "Stripe Webhook Secret" "" STRIPE_WEBHOOK_SECRET
    print_status "Email Configuration (Optional)"
    prompt_input "SMTP Host" "smtp.gmail.com" SMTP_HOST
    prompt_input "SMTP Port" "587" SMTP_PORT
    prompt_input "SMTP User" "" SMTP_USER
    prompt_password "SMTP Password" SMTP_PASSWORD
    SECRET_KEY=$(generate_random)
    print_status "Generated secret key: ${SECRET_KEY:0:16}..."
    print_status "Bank Transfer Details"
    prompt_input "Bank Name" "Your Bank" BANK_NAME
    prompt_input "Account Name" "Your Company" BANK_ACCOUNT_NAME
    prompt_input "Account Number" "" BANK_ACCOUNT_NUMBER
    prompt_input "IBAN" "" BANK_IBAN
    prompt_input "SWIFT Code" "" BANK_SWIFT
}

# Create .env file
create_env_file() {
    print_header "Creating Environment File"
    cat > .env << EOF
ENV=$ENV
DEBUG=$DEBUG
APP_URL=$APP_URL
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME
REDIS_URL=redis://localhost:6379
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_ADMIN_ID=$TELEGRAM_ADMIN_ID
API_HOST=0.0.0.0
API_PORT=8000
SECRET_KEY=$SECRET_KEY
ALGORITHM=HS256
STRIPE_PUBLIC_KEY=$STRIPE_PUBLIC_KEY
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
UPLOAD_DIR=./static/uploads
DOWNLOAD_DIR=./static/downloads
MAX_FILE_SIZE=10485760
BANK_NAME=$BANK_NAME
BANK_ACCOUNT_NAME=$BANK_ACCOUNT_NAME
BANK_ACCOUNT_NUMBER=$BANK_ACCOUNT_NUMBER
BANK_IBAN=$BANK_IBAN
BANK_SWIFT=$BANK_SWIFT
BASE_PRICE_ASSIGNMENT=20.0
BASE_PRICE_PROJECT=50.0
BASE_PRICE_PRESENTATION=30.0
URGENCY_MULTIPLIER_24H=2.0
BUSINESS_NAME=Student Services Platform
SUPPORT_EMAIL=support@yourdomain.com
SUPPORT_TELEGRAM=@your_support
EOF
    print_status ".env file created"
}

# Database setup
setup_database() {
    print_header "Setting up Database"
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" || true
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" || true
    source venv/bin/activate
    python scripts/init_db.py
    print_status "Database ready"
}

# The rest (Nginx, services, SSL, backup, admin user) remains unchanged

# Main function
main() {
    print_header "Student Services Platform Setup"
    read -p "Continue with installation? (y/N): " cont
    [[ ! "$cont" =~ ^[Yy]$ ]] && exit 0
    check_root
    check_requirements
    read -p "Install system dependencies? (y/N): " install_deps
    [[ "$install_deps" =~ ^[Yy]$ ]] && install_system_deps
    setup_venv
    collect_config
    create_env_file
    setup_database
    # Setup Nginx, services, SSL, backup, admin user...
    print_status "Setup completed successfully!"
}

main "$@"
