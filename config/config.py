#!/usr/bin/env python3
"""
Student Services Platform - Simplified Configuration
Basic configuration with minimal required settings
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    """
    Simplified application settings
    """
    
    # Environment
    env: str = "development"
    debug: bool = True
    app_url: str = "http://localhost:8000"
    
    # Database
    database_url: str = "sqlite:///./student_services.db"
    
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    secret_key: str = "your-secret-key-change-this-in-production-make-it-at-least-32-characters-long"
    
    # Admin Authentication
    admin_username: str = "admin"
    admin_password: str = "admin123"
    
    # Telegram Bot (optional)
    telegram_bot_token: str = ""
    telegram_admin_id: str = ""
    
    # Payment - Stripe (optional)
    stripe_public_key: str = ""
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    
    # Email Configuration (optional)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    
    # File Storage
    upload_dir: str = "./static/uploads"
    download_dir: str = "./static/downloads"
    max_file_size: int = 10485760  # 10MB
    
    # Bank Transfer Details (optional)
    bank_name: str = "Your Bank"
    bank_account_name: str = "Your Company"
    bank_account_number: str = ""
    bank_iban: str = ""
    bank_swift: str = ""
    
    # Pricing Configuration
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
    
    # Currency exchange rates (to USD)
    rate_usd_to_jod: float = 0.71
    rate_usd_to_aed: float = 3.67
    rate_usd_to_sar: float = 3.75
    
    # Business Settings
    business_name: str = "Student Services Platform"
    support_email: str = "support@yourdomain.com"
    support_telegram: str = "@your_support"
    
    # Feature Flags
    enable_registration: bool = True
    enable_bank_transfer: bool = True
    enable_stripe: bool = False
    enable_email_notifications: bool = False
    enable_sms_notifications: bool = False
    
    def get_payment_methods(self):
        """
        Get available payment methods configuration
        """
        methods = {}
        
        if self.enable_stripe and self.stripe_public_key and self.stripe_secret_key:
            methods['stripe'] = {
                'name': 'Credit/Debit Card',
                'description': 'Pay securely with your credit or debit card',
                'icon': 'credit-card',
                'instant': True,
                'currencies': ['USD', 'EUR', 'GBP', 'AED', 'SAR']
            }
        
        if self.enable_bank_transfer:
            methods['bank_transfer'] = {
                'name': 'Bank Transfer',
                'description': 'Transfer money directly to our bank account',
                'icon': 'university',
                'instant': False,
                'verification_time': '24 hours',
                'bank_details': {
                    'bank_name': self.bank_name,
                    'account_name': self.bank_account_name,
                    'account_number': self.bank_account_number,
                    'iban': self.bank_iban,
                    'swift': self.bank_swift
                }
            }
        
        return methods
    
    def get_currency_rates(self):
        """
        Get currency exchange rates
        """
        return {
            'USD': 1.0,
            'JOD': self.rate_usd_to_jod,
            'AED': self.rate_usd_to_aed,
            'SAR': self.rate_usd_to_sar,
            'EUR': 0.85  # Example rate
        }
    
    def get_academic_levels(self):
        """
        Get academic levels with multipliers
        """
        return {
            'high_school': {
                'name': 'High School',
                'multiplier': self.academic_multiplier_high_school,
                'description': 'High school level assignments'
            },
            'bachelor': {
                'name': 'Bachelor/Undergraduate',
                'multiplier': self.academic_multiplier_bachelor,
                'description': 'University undergraduate level'
            },
            'masters': {
                'name': 'Masters/Graduate',
                'multiplier': self.academic_multiplier_masters,
                'description': 'Graduate level assignments'
            },
            'phd': {
                'name': 'PhD/Doctoral',
                'multiplier': self.academic_multiplier_phd,
                'description': 'Doctoral level research'
            }
        }
    
    def get_service_types(self):
        """
        Get service types with base prices
        """
        return {
            'assignment': {
                'name': 'Assignment',
                'base_price': self.base_price_assignment,
                'description': 'Essays, reports, homework',
                'icon': 'file-text'
            },
            'project': {
                'name': 'Project',
                'base_price': self.base_price_project,
                'description': 'Research projects, case studies',
                'icon': 'folder'
            },
            'presentation': {
                'name': 'Presentation',
                'base_price': self.base_price_presentation,
                'description': 'PowerPoint, slides',
                'icon': 'presentation'
            },
            'redesign': {
                'name': 'Redesign',
                'base_price': self.base_price_redesign,
                'description': 'Improve existing work',
                'icon': 'edit'
            },
            'summary': {
                'name': 'Summary',
                'base_price': self.base_price_summary,
                'description': 'Summarize documents',
                'icon': 'list'
            },
            'express': {
                'name': 'Express Service',
                'base_price': self.base_price_express,
                'description': 'Urgent work (24h or less)',
                'icon': 'clock'
            }
        }
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

# Create settings instance
settings = Settings()
