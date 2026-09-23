#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

signing_identity="${SIGNING_IDENTITY:-}"
notary_profile="${NOTARY_PROFILE:-}"
app="dist/Resolve AI Music.app"
release_dir="dist/release"
entitlements="packaging/ResolveAIMusic.entitlements"

if [[ -z "$signing_identity" ]]; then
  printf 'SIGNING_IDENTITY is required (Developer ID Application).\n' >&2
  exit 1
fi
if [[ -z "$notary_profile" ]]; then
  printf 'NOTARY_PROFILE is required (notarytool Keychain profile).\n' >&2
  exit 1
fi

bash scripts/test.sh
bash scripts/build-app.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
archive="Resolve-AI-Music-v${version}-macOS.zip"
submission="dist/Resolve-AI-Music-notarization.zip"

codesign --force --deep --options runtime --timestamp \
  --entitlements "$entitlements" --sign "$signing_identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

rm -f "$submission"
ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

mkdir -p "$release_dir"
rm -f "$release_dir/$archive" "$release_dir/SHA256SUMS.txt" "$submission"
ditto -c -k --keepParent "$app" "$release_dir/$archive"
(
  cd "$release_dir"
  shasum -a 256 "$archive" > SHA256SUMS.txt
)

printf 'Release package: %s/%s\n' "$PWD/$release_dir" "$archive"
printf 'Checksum: %s/SHA256SUMS.txt\n' "$PWD/$release_dir"
