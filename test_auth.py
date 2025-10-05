#!/usr/bin/env python3
"""
Test script for simplified authentication system
"""

import sys
import os
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from app.services.auth import auth_service
from config.config import settings

def test_authentication():
    """
    Test the simplified authentication system
    """
    print("Testing Student Services Platform - Simplified Authentication")
    print("=" * 60)
    
    # Test 1: Configuration
    print("1. Testing Configuration...")
    print(f"   Admin Username: {settings.admin_username}")
    print(f"   Admin Password: {'*' * len(settings.admin_password)}")
    print(f"   Secret Key: {settings.secret_key[:10]}...")
    print(f"   Database URL: {settings.database_url}")
    print("   ✓ Configuration loaded successfully")
    
    # Test 2: Authentication
    print("\n2. Testing Authentication...")
    
    # Test valid credentials
    valid_auth = auth_service.authenticate_admin(settings.admin_username, settings.admin_password)
    if valid_auth:
        print("   ✓ Valid credentials accepted")
    else:
        print("   ✗ Valid credentials rejected")
        return False
    
    # Test invalid credentials
    invalid_auth = auth_service.authenticate_admin("wrong", "wrong")
    if not invalid_auth:
        print("   ✓ Invalid credentials rejected")
    else:
        print("   ✗ Invalid credentials accepted")
        return False
    
    # Test 3: Session Management
    print("\n3. Testing Session Management...")
    
    # Create session
    session_id = auth_service.create_session(settings.admin_username, "127.0.0.1")
    if session_id:
        print(f"   ✓ Session created: {session_id[:8]}...")
    else:
        print("   ✗ Failed to create session")
        return False
    
    # Verify session
    session_data = auth_service.verify_session(session_id, "127.0.0.1")
    if session_data and session_data['username'] == settings.admin_username:
        print("   ✓ Session verified successfully")
    else:
        print("   ✗ Session verification failed")
        return False
    
    # Invalidate session
    auth_service.invalidate_session(session_id)
    invalid_session = auth_service.verify_session(session_id, "127.0.0.1")
    if not invalid_session:
        print("   ✓ Session invalidated successfully")
    else:
        print("   ✗ Session invalidation failed")
        return False
    
    # Test 4: Session Cleanup
    print("\n4. Testing Session Cleanup...")
    auth_service.cleanup_expired_sessions()
    print("   ✓ Session cleanup completed")
    
    print("\n" + "=" * 60)
    print("✓ All authentication tests passed!")
    print("The simplified authentication system is working correctly.")
    
    return True

def test_database_connection():
    """
    Test database connection
    """
    print("\n5. Testing Database Connection...")
    
    try:
        from app.models.database import get_db, init_database
        
        # Initialize database
        init_database()
        print("   ✓ Database initialized successfully")
        
        # Test connection
        db = next(get_db())
        db.close()
        print("   ✓ Database connection successful")
        
        return True
        
    except Exception as e:
        print(f"   ✗ Database error: {e}")
        return False

if __name__ == "__main__":
    print("Student Services Platform - Authentication Test")
    print("This script tests the simplified authentication system")
    print()
    
    try:
        # Test authentication
        auth_success = test_authentication()
        
        # Test database
        db_success = test_database_connection()
        
        if auth_success and db_success:
            print("\n🎉 All tests passed! The system is ready to use.")
            print("\nTo start the application:")
            print("   python run_simplified.py")
            print("\nThen visit: http://localhost:8000/admin/login")
            sys.exit(0)
        else:
            print("\n❌ Some tests failed. Please check the configuration.")
            sys.exit(1)
            
    except Exception as e:
        print(f"\n❌ Test error: {e}")
        print("Please check your configuration and try again.")
        sys.exit(1)
