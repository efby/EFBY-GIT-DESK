#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
signing=0
notarizing=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign) signing=1 ;;
        --notarize) signing=1; notarizing=1 ;;
        --universal) export EFBY_UNIVERSAL=1 ;;
        *) echo "Uso: scripts/build-dmg.sh [--universal] [--sign] [--notarize]" >&2; exit 1 ;;
    esac
    shift
done
identity="${DEVELOPER_ID_APP:-Developer ID Application: EFBY SERVICIOS INFORMATICOS LIMITADA (${APPLE_TEAM_ID:-FYU5QTGXLB})}"
profile="${NOTARY_PROFILE:-efby-requestlabs-notary}"
notary_options=(--keychain-profile "$profile")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then notary_options+=(--keychain "$NOTARY_KEYCHAIN"); fi
if [[ "$signing" == "1" ]]; then
    security find-identity -v -p codesigning | grep -F -- "$identity" >/dev/null || { echo "Falta el certificado Developer ID solicitado." >&2; exit 1; }
fi
if [[ "$notarizing" == "1" ]]; then
    xcrun notarytool history "${notary_options[@]}" --output-format json >/dev/null
fi
scripts/build-app.sh release
mkdir -p dist
staging="$(mktemp -d "$PWD/dist/package-dmg.XXXXXX")"
mounted=""
cleanup() {
    if [[ -n "$mounted" ]]; then hdiutil detach "$mounted" >/dev/null || true; fi
    rm -rf "$staging"
}
trap cleanup EXIT
app="$staging/EFBY Git Desk.app"
ditto "dist/EFBY Git Desk.app" "$app"
if [[ "$signing" == "1" ]]; then
    # Sign nested code first. No permissive entitlements are needed.
    codesign --force --options runtime --timestamp --sign "$identity" "$app/Contents/MacOS/EfbyGitDeskCredential"
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --deep --strict "$app"
notarize() {
    local artifact="$1" result="$2"
    xcrun notarytool submit "$artifact" "${notary_options[@]}" --wait --timeout 30m --output-format json > "$result"
    python3 - "$result" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple no aceptó la notarización. Consultar el registro con el ID: ' + result.get('id', 'desconocido'))
print('Notarización Accepted: ' + result['id'])
PY
}
if [[ "$notarizing" == "1" ]]; then
    ditto -c -k --keepParent "$app" "$staging/app.zip"
    notarize "$staging/app.zip" "$staging/app-notary.json"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    codesign --verify --deep --strict "$app"
fi
mkdir "$staging/root"
ditto "$app" "$staging/root/EFBY Git Desk.app"
ln -s /Applications "$staging/root/Applications"
printf 'Arrastra EFBY Git Desk a Applications.\nRequiere macOS 14 o posterior y Git instalado.\n' > "$staging/root/Instalación.txt"
hdiutil create -volname "EFBY Git Desk" -srcfolder "$staging/root" -format UDZO "$staging/EFBY-Git-Desk.dmg"
# Do not sign or alter the DMG after creation/notarization.
if [[ "$notarizing" == "1" ]]; then
    notarize "$staging/EFBY-Git-Desk.dmg" "$staging/dmg-notary.json"
    xcrun stapler staple "$staging/EFBY-Git-Desk.dmg"
    xcrun stapler validate "$staging/EFBY-Git-Desk.dmg"
fi
hdiutil verify "$staging/EFBY-Git-Desk.dmg"
mkdir "$staging/mount"
hdiutil attach "$staging/EFBY-Git-Desk.dmg" -readonly -nobrowse -mountpoint "$staging/mount" >/dev/null
mounted="$staging/mount"
codesign --verify --deep --strict "$mounted/EFBY Git Desk.app"
[[ "$(readlink "$mounted/Applications")" == "/Applications" ]]
if [[ "$notarizing" == "1" ]]; then
    xcrun stapler validate "$mounted/EFBY Git Desk.app"
    spctl --assess --type execute --verbose=2 "$mounted/EFBY Git Desk.app"
fi
hdiutil detach "$mounted" >/dev/null
mounted=""
name="EFBY-Git-Desk-dev"
if [[ "$signing" == "1" ]]; then name="EFBY-Git-Desk-signed"; fi
if [[ "$notarizing" == "1" ]]; then name="EFBY-Git-Desk"; fi
if [[ -e "dist/$name" ]]; then mv "dist/$name" "$staging/previous-output"; fi
mkdir -p "dist/$name"
mv "$app" "dist/$name/EFBY Git Desk.app"
if [[ "$notarizing" == "1" ]]; then
    cp "$staging/app-notary.json" "dist/$name/app-notary.json"
    cp "$staging/dmg-notary.json" "dist/$name/dmg-notary.json"
fi
mv -f "$staging/EFBY-Git-Desk.dmg" "dist/$name.dmg"
(cd dist && shasum -a 256 "$name.dmg" > "$name.dmg.sha256")
printf 'DMG verificado: %s/dist/%s.dmg\n' "$PWD" "$name"
if [[ "$notarizing" == "0" ]]; then echo "Build local sin notarización; no es una distribución aprobada por Gatekeeper."; fi
