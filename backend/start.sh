#!/bin/bash
set -e
cd "$(dirname "$0")"
python manage.py migrate --noinput
python manage.py create_admin
exec gunicorn backend.wsgi:application --bind 0.0.0.0:$PORT
