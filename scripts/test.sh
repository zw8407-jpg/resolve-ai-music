#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
developer_dir="$(xcode-select -p)"
frameworks="$developer_dir/Library/Developer/Frameworks"
test_options=(--disable-sandbox --cache-path "$PWD/.build/cache")

# SwiftPM added this flag together with the Swift Testing runner. Keep the
# script usable with older command-line tools while CI uses Xcode 16+.
if swift test --help 2>&1 | grep -q -- '--disable-xctest'; then
    test_options+=(--disable-xctest)
fi

if [ -d "$frameworks/Testing.framework" ]; then
    swift test "${test_options[@]}" \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xlinker -rpath -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib" \
        -Xlinker -F -Xlinker "$frameworks" "$@"
else
    swift test "${test_options[@]}" "$@"
fi
python3 -m unittest discover -s Tests -p 'test_*.py' -v
