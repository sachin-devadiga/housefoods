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

## Secrets

Copy `backend/.env.example` to `backend/.env` (there are also `.godaddy` and
`.hostinger` variants); never commit real values. Android release signing uses
`android/key.properties`, iOS uses `ios/Flutter/Secrets.xcconfig`. Both are
gitignored.

## Deploy

Production runs on a Hostinger VPS via Passenger + WSGI:

```bash
deploy/hostinger/bootstrap.sh    # first-time setup
deploy/hostinger/deploy.sh       # deploy
```

`render.yaml` is the alternative Render.com target.