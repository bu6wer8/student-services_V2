#!/usr/bin/env python3
"""
Student Services Platform - Enhanced Main API Application
Production-ready FastAPI application with secure admin authentication and CAPTCHA
"""

import os
import sys
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from fastapi import FastAPI, Request, HTTPException, Depends, Form, File, UploadFile, Cookie, Response
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
import uvicorn

# Import application modules
from app.models.database import get_db, init_database
from app.models.models import Order, User, Payment, Feedback
from app.services.payment import PaymentService
from app.services.notification import NotificationService
from app.services.auth import auth_service, get_current_admin, require_admin_auth
from app.utils.utils import format_currency, get_user_ip, sanitize_input
from config.config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[
        logging.FileHandler("logs/app.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("student-services")

# Initialize FastAPI app
app = FastAPI(
    title="Student Services Platform",
    description="Academic writing services platform with secure admin panel",
    version="2.1.0",
    docs_url="/api/docs" if settings.debug else None,
    redoc_url="/api/redoc" if settings.debug else None
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.debug else [settings.app_url],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Initialize templates
templates = Jinja2Templates(directory="templates")

# Initialize services
payment_service = PaymentService()
notification_service = NotificationService()

# Security middleware
@app.middleware("http")
async def security_middleware(request: Request, call_next):
    """
    Security middleware for headers and basic protection
    """
    response = await call_next(request)
    
    # Security headers
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"] = "default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data: blob:"
    
    # Remove server header
    if "server" in response.headers:
        del response.headers["server"]
    
    return response

# Cleanup middleware
@app.middleware("http")
async def cleanup_middleware(request: Request, call_next):
    """
    Cleanup expired sessions and rate limits
    """
    # Cleanup expired sessions periodically
    if hasattr(auth_service, 'cleanup_expired_sessions'):
        auth_service.cleanup_expired_sessions()
    
    response = await call_next(request)
    return response

# -------------------------------------------------
# Authentication Routes
# -------------------------------------------------

@app.get("/admin/login", response_class=HTMLResponse)
async def admin_login_page(request: Request, error: Optional[str] = None):
    """
    Admin login page
    """
    # Check if already logged in
    session_id = request.cookies.get("admin_session")
    if session_id:
        ip_address = auth_service.get_client_ip(request)
        session_data = auth_service.verify_session(session_id, ip_address)
        if session_data:
            return RedirectResponse(url="/admin", status_code=302)
    
    # Check rate limiting
    ip_address = auth_service.get_client_ip(request)
    rate_limited = auth_service.rate_limiter.is_rate_limited(ip_address)
    lockout_time = auth_service.rate_limiter.get_lockout_time(ip_address)
    
    return templates.TemplateResponse("admin_login.html", {
        "request": request,
        "error": error,
        "rate_limited": rate_limited,
        "lockout_time": lockout_time or 0
    })

@app.get("/admin/captcha")
async def get_captcha():
    """
    Generate CAPTCHA for login form
    """
    try:
        captcha_data = auth_service.captcha_service.generate_captcha()
        return JSONResponse(captcha_data)
    except Exception as e:
        logger.error(f"Error generating CAPTCHA: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate CAPTCHA")

@app.post("/admin/login")
async def admin_login(
    request: Request,
    response: Response,
    username: str = Form(...),
    password: str = Form(...),
    captcha_answer: str = Form(...),
    captcha_token: str = Form(...)
):
    """
    Admin login endpoint with CAPTCHA and rate limiting
    """
    ip_address = auth_service.get_client_ip(request)
    
    try:
        # Check rate limiting
        if auth_service.rate_limiter.is_rate_limited(ip_address):
            lockout_time = auth_service.rate_limiter.get_lockout_time(ip_address)
            auth_service.log_security_event("rate_limited_login", ip_address, {
                "username": username,
                "lockout_time": lockout_time
            })
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Too many failed attempts. Please wait before trying again.",
                    "rate_limited": True,
                    "lockout_time": lockout_time
                }
            )
        
        # Verify CAPTCHA
        if not auth_service.captcha_service.verify_captcha(captcha_token, captcha_answer):
            auth_service.rate_limiter.record_attempt(ip_address, success=False)
            auth_service.log_security_event("invalid_captcha", ip_address, {
                "username": username
            })
            return JSONResponse(
                status_code=400,
                content={"detail": "Invalid CAPTCHA. Please try again."}
            )
        
        # Authenticate user
        if not auth_service.authenticate_admin(username, password):
            auth_service.rate_limiter.record_attempt(ip_address, success=False)
            auth_service.log_security_event("failed_login", ip_address, {
                "username": username
            })
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid username or password."}
            )
        
        # Successful login
        auth_service.rate_limiter.record_attempt(ip_address, success=True)
        session_id = auth_service.create_session(username, ip_address)
        
        # Set secure cookie
        response.set_cookie(
            key="admin_session",
            value=session_id,
            max_age=8 * 60 * 60,  # 8 hours
            httponly=True,
            secure=not settings.debug,  # HTTPS only in production
            samesite="lax"
        )
        
        auth_service.log_security_event("successful_login", ip_address, {
            "username": username,
            "session_id": session_id[:8] + "..."
        })
        
        logger.info(f"Admin login successful: {username} from {ip_address}")
        
        return JSONResponse(
            status_code=200,
            content={"detail": "Login successful", "redirect": "/admin"}
        )
        
    except Exception as e:
        logger.error(f"Login error: {e}")
        auth_service.log_security_event("login_error", ip_address, {
            "username": username,
            "error": str(e)
        })
        return JSONResponse(
            status_code=500,
            content={"detail": "An error occurred during login. Please try again."}
        )

