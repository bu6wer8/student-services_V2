#!/usr/bin/env python3
"""
Simple Admin User Creation Script
"""

import sys
import os
import hashlib
import secrets
import getpass
from pathlib import Path

def hash_password(password):
    """Simple but secure password hashing"""
    salt = secrets.token_hex(16)
    password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
    return f"{salt}:{password_hash.hex()}"

def main():
    print("Student Services Platform - Simple Admin Creation")
    print("=" * 50)
    
    # Get credentials
    username = input("Username [admin]: ").strip() or "admin"
    
    while True:
        password = getpass.getpass("Password (8+ chars): ")
        if len(password) < 8:
            print("Password must be at least 8 characters!")
            continue
        if len(password) > 50:  # Reasonable limit
            print("Password too long! Please use 50 characters or less.")
            continue
        
        confirm = getpass.getpass("Confirm password: ")
        if password != confirm:
            print("Passwords don't match!")
            continue
        break
    
    # Generate hash
    password_hash = hash_password(password)
    
    print(f"\n✅ Admin credentials generated:")
    print(f"Username: {username}")
    print(f"Password Hash: {password_hash}")
    
    # Update .env file
    env_file = Path(".env")
    
    if env_file.exists():
        with open(env_file, 'r') as f:
            content = f.read()
        
        # Remove old admin settings
        lines = content.split('\n')
        new_lines = []
        
        for line in lines:
            if not any(line.startswith(prefix) for prefix in [
                'ADMIN_USERNAME=', 'admin_username=',
                'ADMIN_PASSWORD=', 'admin_password=',
                'ADMIN_PASSWORD_HASH=', 'admin_password_hash='
            ]):
                new_lines.append(line)
        
        # Add new admin settings
        new_lines.extend([
            '',
            '# Admin Authentication',
            f'ADMIN_USERNAME={username}',
            f'admin_username={username}',
            f'ADMIN_PASSWORD_HASH={password_hash}',
            f'admin_password_hash={password_hash}'
        ])
        
        with open(env_file, 'w') as f:
            f.write('\n'.join(new_lines))
        
        print(f"\n✅ Updated {env_file}")
    else:
        print(f"\n⚠️  .env file not found. Add these to your .env:")
        print(f"ADMIN_USERNAME={username}")
        print(f"admin_username={username}")
        print(f"ADMIN_PASSWORD_HASH={password_hash}")
        print(f"admin_password_hash={password_hash}")
    
    print(f"\n🎉 Admin user '{username}' created successfully!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nCancelled.")
    except Exception as e:
        print(f"\nError: {e}")
