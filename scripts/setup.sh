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

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
        while [ -z "$input" ]; do
            echo "This field is required!"
            read -p "$prompt: " input
        done
    fi

    eval "$var_name='$input'"
}

# Function to prompt for password
prompt_password() {
    local prompt="$1"
    local var_name="$2"

    read -s -p "$prompt: " input
    echo
    while [ -z "$input" ]; do
        echo "Password is required!"
        read -s -p "$prompt: " input
        echo
    done

    eval "$var_name='$input'"
}

# Function to generate random string
generate_random() {
    openssl rand -hex 32
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This is not recommended for production."
        read -p "Continue anyway? (y/N): " continue_root
        if [ "$continue_root" != "y" ] && [ "$continue_root" != "Y" ]; then
            exit 1
        fi
    fi
}

# Check system requirements
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

    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed"
        exit 1
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git is not installed"
        exit 1
    fi

    print_status "All requirements satisfied"
}

# Install system dependencies (without Python)
install_system_deps() {
    print_header "Installing System Dependencies"

    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian (skip Python)
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib nginx redis-server supervisor
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL (skip Python)
        sudo yum install -y postgresql postgresql-server nginx redis supervisor
    else
        print_warning "Unknown package manager. Please install dependencies manually:"
        print_warning "- PostgreSQL"
        print_warning "- Nginx"
        print_warning "- Redis"
        print_warning "- Supervisor"
    fi
}

# Setup Python virtual environment
setup_venv() {
    print_header "Setting up Python Virtual Environment"

    if [ -d "venv" ]; then
        print_warning "Virtual environment already exists"
        read -p "Remove and recreate? (y/N): " recreate_venv
        if [ "$recreate_venv" = "y" ] || [ "$recreate_venv" = "Y" ]; then
            rm -rf venv
        else
            return
        fi
    fi

    python3 -m venv venv
    source venv/bin/activate

    print_status "Installing Python packages..."
    pip install --upgrade pip
    pip install -r requirements.txt

    print_status "Virtual environment created successfully"
}

# Collect configuration
collect_config() {
    print_header "Configuration Setup"
    echo "Please provide the following configuration details:"
    echo

    # Basic settings
    prompt_input "Environment (development/production)" "production" ENV
    prompt_input "Debug mode (true/false)" "false" DEBUG
    prompt_input "Application URL" "https://yourdomain.com" APP_URL

    # Database configuration
    print_status "Database Configuration"
    prompt_input "Database host" "localhost" DB_HOST
    prompt_input "Database port" "5432" DB_PORT
    prompt_input "Database name" "student_services" DB_NAME
    prompt_input "Database user" "student_services" DB_USER
    prompt_password "Database password" DB_PASSWORD

    # Telegram Bot configuration
    print_status "Telegram Bot Configuration"
    prompt_input "Telegram Bot Token (from @BotFather)" "" TELEGRAM_BOT_TOKEN
    prompt_input "Telegram Admin ID (your user ID)" "" TELEGRAM_ADMIN_ID

    # Stripe payment
    print_status "Stripe Payment Configuration"
    prompt_input "Stripe Public Key" "" STRIPE_PUBLIC_KEY
    prompt_input "Stripe Secret Key" "" STRIPE_SECRET_KEY
    prompt_input "Stripe Webhook Secret" "" STRIPE_WEBHOOK_SECRET

    # Email configuration
    print_status "Email Configuration (Optional)"
    prompt_input "SMTP Host" "smtp.gmail.com" SMTP_HOST
    prompt_input "SMTP Port" "587" SMTP_PORT
    prompt_input "SMTP User" "" SMTP_USER
    prompt_password "SMTP Password" SMTP_PASSWORD

    # Security
    print_status "Security Configuration"
    SECRET_KEY=$(generate_random)
    print_status "Generated secret key: ${SECRET_KEY:0:16}..."

    # Bank details
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
# Environment Configuration
ENV=$ENV
DEBUG=$DEBUG
APP_URL=$APP_URL

# Database Configuration
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME
REDIS_URL=redis://localhost:6379

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
telegram_bot_token=$TELEGRAM_BOT_TOKEN
TELEGRAM_ADMIN_ID=$TELEGRAM_ADMIN_ID
telegram_admin_id=$TELEGRAM_ADMIN_ID

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
SECRET_KEY=$SECRET_KEY
secret_key=$SECRET_KEY
ALGORITHM=HS256

# Stripe Payment Configuration
STRIPE_PUBLIC_KEY=$STRIPE_PUBLIC_KEY
stripe_public_key=$STRIPE_PUBLIC_KEY
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
stripe_secret_key=$STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET

# Email Configuration
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD

# File Storage
UPLOAD_DIR=./static/uploads
DOWNLOAD_DIR=./static/downloads
MAX_FILE_SIZE=10485760

# Bank Transfer Details
BANK_NAME=$BANK_NAME
BANK_ACCOUNT_NAME=$BANK_ACCOUNT_NAME
BANK_ACCOUNT_NUMBER=$BANK_ACCOUNT_NUMBER
BANK_IBAN=$BANK_IBAN
BANK_SWIFT=$BANK_SWIFT

# Pricing Configuration
BASE_PRICE_ASSIGNMENT=20.0
BASE_PRICE_PROJECT=50.0
BASE_PRICE_PRESENTATION=30.0
URGENCY_MULTIPLIER_24H=2.0

# Business Settings
BUSINESS_NAME=Student Services Platform
SUPPORT_EMAIL=support@yourdomain.com
SUPPORT_TELEGRAM=@your_support
EOF

    print_status "Environment file created"
}

# The rest of the script (setup_database, setup_nginx, setup_services, start_services, setup_ssl, backup, final_setup) remains unchanged
# You can keep the previous implementations for these functions

# Main installation function
main() {
    print_header "Student Services Platform Setup"
    echo "This script will set up the complete Student Services Platform"
    echo

    read -p "Continue with installation? (y/N): " continue_install
    if [ "$continue_install" != "y" ] && [ "$continue_install" != "Y" ]; then
        echo "Installation cancelled"
        exit 0
    fi

    check_root
    check_requirements

    read -p "Install system dependencies? (y/N): " install_deps
    if [ "$install_deps" = "y" ] || [ "$install_deps" = "Y" ]; then
        install_system_deps
    fi

    setup_venv
    collect_config
    create_env_file

    # Continue with database, Nginx, services, backups, final setup
    setup_database
    setup_nginx
    setup_services
    start_services
    create_backup_script
    final_setup

    print_header "Installation Complete!"
    print_status "Your Student Services Platform is now running!"
}

# Run main function
main "$@"
