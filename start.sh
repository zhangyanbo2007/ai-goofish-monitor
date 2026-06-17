#!/bin/bash
cd "$(dirname "$0")"
source .venv/bin/activate
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
exec python -c "
import uvicorn
from src.app import app
uvicorn.run(app, host='0.0.0.0', port=8000, log_level='info')
"