@app.post("/admin/logout")
async def admin_logout(request: Request, response: Response):
    """
    Admin logout endpoint
    """
    session_id = request.cookies.get("admin_session")
    if session_id:
        auth_service.invalidate_session(session_id)
        response.delete_cookie("admin_session")
        
        ip_address = auth_service.get_client_ip(request)
        auth_service.log_security_event("logout", ip_address, {
            "session_id": session_id[:8] + "..."
        })
    
    return RedirectResponse(url="/admin/login", status_code=302)

# -------------------------------------------------
# Protected Admin Routes
# -------------------------------------------------

@app.get("/admin", response_class=HTMLResponse)
async def admin_dashboard(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin dashboard - main overview page
    """
    try:
        db = next(get_db())
        
        # Get dashboard statistics
        total_orders = db.query(Order).count()
        pending_orders = db.query(Order).filter(Order.status == 'pending').count()
        completed_orders = db.query(Order).filter(Order.status == 'completed').count()
        total_users = db.query(User).count()
        
        # Recent orders
        recent_orders = db.query(Order).order_by(Order.created_at.desc()).limit(10).all()
        
        # Revenue calculation
        total_revenue = db.query(Order).filter(Order.payment_status == 'paid').with_entities(
            db.func.sum(Order.total_amount)
        ).scalar() or 0
        
        db.close()
        
        return templates.TemplateResponse("admin_dashboard.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "total_orders": total_orders,
            "pending_orders": pending_orders,
            "completed_orders": completed_orders,
            "total_users": total_users,
            "total_revenue": total_revenue,
            "recent_orders": recent_orders
        })
        
    except Exception as e:
        logger.error(f"Error loading admin dashboard: {e}")
        raise HTTPException(status_code=500, detail="Error loading dashboard")

@app.get("/admin/orders", response_class=HTMLResponse)
async def admin_orders(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin orders management page
    """
    try:
        db = next(get_db())
        
        # Get all orders with user information
        orders = db.query(Order).join(User).order_by(Order.created_at.desc()).all()
        
        db.close()
        
        return templates.TemplateResponse("admin_orders.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "orders": orders
        })
        
    except Exception as e:
        logger.error(f"Error loading admin orders: {e}")
        raise HTTPException(status_code=500, detail="Error loading orders")

