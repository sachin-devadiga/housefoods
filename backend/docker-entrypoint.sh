#!/usr/bin/env bash
# MEALIN backend container entrypoint (Hostinger VPS).
# Applies migrations, refreshes static files, ensures the admin user,
# then starts Gunicorn. Safe to run on every (re)deploy.
set -e

python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py create_admin

exec gunicorn -c gunicorn.conf.py backend.wsgi:application
