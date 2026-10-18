# MEALIN — Production Deploy (Hostinger)

**This is the live deployment document.** The GoDaddy / cPanel / Passenger /
Render reports are historical only and live in `deploy/archive/`. They describe
an architecture that no longer runs — do not follow them.

## Topology — two servers, two jobs

| Host | Resolves to | Role | Serves |
|------|-------------|------|--------|
| `api.mealin.in` | `88.222.215.239` | Hostinger **VPS** | Django + DRF, PostgreSQL 16, Caddy (TLS) |
| `mealin.in` | `2.57.91.91` | Hostinger **shared / hPanel** | Marketing site, privacy policy, terms, support |

The apex domain is **not** served by the API. Static marketing content goes on
the shared host; the API is a separate VPS. They are deliberately independent so
a marketing deploy can never take the API down.

## API stack (VPS)

Defined in `backend/docker-compose.yml`:

| Service | Image | Notes |
|---------|-------|-------|
| `db` | `postgres:16-alpine` | internal only — Postgres is **not** published to the host |
| `web` | built from `backend/Dockerfile` | Gunicorn, non-root, runs migrate + collectstatic + create_admin on start |
| `caddy` | `caddy:2-alpine` | auto-TLS for `api.mealin.in`, reverse-proxies to `web:8000` |

```bash
cd ~/mealin-api/deploy/hostinger
bash bootstrap.sh    # first-time setup only
bash deploy.sh       # pull, rebuild, migrate, verify
```

`deploy.sh` refuses to run while `backend/.env` still contains `REPLACE_`
placeholders, and hard-fails unless `DATABASE_URL` is `postgres://…@db:5432/…`.

> **`db` is a compose service name, not `localhost`.** `settings.py` falls back
> to a MySQL engine when `DATABASE_URL` is empty, which cannot talk to the
> Postgres container — the container then dies on boot. This is the single most
> common way this deployment fails.

## Verify

```bash
# public path — TLS, DNS, Django and the database together
curl -s https://api.mealin.in/api/auth/admin-health/
# {"ok":true,"checks":{"database":"ok",...,"django":"5.2.17","admin_models":"ok:31"}}
```

**Routing trap:** every API route lives under `/api/auth/`, because
`backend/backend/urls.py` mounts `api.urls` at `api/auth/`.

| Correct | Wrong (404) |
|---------|-------------|
| `/api/auth/admin-health/` | `/api/admin-health/` |
| `/api/auth/app-version/` | `/api/app-version/` |
| `/api/auth/kitchens/` | `/api/kitchens/` |

`admin_models` is asserted to be **31** by `deploy.sh`. A lower number means
migrations 0017/0018 did not run and the subscription tables are missing.

## Known gaps

- **`mealin.in` TLS is not issued yet.** The apex domain currently fails the
  TLS handshake (`tlsv1 alert internal error`). Install AutoSSL in hPanel
  (Security → SSL → `mealin.in` + `www`, force HTTPS) before serving anything
  from it. This also blocks the Play Store privacy-policy URL.
- **Release signing is intentionally uncommitted.** `android/key.properties` and
  the keystore are gitignored. A backup lives outside the repo — losing the
  upload key requires a Google Support reset request.
- **`admin_models` count.** 31 was correct at the time of writing. Bump it in
  `deploy.sh` when migrations add models, or the deploy check becomes a lie.