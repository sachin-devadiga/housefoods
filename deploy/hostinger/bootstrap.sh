#!/usr/bin/env bash
# One-time Hostinger VPS setup for the Mealin backend.
#
#   ssh you@<VPS-IP>
#   mkdir -p ~/mealin-api && cd ~/mealin-api
#   # paste or scp deploy/hostinger/bootstrap.sh here, then:
#   bash bootstrap.sh
#
# Installs Docker, clones the repo, and lays down .env for you to fill in.
# Safe to re-run: it will not overwrite an existing .env.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/sachin-devadiga/housefoods.git}"
ROOT="${ROOT:-$HOME/mealin-api}"

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

say "Preflight"
command -v curl >/dev/null || die "curl is missing"
[ "$(id -u)" -eq 0 ] && die "run as a normal user with sudo, not as root"
sudo -v || die "sudo needs a password and cannot run non-interactively"

say "Installing Docker"
if command -v docker >/dev/null 2>&1; then
  echo "    docker already present: $(docker --version)"
else
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker.io docker-compose-plugin ca-certificates curl git
fi

sudo systemctl enable --now docker >/dev/null 2>&1 || true
sudo usermod -aG docker "$USER"

if ! docker info >/dev/null 2>&1; then
  echo
  echo "    Docker is installed but this session cannot use it yet."
  echo "    Log out and back in (or run 'newgrp docker'), then re-run this script."
  exit 0
fi
echo "    docker usable: $(docker --version)"

say "Fetching the repository"
mkdir -p "$ROOT"
cd "$ROOT"

if [ -d .git ]; then
  echo "    already a clone, fetching"
  git pull --ff-only || echo "    (pull failed — continuing with the checkout already here)"
else
  git clone "$REPO_URL" .
fi

say "Laying out backend/.env"
cd "$ROOT/backend"

if [ -f .env ]; then
  echo "    .env already exists — leaving it alone"
else
  cp ../deploy/hostinger/vps.env.template .env
  echo "    created backend/.env from vps.env.template"
fi

mkdir -p media
chmod 600 .env

say "Preflight complete"
cat <<'EOF'

  NEXT: fill in the secrets.

    cd ~/mealin-api/backend
    nano .env

  Every REPLACE_ line must be replaced. The ones that bite hardest:

    DATABASE_URL                 password part must match POSTGRES_PASSWORD
    POSTGRES_PASSWORD            any strong password you choose
    FIREBASE_SERVICE_ACCOUNT     whole inline JSON from your laptop .env
    BREVO_*                      copy the five values from your laptop .env

  Generate a secret key with:
    python3 -c "import secrets; print(secrets.token_urlsafe(50))"

  Then deploy:
    bash ~/mealin-api/deploy/hostinger/deploy.sh

  Do NOT change the api.mealin.in DNS record yet. Verify on the VPS IP first.
EOF