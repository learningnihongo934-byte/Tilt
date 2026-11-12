#!/bin/bash
# Build Tilt.app.  ./build.sh          -> build.noindex/Tilt.app
#                  ./build.sh install  -> also copy to /Applications and open it
#                  ./build.sh dmg      -> also make build.noindex/Tilt.dmg
set -euo pipefail
cd "$(dirname "$0")"
APP=build.noindex/Tilt.app  # .noindex keeps Spotlight from listing a second Tilt
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target "$(uname -m)-apple-macos13.0" Sources/main.swift -o "$APP/Contents/MacOS/Tilt"

swift tools/make-icon.swift build.noindex/Tilt.iconset
iconutil -c icns build.noindex/Tilt.iconset -o "$APP/Contents/Resources/Tilt.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Tilt</string>
  <key>CFBundleDisplayName</key><string>Tilt</string>
  <key>CFBundleIdentifier</key><string>tech.rennko.tilt</string>
  <key>CFBundleExecutable</key><string>Tilt</string>
  <key>CFBundleIconFile</key><string>Tilt</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"

case "${1:-}" in
  install)
    pkill -x Tilt 2>/dev/null || true
    rm -rf /Applications/Tilt.app && cp -R "$APP" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$APP" 2>/dev/null || true
    open /Applications/Tilt.app
    echo "Installed to /Applications/Tilt.app" ;;
  dmg)
    rm -f build.noindex/Tilt.dmg
    hdiutil create -volname Tilt -srcfolder "$APP" -ov -format UDZO build.noindex/Tilt.dmg >/dev/null
    echo "Made build.noindex/Tilt.dmg" ;;
esac
