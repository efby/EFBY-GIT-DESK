#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
options=(--disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security --scratch-path .build --disable-keychain --disable-netrc --configuration "$configuration")
if [[ "${EFBY_UNIVERSAL:-0}" == "1" ]]; then options+=(--arch arm64 --arch x86_64); fi
swift build "${options[@]}"
binary_path="$(swift build "${options[@]}" --show-bin-path)"
output="$PWD/dist/EFBY Git Desk.app"
staging="$(mktemp -d "$PWD/.build/package.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/EFBY Git Desk.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_path/EfbyGitDesk" "$bundle/Contents/MacOS/"
cp "$binary_path/EfbyGitDeskCredential" "$bundle/Contents/MacOS/"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
if [[ -n "${APP_VERSION:-}" ]]; then
    [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "APP_VERSION debe tener formato X.Y.Z." >&2; exit 1; }
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$bundle/Contents/Info.plist"
fi
codesign --force --sign - --identifier com.efby.EfbyGitDesk.Credential "$bundle/Contents/MacOS/EfbyGitDeskCredential"
codesign --force --sign - --identifier com.efby.EfbyGitDesk "$bundle"
codesign --verify --deep --strict "$bundle"
mkdir -p "$PWD/dist"
if [ -e "$output" ]; then mv "$output" "$staging/previous.app"; fi
mv "$bundle" "$output"
printf 'Aplicación de desarrollo: %s\n' "$output"
