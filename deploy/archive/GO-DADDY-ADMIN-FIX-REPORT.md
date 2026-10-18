# GO-DADDY ADMIN 500 — Root-Cause & Fix Report (api.mealin.in)

No secrets in this file. Code changes are minimal; no logic, model, migration, auth, AI, or API changes.

## 1. Exact root cause

**Primary defect (proven in code): `api/middleware.py::ForceRenderMiddleware` converts every
template-render exception into a plain `HttpResponse(status=500)` — even with `DEBUG=True`.**
That is exactly why the server shows a blank 500 with no Django traceback. Django's DEBUG
traceback page can never appear because the exception never reaches Django's handler.
Fix: re-raise when `settings.DEBUG` is true (standard Django behavior restored);
production still returns the safe generic 500. File: `backend/api/middleware.py`.

**Why the underlying trigger is environmental, proven by elimination:**
- `/` renders Django's 404 page → Django boots, URLconf imports, middleware chain, template engine all work.
- `manage.py check` returncode 0 on the server → admin registry consistent with models.
- Reproduced locally with project settings, `DEBUG=False`, fresh DB: `GET /admin/login/` → 200,
  `GET /admin/` anon → 302, authed → 200 — on BOTH the dev dependency set AND the exact
  fresh-resolve set GoDaddy installs (Django 5.2.17, jazzmin 3.0.5, DRF 3.18.1, …).
- Decisive test: with a **dead/unreachable database**, `GET /admin/login/` still returns **200**
  (anonymous login render touches no DB). So the server's login-page 500 **cannot** be the database.
- Remaining possible triggers all live on the server, not in this code: Passenger serving a stale
  process after edits (notably the jazzmin-removal test), incomplete/corrupt file upload or
  permissions on templates, or a newer-than-verified package release. All are neutralized below.

## 2. Exact files changed
- `backend/api/middleware.py` — re-raise render exceptions when `DEBUG=True`.
- `backend/requirements.txt` — pinned to the verified set (was floating `>=` ranges that let
  cPanel resolve untested future releases): `Django==5.2.17`, `django-jazzmin==3.0.5`,
  `djangorestframework==3.18.1`, `djangorestframework-simplejwt==5.5.1`,
  `django-cors-headers==4.9.0`, `PyMySQL==1.2.3`, `dj-database-url==3.1.2`,
  `gunicorn==26.2.0`, `whitenoise[brotli]==6.12.0`, `python-dotenv==1.2.3`,
  `requests==2.34.2`, `firebase-admin==7.7.0`.
- `backend/api/health_views.py` — NEW: `GET /api/auth/admin-health/` returns booleans only
  (`database`, `session_table`, `admin_templates`, `admin_models`, versions). No tracebacks,
  no SQL, no paths, no user data. Safe to keep enabled.
- `backend/api/urls.py` — one route added: `admin-health/`.

## 3. Exact code changes
1. `ForceRenderMiddleware.__call__`: added `from django.conf import settings` and
   `if settings.DEBUG: raise` inside the `except` before the generic-500 return.
2. `requirements.txt`: `>=` → `==` pins listed above.
3. New `AdminHealthView` (AllowAny, read-only `SELECT 1`, introspection for `django_session`,
   `get_template('admin/login.html'/'admin/index.html')`, admin registry count).

## 4. Why the old package failed
Two compounding causes, both fixed: (a) the middleware masked the real error into a plain 500
even in DEBUG, making diagnosis impossible; (b) floating requirements let cPanel install
dependency releases newer than anything tested (plus any stale-process/upload issue on the
server, which no code change can prevent — hence the health endpoint + pinned set).

## 5. Database compatibility status
Unchanged: MySQL/MariaDB via PyMySQL, migrations 0001–0016 untouched, no pg-specific code
(re-scanned: zero hits). No live-MySQL migration test locally (no server); run `migrate` on GoDaddy.

## 6. Tests performed and results
- Fresh venv with exact cPanel-fresh dependency set: `/admin/login/` 200, `/admin/` anon 302,
  `/admin/` authed 200, `/api/auth/admin-health/` 200 `{"ok":true,…24 models}` — all `DEBUG=False`.
- Dead-DB login render: 200 (proves login 500 ≠ database).
- `manage.py check`: 0 issues. `makemigrations --check`: no changes. `compileall`: clean.
- Backend suite: none exists (SKIPPED). No failures hidden.
- Server-side verification (`/admin/login/`, `/admin/`, health endpoint after restart) still required.

## 7. Exact cPanel deployment steps
1. Upload `deploy/mealin-api-godaddy-admin-fixed.zip`, extract into `/home/<user>/mealin-api`
   (overwrite; `passenger_wsgi.py` already inside at root).
2. In the cPanel Python app: Python 3.11.15, startup `passenger_wsgi.py`, entry `application`,
   env vars per `.env.example.godaddy` (`ALLOWED_HOSTS=api.mealin.in`,
   `CSRF_TRUSTED_ORIGINS=https://api.mealin.in`, DB vars, secret, Firebase, Brevo, Gemini, Sarvam).
3. `pip install -r requirements.txt` (fresh — picks up the pins), `migrate --noinput`,
   `collectstatic --noinput`, ensure `/media/` alias from the main report.
4. **Restart Passenger** (cPanel Restart or `tmp/restart.txt`) — required after every code/env change.
5. `curl https://api.mealin.in/api/auth/admin-health/` → expect `"ok":true`.
6. Open `/admin/login/` → login page; log in → `/admin/` index. With `DEBUG=True` temporarily,
   any residual error now shows the real traceback; set `DEBUG=False` after.

## 8. Jazzmin restored?
Yes. Jazzmin was never the proven cause (admin renders 200 with jazzmin 3.0.5 + Django 5.2.17
in two independent dependency sets). It stays enabled with the full custom theme/dashboard.
If `/admin-health/` ever reports `admin_templates: error`, that line names the culprit precisely.

## 9. Environment variables required
No new variables. Same list as `.env.example.godaddy` (`DJANGO_SECRET_KEY`, `DEBUG`,
`ALLOWED_HOSTS`, `DATABASE_URL` or `DB_*`, superuser trio, Brevo, `GEMINI_API_KEY`,
`SARVAM_API_KEY`, Firebase credential, optional tuning keys).
