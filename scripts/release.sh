#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/BarDock.app"
SIGNED_ZIP="$BUILD_DIR/BarDock-signed.zip"
RELEASE_ZIP="$BUILD_DIR/BarDock-1.0.0.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-BarDock}"

find_identity() {
  security find-identity -v -p codesigning |
    sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' |
    head -n 1
}

IDENTITY="${DEVELOPER_ID_APPLICATION:-$(find_identity)}"

if [[ -z "$IDENTITY" ]]; then
  cat >&2 <<'EOF'
No Developer ID Application signing identity was found.

Install a Developer ID Application certificate into your login keychain, then retry.
You can check with:
  security find-identity -v -p codesigning
EOF
  exit 2
fi

echo "Building BarDock..."
"$ROOT_DIR/scripts/build.sh"

echo "Signing with: $IDENTITY"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$SIGNED_ZIP" "$RELEASE_ZIP"
ditto -c -k --keepParent "$APP_DIR" "$SIGNED_ZIP"

echo "Submitting for notarization with keychain profile: $NOTARY_PROFILE"
xcrun notarytool submit "$SIGNED_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"

echo "Checking Gatekeeper assessment..."
spctl --assess --type execute --verbose=4 "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$RELEASE_ZIP"
echo "Release ready: $RELEASE_ZIP"
