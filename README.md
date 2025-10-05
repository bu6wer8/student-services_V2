# Student Services Platform

A comprehensive academic writing services platform with Telegram bot integration, admin panel, and payment processing.

## 🚀 Features

### 📝 Core Services
- **Assignment Writing** - Essays, reports, homework
- **Project Development** - Research projects, case studies  
- **Presentation Creation** - PowerPoint, slides
- **Document Redesign** - Improve existing work
- **Content Summarization** - Summarize documents
- **Express Services** - Urgent work (24h or less)

### 🤖 Telegram Bot
- **Interactive Order Placement** - Step-by-step order creation
- **Real-time Updates** - Order status notifications
- **File Upload/Download** - Requirement and delivery files
- **Payment Integration** - Stripe and bank transfer support
- **Multi-language Support** - English, Arabic, and more
- **Customer Support** - Direct communication channel

### 💳 Payment Processing
- **Stripe Integration** - Credit/debit card payments
- **Bank Transfer** - Manual verification system
- **Multi-currency Support** - USD, JOD, AED, SAR, EUR
- **Automatic Pricing** - Dynamic pricing based on urgency and academic level
- **Secure Webhooks** - Real-time payment status updates

### 🎛️ Admin Panel
- **Dashboard** - Overview of orders, revenue, statistics
- **Order Management** - Track and update order status
- **Customer Management** - User profiles and history
- **Payment Tracking** - Payment verification and refunds
- **Analytics** - Business insights and reports
- **Settings** - Platform configuration

### 🔧 Technical Features
- **FastAPI Backend** - High-performance async API
- **PostgreSQL Database** - Robust data storage
- **Redis Caching** - Fast data access
- **Nginx Reverse Proxy** - Production web server
- **SSL/HTTPS Support** - Secure connections
- **Automated Backups** - Data protection
- **Systemd Services** - Reliable service management
- **Docker Support** - Containerized deployment

## 📋 Requirements

### System Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **Python**: 3.8 or higher
- **Memory**: 2GB RAM minimum (4GB recommended)
- **Storage**: 10GB free space minimum
- **Network**: Internet connection for external services

