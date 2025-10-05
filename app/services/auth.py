#!/usr/bin/env python3
"""
Student Services Platform - Authentication Service
Secure admin authentication with session management and CAPTCHA
"""

import hashlib
import secrets
import time
import logging
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import HTTPException, Request, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from jose import JWTError, jwt
import requests

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from config.config import settings

# Configure logging
logger = logging.getLogger("auth")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT settings
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30


class CaptchaService:
    """
    CAPTCHA service for bot protection
    """

    def __init__(self):
        self.captcha_store = {}  # In production, use Redis
        self.cleanup_interval = 300  # 5 minutes
        self.last_cleanup = time.time()

    def generate_captcha(self) -> Dict[str, Any]:
        """
        Generate a simple math CAPTCHA
        """
        import random

        # Clean up old captchas
        self._cleanup_expired()

        # Generate simple math problem
        num1 = random.randint(1, 10)
        num2 = random.randint(1, 10)
        operation = random.choice(['+', '-', '*'])

        if operation == '+':
            answer = num1 + num2
            question = f"{num1} + {num2}"
        elif operation == '-':
            # Ensure positive result
            if num1 < num2:
                num1, num2 = num2, num1
            answer = num1 - num2
            question = f"{num1} - {num2}"
        else:  # multiplication
            answer = num1 * num2
            question = f"{num1} × {num2}"

        # Generate unique token
        token = secrets.token_urlsafe(32)

        # Store with expiration
        self.captcha_store[token] = {
            'answer': answer,
            'expires': time.time() + 300,  # 5 minutes
            'attempts': 0
        }

        return {
            'token': token,
            'question': f"What is {question}?",
            'expires_in': 300
        }

    def verify_captcha(self, token: str, answer: str) -> bool:
        """
        Verify CAPTCHA answer
        """
        if token not in self.captcha_store:
            return False

        captcha_data = self.captcha_store[token]

        # Check expiration
        if time.time() > captcha_data['expires']:
            del self.captcha_store[token]
            return False

        # Check attempts
        captcha_data['attempts'] += 1
        if captcha_data['attempts'] > 3:
            del self.captcha_store[token]
            return False

        # Verify answer
        try:
            user_answer = int(answer.strip())
            if user_answer == captcha_data['answer']:
                del self.captcha_store[token]
                return True
        except ValueError:
            pass

        return False

    def _cleanup_expired(self):
        """
        Clean up expired CAPTCHAs
        """
        current_time = time.time()

        if current_time - self.last_cleanup < self.cleanup_interval:
            return

        expired_tokens = [
            token for token, data in self.captcha_store.items()
            if current_time > data['expires']
        ]

        for token in expired_tokens:
            del self.captcha_store[token]

        self.last_cleanup = current_time


class RateLimiter:
    """
    Rate limiting for login attempts
    """

    def __init__(self):
        self.attempts = {}  # In production, use Redis
        self.cleanup_interval = 300  # 5 minutes
        self.last_cleanup = time.time()

    def is_rate_limited(self, ip_address: str) -> bool:
        """
        Check if IP is rate limited
        """
        self._cleanup_expired()

        if ip_address not in self.attempts:
            return False

        attempts_data = self.attempts[ip_address]
        current_time = time.time()

        # Check if still in lockout period
        if attempts_data['locked_until'] and current_time < attempts_data['locked_until']:
            return True

        # Reset if lockout period expired
        if attempts_data['locked_until'] and current_time >= attempts_data['locked_until']:
            self.attempts[ip_address] = {
                'count': 0,
                'first_attempt': current_time,
                'locked_until': None
            }

        return False

    def record_attempt(self, ip_address: str, success: bool = False):
        """
        Record login attempt
        """
        current_time = time.time()

        if ip_address not in self.attempts:
            self.attempts[ip_address] = {
                'count': 0,
                'first_attempt': current_time,
                'locked_until': None
            }

        attempts_data = self.attempts[ip_address]

        if success:
            # Reset on successful login
            self.attempts[ip_address] = {
                'count': 0,
                'first_attempt': current_time,
                'locked_until': None
            }
            return

        # Increment failed attempts
        attempts_data['count'] += 1

        # Apply rate limiting
        if attempts_data['count'] >= 5:
            # Lock for 15 minutes after 5 failed attempts
            attempts_data['locked_until'] = current_time + 900
        elif attempts_data['count'] >= 3:
            # Lock for 5 minutes after 3 failed attempts
            attempts_data['locked_until'] = current_time + 300

    def get_lockout_time(self, ip_address: str) -> Optional[int]:
        """
        Get remaining lockout time in seconds
        """
        if ip_address not in self.attempts:
            return None

        attempts_data = self.attempts[ip_address]
        if not attempts_data['locked_until']:
            return None

        remaining = int(attempts_data['locked_until'] - time.time())
        return remaining if remaining > 0 else None

    def _cleanup_expired(self):
        """
        Clean up old attempt records
        """
        current_time = time.time()

        if current_time - self.last_cleanup < self.cleanup_interval:
            return

        expired_ips = []
        for ip, data in self.attempts.items():
            # Remove records older than 1 hour
            if current_time - data['first_attempt'] > 3600:
                expired_ips.append(ip)

        for ip in expired_ips:
            del self.attempts[ip]

        self.last_cleanup = current_time


