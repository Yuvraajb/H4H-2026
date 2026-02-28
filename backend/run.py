#!/usr/bin/env python3
"""
Run script for GuideVR backend server.
"""
import uvicorn
from main import app

if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
    )
