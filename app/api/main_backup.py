#!/usr/bin/env python3
"""
Student Services Platform - Main API Application
Production-ready FastAPI application with admin panel and payment processing
"""

import os
import sys
import logging
from datetime import datetime
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from fastapi import FastAPI, Request, HTTPException, Depends, Form, File, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import uvicorn

# Import application modules
from app.models.database import get_db, init_database
from app.models.models import Order, User, Payment, Feedback
from app.services.payment import PaymentService
from app.services.notification import NotificationService
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
    description="Academic writing services platform with admin panel",
    version="2.0.0",
    docs_url="/api/docs" if settings.debug else None,
    redoc_url="/api/redoc" if settings.debug else None
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.debug else [settings.app_url],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Initialize templates
templates = Jinja2Templates(directory="templates")

# Initialize services
payment_service = PaymentService()
notification_service = NotificationService()

# -------------------------------------------------
# Startup and Shutdown Events
# -------------------------------------------------

@app.on_event("startup")
async def startup_event():
    """Initialize application on startup"""
    try:
        # Initialize database
        init_database()
        
        # Create upload directories
        os.makedirs("static/uploads", exist_ok=True)
        os.makedirs("static/downloads", exist_ok=True)
        os.makedirs("uploaded_works", exist_ok=True)
        os.makedirs("logs", exist_ok=True)
        
        logger.info("Student Services Platform started successfully")
        logger.info(f"Environment: {settings.env}")
        logger.info(f"Debug mode: {settings.debug}")
        logger.info(f"Database: {settings.database_url.split('@')[1] if '@' in settings.database_url else 'SQLite'}")
        
    except Exception as e:
        logger.error(f"Startup error: {e}")
        raise

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Student Services Platform shutting down")

