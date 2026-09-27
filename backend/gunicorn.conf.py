# MEALIN backend — Gunicorn config for Hostinger KVM1 VPS (1 vCPU / 4 GB RAM).
bind = "0.0.0.0:8000"
workers = 3
worker_class = "sync"
timeout = 90
graceful_timeout = 30
keepalive = 5
accesslog = "-"
errorlog = "-"
loglevel = "info"
