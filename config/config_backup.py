# File: config/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional

class Settings(BaseSettings):
    # Environment
    env: str = "development"
    debug: bool = True
    app_url: str = "http://localhost:8000"
    
    # Bot
    telegram_bot_token: str
    telegram_admin_id: str
    
    # Database
    database_url: str
    redis_url: str = "redis://localhost:6379"
    
    # API
    api_host: str = "127.0.0.1"
    api_port: int = 8000
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    # Payment - Stripe
    stripe_public_key: str
    stripe_secret_key: str
    stripe_webhook_secret: str = "whsec_test"  # Add this field
    
    # Email Configuration (Optional)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = "your-email@gmail.com"
    smtp_password: str = "your-app-password"
    
    # File Storage
    upload_dir: str = "./static/uploads"
    download_dir: str = "./static/downloads"
    max_file_size: int = 10485760  # 10MB
    
    # Pricing - Base prices
    base_price_assignment: float = 20.0
    base_price_project: float = 50.0
    base_price_presentation: float = 30.0
    base_price_redesign: float = 25.0
    base_price_summary: float = 15.0
    base_price_express: float = 50.0
    
    # Urgency multipliers
    urgency_multiplier_24h: float = 2.0
    urgency_multiplier_48h: float = 1.5
    urgency_multiplier_72h: float = 1.3
    
    # Academic level multipliers
    academic_multiplier_high_school: float = 1.0
    academic_multiplier_bachelor: float = 1.2
    academic_multiplier_masters: float = 1.5
    academic_multiplier_phd: float = 2.0
    
    # Currency rates
    rate_usd_to_jod: float = 0.71
    rate_usd_to_aed: float = 3.67
    rate_usd_to_sar: float = 3.75
    
    # Bank Transfer Details
    bank_name: str = "Arab Bank"
    bank_account_name: str = "Your Company Name"
    bank_account_number: str = "1234567890"
    bank_iban: str = "JO94ARAB1234567890123456789012"
    bank_swift: str = "ARABJOAX"
    
    # Admin credentials
    admin_username: str = "admin"
    admin_password: str = "admin123"
    admin_token: str = "admin-secret-token"
    
    # Business settings
    business_name: str = "Student Services Platform"
    support_email: str = "support@example.com"
    support_telegram: str = "@support_username"
    
    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
        extra = "allow"  # This allows extra fields without error

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()
