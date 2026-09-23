#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
developer_dir="$(xcode-select -p)"
frameworks="$developer_dir/Library/Developer/Frameworks"
if [ -d "$frameworks/Testing.framework" ]; then
    swift test --disable-sandbox --disable-xctest --cache-path "$PWD/.build/cache" \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xlinker -rpath -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib" \
        -Xlinker -F -Xlinker "$frameworks" "$@"
else
    swift test --disable-sandbox --disable-xctest --cache-path "$PWD/.build/cache" "$@"
fi
python3 -m unittest discover -s Tests -p 'test_*.py' -v
