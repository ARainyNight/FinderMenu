#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/work/module-cache"
xcrun swiftc -swift-version 6 -module-cache-path "$PROJECT_ROOT/work/module-cache" \
    "$PROJECT_ROOT"/Sources/Shared/*.swift "$PROJECT_ROOT/Sources/App/HiddenFilesService.swift" \
    "$PROJECT_ROOT/Tests/main.swift" \
    -framework AppKit -o "$PROJECT_ROOT/work/behavior-tests"
"$PROJECT_ROOT/work/behavior-tests" "$PROJECT_ROOT"

APP="$PROJECT_ROOT/build/FinderMenu.app"
EXTENSION="$APP/Contents/PlugIns/FinderMenuExtension.appex"
plutil -lint "$APP/Contents/Info.plist" "$EXTENSION/Contents/Info.plist" "$PROJECT_ROOT/Resources/Extension.entitlements" \
    "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings" \
    "$EXTENSION/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
codesign --verify --deep --strict "$APP"
printf 'Bundle declarations and signatures verified.\n'
