#!/usr/bin/env python3
"""
Student Services Platform - Simplified Startup Script
Run the simplified version of the application
"""

import os
import sys
import logging
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Set environment to use simplified config
os.environ['USE_SIMPLIFIED_CONFIG'] = 'true'

import uvicorn
from app.api.main import app

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger("startup")

def main():
    """
    Main startup function
    """
    logger.info("Starting Student Services Platform (Simplified Version)...")
    
    # Create necessary directories
    os.makedirs("logs", exist_ok=True)
    os.makedirs("static/uploads", exist_ok=True)
    os.makedirs("static/downloads", exist_ok=True)
    
    # Copy environment file if it doesn't exist
    if not os.path.exists(".env"):
        if os.path.exists(".env.simplified"):
            import shutil
            shutil.copy(".env.simplified", ".env")
            logger.info("Created .env file from .env.simplified template")
        else:
            logger.warning("No .env file found. Using default configuration.")
    
    # Run the application
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )

if __name__ == "__main__":
    main()
