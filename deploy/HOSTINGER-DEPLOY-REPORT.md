# MEALIN — Hostinger VPS + GoDaddy DNS + Play Store Deployment Report

Target architecture (confirmed): Django backend on Hostinger **VPS KVM1** via
**Docker Compose** with **PostgreSQL**; `mealin.in` DNS stays in **GoDaddy**
with `api.mealin.in` pointing at the VPS; Flutter apps ship to Play Store.
No secrets in this file.

## 1. Files created / changed

New in `backend/` (Hostinger Docker stack):
- `Dockerfile` — Python 3.12-slim + Gunicorn, non-root `appuser`, healthcheck
  via curl, `collectstatic` at build, entrypoint `docker-entrypoint.sh`.
- `docker-compose.yml` — services `db` (postgres:16-alpine + volume + pg_isready
  healthcheck), `web` (Django, migrate/collectstatic/create_admin on start,
  healthcheck hits `/api/auth/admin-health/`), `caddy` (ports 80/443, auto-TLS).
- `docker-entrypoint.sh` — migrate → collectstatic → create_admin → Gunicorn.
- `gunicorn.conf.py` — 0.0.0.0:8000, 3 sync workers (sized for KVM1 1vCPU/4GB).
- `Caddyfile` — `api.mealin.in { reverse_proxy web:8000 }` (auto Let's Encrypt).
- `.dockerignore` — excludes `.env`, sqlite, logs, media, service-account JSON.
- `.env.example.hostinger` — variable names only; `DATABASE_URL=postgres://…@db:5432/…`.

Changed:
- `backend/requirements.txt` — `PyMySQL` → `psycopg2-binary==2.9.0` (prod is
  Postgres again); everything else still pinned.
- `backend/backend/settings.py` — comment only: prod DB documented as
  PostgreSQL (no logic change; `DATABASE_URL` already handled postgres).
- `lib/core/constants/app_constants.dart` — production API default
  `https://housefoods.onrender.com` → **`https://api.mealin.in`**
  (`--dart-define=API_BASE_URL=` override still works).

Untouched legacy: `.cpanel.yml`, `passenger_wsgi.py`, `build.sh`/`start.sh`
(GoDaddy-specific; now unused, harmless).

## 2. Hostinger VPS setup (KVM1, Ubuntu 24.04)

```bash
# 1. Docker
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER  # re-login after

# 2. Project (private repo recommended)
mkdir -p ~/mealin-api && cd ~/mealin-api
git clone <repo-url> .   # needs backend/ at ./backend
cd backend
cp .env.example.hostinger .env && nano .env   # fill ALL values

# 3. Launch
docker compose up -d --build
docker compose ps                        # db healthy, web healthy
docker compose logs -f web               # watch migrate/create_admin
curl -s https://api.mealin.in/api/auth/admin-health/
```

Firewall (Hostinger panel or ufw): allow 80/443 (and 22 for SSH) only.

## 3. GoDaddy DNS for mealin.in

In GoDaddy DNS management add:
- `A  api  <VPS-IP>  TTL 600` (proxied OFF if using Cloudflare DNS).
- Keep existing apex records as-is.

Then on the VPS: `docker compose logs caddy` should show the certificate
issued for `api.mealin.in`. Verify `https://api.mealin.in/admin/` loads.

## 4. Backend verification (post-deploy)

- `GET /api/auth/admin-health/` → `{"ok":true,…}` (db, session_table,
  admin_templates, 24 admin models).
- `GET /admin/login/` → 200; log in → `/admin/` index 200.
- `docker compose exec web python manage.py check` → no issues.

## 5. Play Store readiness (Flutter)

Ready:
- Release signing enforced in `android/app/build.gradle.kts`; `android/key.properties`
  + `android/app/mealin-release.keystore` present (never commit these — gitignored).
- Version `1.3.0+500` in `pubspec.yaml`; per-role applicationIds
  (`app.mealin.customer` / `.kitchen` / `.delivery` via `APP_ROLE`).
- `google-services.json` present (FCM); store listing draft in `play-store-listing.md`;
  privacy policy + Play graphics exist at repo root.
- App now targets `https://api.mealin.in` by default.

Build (one AAB per role, from repo root):
```bash
flutter build appbundle --release --dart-define=APP_ROLE=customer \
  --dart-define=RAZORPAY_KEY=rzp_live_XXXX --dart-define=MAPS_API_KEY=XXXX
# repeat with APP_ROLE=chef and APP_ROLE=delivery_partner
```
Still needed from you: Razorpay **live** key, Maps API key, and the keystore
passwords in `android/key.properties` (already local-only). Each role is a
separate Play Store app entry.

## 6. Local verification performed

- `docker-compose.yml` parses; services `db/web/caddy`, Caddy 80/443 exposed.
- `gunicorn.conf.py` compiles; entrypoint follows the proven start.sh pattern.
- `manage.py check` with `DATABASE_URL=postgres://…` → 0 issues, no driver
  install needed for checks (driver installs in the image).
- `makemigrations --check` → no changes (models/migrations in sync).
- Admin render (`DEBUG=False`): login 200, `/admin/` 302 anon / 200 authed,
  health endpoint `ok:true`.
- Docker image build not run here (no Docker on this machine) — first
  `docker compose up --build` on the VPS is the build test.
