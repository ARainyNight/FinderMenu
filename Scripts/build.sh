#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_ROOT/build/FinderMenu.app"
EXTENSION="$APP/Contents/PlugIns/FinderMenuExtension.appex"
SDK="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macosx13.0"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Templates" \
    "$APP/Contents/Resources/zh-Hans.lproj" "$EXTENSION/Contents/Resources/zh-Hans.lproj" \
    "$EXTENSION/Contents/MacOS" "$PROJECT_ROOT/work/module-cache"

printf 'Building FinderMenu for %s\n' "$TARGET"
xcrun swiftc -swift-version 6 -sdk "$SDK" -target "$TARGET" \
    -module-cache-path "$PROJECT_ROOT/work/module-cache" \
    -module-name FinderMenu -O \
    "$PROJECT_ROOT"/Sources/Shared/*.swift "$PROJECT_ROOT"/Sources/App/*.swift \
    -framework AppKit -framework FinderSync \
    -o "$APP/Contents/MacOS/FinderMenu"

printf 'Building Finder Sync extension\n'
xcrun swiftc -swift-version 6 -sdk "$SDK" -target "$TARGET" \
    -module-cache-path "$PROJECT_ROOT/work/module-cache" \
    -module-name FinderMenuExtension -application-extension -O \
    "$PROJECT_ROOT/Sources/Shared/MenuAction.swift" \
    "$PROJECT_ROOT/Sources/Shared/DirectoryResolver.swift" \
    "$PROJECT_ROOT/Sources/Shared/CutSelection.swift" \
    "$PROJECT_ROOT/Sources/Shared/CutClipboard.swift" \
    "$PROJECT_ROOT/Sources/Shared/MoveRequest.swift" \
    "$PROJECT_ROOT"/Sources/Extension/*.swift \
    -framework AppKit -framework FinderSync -lextension \
    -o "$EXTENSION/Contents/MacOS/FinderMenuExtension"

cp "$PROJECT_ROOT/Resources/App-Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/Extension-Info.plist" "$EXTENSION/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/Templates/Empty.txt" "$APP/Contents/Resources/Templates/Empty.txt"
cp "$PROJECT_ROOT/Resources/Templates/Empty.md" "$APP/Contents/Resources/Templates/Empty.md"
for bundle in "$APP" "$EXTENSION"; do
    cp "$PROJECT_ROOT/Resources/zh-Hans.lproj/InfoPlist.strings" \
        "$bundle/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
done

printf 'Building application icon\n'
xcrun swift -swift-version 6 -sdk "$SDK" \
    -module-cache-path "$PROJECT_ROOT/work/module-cache" \
    "$PROJECT_ROOT/Scripts/generate-icon.swift" "$PROJECT_ROOT/work/AppIcon.iconset"
iconutil --convert icns "$PROJECT_ROOT/work/AppIcon.iconset" --output "$PROJECT_ROOT/work/AppIcon.icns"
cp "$PROJECT_ROOT/work/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$PROJECT_ROOT/work/AppIcon.icns" "$EXTENSION/Contents/Resources/AppIcon.icns"

codesign --force --sign - --entitlements "$PROJECT_ROOT/Resources/Extension.entitlements" "$EXTENSION"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built and verified: %s\n' "$APP"
