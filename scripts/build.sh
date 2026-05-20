#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/BarDock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
CACHE_DIR="$BUILD_DIR/cache"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_TOOL="$CACHE_DIR/GenerateAppIcon"
ICONSET_DIR="$CACHE_DIR/AppIcon.iconset"
ASSETS_DIR="$CACHE_DIR/Assets.xcassets"
APPICONSET_DIR="$ASSETS_DIR/AppIcon.appiconset"
PROJECT_ICON_PNG="$ROOT_DIR/Resources/AppIcon.png"
PROJECT_ICON_ICNS="$ROOT_DIR/Resources/AppIcon.icns"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CACHE_DIR"

xcrun swiftc \
  -target arm64-apple-macos14.0 \
  -module-cache-path "$CACHE_DIR/ModuleCache" \
  -framework AppKit \
  -o "$ICON_TOOL" \
  "$ROOT_DIR/scripts/GenerateAppIcon.swift"

"$ICON_TOOL" "$ICONSET_DIR" "$PROJECT_ICON_PNG" "$PROJECT_ICON_ICNS"
cp "$PROJECT_ICON_ICNS" "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ASSETS_DIR"
mkdir -p "$APPICONSET_DIR"
cp "$ICONSET_DIR"/*.png "$APPICONSET_DIR/"
cat > "$APPICONSET_DIR/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "size": "16x16", "scale": "1x", "filename": "icon_16x16.png" },
    { "idiom": "mac", "size": "16x16", "scale": "2x", "filename": "icon_16x16@2x.png" },
    { "idiom": "mac", "size": "32x32", "scale": "1x", "filename": "icon_32x32.png" },
    { "idiom": "mac", "size": "32x32", "scale": "2x", "filename": "icon_32x32@2x.png" },
    { "idiom": "mac", "size": "128x128", "scale": "1x", "filename": "icon_128x128.png" },
    { "idiom": "mac", "size": "128x128", "scale": "2x", "filename": "icon_128x128@2x.png" },
    { "idiom": "mac", "size": "256x256", "scale": "1x", "filename": "icon_256x256.png" },
    { "idiom": "mac", "size": "256x256", "scale": "2x", "filename": "icon_256x256@2x.png" },
    { "idiom": "mac", "size": "512x512", "scale": "1x", "filename": "icon_512x512.png" },
    { "idiom": "mac", "size": "512x512", "scale": "2x", "filename": "icon_512x512@2x.png" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
JSON
if ! xcrun actool \
  --compile "$RESOURCES_DIR" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$CACHE_DIR/AssetCatalogInfo.plist" \
  "$ASSETS_DIR" >/dev/null 2>&1; then
  echo "Warning: could not compile asset catalog; using AppIcon.icns fallback." >&2
fi

xcrun swiftc \
  -target arm64-apple-macos14.0 \
  -O \
  -module-cache-path "$CACHE_DIR/ModuleCache" \
  -parse-as-library \
  -framework AppKit \
  -o "$MACOS_DIR/BarDock" \
  "$ROOT_DIR"/Sources/BarDock/*.swift

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

chmod +x "$MACOS_DIR/BarDock"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
touch "$APP_DIR"
echo "Built $APP_DIR"
