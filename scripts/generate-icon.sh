#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
swift Tools/generate_app_icon.swift Resources/Brand/EfbyLogo.ai Resources/AppIcon.png
icon_staging="$(mktemp -d "$PWD/.build/icon.XXXXXX")"
trap 'rm -rf "$icon_staging"' EXIT
iconset="$icon_staging/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