@app.get("/admin/customers", response_class=HTMLResponse)
async def admin_customers(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin customers management page
    """
    try:
        db = next(get_db())
        
        # Get all users with order statistics
        users = db.query(User).all()
        
        # Add order statistics for each user
        for user in users:
            user.order_count = db.query(Order).filter(Order.user_id == user.id).count()
            user.total_spent = db.query(Order).filter(
                Order.user_id == user.id,
                Order.payment_status == 'paid'
            ).with_entities(db.func.sum(Order.total_amount)).scalar() or 0
        
        db.close()
        
        return templates.TemplateResponse("admin_customers.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "customers": users
        })
        
    except Exception as e:
        logger.error(f"Error loading admin customers: {e}")
        raise HTTPException(status_code=500, detail="Error loading customers")

@app.get("/admin/payments", response_class=HTMLResponse)
async def admin_payments(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin payments management page
    """
    try:
        db = next(get_db())
        
        # Get all payments
        payments = db.query(Payment).join(Order).join(User).order_by(Payment.created_at.desc()).all()
        
        db.close()
        
        return templates.TemplateResponse("admin_payments.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "payments": payments
        })
        
    except Exception as e:
        logger.error(f"Error loading admin payments: {e}")
        raise HTTPException(status_code=500, detail="Error loading payments")

@app.get("/admin/analytics", response_class=HTMLResponse)
async def admin_analytics(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin analytics and reports page
    """
    try:
        db = next(get_db())
        
        # Get analytics data
        analytics_data = {
            'total_orders': db.query(Order).count(),
            'total_revenue': db.query(Order).filter(Order.payment_status == 'paid').with_entities(
                db.func.sum(Order.total_amount)
            ).scalar() or 0,
            'avg_order_value': db.query(Order).filter(Order.payment_status == 'paid').with_entities(
                db.func.avg(Order.total_amount)
            ).scalar() or 0,
            'conversion_rate': 0  # Calculate based on your metrics
        }
        
        # Monthly revenue data (last 12 months)
        monthly_revenue = []
        for i in range(12):
            month_start = datetime.now().replace(day=1) - timedelta(days=30*i)
            month_end = month_start.replace(day=28) + timedelta(days=4)
            
            revenue = db.query(Order).filter(
                Order.payment_status == 'paid',
                Order.created_at >= month_start,
                Order.created_at < month_end
            ).with_entities(db.func.sum(Order.total_amount)).scalar() or 0
            
            monthly_revenue.append({
                'month': month_start.strftime('%Y-%m'),
                'revenue': float(revenue)
            })
        
        monthly_revenue.reverse()
        
        db.close()
        
        return templates.TemplateResponse("admin_analytics.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "analytics": analytics_data,
            "monthly_revenue": monthly_revenue
        })
        
    except Exception as e:
        logger.error(f"Error loading admin analytics: {e}")
        raise HTTPException(status_code=500, detail="Error loading analytics")

@app.get("/admin/settings", response_class=HTMLResponse)
async def admin_settings(request: Request, admin_session: dict = Depends(get_current_admin)):
    """
    Admin settings page
    """
    try:
        return templates.TemplateResponse("admin_settings.html", {
            "request": request,
            "admin_user": admin_session['username'],
            "settings": {
                "app_url": settings.app_url,
                "debug": settings.debug,
                "telegram_bot_token": settings.telegram_bot_token[:10] + "..." if settings.telegram_bot_token else "Not set",
                "stripe_public_key": settings.stripe_public_key[:10] + "..." if settings.stripe_public_key else "Not set"
            }
        })
        
    except Exception as e:
        logger.error(f"Error loading admin settings: {e}")
        raise HTTPException(status_code=500, detail="Error loading settings")

# -------------------------------------------------
# API Routes (Protected)
# -------------------------------------------------

@app.get("/api/orders")
async def get_orders(admin_session: dict = Depends(get_current_admin), db: Session = Depends(get_db)):
    """
    Get all orders (API endpoint)
    """
    try:
        orders = db.query(Order).join(User).order_by(Order.created_at.desc()).all()
        
        orders_data = []
        for order in orders:
            orders_data.append({
                "id": order.id,
                "order_number": order.order_number,
                "user_name": order.user.full_name,
                "service_type": order.service_type,
                "subject": order.subject,
                "status": order.status,
                "payment_status": order.payment_status,
                "total_amount": float(order.total_amount),
                "currency": order.currency,
                "created_at": order.created_at.isoformat(),
                "deadline": order.deadline.isoformat() if order.deadline else None
            })
        
        return JSONResponse(content={"orders": orders_data})
        
    except Exception as e:
        logger.error(f"Error fetching orders: {e}")
        raise HTTPException(status_code=500, detail="Error fetching orders")

@app.put("/api/orders/{order_id}/status")
async def update_order_status(
    order_id: int,
    status: str = Form(...),
    admin_session: dict = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    """
    Update order status
    """
    try:
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        old_status = order.status
        order.status = status
        order.updated_at = datetime.utcnow()
        
        db.commit()
        
        # Send notification to user
        try:
            await notification_service.send_order_status_update(order, old_status, status)
        except Exception as e:
            logger.warning(f"Failed to send notification: {e}")
        
        logger.info(f"Order {order.order_number} status updated from {old_status} to {status} by {admin_session['username']}")
        
        return JSONResponse(content={"message": "Order status updated successfully"})
        
    except Exception as e:
        logger.error(f"Error updating order status: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Error updating order status")

# -------------------------------------------------
# Public Routes
# -------------------------------------------------

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """
    Home page
    """
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Student Services Platform</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #333; text-align: center; margin-bottom: 30px; }
            .features { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 30px 0; }
            .feature { padding: 20px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #007bff; }
            .feature h3 { margin: 0 0 10px 0; color: #007bff; }
            .cta { text-align: center; margin: 40px 0; }
            .btn { display: inline-block; padding: 12px 30px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; margin: 0 10px; }
            .btn:hover { background: #0056b3; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🎓 Student Services Platform</h1>
            <p style="text-align: center; font-size: 18px; color: #666; margin-bottom: 40px;">
                Professional academic writing services with secure admin management
            </p>
            
            <div class="features">
                <div class="feature">
                    <h3>📝 Academic Writing</h3>
                    <p>High-quality assignments, projects, and presentations</p>
                </div>
                <div class="feature">
                    <h3>🤖 Telegram Bot</h3>
                    <p>Easy order placement and real-time updates</p>
                </div>
                <div class="feature">
                    <h3>💳 Secure Payments</h3>
                    <p>Stripe integration and bank transfer options</p>
                </div>
                <div class="feature">
                    <h3>🛡️ Admin Panel</h3>
                    <p>Secure management with CAPTCHA protection</p>
                </div>
            </div>
            
            <div class="cta">
                <a href="/admin" class="btn">Admin Panel</a>
                <a href="/api/docs" class="btn">API Documentation</a>
            </div>
            
            <div style="text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #666;">
                <p>Contact us on Telegram: <strong>@your_bot_username</strong></p>
                <p>© 2024 Student Services Platform. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """)

