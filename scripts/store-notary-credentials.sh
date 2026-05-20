#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${1:-BarDock}"

if [[ -z "${APPLE_ID:-}" || -z "${TEAM_ID:-}" ]]; then
  cat >&2 <<EOF
Usage:
  APPLE_ID="you@example.com" TEAM_ID="ABCDE12345" ./scripts/store-notary-credentials.sh

This stores notarization credentials in your login keychain under profile:
  ${PROFILE_NAME}

You will be prompted for an app-specific password.
Create one at:
  https://appleid.apple.com/account/manage
EOF
  exit 2
fi

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID"