# -------------------------------------------------
# Health Check and Root Routes
# -------------------------------------------------

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "2.0.0",
        "environment": settings.env
    }

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Root endpoint - redirect to admin"""
    return RedirectResponse(url="/admin")

# -------------------------------------------------
# Admin Panel Routes
# -------------------------------------------------

@app.get("/admin", response_class=HTMLResponse)
async def admin_dashboard(request: Request, db: Session = Depends(get_db)):
    """Admin dashboard with statistics"""
    try:
        # Get dashboard statistics
        total_orders = db.query(Order).count()
        pending_orders = db.query(Order).filter(Order.status == "pending").count()
        in_progress_orders = db.query(Order).filter(Order.status == "in_progress").count()
        completed_orders = db.query(Order).filter(Order.status == "completed").count()
        
        # Calculate revenue
        paid_orders = db.query(Order).filter(Order.payment_status == "paid").all()
        total_revenue = sum(float(order.total_amount or 0) for order in paid_orders)
        
        # Recent orders
        recent_orders = db.query(Order).order_by(Order.created_at.desc()).limit(10).all()
        
        stats = {
            "total_orders": total_orders,
            "pending_orders": pending_orders,
            "in_progress_orders": in_progress_orders,
            "completed_orders": completed_orders,
            "total_revenue": total_revenue,
            "recent_orders": recent_orders
        }
        
        return templates.TemplateResponse("admin_dashboard.html", {
            "request": request,
            "stats": stats,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin dashboard error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/admin/orders", response_class=HTMLResponse)
async def admin_orders(request: Request, db: Session = Depends(get_db)):
    """Orders management page"""
    try:
        orders = db.query(Order).order_by(Order.created_at.desc()).all()
        
        return templates.TemplateResponse("admin_orders.html", {
            "request": request,
            "orders": orders,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin orders error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/admin/customers", response_class=HTMLResponse)
async def admin_customers(request: Request, db: Session = Depends(get_db)):
    """Customers management page"""
    try:
        customers = db.query(User).order_by(User.created_at.desc()).all()
        
        return templates.TemplateResponse("admin_customers.html", {
            "request": request,
            "customers": customers,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin customers error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/admin/payments", response_class=HTMLResponse)
async def admin_payments(request: Request, db: Session = Depends(get_db)):
    """Payments management page"""
    try:
        payments = db.query(Payment).order_by(Payment.created_at.desc()).all()
        
        return templates.TemplateResponse("admin_payments.html", {
            "request": request,
            "payments": payments,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin payments error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/admin/analytics", response_class=HTMLResponse)
async def admin_analytics(request: Request, db: Session = Depends(get_db)):
    """Analytics and reports page"""
    try:
        # Generate analytics data
        analytics_data = {
            "orders_by_status": {},
            "revenue_by_month": {},
            "popular_services": {},
            "customer_stats": {}
        }
        
        return templates.TemplateResponse("admin_analytics.html", {
            "request": request,
            "analytics": analytics_data,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin analytics error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/admin/settings", response_class=HTMLResponse)
async def admin_settings(request: Request):
    """Settings management page"""
    try:
        return templates.TemplateResponse("admin_settings.html", {
            "request": request,
            "settings": settings
        })
        
    except Exception as e:
        logger.error(f"Admin settings error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# -------------------------------------------------
# API Routes
# -------------------------------------------------

@app.get("/api/orders")
async def get_orders(db: Session = Depends(get_db)):
    """Get all orders"""
    try:
        orders = db.query(Order).order_by(Order.created_at.desc()).all()
        return {"orders": [order.__dict__ for order in orders]}
    except Exception as e:
        logger.error(f"Get orders error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/orders/{order_id}")
async def get_order(order_id: int, db: Session = Depends(get_db)):
    """Get specific order"""
    try:
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        return {"order": order.__dict__}
    except Exception as e:
        logger.error(f"Get order error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.put("/api/orders/{order_id}/status")
async def update_order_status(
    order_id: int,
    status: str = Form(...),
    db: Session = Depends(get_db)
):
    """Update order status"""
    try:
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        order.status = status
        order.updated_at = datetime.utcnow()
        db.commit()
        
        # Send notification to customer
        await notification_service.notify_order_status_change(order)
        
        return {"message": "Order status updated successfully"}
        
    except Exception as e:
        logger.error(f"Update order status error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/orders/{order_id}/upload")
async def upload_work_file(
    order_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Upload completed work file"""
    try:
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Save file
        file_path = f"uploaded_works/{order_id}_{file.filename}"
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Update order
        order.work_file_path = file_path
        order.status = "delivered"
        order.updated_at = datetime.utcnow()
        db.commit()
        
        # Notify customer
        await notification_service.notify_work_delivered(order)
        
        return {"message": "Work file uploaded successfully"}
        
    except Exception as e:
        logger.error(f"Upload work file error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# -------------------------------------------------
# Payment Webhook Routes
# -------------------------------------------------

@app.post("/webhook/stripe")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    """Handle Stripe webhook events"""
    try:
        payload = await request.body()
        sig_header = request.headers.get('stripe-signature')
        
        # Process webhook with payment service
        result = await payment_service.handle_webhook(payload, sig_header, db)
        
        return {"status": "success"}
        
    except Exception as e:
        logger.error(f"Stripe webhook error: {e}")
        raise HTTPException(status_code=400, detail="Webhook error")

# -------------------------------------------------
# Error Handlers
# -------------------------------------------------

@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    """Handle 404 errors"""
    return templates.TemplateResponse("404.html", {
        "request": request,
        "settings": settings
    }, status_code=404)

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc: HTTPException):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {exc}")
    return templates.TemplateResponse("500.html", {
        "request": request,
        "settings": settings
    }, status_code=500)

# -------------------------------------------------
# Main Entry Point
# -------------------------------------------------

if __name__ == "__main__":
    logger.info("Starting Student Services Platform...")
    
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.debug,
        log_level="info" if settings.debug else "warning"
    )