@app.get("/health")
async def health_check():
    """
    Health check endpoint
    """
    return JSONResponse(content={
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "2.1.0"
    })

# -------------------------------------------------
# Error Handlers
# -------------------------------------------------

@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    """
    Custom 404 handler
    """
    return HTMLResponse(
        content="""
        <!DOCTYPE html>
        <html>
        <head><title>404 - Page Not Found</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1>404 - Page Not Found</h1>
            <p>The page you're looking for doesn't exist.</p>
            <a href="/" style="color: #007bff;">Go Home</a>
        </body>
        </html>
        """,
        status_code=404
    )

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc: HTTPException):
    """
    Custom 500 handler
    """
    logger.error(f"Internal server error: {exc}")
    return HTMLResponse(
        content="""
        <!DOCTYPE html>
        <html>
        <head><title>500 - Internal Server Error</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1>500 - Internal Server Error</h1>
            <p>Something went wrong on our end. Please try again later.</p>
            <a href="/" style="color: #007bff;">Go Home</a>
        </body>
        </html>
        """,
        status_code=500
    )

# -------------------------------------------------
# Startup Events
# -------------------------------------------------

@app.on_event("startup")
async def startup_event():
    """
    Application startup
    """
    logger.info("Starting Student Services Platform...")
    
    # Initialize database
    try:
        init_database()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        raise
    
    # Create necessary directories
    os.makedirs("logs", exist_ok=True)
    os.makedirs("static/uploads", exist_ok=True)
    os.makedirs("static/downloads", exist_ok=True)
    os.makedirs("uploaded_works", exist_ok=True)
    
    logger.info("Student Services Platform started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """
    Application shutdown
    """
    logger.info("Shutting down Student Services Platform...")

# -------------------------------------------------
# Main Entry Point
# -------------------------------------------------

if __name__ == "__main__":
    uvicorn.run(
        "main_enhanced:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="info"
    )
