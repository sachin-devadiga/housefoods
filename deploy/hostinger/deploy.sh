#!/usr/bin/env bash
# Build and start the Mealin backend stack on the Hostinger VPS, then verify it.
#
#   bash ~/mealin-api/deploy/hostinger/deploy.sh
#
# Verification is deliberately run from INSIDE the container. From the host,
# settings.py:249 sets SECURE_SSL_REDIRECT when DEBUG is False, so hitting
# http://<VPS-IP>:8000 just 301-redirects to https and fails until Caddy has a
# certificate — which only happens after the DNS record is pointed at this box.

set -euo pipefail

ROOT="${ROOT:-$HOME/mealin-api}"
say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

cd "$ROOT/backend"

say "Checking .env"
[ -f .env ] || die "backend/.env missing — run bootstrap.sh first"
grep -q "REPLACE_" .env && {
  echo "    backend/.env still contains REPLACE_ placeholders:" >&2
  grep -n "REPLACE_" .env | sed 's/^/      /' >&2
  die "fill those in first"
}
grep -qE '^DATABASE_URL=postgres://[^@]+@db:5432/' .env || {
  echo "    DATABASE_URL must be postgres://...@db:5432/mealin" >&2
  echo "    'db' is the compose service name. settings.py falls back to the" >&2
  echo "    MySQL engine when DATABASE_URL is empty, which cannot talk to Postgres." >&2
  die "DATABASE_URL is wrong"
}
echo "    .env looks complete"

say "Building images"
docker compose build --pull

say "Starting the stack"
docker compose up -d

say "Waiting for health (up to 180s)"
for i in $(seq 1 60); do
  status=$(docker inspect --format '{{.State.Health.Status}}' \
    "$(docker compose ps -q web)" 2>/dev/null || echo starting)
  [ "$status" = "healthy" ] && break
  printf '\r    web: %-12s (%ss)' "$status" "$((i * 3))"
  sleep 3
done
echo

docker compose ps

say "Container logs (web)"
docker compose logs --tail=40 web

say "Verification — from inside the container"
echo "  This bypasses SECURE_SSL_REDIRECT, so it works before DNS is cut over."
echo
health=$(docker compose exec -T web curl -s localhost:8000/api/auth/admin-health/)
echo "  $health"

echo "$health" | grep -q '"ok":true' \
  || die "admin-health did not return ok:true — see the logs above"

models=$(echo "$health" | grep -oE 'admin_models":"ok:[0-9]+' | cut -d: -f3)
echo
if [ "$models" -lt 31 ] 2>/dev/null; then
  die "admin_models is $models, expected 31. Migrations 0017/0018 did not run — the subscription tables are missing."
fi
echo "  admin_models: $models  (expected 31 — proves the new build is live)"

echo
echo "  Checking the subscription tables exist:"
docker compose exec -T web python manage.py shell -c "
from django.db import connection
with connection.cursor() as c:
    names = connection.introspection.table_names(c)
for t in ('meal_plans','plan_slots','subscriptions','subscription_meals'):
    print(f'    {t:20} {\"present\" if t in names else \"MISSING\"}')
"

say "Done — the stack is running on this VPS"
cat <<EOF

  Still on GoDaddy? Good. api.mealin.in has NOT been changed yet.

  To verify media serving before touching DNS:
    docker compose exec -T web sh -c 'echo hi > media/probe.txt'
    docker compose exec -T web curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/media/probe.txt
    # expect: 200

  Your public IP for the Brevo allowlist and the DNS cutover:
    curl -4 -s ifconfig.co

  Next: set the api A record to that IP (TTL 300 first), then re-run
  deploy.sh and confirm:
    curl -s https://api.mealin.in/api/auth/admin-health/
EOF