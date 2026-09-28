# MEALIN backend — Hostinger VPS (KVM) production image.
# Python 3.12 slim + Gunicorn. PostgreSQL driver via psycopg2-binary.
# Build context is backend/. Run with docker-compose.yml on the VPS.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# curl powers the container healthcheck; nothing else needs OS packages
# (psycopg2-binary ships its own libpq).
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Collect static at build time so the image serves admin/API static files
# even before first boot (re-collected on every container start too).
# Build-time only: collectstatic must not require the production database
# (compose env_file applies at run time, not build time), so point it at a
# throwaway SQLite file. Runtime DATABASE_URL is unaffected.
ENV DATABASE_URL=sqlite:///tmp/docker-build.db
RUN python manage.py collectstatic --noinput
ENV DATABASE_URL=

RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