### External Services
- **Telegram Bot Token** - From [@BotFather](https://t.me/botfather)
- **Stripe Account** - For payment processing
- **Domain Name** - For production deployment
- **Email Service** - For notifications (optional)

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/student-services-platform.git
cd student-services-platform
```

### 2. Run Interactive Setup
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The setup script will:
- Install system dependencies
- Create Python virtual environment
- Configure database
- Set up web server
- Create system services
- Configure SSL (optional)

### 3. Access Your Platform
- **Web Interface**: `https://yourdomain.com`
- **Admin Panel**: `https://yourdomain.com/admin`
- **API Documentation**: `https://yourdomain.com/api/docs`

## 🔧 Manual Installation

### 1. System Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y python3 python3-venv python3-pip postgresql postgresql-contrib nginx redis-server supervisor

# CentOS/RHEL
sudo yum install -y python3 python3-venv python3-pip postgresql postgresql-server nginx redis supervisor
```

### 2. Python Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Database Setup
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database
sudo -u postgres createdb student_services
sudo -u postgres createuser student_services
sudo -u postgres psql -c "ALTER USER student_services WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE student_services TO student_services;"
```

### 4. Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 5. Initialize Database
```bash
python scripts/init_db.py
```

### 6. Start Services
```bash
# Web application
uvicorn app.api.main:app --host 0.0.0.0 --port 8000

# Telegram bot
python app/bot/bot.py
```

## ⚙️ Configuration

### Environment Variables

#### Core Settings
```env
ENV=production
DEBUG=false
APP_URL=https://yourdomain.com
SECRET_KEY=your-secret-key
```

#### Database
```env
DATABASE_URL=postgresql://user:password@localhost:5432/student_services
REDIS_URL=redis://localhost:6379
```

#### Telegram Bot
```env
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_ADMIN_ID=your-telegram-user-id
```

#### Payment Processing
```env
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

#### Email (Optional)
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Pricing Configuration
```env
BASE_PRICE_ASSIGNMENT=20.0
BASE_PRICE_PROJECT=50.0
BASE_PRICE_PRESENTATION=30.0
URGENCY_MULTIPLIER_24H=2.0
```

## 🎛️ Admin Panel

### Access
- URL: `https://yourdomain.com/admin`
- Default credentials: Set during installation

### Features
- **Dashboard**: Overview of platform statistics
- **Orders**: Manage all customer orders
- **Customers**: View and manage user accounts
- **Payments**: Track and verify payments
- **Analytics**: Business insights and reports
- **Settings**: Platform configuration

### Order Management
1. **View Orders**: See all orders with status and details
2. **Update Status**: Change order status (pending → in_progress → delivered → completed)
3. **Upload Files**: Deliver completed work to customers
4. **Communication**: Add notes and communicate with customers

### Payment Verification
1. **Stripe Payments**: Automatically verified via webhooks
2. **Bank Transfers**: Manual verification with receipt upload
3. **Refunds**: Process refunds for cancelled orders

## 🤖 Telegram Bot

### Setup
1. Create bot with [@BotFather](https://t.me/botfather)
2. Get bot token
3. Add token to configuration
4. Start bot service

### Features
- **Order Creation**: Interactive order placement
- **File Upload**: Upload requirement files
- **Payment**: Choose payment method and complete payment
- **Status Updates**: Real-time order status notifications
- **Support**: Direct communication with admin

### Commands
- `/start` - Start the bot and show main menu
- `/orders` - View your orders
- `/help` - Show help information
- `/cancel` - Cancel current operation

## 💳 Payment Integration

### Stripe Setup
1. Create Stripe account
2. Get API keys from dashboard
3. Configure webhook endpoint: `https://yourdomain.com/webhook/stripe`
4. Add webhook events: `checkout.session.completed`, `payment_intent.succeeded`

### Bank Transfer
1. Configure bank details in settings
2. Customers upload payment receipts
3. Admin verifies payments manually
4. Automatic order confirmation upon verification

### Supported Currencies
- USD (US Dollar)
- JOD (Jordanian Dinar)
- AED (UAE Dirham)
- SAR (Saudi Riyal)
- EUR (Euro)

## 🔒 Security

### SSL/HTTPS
```bash
# Install Let's Encrypt
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d yourdomain.com
```

### Security Headers
- X-Frame-Options
- X-XSS-Protection
- X-Content-Type-Options
- Content-Security-Policy

### Data Protection
- Password hashing with bcrypt
- JWT token authentication
- SQL injection prevention
- XSS protection

## 📊 Monitoring

### Service Status
```bash
# Check web application
sudo systemctl status student-services-web

# Check Telegram bot
sudo systemctl status student-services-bot

# Check logs
sudo journalctl -u student-services-web -f
sudo journalctl -u student-services-bot -f
```

### Application Logs
```bash
# Application logs
tail -f logs/app.log
tail -f logs/bot.log

# Error logs
tail -f logs/error.log
```

### Health Checks
- **Web**: `GET /health`
- **Database**: Connection monitoring
- **Redis**: Cache availability
- **External Services**: Stripe, Telegram API

## 🔄 Backup & Recovery

### Automated Backups
```bash
# Run backup script
./scripts/backup.sh

# Schedule daily backups (already configured)
crontab -l
```

### Manual Backup
```bash
# Database backup
pg_dump student_services > backup.sql

# Files backup
tar -czf files_backup.tar.gz static/uploads uploaded_works

# Configuration backup
cp .env env_backup
```

### Recovery
```bash
# Restore database
psql student_services < backup.sql

# Restore files
tar -xzf files_backup.tar.gz

# Restore configuration
cp env_backup .env
```

## 🚀 Deployment

### Production Checklist
- [ ] Domain configured and pointing to server
- [ ] SSL certificate installed
- [ ] Database secured
- [ ] Firewall configured
- [ ] Backups scheduled
- [ ] Monitoring set up
- [ ] Error tracking configured

### Scaling
- **Horizontal**: Multiple server instances with load balancer
- **Vertical**: Increase server resources
- **Database**: Read replicas, connection pooling
- **Caching**: Redis cluster, CDN for static files

## 🛠️ Development

### Local Development
```bash
# Clone repository
git clone https://github.com/yourusername/student-services-platform.git
cd student-services-platform

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up local database
createdb student_services_dev

# Configure environment
cp .env.example .env.dev
# Edit .env.dev with local settings

# Run migrations
python scripts/init_db.py

# Start development server
uvicorn app.api.main:app --reload --host 0.0.0.0 --port 8000

# Start bot (in another terminal)
python app/bot/bot.py
```

### Code Structure
```
student-services-platform/
├── app/
│   ├── api/           # FastAPI application
│   ├── bot/           # Telegram bot
│   ├── models/        # Database models
│   ├── services/      # Business logic
│   └── utils/         # Utilities
├── templates/         # HTML templates
├── static/           # CSS, JS, images
├── config/           # Configuration files
├── scripts/          # Setup and utility scripts
├── logs/             # Application logs
└── docs/             # Documentation
```

### Testing
```bash
# Run tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test
pytest tests/test_orders.py
```

## 📚 API Documentation

### Interactive Documentation
- **Swagger UI**: `https://yourdomain.com/api/docs`
- **ReDoc**: `https://yourdomain.com/api/redoc`

### Key Endpoints
- `GET /health` - Health check
- `GET /admin` - Admin dashboard
- `GET /api/orders` - List orders
- `POST /api/orders` - Create order
- `PUT /api/orders/{id}/status` - Update order status
- `POST /webhook/stripe` - Stripe webhook

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Documentation
- [Installation Guide](docs/installation.md)
- [Configuration Guide](docs/configuration.md)
- [API Reference](docs/api.md)
- [Troubleshooting](docs/troubleshooting.md)

### Community
- **Issues**: [GitHub Issues](https://github.com/yourusername/student-services-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/student-services-platform/discussions)
- **Email**: support@yourdomain.com

### Professional Support
For professional support, custom development, or enterprise features, contact us at enterprise@yourdomain.com

## 🎯 Roadmap

### Version 2.1
- [ ] Mobile app (React Native)
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] API rate limiting
- [ ] Advanced user roles

### Version 2.2
- [ ] AI-powered content analysis
- [ ] Automated quality checks
- [ ] Integration with academic databases
- [ ] Advanced reporting
- [ ] White-label solution

### Version 3.0
- [ ] Microservices architecture
- [ ] GraphQL API
- [ ] Real-time collaboration
- [ ] Advanced AI features
- [ ] Enterprise features

---

**Made with ❤️ for academic success**
