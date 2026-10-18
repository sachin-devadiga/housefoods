#!/usr/bin/env bash
#
# Build the MEALIN role APKs and place them in apks/.
#
#   ./scripts/build-apks.sh [--role customer|chef|delivery_partner|all] [--debug|--release]
#
# Bash twin of scripts/windows/build-apks.ps1. See apks/README.md.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APK_DIR="$REPO_ROOT/apks"
LATEST_DIR="$APK_DIR/latest"
ARCHIVE_DIR="$APK_DIR/archive"

STRINGS_XML="android/app/src/main/res/values/strings.xml"
GRADLE_PROPS="android/gradle.properties"
KEY_PROPERTIES="android/key.properties"

ROLE="all"
MODE="release"
SPLIT_ABI="false"

# role key -> launcher app name
declare -A APP_NAME=(
  [customer]="MEALIN"
  [chef]="MEALIN RESTO"
  [delivery_partner]="MEALIN RIDER"
)
# role key -> APP_ROLE value written to gradle.properties
declare -A GRADLE_ROLE=(
  [customer]="customer"
  [chef]="chef"
  [delivery_partner]="delivery_partner"
)
# role key -> APK filename stem
declare -A FILE_STEM=(
  [customer]="mealin-customer"
  [chef]="mealin-kitchen"
  [delivery_partner]="mealin-delivery"
)
ROLES=(customer chef delivery_partner)

usage() {
  cat <<'EOF'
Usage: scripts/build-apks.sh [--role ROLE] [--debug|--release] [--split-per-abi]

  --role ROLE   customer | chef | delivery_partner | all   (default: all)
  --debug       build debug APKs (no release signing)
  --release     build release APKs (default)
  --split-per-abi
                one APK per ABI (armeabi-v7a, arm64-v8a, x86_64) instead of
                a single universal APK
  -h, --help    show this help
EOF
}

die() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf '\nWARNING: %s\n' "$1" >&2
}

note() {
  printf '%s\n' "$1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role)
      [ $# -ge 2 ] || die "--role needs a value"
      ROLE="$2"
      shift 2
      ;;
    --role=*)
      ROLE="${1#*=}"
      shift
      ;;
    --debug)
      MODE="debug"
      shift
      ;;
    --release)
      MODE="release"
      shift
      ;;
    --split-per-abi)
      SPLIT_ABI="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

if [ "$ROLE" != "all" ]; then
  if [ -z "${APP_NAME[$ROLE]:-}" ]; then
    usage >&2
    die "unknown role: $ROLE (use customer, chef, delivery_partner, or all)"
  fi
fi

command -v flutter >/dev/null 2>&1 || die "flutter not found on PATH"

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || die "could not read version from pubspec.yaml"

# ---------------------------------------------------------------- preflight

if [ "$MODE" = "release" ]; then
  [ -n "${MAPS_API_KEY:-}" ] || die "MAPS_API_KEY is not set. Google Maps will be blank in release builds. Export it, or build with --debug."

  # AppConstants.razorpayKey falls back to the literal placeholder
  # rzp_test_YOUR_KEY_HERE, so a release build without this ships a broken
  # payment key. CI guards the same way - see .github/workflows/build-android.yml.
  [ -n "${RAZORPAY_KEY:-}" ] || die "RAZORPAY_KEY is not set. A release build without it embeds the placeholder rzp_test_YOUR_KEY_HERE. Export it, or build with --debug."
  case "$RAZORPAY_KEY" in
    *YOUR_KEY*) die "RAZORPAY_KEY still holds the placeholder value. Set the real key." ;;
  esac
  case "$RAZORPAY_KEY" in
    rzp_test_*)
      warn "RAZORPAY_KEY is a TEST key. Fine for sideloading, a Play Store violation if published."
      ;;
  esac

  [ -f "$KEY_PROPERTIES" ] || die "missing $KEY_PROPERTIES - release signing credentials are required"
  STORE_FILE="$(sed -n 's/^storeFile=//p' "$KEY_PROPERTIES" | head -1)"
  [ -n "$STORE_FILE" ] || STORE_FILE="mealin-release.keystore"
  # storeFile in key.properties is resolved relative to android/app/
  RESOLVED_STORE="android/app/$STORE_FILE"
  [ -f "$RESOLVED_STORE" ] || die "release keystore not found at $RESOLVED_STORE (storeFile=$STORE_FILE)"
else
  if [ -z "${MAPS_API_KEY:-}" ]; then
    warn "MAPS_API_KEY is not set - Google Maps will be blank in this build."
  fi
  if [ -z "${RAZORPAY_KEY:-}" ]; then
    warn "RAZORPAY_KEY is not set - payments will use the placeholder key."
  fi
fi

# ------------------------------------------------------- backup and restore

BACKUP_DIR="$(mktemp -d)"
cp "$STRINGS_XML" "$BACKUP_DIR/strings.xml"
cp "$GRADLE_PROPS" "$BACKUP_DIR/gradle.properties"

restore() {
  cp "$BACKUP_DIR/strings.xml" "$STRINGS_XML" 2>/dev/null || true
  cp "$BACKUP_DIR/gradle.properties" "$GRADLE_PROPS" 2>/dev/null || true
  rm -rf "$BACKUP_DIR"
}
trap restore EXIT

# ----------------------------------------------------------------- helpers

set_app_role() {
  local role="$1"
  if grep -q '^APP_ROLE=' "$GRADLE_PROPS"; then
    sed -i "s/^APP_ROLE=.*/APP_ROLE=$role/" "$GRADLE_PROPS"
  else
    printf '\nAPP_ROLE=%s\n' "$role" >> "$GRADLE_PROPS"
  fi
}

