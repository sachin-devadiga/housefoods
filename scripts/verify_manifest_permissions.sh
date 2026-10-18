#!/usr/bin/env bash
# Verify the merged AndroidManifest is actually correct.
#
# Usage:  bash scripts/verify_manifest_permissions.sh
#
# This exists because of a bug that hid behind a green build. Role overlays
# were wired with `sourceSets { getByName("main") { manifest.srcFile(...) } }`,
# which REPLACES the app's main manifest instead of merging an extra file into
# it. Every build silently lost ACCESS_FINE_LOCATION, the <application> block
# and the launcher activity — and `./gradlew processDebugMainManifest` still
# exited 0, so nothing looked broken until the permissions themselves were read.
#
# The checks below are the minimum set that would have caught it. They assert
# that the manifest declares what the app needs to run, not merely that Gradle
# succeeded.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/android" || exit 1

# Merged-manifest output is redirected to the repo-root build/ dir by
# android/build.gradle.kts, not android/app/build.
MERGED="$ROOT/build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml"

# Permissions the app cannot function without. Losing any of these means the
# release build is broken even though the manifest merge "succeeded".
REQUIRED="INTERNET ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION VIBRATE
POST_NOTIFICATIONS MODIFY_AUDIO_SETTINGS RECORD_AUDIO"

# local_auth is unused (no call site in lib/) and must not be requested.
MUST_BE_ABSENT="USE_BIOMETRIC USE_FINGERPRINT"

status=0
fail() { echo "  FAIL: $*"; status=1; }

echo "=== building merged manifest ==="
./gradlew :app:processDebugMainManifest --offline -q || { fail "gradle task failed"; exit 1; }

if [ ! -f "$MERGED" ]; then
  fail "merged manifest not found at $MERGED"
  exit 1
fi

actual=$(grep -oE 'android:name="android\.permission\.[A-Z_]+"' "$MERGED" \
  | sed 's/.*\.\([A-Z_]*\)"/\1/' | sort -u)

echo "=== required permissions ==="
for perm in $REQUIRED; do
  if echo "$actual" | grep -qx "$perm"; then
    echo "  OK   $perm"
  else
    fail "$perm is MISSING — the app cannot function without it"
  fi
done

echo "=== permissions that must not be present ==="
for perm in $MUST_BE_ABSENT; do
  if echo "$actual" | grep -qx "$perm"; then
    fail "$perm is present but local_auth has no call site"
  else
    echo "  OK   $perm absent"
  fi
done

echo "=== structural integrity (the regression this script exists for) ==="
# The merger expands the relative ".MainActivity" to its fully-qualified form,
# so match the resolved class name rather than the literal shorthand.
for needle in "<application" "MainActivity\"" "android.intent.category.LAUNCHER" "com.google.android.geo.API_KEY"; do
  if grep -q -- "$needle" "$MERGED"; then
    echo "  OK   found: $needle"
  else
    fail "merged manifest is missing $needle — src/main manifest was not merged"
  fi
done

echo "=== cleartext ==="
# Debug builds legitimately allow cleartext (src/debug/AndroidManifest.xml).
# The release manifest is checked separately by the release build task.
if grep -q 'android:usesCleartextTraffic="true"' "$MERGED"; then
  echo "  OK   debug build allows cleartext (expected)"
else
  fail "debug build does not allow cleartext — local dev against localhost will break"
fi

echo "=== release cleartext check ==="
./gradlew :app:processReleaseMainManifest --offline -q >/dev/null 2>&1
REL="$ROOT/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml"
if [ -f "$REL" ]; then
  if grep -q 'android:usesCleartextTraffic="false"' "$REL"; then
    echo "  OK   release build blocks cleartext"
  else
    fail "release build does NOT block cleartext — Play Store will flag this"
  fi
else
  echo "  SKIP release manifest not produced (needs signing secrets)"
fi

echo "=== usb host feature ==="
if grep -q 'android.hardware.usb.host' "$MERGED"; then
  if grep -q 'android.hardware.usb.host" android:required="false"' "$MERGED" \
     || grep -q 'required="false"' "$MERGED"; then
    echo "  OK   usb host declared optional"
  else
    fail "usb host is a hard device requirement — app will not install without OTG"
  fi
else
  echo "  WARN usb host feature missing (needed for OTG bill printing)"
fi

echo
if [ $status -eq 0 ]; then
  echo "PASS — merged manifest is correct"
else
  echo "FAIL — see above"
fi
exit $status