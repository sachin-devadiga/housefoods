# MealIn

Flutter customer app + Django backend connecting home kitchens with customers.

Customer, Chef and Delivery Partner are built as **one codebase with a build-time
`APP_ROLE` flag** — see `lib/core/` and `android/gradle.properties`.

## Requirements

- Flutter SDK (>=3.0.0 <4.0.0, Dart SDK per `pubspec.yaml`)
- Python 3.12 for the backend
- JDK 21 for Android builds

## Quick start

```bash
flutter pub get

./scripts/start_backend.sh          # Django on :8000
./scripts/run_dev.sh                # app, customer role
./scripts/run_dev.sh chef           # app, chef role
./scripts/run_dev.sh delivery_partner
```

Both scripts resolve the repo root from their own location, so they work from
any working directory.

`run_dev.sh` exists because this machine has no `clang` and no non-interactive
`sudo`; it points the build at gcc and at dev headers unpacked under
`~/.local/gstreamer-dev`. If you install `clang libsecret-1-dev
libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`, you can drop it and run
`flutter run` directly.

## Layout

```
lib/                Flutter app (core/ + features/)
backend/            Django project (api/ = business logic)
android/ ios/ web/ macos/ windows/ linux/
                    Flutter platform runners
assets/             logo, images, icons, sounds  (bundled at runtime)
  assets/store/     Play Store icon + feature graphic (not bundled)
scripts/            dev entry points
  scripts/windows/  Windows-only build/start scripts
docs/
  architecture/     MEAL voice (wake-word) setup
  store/            Play listing copy, console answers, screenshots
  legal/            privacy-policy.html
deploy/
  hostinger/        production deploy scripts for the VPS
  archive/          historical deployment reports
```

## Build release APKs

Google Maps keys come from the environment and are **never hardcoded**.

```bat
set MAPS_API_KEY=your_key
scripts\windows\build_all_apks.bat
```

PowerShell equivalent: `scripts\windows\build-apks.ps1`

On Linux/macOS use `scripts/build-apks.sh`. It builds the same three roles
(`customer`, `chef`, `delivery_partner`) and writes the APKs into `apks/` -
newest build per role in `apks/latest/`, previous builds kept in
`apks/archive/`.

```bash
export MAPS_API_KEY=your_key
export RAZORPAY_KEY=rzp_live_xxxx     # without this the app ships a placeholder payment key
./scripts/build-apks.sh               # all three roles
./scripts/build-apks.sh --role customer --split-per-abi
```

See `apks/README.md` for the full flag list and file naming.

## Secrets

Copy `backend/.env.example.hostinger` to `backend/.env` on the VPS and fill in
every value; never commit real values. `deploy/hostinger/vps.env.template` is
the annotated version and must stay placeholder-free of secrets. Android
release signing uses `android/key.properties`, iOS uses
`ios/Flutter/Secrets.xcconfig`. All are gitignored.

## Deploy

Production API runs on a **Hostinger VPS** as a Docker Compose stack
(PostgreSQL + Gunicorn + Caddy). `mealin.in` is a separate **shared hPanel**
host serving the marketing site and legal pages.

```bash
deploy/hostinger/bootstrap.sh    # first-time setup
deploy/hostinger/deploy.sh       # pull, rebuild, migrate, verify
```

**Read [`deploy/HOSTINGER-DEPLOY.md`](deploy/HOSTINGER-DEPLOY.md)** before any
production change. It documents the two-server topology, the `/api/auth/`
routing prefix, and the known gaps. `deploy/archive/` holds historical GoDaddy /
cPanel / Render reports — those describe a stack that no longer runs.

Automated deploys: `.github/workflows/deploy-backend.yml` (manual trigger,
requires typing `DEPLOY`).