write_app_name() {
  local name="$1"
  printf '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">%s</string>\n</resources>\n' \
    "$name" > "$STRINGS_XML"
}

# Move the outgoing APK for a role into archive/<timestamp>/ so latest/ always
# holds exactly one APK per role and no build is lost.
archive_existing() {
  local stem="$1"
  local -a existing=()
  while IFS= read -r f; do
    [ -n "$f" ] && existing+=("$f")
  done < <(find "$LATEST_DIR" -maxdepth 1 -name "${stem}-*.apk" 2>/dev/null || true)

  [ "${#existing[@]}" -gt 0 ] || return 0

  local dest="$ARCHIVE_DIR/$TIMESTAMP"
  mkdir -p "$dest"
  local f
  for f in "${existing[@]}"; do
    mv "$f" "$dest/"
    note "  archived $(basename "$f") -> archive/$TIMESTAMP/"
  done
  write_checksums "$dest"
}

write_checksums() {
  local dir="$1"
  if ! ( cd "$dir" && ls ./*.apk >/dev/null 2>&1 ); then
    rm -f "$dir/SHA256SUMS"
    return 0
  fi
  ( cd "$dir" && rm -f SHA256SUMS && sha256sum ./*.apk > SHA256SUMS 2>/dev/null ) || true
}

# ------------------------------------------------------------------- build

TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$LATEST_DIR" "$ARCHIVE_DIR"

if [ "$ROLE" = "all" ]; then
  BUILD_ROLES=("${ROLES[@]}")
else
  BUILD_ROLES=("$ROLE")
fi

GRADLE_FLAG="--release"
if [ "$MODE" = "debug" ]; then
  GRADLE_FLAG="--debug"
fi
if [ "$SPLIT_ABI" = "true" ]; then
  GRADLE_FLAG="$GRADLE_FLAG --split-per-abi"
fi

note "MEALIN APK build - mode=$MODE version=$VERSION roles=${BUILD_ROLES[*]} split_abi=$SPLIT_ABI"

FAILED=0
for role in "${BUILD_ROLES[@]}"; do
  name="${APP_NAME[$role]}"
  stem="${FILE_STEM[$role]}"
  gradle_role="${GRADLE_ROLE[$role]}"

  printf '\n=== Building %s (%s) ===\n' "$name" "$role"

  write_app_name "$name"
  set_app_role "$gradle_role"

  if [ "$MODE" = "release" ]; then
    maps_key="$MAPS_API_KEY"
  else
    maps_key="${MAPS_API_KEY:-}"
  fi

  if [ "$MODE" = "release" ]; then
    suffix="release"
  else
    suffix="debug"
  fi

  # Clear stale APKs so the collection below sees exactly what this build
  # produced. Timestamps are unreliable here - the repo sits on an NTFS mount
  # with coarse mtime granularity.
  rm -f build/app/outputs/flutter-apk/app-*.apk 2>/dev/null || true

  # Gradle occasionally fails a role build right after an applicationId
  # switch (daemon hiccup). One retry clears it.
  built_ok="false"
  attempt=1
  while [ "$attempt" -le 2 ]; do
    if flutter build apk $GRADLE_FLAG \
      --dart-define=APP_ROLE="$gradle_role" \
      --dart-define=RAZORPAY_KEY="${RAZORPAY_KEY:-}" \
      -PMAPS_API_KEY="$maps_key"; then
      built_ok="true"
      break
    fi
    if [ "$attempt" -eq 1 ]; then
      printf '!! build failed, retrying once\n' >&2
      sleep 5
    fi
    attempt=$((attempt + 1))
  done

  if [ "$built_ok" != "true" ]; then
    printf '=> FAILED to build %s\n' "$stem" >&2
    FAILED=1
    continue
  fi

  # Collect the APKs this build produced. A split build yields one per ABI
  # (app-armeabi-v7a-release.apk, ...); a normal build yields a single
  # universal app-release.apk.
  built_files=()
  while IFS= read -r f; do
    [ -n "$f" ] && built_files+=("$f")
  done < <(find build/app/outputs/flutter-apk -maxdepth 1 -name "app-*.apk" 2>/dev/null | sort || true)

  if [ "${#built_files[@]}" -eq 0 ]; then
    printf '=> FAILED: no APK produced for %s\n' "$stem" >&2
    FAILED=1
    continue
  fi

  archive_existing "$stem"

  for built in "${built_files[@]}"; do
    base="$(basename "$built")"
    if [ "$MODE" = "debug" ]; then
      mode_tag="-DEBUG"
    else
      mode_tag=""
    fi

    if [ "$SPLIT_ABI" = "true" ]; then
      abi="${base#app-}"          # armeabi-v7a-release.apk
      abi="${abi%-$suffix.apk}"   # armeabi-v7a
      if [ "$abi" = "$base" ] || [ -z "$abi" ]; then
        out_name="${stem}-${VERSION}${mode_tag}.apk"
      else
        out_name="${stem}-${VERSION}-${abi}${mode_tag}.apk"
      fi
    else
      out_name="${stem}-${VERSION}${mode_tag}.apk"
    fi

    cp "$built" "$LATEST_DIR/$out_name"
    printf '=> %s\n' "$out_name"
  done
done

write_checksums "$LATEST_DIR"

printf '\n=== Done ===\n'
if [ -d "$LATEST_DIR" ]; then
  for f in "$LATEST_DIR"/*.apk; do
    [ -e "$f" ] || continue
    size="$(du -m "$f" | cut -f1)"
    printf '  %s - %s MB\n' "$(basename "$f")" "$size"
  done
fi

exit "$FAILED"
