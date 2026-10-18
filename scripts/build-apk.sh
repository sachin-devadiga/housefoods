#!/usr/bin/env bash
#
# Interactive APK builder for MEALIN.
#
#   ./scripts/build-apk.sh
#
# Asks which role to build (customer / restro / delivery) and which build
# mode (release / debug), then delegates to scripts/build-apks.sh and drops
# the resulting APK into apks/latest/.
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo
echo "============================================"
echo "  MEALIN APK builder"
echo "============================================"
echo
echo "Which APK do you want to build?"
echo "  1) customer   (MEALIN)"
echo "  2) restro     (MEALIN RESTO)"
echo "  3) delivery   (MEALIN RIDER)"
echo "  4) all        (all three)"
echo
read -r -p "Enter choice [1-4]: " choice
case "$choice" in
  1) ROLE="customer" ;;
  2) ROLE="chef" ;;
  3) ROLE="delivery_partner" ;;
  4) ROLE="all" ;;
  *) echo "Invalid choice: $choice"; exit 1 ;;
esac

echo
echo "Build mode?"
echo "  1) release  (signed, needs MAPS_API_KEY + RAZORPAY_KEY + keystore)"
echo "  2) debug    (unsigned, no keys needed)"
echo
read -r -p "Enter choice [1-2] (default 2 - debug, no keys needed): " mode_choice
case "${mode_choice:-2}" in
  1) MODE_FLAG="--release" ;;
  2) MODE_FLAG="--debug" ;;
  *) echo "Invalid choice: $mode_choice"; exit 1 ;;
esac

echo
echo "Building role=$ROLE mode=$MODE_FLAG ..."
exec "$SCRIPT_DIR/build-apks.sh" --role "$ROLE" $MODE_FLAG