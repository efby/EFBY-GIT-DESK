#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
# All suites use Swift Testing. Do not launch the unused XCTest runner first.
swift test --disable-xctest --enable-swift-testing --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security --scratch-path .build --disable-keychain --disable-netrc "$@"
