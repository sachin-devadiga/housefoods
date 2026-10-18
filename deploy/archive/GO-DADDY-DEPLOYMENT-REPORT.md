# MEALIN — GoDaddy Deployment Report (api.mealin.in)

Target: GoDaddy Web Hosting Ultimate (cPanel Linux) · Python 3.11.15 · Apache + Passenger · GoDaddy MySQL/MariaDB.
Date: 2026-09-24. Source: latest `main`. No secrets are stored in this file.

## 1. Project structure (ZIP root = cPanel app root)

```
manage.py · requirements.txt · passenger_wsgi.py
.env.example · .env.example.godaddy
build.sh · start.sh · safe_deploy.py   (reference scripts)
backend/   (Django project package: settings.py, urls.py, wsgi.py)
api/       (models, views, serializers, urls, admin, middleware, templates,
            management/commands, migrations 0001–0016)
```

## 2. Files changed for this deployment
- `backend/backend/__init__.py` — PyMySQL→MySQLdb shim (new 6 lines; file was empty).
- `backend/backend/settings.py` — MySQL ENGINE + MySQL defaults; removed `RENDER_EXTERNAL_HOSTNAME` auto-append blocks (were Render-only runtime behavior).
- `backend/requirements.txt` — `psycopg2-binary` → `PyMySQL>=1.1`.
- `backend/passenger_wsgi.py` — per cPanel spec (loads real `backend.wsgi:application`).
- `backend/.env.example.godaddy` — safe env-name reference (placeholders only).
- Nothing else: no logic, model, migration, auth, AI, FCM, or API changes.

## 3. Database changes
- PostgreSQL → MySQL/MariaDB, config-only. `DATABASE_URL=mysql://…` supported via dj-database-url; `DB_NAME/DB_USER/DB_PASSWORD/DB_HOST/DB_PORT` fallback (default port 3306, no SQLite fallback anywhere).
- Verified: models use only portable `JSONField` (no ArrayField/HStore/GIN/RawSQL/pg functions); all 16 migrations are generic operations — MySQL-compatible as-is, history untouched.

## 4. PostgreSQL → MySQL changes
- Driver: **PyMySQL** (pure-Python wheel — installs on shared cPanel with no compiler; `mysqlclient` would need unavailable system build tools).
- `makemigrations --check --dry-run`: **No changes detected**.
- Live migration test against real MySQL was **not possible locally** (no server) — run `migrate` on GoDaddy.

## 5. Required cPanel environment variables
`DJANGO_SECRET_KEY`, `DEBUG=False`, `ALLOWED_HOSTS=api.mealin.in`, `CSRF_TRUSTED_ORIGINS=https://api.mealin.in`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT=3306` (or single `DATABASE_URL`), `DJANGO_SUPERUSER_USERNAME`, `DJANGO_SUPERUSER_EMAIL`, `DJANGO_SUPERUSER_PASSWORD`, `BREVO_SMTP_HOST/PORT/TLS/USER/PASSWORD`, `BREVO_SENDER_EMAIL`, `GEMINI_API_KEY`, `SARVAM_API_KEY`, `FIREBASE_SERVICE_ACCOUNT` (or uploaded JSON file). Optional: `CORS_ALLOWED_ORIGINS`, `VOICE_API_THROTTLE`, JWT lifetimes, `APP_*` update keys.

## 6. Required GoDaddy MySQL settings
Create one empty MySQL DB + user in cPanel; grant all privileges; use host `localhost` (or the host cPanel shows), port 3306, charset `utf8mb4`. Fresh database (existing Postgres is empty/new — nothing to preserve).

## 7. Python version
3.11.15. Resolved stack (Django 4.2/5.x, DRF, simplejwt, corsheaders, PyMySQL, whitenoise, firebase-admin, requests) all ship cp311 wheels.

## 8. Passenger configuration
- Application root: dir containing `manage.py` (e.g. `/home/<user>/mealin-api`).
- Startup file: `passenger_wsgi.py`; Entry point: `application` (= `backend.wsgi:application`, WSGI-only, no ASGI in project).

## 9. Static files
WhiteNoise + `STATIC_ROOT=staticfiles`. Run `collectstatic --noinput`. Admin/Jazzmin static served by WhiteNoise — no web-server config needed.

## 10. Media configuration
`MEDIA_URL=/media/`, `MEDIA_ROOT=<app>/media`. Django's `static()` helper serves media **only with DEBUG=True**, so on production add an Apache rule mapping `/media/*` to `<app-root>/media/` (cPanel `.htaccess` in a `media/` path or an Alias), e.g.:
`RewriteRule ^media/(.*)$ /home/<user>/mealin-api/media/$1 [L]`
placed so it resolves to the real directory. Local `media/uploads/` (dev images) are excluded from the ZIP — start empty.

## 11. Migration commands (cPanel terminal, venv active, app root)
```
pip install -r requirements.txt
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py create_admin
```

## 12. collectstatic command
`python manage.py collectstatic --noinput`

## 13. Admin creation command
`python manage.py create_admin` (reads `DJANGO_SUPERUSER_*`; skips if a superuser exists). Admin at `https://api.mealin.in/admin/` (Jazzmin + custom dashboard/reports kept).

## 14. Restart procedure
cPanel → Python app → Restart, or `mkdir -p tmp && touch tmp/restart.txt` in app root.

## 15. Known limitations
- `ForceRenderMiddleware` is hosting-neutral despite its name (forces Django-5 template render; no Render dependency) — kept as-is.
- `SECURE_SSL_REDIRECT=True` is hardcoded when `DEBUG=False`; verify no redirect loop on first HTTPS hit (proxy header configured).
- Push notifications need the Firebase credential present; MEAL AI needs `GEMINI_API_KEY`; STT needs `SARVAM_API_KEY`; OTP mail needs Brevo vars — app boots without them, features degrade with clear log warnings.
- Subscription system was removed upstream per product direction; all search/order/AI paths are open to free users (verified: no subscription gates in code; only historical migration files mention it).

## 16. Test results
- `manage.py check`: **PASSED** (0 issues) on MySQL backend.
- `makemigrations --check --dry-run`: **PASSED** (No changes detected).
- `python -m compileall`: **PASSED**.
- Django test suite: **SKIPPED** — project has no backend tests.
- Live MySQL migrate/boot: **NOT RUN** (no local server) — must run on GoDaddy.

## 17. Remaining manual GoDaddy steps
1. Create Python 3.11.15 app (URL `api.mealin.in`, root, `passenger_wsgi.py`, `application`), upload + extract ZIP.
2. Create MySQL DB/user, enter §5 env vars, upload Firebase JSON if file-based.
3. Run §11 commands, add §10 media rule, enable SSL, restart, smoke-test `/admin/login/`, an order flow, and MEAL AI chat.
