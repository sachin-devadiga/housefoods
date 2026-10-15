#!/usr/bin/env bash
# Run the Mealin backend (Django) locally against backend/db.sqlite3.
#
#   ./start_backend.sh
#
# This is for LOCAL development only. The desktop app defaults to the live API
# (https://api.mealin.in) so you normally do not need this at all -- see
# run_dev.sh. Use it when you are changing backend/api/*.py and want to
# exercise those changes without deploying.
#
# The local database is empty apart from admin settings, so there is no real
# data here. Login OTP codes land in backend/otp_output.txt.
#
# For the cloud database on the Hostinger VPS, put DATABASE_URL in backend/.env
# and SSH-tunnel the Postgres port -- deliberately not wired up here yet, so it
# cannot silently point at production.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT/backend"
PORT="${PORT:-8000}"

cd "$BACKEND"

if [ ! -x .venv/bin/python ]; then
  echo "ERROR: $BACKEND/.venv missing. Create it with:" >&2
  echo "  python3 -m venv backend/.venv" >&2
  echo "  backend/.venv/bin/pip install -r backend/requirements.txt" >&2
  exit 1
fi

# Free the port, like the old start_server.bat did on Windows.
if command -v fuser >/dev/null 2>&1; then
  fuser -k "${PORT}/tcp" 2>/dev/null || true
fi

# sqlite3 rather than MySQL/Postgres: no driver, no server, no risk of writing
# to the real database by accident.
export DATABASE_URL="sqlite:///db.sqlite3"

echo "  backend : http://localhost:${PORT}"
echo "  database: backend/db.sqlite3 (local, empty)"
echo
echo "  To point the Flutter app here:"
echo "    API_BASE_URL=http://localhost:${PORT} ./run_dev.sh"
echo

.venv/bin/python manage.py migrate
exec .venv/bin/python manage.py runserver "0.0.0.0:${PORT}" --noreload