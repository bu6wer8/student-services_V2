# Student Services Platform - Simplified Version

This is a simplified version of the Student Services Platform with basic authentication and minimal security complexity.

## Features

- **Simple Admin Authentication**: Basic username/password login without CAPTCHA
- **Admin Dashboard**: Overview of orders, customers, and analytics
- **Order Management**: View and manage customer orders
- **Customer Management**: View customer information and statistics
- **Payment Tracking**: Monitor payment status and history
- **Clean UI**: Modern, responsive admin interface

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy the environment template:
```bash
cp .env.simplified .env
```

Edit `.env` file and update the following required settings:
```
SECRET_KEY=your-secret-key-change-this-in-production-make-it-at-least-32-characters-long
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
DATABASE_URL=sqlite:///./student_services.db
```

### 3. Run the Application

```bash
python run_simplified.py
```

Or run directly:
```bash
python -m uvicorn app.api.main_simplified:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Access Admin Panel

1. Open your browser and go to: `http://localhost:8000/admin/login`
2. Login with your admin credentials (default: admin/admin123)
3. Access the admin dashboard at: `http://localhost:8000/admin`

## File Structure

```
student-services-production/
├── app/
│   ├── api/
│   │   ├── main_simplified.py          # Simplified main application
│   │   └── main.py                     # Original complex application
│   ├── services/
│   │   ├── auth_simplified.py          # Simplified authentication
│   │   └── auth.py                     # Original complex authentication
│   └── models/
│       ├── database.py                 # Database configuration
│       └── models.py                   # Data models
├── config/
│   ├── config_simplified.py            # Simplified configuration
│   └── config.py                       # Original complex configuration
├── templates/
│   ├── admin_login_simplified.html     # Simplified login page
│   ├── admin_dashboard.html            # Admin dashboard
│   ├── admin_orders.html               # Orders management
│   ├── admin_customers.html            # Customer management
│   ├── admin_payments.html             # Payment tracking
│   ├── admin_analytics.html            # Analytics page
│   └── admin_settings.html             # Settings page
├── static/                             # Static files (CSS, JS, images)
├── .env.simplified                     # Environment template
├── run_simplified.py                   # Simplified startup script
└── requirements.txt                    # Python dependencies
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | Secret key for sessions (required) | - |
| `ADMIN_USERNAME` | Admin username | admin |
| `ADMIN_PASSWORD` | Admin password | admin123 |
| `DATABASE_URL` | Database connection string | sqlite:///./student_services.db |
| `DEBUG` | Enable debug mode | true |
| `APP_URL` | Application URL | http://localhost:8000 |

### Database

The simplified version uses SQLite by default. For production, you can use PostgreSQL:

```
DATABASE_URL=postgresql://username:password@localhost/student_services
```

## API Endpoints

### Authentication
- `GET /admin/login` - Login page
- `POST /admin/login` - Login endpoint
- `POST /admin/logout` - Logout endpoint

### Admin Pages
- `GET /admin` - Dashboard
- `GET /admin/orders` - Orders management
- `GET /admin/customers` - Customer management
- `GET /admin/payments` - Payment tracking
- `GET /admin/analytics` - Analytics
- `GET /admin/settings` - Settings

### API Routes (Protected)
- `GET /api/orders` - Get all orders
- `PUT /api/orders/{id}/status` - Update order status
- `GET /api/users` - Get all users

### Utility
- `GET /health` - Health check
- `GET /` - API information

## Security Notes

This simplified version removes complex security measures for easier setup and debugging:

- **No CAPTCHA**: Login form doesn't require CAPTCHA verification
- **No Rate Limiting**: No automatic blocking of failed login attempts
- **Basic Session Management**: Simple session handling without advanced security
- **Minimal Validation**: Basic input validation only

**For production use**, consider implementing additional security measures:
- HTTPS/SSL certificates
- Rate limiting for login attempts
- CAPTCHA for bot protection
- Advanced session security
- Input sanitization and validation
- Security headers and CSRF protection

## Troubleshooting

### Common Issues

1. **Database Connection Error**
   - Check `DATABASE_URL` in `.env` file
   - Ensure database server is running (for PostgreSQL/MySQL)

2. **Authentication Not Working**
   - Verify `ADMIN_USERNAME` and `ADMIN_PASSWORD` in `.env`
   - Check browser cookies are enabled

3. **Static Files Not Loading**
   - Ensure `static/` directory exists
   - Check file permissions

4. **Port Already in Use**
   - Change port in `run_simplified.py` or kill existing process

### Logs

Application logs are displayed in the console. For file logging, check:
- `logs/app.log` (if created)

## Development

To modify the application:

1. **Add New Routes**: Edit `app/api/main_simplified.py`
2. **Update Templates**: Modify files in `templates/`
3. **Change Styling**: Edit CSS files in `static/css/`
4. **Add Features**: Create new modules in `app/`

## Production Deployment

For production deployment:

1. **Update Environment**:
   ```
   ENV=production
   DEBUG=false
   SECRET_KEY=your-production-secret-key
   ```

2. **Use Production Database**:
   ```
   DATABASE_URL=postgresql://user:pass@localhost/student_services
   ```

3. **Set Strong Admin Password**:
   ```
   ADMIN_PASSWORD=your-very-secure-password
   ```

4. **Use HTTPS**: Configure SSL certificates and reverse proxy

5. **Monitor**: Set up logging and monitoring

## Support

For issues and questions:
- Check the troubleshooting section above
- Review application logs
- Ensure all environment variables are set correctly

## License

This project is licensed under the MIT License.
