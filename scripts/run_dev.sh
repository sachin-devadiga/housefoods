#!/usr/bin/env bash
# Run the Mealin app on the Linux desktop with live reload.
#
#   ./scripts/run_dev.sh                 # customer role
#   ./scripts/run_dev.sh chef            # kitchen role
#   ./scripts/run_dev.sh delivery_partner
#
#   R = hot reload   r = hot restart   q = quit
#
# API: talks to https://api.mealin.in (the live production Django backend and
# its database) by default -- the same value AppConstants.apiBaseUrl uses when
# no --dart-define is passed. To use a local Django instead:
#   API_BASE_URL=http://localhost:8000 ./scripts/run_dev.sh     (see scripts/start_backend.sh)
#
# Known limitation: push notifications do not work here. firebase_messaging has
# no Linux desktop implementation and DefaultFirebaseOptions deliberately throws
# for TargetPlatform.linux. main.dart catches that, so startup continues -- you
# just get no FCM tokens and no push. Everything else (auth, orders, SDUI) is
# unaffected. Test notifications on a real Android device.
#
# This exists because this machine has no `clang` (flutter hardcodes CC/CXX at
# packages/flutter_tools/lib/src/linux/build_linux.dart:197 and sudo is not
# available non-interactively). It points the build at gcc and at dev headers
# unpacked under ~/.local/gstreamer-dev. Once you run
#   sudo apt install clang libsecret-1-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
# you can delete this script and use `flutter run -d linux` directly.

set -euo pipefail

# Always run from the repo root regardless of where this script lives.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROLE="${1:-customer}"
PREFIX="$HOME/.local/gstreamer-dev/usr"
LIBDIR="$PREFIX/lib/x86_64-linux-gnu"

export PATH="$HOME/.local/flutter-shims:$PATH"
export PKG_CONFIG_PATH="$LIBDIR/pkgconfig:$PREFIX/share/pkgconfig"
export LIBRARY_PATH="$LIBDIR"

exec flutter run -d linux \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://api.mealin.in}" \
  --dart-define=APP_ROLE="$ROLE" \
  "${@:2}"
