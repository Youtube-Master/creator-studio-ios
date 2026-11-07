#!/bin/bash
# macOS(Xcode)에서: 서명 안 한 CreatorStudio.ipa를 만든다(설치할 때 Sideloadly가 애플 ID로 서명).
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build && mkdir -p build/Payload/CreatorStudio.app
APP=build/Payload/CreatorStudio.app
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun -sdk iphoneos swiftc -O -sdk "$SDK" -target arm64-apple-ios15.0 App/main.swift -o "$APP/CreatorStudio"
cp App/Info.plist "$APP/Info.plist"
cp -R App/app "$APP/app"
cp App/AppIcon120.png "$APP/AppIcon60x60@2x.png"
cp App/AppIcon180.png "$APP/AppIcon60x60@3x.png"
xcrun actool App/Assets.xcassets --compile "$APP" --platform iphoneos --minimum-deployment-target 15.0 \
  --app-icon AppIcon --output-partial-info-plist build/partial.plist --target-device iphone --output-format human-readable-text || echo "actool 실패(아이콘은 낱장 파일로)"
/usr/libexec/PlistBuddy -c "Add :DTPlatformName string iphoneos" "$APP/Info.plist" || true
/usr/libexec/PlistBuddy -c "Add :DTSDKName string iphoneos$(xcrun --sdk iphoneos --show-sdk-version)" "$APP/Info.plist" || true
plutil -convert binary1 "$APP/Info.plist"
(cd build && zip -qry CreatorStudio.ipa Payload)
ls -la build/CreatorStudio.ipa