class AuthService:
    """
    Authentication service for admin panel
    """

    def __init__(self):
        self.captcha_service = CaptchaService()
        self.rate_limiter = RateLimiter()
        self.sessions = {}  # In production, use Redis

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """
        Verify password with support for both bcrypt and simple salted hash formats
        """
        try:
            if ':' in hashed_password:
                # Simple hash format: salt:hash
                salt, stored_hash = hashed_password.split(':', 1)
                password_hash = hashlib.pbkdf2_hmac('sha256', plain_password.encode(), salt.encode(), 100000)
                return stored_hash == password_hash.hex()
            else:
                # Try bcrypt format (fallback)
                return pwd_context.verify(plain_password, hashed_password)
        except Exception:
            return False

    def get_password_hash(self, password: str) -> str:
        """
        Hash password
        """
        return pwd_context.hash(password)

    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None):
        """
        Create JWT access token
        """
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, settings.secret_key, algorithm=ALGORITHM)
        return encoded_jwt

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Verify JWT token
        """
        try:
            payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
            username: str = payload.get("sub")
            if username is None:
                return None
            return payload
        except JWTError:
            return None

    def authenticate_admin(self, username: str, password: str) -> bool:
        """
        Authenticate admin user
        """
        if username == settings.admin_username:
            if hasattr(settings, 'admin_password_hash'):
                return self.verify_password(password, settings.admin_password_hash)
            else:
                return password == settings.admin_password
        return False

    def create_session(self, username: str, ip_address: str) -> str:
        """
        Create admin session
        """
        session_id = secrets.token_urlsafe(32)
        self.sessions[session_id] = {
            'username': username,
            'ip_address': ip_address,
            'created_at': datetime.utcnow(),
            'last_activity': datetime.utcnow(),
            'expires_at': datetime.utcnow() + timedelta(hours=8)
        }
        return session_id

    def verify_session(self, session_id: str, ip_address: str) -> Optional[Dict[str, Any]]:
        """
        Verify admin session
        """
        if session_id not in self.sessions:
            return None

        session_data = self.sessions[session_id]

        if datetime.utcnow() > session_data['expires_at']:
            del self.sessions[session_id]
            return None

        if session_data['ip_address'] != ip_address:
            logger.warning(f"Session IP mismatch: {session_data['ip_address']} vs {ip_address}")

        session_data['last_activity'] = datetime.utcnow()
        return session_data

    def invalidate_session(self, session_id: str):
        """
        Invalidate admin session
        """
        if session_id in self.sessions:
            del self.sessions[session_id]

    def cleanup_expired_sessions(self):
        """
        Clean up expired sessions
        """
        current_time = datetime.utcnow()
        expired_sessions = [
            session_id for session_id, data in self.sessions.items()
            if current_time > data['expires_at']
        ]
        for session_id in expired_sessions:
            del self.sessions[session_id]

    def get_client_ip(self, request: Request) -> str:
        """
        Get client IP address from request
        """
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()

        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip

        return request.client.host if request.client else "unknown"

    def log_security_event(self, event_type: str, ip_address: str, details: Dict[str, Any] = None):
        """
        Log security events
        """
        log_data = {
            'event': event_type,
            'ip': ip_address,
            'timestamp': datetime.utcnow().isoformat(),
            'details': details or {}
        }
        logger.warning(f"Security Event: {log_data}")


# Global auth service instance
auth_service = AuthService()


def get_current_admin(request: Request):
    """
    Dependency to get current authenticated admin
    """
    session_id = request.cookies.get("admin_session")
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    ip_address = auth_service.get_client_ip(request)
    session_data = auth_service.verify_session(session_id, ip_address)

    if not session_data:
        raise HTTPException(status_code=401, detail="Invalid session")

    return session_data


def require_admin_auth(request: Request):
    """
    Decorator for admin-only routes
    """
    return get_current_admin(request)
