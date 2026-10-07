#!/bin/bash
set -euo pipefail
for app in /Applications/Xcode_27.1.app /Applications/Xcode_27.0.app /Applications/Xcode_26.5.app /Applications/Xcode_26.4.1.app /Applications/Xcode_26.4.app /Applications/Xcode.app; do
    if [[ -d "$app" ]]; then sudo xcode-select -s "$app"; break; fi
done
xcodebuild -version
swift --version
swift --version | python3 -c 'import re,sys; version=re.search(r"Swift version (\d+)\.(\d+)",sys.stdin.read()); assert version and tuple(map(int,version.groups())) >= (6,2), "Swift 6.2+ requerido"'
