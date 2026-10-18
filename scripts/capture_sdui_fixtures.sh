#!/usr/bin/env bash
# Regenerate the SDUI contract fixtures from a live Django server.
#
# The fixtures in test/fixtures/ are captured verbatim from the running backend.
# They are the only check that the Dart parser and the Python schema agree —
# every other SDUI test builds objects by hand, which both sides would happily
# accept even if they had drifted apart.
#
# Run this after changing either:
#   * backend/api/sdui/schema.py   (the Python contract)
#   * lib/core/sdui/sdui_types.dart (the Dart mirror)
#
# Usage: bash scripts/capture_sdui_fixtures.sh [port]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8098}"
BASE="http://127.0.0.1:$PORT"
OUT="$ROOT/test/fixtures"
DB="$(mktemp -u /tmp/sdui_contract_XXXX.sqlite3)"

cd "$ROOT/backend"

cleanup() {
  # Stop the server we started, and never leave the throwaway DB behind.
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
  rm -f "$DB"
}
trap cleanup EXIT

echo "==> migrating a throwaway database"
DATABASE_URL="sqlite:///$DB" .venv/bin/python manage.py migrate --noinput -v 0

echo "==> activating a screen and seeding flags + navigation"
# Left inactive by migration 0002, so activate them to exercise the
# "serve from the database" path rather than the baked-in default path.
# Everything the contract tests assert must be present here — a fixture that
# silently lacks a field makes the test assert nothing.
DATABASE_URL="sqlite:///$DB" .venv/bin/python manage.py shell -c "
from api.sdui.models import ScreenDefinition, FeatureFlag, NavigationConfig
from api.sdui.schema import default_for

ScreenDefinition.objects.filter(key='customer_home').update(is_active=True)

# A published banners spec, as an admin would create from /admin/.
spec = default_for('banners')
spec['root'] = {
    'type': 'banner_carousel', 'id': 'launch', 'height': 180,
    'banners': [{
        'id': 'launch',
        'title': 'Launch week: 20% off',
        'subtitle': 'Home-cooked meals, this week only',
        'action': {'type': 'open_url', 'value': 'https://mealin.in'},
    }],
}
ScreenDefinition.objects.filter(key='banners').delete()
ScreenDefinition.objects.create(
    key='banners', role='customer', version=2, is_active=True, spec=spec)

FeatureFlag.objects.update_or_create(
    key='new_cart',
    defaults={'enabled': True, 'rollout_pct': 100, 'allowed_roles': ['customer']})

NavigationConfig.objects.update_or_create(
    role='customer',
    defaults={'ordered_items': [
        {'id': 'nav_home', 'enabled': True, 'order': 0},
        {'id': 'nav_orders', 'enabled': True, 'order': 1},
        {'id': 'nav_search', 'enabled': False, 'order': 2},
        {'id': 'nav_subscriptions', 'enabled': True, 'order': 3},
        {'id': 'nav_profile', 'enabled': True, 'order': 4},
    ]})
" 2>/dev/null | tail -1

echo "==> starting server on :$PORT"
DATABASE_URL="sqlite:///$DB" .venv/bin/python manage.py runserver "$PORT" --noreload \
  >/tmp/sdui_contract_server.log 2>&1 &
SERVER_PID=$!

# Wait for readiness rather than sleeping a fixed amount.
for _ in $(seq 1 40); do
  if curl -sf "$BASE/api/auth/admin-health/" >/dev/null 2>&1; then break; fi
  sleep 0.5
done
curl -sf "$BASE/api/auth/admin-health/" >/dev/null || {
  echo "server never became healthy; see /tmp/sdui_contract_server.log" >&2
  exit 1
}

mkdir -p "$OUT"
echo "==> capturing"
# NOTE the /api/auth/ prefix: api.urls is mounted at 'api/auth/', so the bare
# /api/config/... path is a 404. This has already tripped up this project once.
curl -sf "$BASE/api/auth/config/bootstrap/" -o "$OUT/sdui_bootstrap.json"
curl -sf "$BASE/api/auth/config/screens/customer_home/" \
  -o "$OUT/sdui_screen_customer_home.json"
curl -sf "$BASE/api/auth/config/screens/banners/" -o "$OUT/sdui_screen_banners.json"
curl -sf "$BASE/api/auth/config/manifest/" -o "$OUT/sdui_manifest.json"

echo "==> captured:"
for f in "$OUT"/*.json; do
  printf '    %-40s %s bytes\n' "$(basename "$f")" "$(wc -c <"$f")"
done

echo
echo "Now run: flutter test test/sdui_contract_test.dart"