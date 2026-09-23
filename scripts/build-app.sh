#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --disable-sandbox --cache-path "$PWD/.build/cache"
app="dist/Resolve AI Music.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/ResolveAIMusic "$app/Contents/MacOS/ResolveAIMusic"
root_resource_bundle="$app/ResolveAIMusic_ResolveAIMusic.bundle"
if [[ -d "$root_resource_bundle" ]]; then rm -R "$root_resource_bundle"; fi
cp -R .build/release/ResolveAIMusic_ResolveAIMusic.bundle "$app/Contents/Resources/"

icon_source="Assets/AppIconSource.png"
iconset="$PWD/.build/AppIcon.iconset"
if [[ ! -f "$icon_source" ]]; then
  printf 'Missing app icon source: %s\n' "$icon_source" >&2
  exit 1
fi
if [[ -d "$iconset" ]]; then rm -R "$iconset"; fi
mkdir -p "$iconset"
sips -z 16 16 "$icon_source" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset/icon_512x512.png" >/dev/null
cp "$icon_source" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

cp packaging/Info.plist "$app/Contents/Info.plist"
touch "$app"
codesign --force --deep --sign - "$app"
printf 'Built: %s\n' "$PWD/$app"
