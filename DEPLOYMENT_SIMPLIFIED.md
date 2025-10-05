# Student Services Platform - Simplified Deployment Guide

This guide covers deploying the simplified version of the Student Services Platform with basic authentication.

## Quick Start (Local Development)

### 1. Download and Extract
```bash
# Download the simplified package
unzip student-services-simplified-fixed.zip
cd student-services-simplified
```

### 2. Install Dependencies
```bash
# Install Python dependencies
pip install -r requirements_simplified.txt
```

### 3. Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit configuration (required)
nano .env
```

**Required Settings:**
```env
SECRET_KEY=your-secret-key-change-this-in-production-make-it-at-least-32-characters-long
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
DATABASE_URL=sqlite:///./student_services.db
```

### 4. Test the System
```bash
# Run authentication tests
python test_auth.py
```

### 5. Start the Application
```bash
# Start the server
python run_simplified.py
```

### 6. Access Admin Panel
- Open browser: `http://localhost:8000/admin/login`
- Login with your admin credentials
- Access dashboard: `http://localhost:8000/admin`

## Production Deployment

### Option 1: VPS/Server Deployment

#### 1. Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and dependencies
sudo apt install python3 python3-pip python3-venv nginx -y

# Create application user
sudo useradd -m -s /bin/bash student-services
sudo su - student-services
```

#### 2. Application Setup
```bash
# Clone or upload your code
git clone https://github.com/yourusername/student-services-simplified.git
cd student-services-simplified

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements_simplified.txt
```

#### 3. Production Configuration
```bash
# Create production environment file
cp .env.example .env
nano .env
```

**Production Settings:**
```env
ENV=production
DEBUG=false
APP_URL=https://yourdomain.com
SECRET_KEY=your-very-secure-production-secret-key-at-least-32-characters
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-very-secure-admin-password
DATABASE_URL=postgresql://username:password@localhost/student_services
```

#### 4. Database Setup (PostgreSQL)
```bash
# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Create database
sudo -u postgres psql
CREATE DATABASE student_services;
CREATE USER student_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE student_services TO student_user;
\q
```

#### 5. Systemd Service
```bash
# Create service file
sudo nano /etc/systemd/system/student-services.service
```

```ini
[Unit]
Description=Student Services Platform
After=network.target

[Service]
Type=simple
User=student-services
WorkingDirectory=/home/student-services/student-services-simplified
Environment=PATH=/home/student-services/student-services-simplified/venv/bin
ExecStart=/home/student-services/student-services-simplified/venv/bin/python run_simplified.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable student-services
sudo systemctl start student-services
sudo systemctl status student-services
```

#### 6. Nginx Configuration
```bash
# Create Nginx config
sudo nano /etc/nginx/sites-available/student-services
```

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        alias /home/student-services/student-services-simplified/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/student-services /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

#### 7. SSL Certificate (Let's Encrypt)
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Option 2: Docker Deployment

#### 1. Create Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements_simplified.txt .
RUN pip install --no-cache-dir -r requirements_simplified.txt

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p logs static/uploads static/downloads

# Expose port
EXPOSE 8000

# Run application
CMD ["python", "run_simplified.py"]
```

#### 2. Create docker-compose.yml
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ENV=production
      - DEBUG=false
      - DATABASE_URL=postgresql://student_user:secure_password@db:5432/student_services
      - SECRET_KEY=your-very-secure-production-secret-key
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=your-secure-admin-password
    depends_on:
      - db
    volumes:
      - ./static/uploads:/app/static/uploads
      - ./static/downloads:/app/static/downloads
      - ./logs:/app/logs

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=student_services
      - POSTGRES_USER=student_user
      - POSTGRES_PASSWORD=secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app

volumes:
  postgres_data:
```

#### 3. Deploy with Docker
```bash
# Build and start
docker-compose up -d

# Check logs
docker-compose logs -f app

# Stop
docker-compose down
```

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ENV` | Environment (development/production) | development | No |
| `DEBUG` | Enable debug mode | true | No |
| `APP_URL` | Application URL | http://localhost:8000 | No |
| `SECRET_KEY` | Secret key for sessions | - | **Yes** |
| `ADMIN_USERNAME` | Admin username | admin | **Yes** |
| `ADMIN_PASSWORD` | Admin password | admin123 | **Yes** |
| `DATABASE_URL` | Database connection string | sqlite:///./student_services.db | **Yes** |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | - | No |
| `STRIPE_PUBLIC_KEY` | Stripe public key | - | No |
| `STRIPE_SECRET_KEY` | Stripe secret key | - | No |

## Security Checklist

### For Production:
- [ ] Change default admin password
- [ ] Use strong SECRET_KEY (32+ characters)
- [ ] Use PostgreSQL instead of SQLite
- [ ] Enable HTTPS/SSL
- [ ] Set secure environment variables
- [ ] Configure firewall
- [ ] Regular backups
- [ ] Monitor logs
- [ ] Update dependencies regularly

### Optional Security Enhancements:
- [ ] Add rate limiting
- [ ] Implement CAPTCHA
- [ ] Add IP whitelisting
- [ ] Enable audit logging
- [ ] Add two-factor authentication
- [ ] Implement CSRF protection

## Troubleshooting

### Common Issues:

1. **Authentication fails**
   - Check ADMIN_USERNAME and ADMIN_PASSWORD in .env
   - Verify SECRET_KEY is set and long enough
   - Clear browser cookies

2. **Database connection error**
   - Verify DATABASE_URL format
   - Check database server is running
   - Ensure database exists and user has permissions

3. **Static files not loading**
   - Check static directory permissions
   - Verify Nginx configuration
   - Ensure static files exist

4. **Application won't start**
   - Check logs: `sudo journalctl -u student-services -f`
   - Verify all dependencies installed
   - Check port availability

### Logs:
- Application logs: `logs/app.log`
- System logs: `sudo journalctl -u student-services`
- Nginx logs: `/var/log/nginx/`

## Backup and Maintenance

### Database Backup:
```bash
# PostgreSQL
pg_dump -U student_user -h localhost student_services > backup.sql

# SQLite
cp student_services.db backup_$(date +%Y%m%d).db
```

### Application Update:
```bash
# Pull latest code
git pull origin main

# Update dependencies
pip install -r requirements_simplified.txt

# Restart service
sudo systemctl restart student-services
```

### Monitoring:
```bash
# Check service status
sudo systemctl status student-services

# View logs
sudo journalctl -u student-services -f

# Check disk space
df -h

# Check memory usage
free -h
```

## Support

For deployment issues:
1. Check the troubleshooting section
2. Review application logs
3. Verify all environment variables are set
4. Test with the included `test_auth.py` script

## License

This project is licensed under the MIT License.
